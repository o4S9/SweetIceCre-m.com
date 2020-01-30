// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:platform/platform.dart';
import 'package:process/process.dart';

import '../base/common.dart';
import '../base/context.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/process.dart';
import '../base/user_messages.dart';
import '../base/utils.dart';
import '../base/version.dart';
import '../convert.dart';
import '../doctor.dart';
import '../globals.dart' as globals;
import 'android_sdk.dart';

const int kAndroidSdkMinVersion = 28;
final Version kAndroidJavaMinVersion = Version(1, 8, 0);
final Version kAndroidSdkBuildToolsMinVersion = Version(28, 0, 3);

AndroidWorkflow get androidWorkflow => context.get<AndroidWorkflow>();
AndroidValidator get androidValidator => context.get<AndroidValidator>();
AndroidLicenseValidator get androidLicenseValidator => context.get<AndroidLicenseValidator>();

enum LicensesAccepted {
  none,
  some,
  all,
  unknown,
}

final RegExp licenseCounts = RegExp(r'(\d+) of (\d+) SDK package licenses? not accepted.');
final RegExp licenseNotAccepted = RegExp(r'licenses? not accepted', caseSensitive: false);
final RegExp licenseAccepted = RegExp(r'All SDK package licenses accepted.');

class AndroidWorkflow implements Workflow {
  @override
  bool get appliesToHostPlatform => true;

  @override
  bool get canListDevices => getAdbPath(androidSdk) != null;

  @override
  bool get canLaunchDevices => androidSdk != null && androidSdk.validateSdkWellFormed().isEmpty;

  @override
  bool get canListEmulators => getEmulatorPath(androidSdk) != null;
}

class AndroidValidator extends DoctorValidator {
  AndroidValidator({
    @required AndroidSdk androidSdk,
    @required FileSystem fs,
    @required Platform platform,
    @required ProcessManager processManager,
    @required Stdio stdio,
    @required UserMessages userMessages,
  }) : _androidSdk = androidSdk,
       _fs = fs,
       _platform = platform,
       _processManager = processManager,
       _stdio = stdio,
       _userMessages = userMessages,
       super('Android toolchain - develop for Android devices');

  final AndroidSdk _androidSdk;
  final FileSystem _fs;
  final Platform _platform;
  final ProcessManager _processManager;
  final Stdio _stdio;
  final UserMessages _userMessages;

  @override
  String get slowWarning => '${_task ?? 'This'} is taking a long time...';
  String _task;

  /// Finds the semantic version anywhere in a text.
  static final RegExp _javaVersionPattern = RegExp(r'(\d+)(\.(\d+)(\.(\d+))?)?');

  /// `java -version` response is not only a number, but also includes other
  /// information eg. `openjdk version "1.7.0_212"`.
  /// This method extracts only the semantic version from from that response.
  static String _extractJavaVersion(String text) {
    final Match match = _javaVersionPattern.firstMatch(text ?? '');
    return text?.substring(match.start, match.end);
  }

  /// Returns false if we cannot determine the Java version or if the version
  /// is older that the minimum allowed version of 1.8.
  Future<bool> _checkJavaVersion(String javaBinary, List<ValidationMessage> messages) async {
    _task = 'Checking Java status';
    try {
      if (!globals.processManager.canRun(javaBinary)) {
        messages.add(ValidationMessage.error(userMessages.androidCantRunJavaBinary(javaBinary)));
        return false;
      }
      String javaVersionText;
      try {
        globals.printTrace('java -version');
        final ProcessResult result = await globals.processManager.run(<String>[javaBinary, '-version']);
        if (result.exitCode == 0) {
          final List<String> versionLines = (result.stderr as String).split('\n');
          javaVersionText = versionLines.length >= 2 ? versionLines[1] : versionLines[0];
        }
      } catch (error) {
        globals.printTrace(error.toString());
      }
      if (javaVersionText == null || javaVersionText.isEmpty) {
        // Could not determine the java version.
        messages.add(ValidationMessage.error(userMessages.androidUnknownJavaVersion));
        return false;
      }
      final Version javaVersion = Version.parse(_extractJavaVersion(javaVersionText));
      if (javaVersion < kAndroidJavaMinVersion) {
        messages.add(ValidationMessage.error(userMessages.androidJavaMinimumVersion(javaVersionText)));
        return false;
      }
      messages.add(ValidationMessage(userMessages.androidJavaVersion(javaVersionText)));
      return true;
    } finally {
      _task = null;
    }
  }

  @override
  Future<ValidationResult> validate() async {
    final List<ValidationMessage> messages = <ValidationMessage>[];

    if (_androidSdk == null) {
      // No Android SDK found.
      if (_platform.environment.containsKey(kAndroidHome)) {
        final String androidHomeDir = _platform.environment[kAndroidHome];
        messages.add(ValidationMessage.error(_userMessages.androidBadSdkDir(kAndroidHome, androidHomeDir)));
      } else {
        // Instruct user to set [kAndroidSdkRoot] and not deprecated [kAndroidHome]
        // See https://github.com/flutter/flutter/issues/39301
        messages.add(ValidationMessage.error(_userMessages.androidMissingSdkInstructions(kAndroidSdkRoot)));
      }
      return ValidationResult(ValidationType.missing, messages);
    }

    if (_androidSdk.licensesAvailable && !_androidSdk.platformToolsAvailable) {
      messages.add(ValidationMessage.hint(_userMessages.androidSdkLicenseOnly(kAndroidHome)));
      return ValidationResult(ValidationType.partial, messages);
    }

    messages.add(ValidationMessage(_userMessages.androidSdkLocation(_androidSdk.directory)));

    messages.add(ValidationMessage(_androidSdk.ndk == null
          ? _userMessages.androidMissingNdk
          : _userMessages.androidNdkLocation(_androidSdk.ndk.directory)));

    String sdkVersionText;
    if (_androidSdk.latestVersion != null) {
      if (_androidSdk.latestVersion.sdkLevel < 28 || _androidSdk.latestVersion.buildToolsVersion < kAndroidSdkBuildToolsMinVersion) {
        messages.add(ValidationMessage.error(
          _userMessages.androidSdkBuildToolsOutdated(_androidSdk.sdkManagerPath, kAndroidSdkMinVersion, kAndroidSdkBuildToolsMinVersion.toString())),
        );
        return ValidationResult(ValidationType.missing, messages);
      }
      sdkVersionText = _userMessages.androidStatusInfo(_androidSdk.latestVersion.buildToolsVersionName);

      messages.add(ValidationMessage(_userMessages.androidSdkPlatformToolsVersion(
        _androidSdk.latestVersion.platformName,
        _androidSdk.latestVersion.buildToolsVersionName)));
    } else {
      messages.add(ValidationMessage.error(_userMessages.androidMissingSdkInstructions(kAndroidHome)));
    }

    if (_platform.environment.containsKey(kAndroidHome)) {
      final String androidHomeDir = _platform.environment[kAndroidHome];
      messages.add(ValidationMessage('$kAndroidHome = $androidHomeDir'));
    }
    if (_platform.environment.containsKey(kAndroidSdkRoot)) {
      final String androidSdkRoot = _platform.environment[kAndroidSdkRoot];
      messages.add(ValidationMessage('$kAndroidSdkRoot = $androidSdkRoot'));
    }

    final List<String> validationResult = _androidSdk.validateSdkWellFormed();

    if (validationResult.isNotEmpty) {
      // Android SDK is not functional.
      messages.addAll(validationResult.map<ValidationMessage>((String message) {
        return ValidationMessage.error(message);
      }));
      messages.add(ValidationMessage(_userMessages.androidSdkInstallHelp));
      return ValidationResult(ValidationType.partial, messages, statusInfo: sdkVersionText);
    }

    // Now check for the JDK.
    final String javaBinary = AndroidSdk.findJavaBinary();
    if (javaBinary == null) {
      messages.add(ValidationMessage.error(_userMessages.androidMissingJdk));
      return ValidationResult(ValidationType.partial, messages, statusInfo: sdkVersionText);
    }
    messages.add(ValidationMessage(_userMessages.androidJdkLocation(javaBinary)));

    // Check JDK version.
    if (! await _checkJavaVersion(javaBinary, messages)) {
      return ValidationResult(ValidationType.partial, messages, statusInfo: sdkVersionText);
    }

    // Success.
    return ValidationResult(ValidationType.installed, messages, statusInfo: sdkVersionText);
  }
}

class AndroidLicenseValidator extends DoctorValidator {
  AndroidLicenseValidator() : super('Android license subvalidator',);

  @override
  String get slowWarning => 'Checking Android licenses is taking an unexpectedly long time...';

  @override
  Future<ValidationResult> validate() async {
    final List<ValidationMessage> messages = <ValidationMessage>[];

    // Match pre-existing early termination behavior
    if (androidSdk == null || androidSdk.latestVersion == null ||
        androidSdk.validateSdkWellFormed().isNotEmpty ||
        ! await _checkJavaVersionNoOutput()) {
      return ValidationResult(ValidationType.missing, messages);
    }

    final String sdkVersionText = userMessages.androidStatusInfo(androidSdk.latestVersion.buildToolsVersionName);

    // Check for licenses.
    switch (await licensesAccepted) {
      case LicensesAccepted.all:
        messages.add(ValidationMessage(userMessages.androidLicensesAll));
        break;
      case LicensesAccepted.some:
        messages.add(ValidationMessage.hint(userMessages.androidLicensesSome));
        return ValidationResult(ValidationType.partial, messages, statusInfo: sdkVersionText);
      case LicensesAccepted.none:
        messages.add(ValidationMessage.error(userMessages.androidLicensesNone));
        return ValidationResult(ValidationType.partial, messages, statusInfo: sdkVersionText);
      case LicensesAccepted.unknown:
        messages.add(ValidationMessage.error(userMessages.androidLicensesUnknown));
        return ValidationResult(ValidationType.partial, messages, statusInfo: sdkVersionText);
    }
    return ValidationResult(ValidationType.installed, messages, statusInfo: sdkVersionText);
  }

  Future<bool> _checkJavaVersionNoOutput() async {
    final String javaBinary = AndroidSdk.findJavaBinary();
    if (javaBinary == null) {
      return false;
    }
    if (!globals.processManager.canRun(javaBinary)) {
      return false;
    }
    String javaVersion;
    try {
      final ProcessResult result = await globals.processManager.run(<String>[javaBinary, '-version']);
      if (result.exitCode == 0) {
        final List<String> versionLines = (result.stderr as String).split('\n');
        javaVersion = versionLines.length >= 2 ? versionLines[1] : versionLines[0];
      }
    } catch (error) {
      globals.printTrace(error.toString());
    }
    if (javaVersion == null) {
      // Could not determine the java version.
      return false;
    }
    return true;
  }

  Future<LicensesAccepted> get licensesAccepted async {
    LicensesAccepted status;

    void _handleLine(String line) {
      if (licenseCounts.hasMatch(line)) {
        final Match match = licenseCounts.firstMatch(line);
        if (match.group(1) != match.group(2)) {
          status = LicensesAccepted.some;
        } else {
          status = LicensesAccepted.none;
        }
      } else if (licenseNotAccepted.hasMatch(line)) {
        // The licenseNotAccepted pattern is trying to match the same line as
        // licenseCounts, but is more general. In case the format changes, a
        // more general match may keep doctor mostly working.
        status = LicensesAccepted.none;
      } else if (licenseAccepted.hasMatch(line)) {
        status ??= LicensesAccepted.all;
      }
    }

    if (!_canRunSdkManager()) {
      return LicensesAccepted.unknown;
    }

    try {
      final Process process = await processUtils.start(
        <String>[androidSdk.sdkManagerPath, '--licenses'],
        environment: androidSdk.sdkManagerEnv,
      );
      process.stdin.write('n\n');
      // We expect logcat streams to occasionally contain invalid utf-8,
      // see: https://github.com/flutter/flutter/pull/8864.
      final Future<void> output = process.stdout
        .transform<String>(const Utf8Decoder(reportErrors: false))
        .transform<String>(const LineSplitter())
        .listen(_handleLine)
        .asFuture<void>(null);
      final Future<void> errors = process.stderr
        .transform<String>(const Utf8Decoder(reportErrors: false))
        .transform<String>(const LineSplitter())
        .listen(_handleLine)
        .asFuture<void>(null);
      await Future.wait<void>(<Future<void>>[output, errors]);
      return status ?? LicensesAccepted.unknown;
    } on ProcessException catch (e) {
      globals.printTrace('Failed to run Android sdk manager: $e');
      return LicensesAccepted.unknown;
    }
  }

  /// Run the Android SDK manager tool in order to accept SDK licenses.
  static Future<bool> runLicenseManager() async {
    if (androidSdk == null) {
      globals.printStatus(userMessages.androidSdkShort);
      return false;
    }

    if (!_canRunSdkManager()) {
      throwToolExit(userMessages.androidMissingSdkManager(androidSdk.sdkManagerPath));
    }

    final Version sdkManagerVersion = Version.parse(androidSdk.sdkManagerVersion);
    if (sdkManagerVersion == null || sdkManagerVersion.major < 26) {
      // SDK manager is found, but needs to be updated.
      throwToolExit(userMessages.androidSdkManagerOutdated(androidSdk.sdkManagerPath));
    }

    try {
      final Process process = await processUtils.start(
        <String>[androidSdk.sdkManagerPath, '--licenses'],
        environment: androidSdk.sdkManagerEnv,
      );

      // The real stdin will never finish streaming. Pipe until the child process
      // finishes.
      unawaited(process.stdin.addStream(globals.stdio.stdin)
        // If the process exits unexpectedly with an error, that will be
        // handled by the caller.
        .catchError((dynamic err, StackTrace stack) {
          globals.printTrace('Echoing stdin to the licenses subprocess failed:');
          globals.printTrace('$err\n$stack');
        }
      ));

      // Wait for stdout and stderr to be fully processed, because process.exitCode
      // may complete first.
      try {
        await waitGroup<void>(<Future<void>>[
          globals.stdio.addStdoutStream(process.stdout),
          globals.stdio.addStderrStream(process.stderr),
        ]);
      } catch (err, stack) {
        globals.printTrace('Echoing stdout or stderr from the license subprocess failed:');
        globals.printTrace('$err\n$stack');
      }

      final int exitCode = await process.exitCode;
      return exitCode == 0;
    } on ProcessException catch (e) {
      throwToolExit(userMessages.androidCannotRunSdkManager(
        androidSdk.sdkManagerPath,
        e.toString(),
      ));
      return false;
    }
  }

  static bool _canRunSdkManager() {
    assert(androidSdk != null);
    final String sdkManagerPath = androidSdk.sdkManagerPath;
    return globals.processManager.canRun(sdkManagerPath);
  }
}
