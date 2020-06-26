// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:process/process.dart';

import '../artifacts.dart';
import '../base/common.dart';
import '../base/io.dart';
import '../base/logger.dart';
import '../base/platform.dart';
import '../base/process.dart';
import '../build_info.dart';
import '../cache.dart';
import '../convert.dart';
import 'code_signing.dart';
import 'devices.dart';

// Error message patterns from ios-deploy output
const String noProvisioningProfileErrorOne = 'Error 0xe8008015';
const String noProvisioningProfileErrorTwo = 'Error 0xe8000067';
const String deviceLockedError = 'e80000e2';
const String unknownAppLaunchError = 'Error 0xe8000022';

class IOSDeploy {
  IOSDeploy({
    @required Artifacts artifacts,
    @required Cache cache,
    @required Logger logger,
    @required Platform platform,
    @required ProcessManager processManager,
  }) : _platform = platform,
       _cache = cache,
       _processUtils = ProcessUtils(processManager: processManager, logger: logger),
       _logger = logger,
       _binaryPath = artifacts.getArtifactPath(Artifact.iosDeploy, platform: TargetPlatform.ios);

  final Cache _cache;
  final String _binaryPath;
  final Logger _logger;
  final Platform _platform;
  final ProcessUtils _processUtils;

  Map<String, String> get iosDeployEnv {
    // Push /usr/bin to the front of PATH to pick up default system python, package 'six'.
    //
    // ios-deploy transitively depends on LLDB.framework, which invokes a
    // Python script that uses package 'six'. LLDB.framework relies on the
    // python at the front of the path, which may not include package 'six'.
    // Ensure that we pick up the system install of python, which includes it.
    final Map<String, String> environment = Map<String, String>.of(_platform.environment);
    environment['PATH'] = '/usr/bin:${environment['PATH']}';
    environment.addEntries(<MapEntry<String, String>>[_cache.dyLdLibEntry]);
    return environment;
  }

  /// Uninstalls the specified app bundle.
  ///
  /// Uses ios-deploy and returns the exit code.
  Future<int> uninstallApp({
    @required String deviceId,
    @required String bundleId,
  }) async {
    final List<String> launchCommand = <String>[
      _binaryPath,
      '--id',
      deviceId,
      '--uninstall_only',
      '--bundle_id',
      bundleId,
    ];

    return _processUtils.stream(
      launchCommand,
      mapFunction: _monitorFailure,
      trace: true,
      environment: iosDeployEnv,
    );
  }

  /// Installs the specified app bundle.
  ///
  /// Uses ios-deploy and returns the exit code.
  Future<int> installApp({
    @required String deviceId,
    @required String bundlePath,
    @required List<String>launchArguments,
    @required IOSDeviceInterface interfaceType,
  }) async {
    final List<String> launchCommand = <String>[
      _binaryPath,
      '--id',
      deviceId,
      '--bundle',
      bundlePath,
      if (interfaceType != IOSDeviceInterface.network)
        '--no-wifi',
      if (launchArguments.isNotEmpty) ...<String>[
        '--args',
        launchArguments.join(' '),
      ],
    ];

    return _processUtils.stream(
      launchCommand,
      mapFunction: _monitorFailure,
      trace: true,
      environment: iosDeployEnv,
    );
  }

  /// Returns [IOSDeployDebugger] wrapping attached debugger logic.
  ///
  /// This method does not install the app. Call [IOSDeployDebugger.launchAndAttach()]
  /// to install and attach the debugger to the specified app bundle.
  IOSDeployDebugger prepareDebuggerForLaunch({
    @required String deviceId,
    @required String bundlePath,
    @required List<String> launchArguments,
    @required IOSDeviceInterface interfaceType,
  }) {
    // Interactive debug session to support sending the lldb detach command.
    final List<String> launchCommand = <String>[
      'script',
      '-t',
      '0',
      '/dev/null',
      _binaryPath,
      '--id',
      deviceId,
      '--bundle',
      bundlePath,
      '--debug',
      if (interfaceType != IOSDeviceInterface.network)
        '--no-wifi',
      if (launchArguments.isNotEmpty) ...<String>[
        '--args',
        launchArguments.join(' '),
      ],
    ];
    return IOSDeployDebugger(
      launchCommand: launchCommand,
      logger: _logger,
      processUtils: _processUtils,
      iosDeployEnv: iosDeployEnv,
    );
  }

  /// Installs and then runs the specified app bundle.
  ///
  /// Uses ios-deploy and returns the exit code.
  Future<int> launchApp({
    @required String deviceId,
    @required String bundlePath,
    @required List<String> launchArguments,
    @required IOSDeviceInterface interfaceType,
  }) async {
    final List<String> launchCommand = <String>[
      _binaryPath,
      '--id',
      deviceId,
      '--bundle',
      bundlePath,
      if (interfaceType != IOSDeviceInterface.network)
        '--no-wifi',
      '--justlaunch',
      if (launchArguments.isNotEmpty) ...<String>[
        '--args',
        launchArguments.join(' '),
      ],
    ];

    return _processUtils.stream(
      launchCommand,
      mapFunction: _monitorFailure,
      trace: true,
      environment: iosDeployEnv,
    );
  }

  Future<bool> isAppInstalled({
    @required String bundleId,
    @required String deviceId,
  }) async {
    final List<String> launchCommand = <String>[
      _binaryPath,
      '--id',
      deviceId,
      '--exists',
      '--timeout', // If the device is not connected, ios-deploy will wait forever.
      '10',
      '--bundle_id',
      bundleId,
    ];
    final RunResult result = await _processUtils.run(
      launchCommand,
      environment: iosDeployEnv,
    );
    // Device successfully connected, but app not installed.
    if (result.exitCode == 255) {
      _logger.printTrace('$bundleId not installed on $deviceId');
      return false;
    }
    if (result.exitCode != 0) {
      _logger.printTrace('App install check failed: ${result.stderr}');
      return false;
    }
    return true;
  }

  String _monitorFailure(String stdout) => _monitorIOSDeployFailure(stdout, _logger);
}

/// Wrapper to launch app and attach the debugger with ios-deploy.
class IOSDeployDebugger {
  IOSDeployDebugger({
    @required Logger logger,
    @required ProcessUtils processUtils,
    @required List<String> launchCommand,
    @required Map<String, String> iosDeployEnv,
    StreamController<String> debuggerOutput,
  }) : _processUtils = processUtils,
        _logger = logger,
        _launchCommand = launchCommand,
        _iosDeployEnv = iosDeployEnv,
        _debuggerOutput = debuggerOutput ?? StreamController<String>.broadcast();

  factory IOSDeployDebugger.test({
    ProcessManager processManager,
    Logger logger,
  }) {
    final Logger debugLogger = logger ?? BufferLogger.test();
    return IOSDeployDebugger(
      logger: debugLogger,
      processUtils: ProcessUtils(logger: debugLogger, processManager: processManager),
      launchCommand: <String>['ios-deploy'],
      iosDeployEnv: <String, String>{},
    );
  }

  final Logger _logger;
  final ProcessUtils _processUtils;
  final List<String> _launchCommand;
  final Map<String, String> _iosDeployEnv;

  Process _iosDeployProcess;

  Stream<String> get logLines => _debuggerOutput.stream;
  final StreamController<String> _debuggerOutput;

  bool get debuggerAttached => _debuggerAttached;
  bool _debuggerAttached = false;

  /// Launch the app on the device, and attach the debugger.
  ///
  /// Returns whether or not the debugger successfully attached.
  Future<bool> launchAndAttach() async {
    // Return when the debugger attaches, or the ios-deploy process exits.
    final Completer<bool> debuggerCompleter = Completer<bool>();
    try {
      _iosDeployProcess = await _processUtils.start(
        _launchCommand,
        environment: _iosDeployEnv,
      );
      bool lldbRunCalled = false;
      String lastLineFromDebugger;
      final StreamSubscription<String> stdoutSubscription = _iosDeployProcess.stdout
          .transform<String>(utf8.decoder)
          .transform<String>(const LineSplitter())
          .listen((String line) {
        _monitorIOSDeployFailure(line, _logger);

        // (lldb)     run
        // success
        // 2020-09-15 13:42:25.185474-0700 Runner[477:181141] flutter: Observatory listening on http://127.0.0.1:57782/
        if (line == '(lldb)     run') {
          _logger.printTrace(line);
          lldbRunCalled = true;
          return;
        }
        // next line must be "success".
        if (lldbRunCalled && line == 'success') {
          _logger.printTrace(line);
          _debuggerAttached = true;
          debuggerCompleter.complete(true);
          return;
        }
        lldbRunCalled = false;
        if (line.contains('PROCESS_STOPPED') ||
            line.contains('PROCESS_EXITED')) {
          // The app exited or crashed, so stop echoing the output.
          // Don't pass any further ios-deploy debugging messages to the log reader after it exits.
          _debuggerAttached = false;
          _logger.printTrace(line);
          return;
        }

        if (line.contains('error: process launch failed')) {
          // Timed out waiting for the app to launch.
          _debuggerAttached = false;
          _logger.printTrace(line);
          debuggerCompleter.complete(false);
          return;
        }
        if (!debuggerAttached) {
          _logger.printTrace(line);
          return;
        }
        if (lastLineFromDebugger != null && lastLineFromDebugger.isNotEmpty && line.isEmpty) {
          // The lldb console stream from ios-deploy is separated lines by an extra \r\n.
          // To avoid all lines being double spaced, if the last line from the
          // debugger was not an empty line, skip this empty line.
          // This will still cause "legit" logged newlines to be doubled...
        } else {
          _debuggerOutput.add(line);
        }
        lastLineFromDebugger = line;
      });
      final StreamSubscription<String> stderrSubscription = _iosDeployProcess.stderr
          .transform<String>(utf8.decoder)
          .transform<String>(const LineSplitter())
          .listen((String line) {
        _logger.printTrace(line);
      });
      unawaited(_iosDeployProcess.exitCode.then((int status) {
        _logger.printTrace('ios-deploy exited with code $exitCode');
        _debuggerAttached = false;
        unawaited(stdoutSubscription.cancel());
        unawaited(stderrSubscription.cancel());
      }).whenComplete(() async {
        if (_debuggerOutput.hasListener) {
          // Tell listeners the process died.
          await _debuggerOutput.close();
        }
        if (!debuggerCompleter.isCompleted) {
          debuggerCompleter.complete(false);
        }
        _iosDeployProcess = null;
      }));
    } on ProcessException catch (exception, stackTrace) {
      _logger.printTrace('ios-deploy failed: $exception');
      _debuggerAttached = false;
      _debuggerOutput.addError(exception, stackTrace);
    } on ArgumentError catch (exception, stackTrace) {
      _logger.printTrace('ios-deploy failed: $exception');
      _debuggerAttached = false;
      _debuggerOutput.addError(exception, stackTrace);
    }
    // Wait until the debugger attaches, or the attempt fails.
    return debuggerCompleter.future;
  }

  bool exit() {
    final bool success = (_iosDeployProcess == null) || _iosDeployProcess.kill();
    _iosDeployProcess = null;
    return success;
  }

  void detach() {
    if (!debuggerAttached) {
      return;
    }

    try {
      // Detach lldb from the app process.
      _iosDeployProcess?.stdin?.writeln('process detach');
      _debuggerAttached = false;
    } on SocketException catch (error) {
      // Best effort, try to detach, but maybe the app already exited or already detached.
      _logger.printTrace('Could not detach from debugger: $error');
    }
  }
}

// Maps stdout line stream. Must return original line.
String _monitorIOSDeployFailure(String stdout, Logger logger) {
  // Installation issues.
  if (stdout.contains(noProvisioningProfileErrorOne) || stdout.contains(noProvisioningProfileErrorTwo)) {
    logger.printError(noProvisioningProfileInstruction, emphasis: true);

    // Launch issues.
  } else if (stdout.contains(deviceLockedError)) {
    logger.printError('''
═══════════════════════════════════════════════════════════════════════════════════
Your device is locked. Unlock your device first before running.
═══════════════════════════════════════════════════════════════════════════════════''',
        emphasis: true);
  } else if (stdout.contains(unknownAppLaunchError)) {
    logger.printError('''
═══════════════════════════════════════════════════════════════════════════════════
Error launching app. Try launching from within Xcode via:
    open ios/Runner.xcworkspace

Your Xcode version may be too old for your iOS version.
═══════════════════════════════════════════════════════════════════════════════════''',
        emphasis: true);
  }

  return stdout;
}
