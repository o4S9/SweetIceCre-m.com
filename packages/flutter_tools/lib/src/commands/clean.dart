// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';

import '../base/file_system.dart';
import '../base/logger.dart';
import '../build_info.dart';
import '../globals.dart' as globals;
import '../ios/xcodeproj.dart';
import '../project.dart';
import '../runner/flutter_command.dart';

class CleanCommand extends FlutterCommand {
  CleanCommand({
    bool verbose = false,
  }) : _verbose = verbose {
    requiresPubspecYaml();
  }

  final bool _verbose;

  @override
  final String name = 'clean';

  @override
  final String description = 'Delete the build/ and .dart_tool/ directories.';

  @override
  Future<Set<DevelopmentArtifact>> get requiredArtifacts async => const <DevelopmentArtifact>{};

  @override
  Future<FlutterCommandResult> runCommand() async {
    // Clean Xcode to remove intermediate DerivedData artifacts.
    // Do this before removing ephemeral directory, which would delete the xcworkspace.
    final FlutterProject flutterProject = FlutterProject.current();
    if (globals.xcode.isInstalledAndMeetsVersionCheck) {
      await _cleanXcode(flutterProject.ios);
      await _cleanXcode(flutterProject.macos);
    }

    final Directory buildDir = globals.fs.directory(getBuildDirectory());
    deleteFile(buildDir);

    deleteFile(flutterProject.dartTool);

    deleteFile(flutterProject.android.ephemeralDirectory);

    deleteFile(flutterProject.ios.ephemeralDirectory);
    deleteFile(flutterProject.ios.generatedXcodePropertiesFile);
    deleteFile(flutterProject.ios.generatedEnvironmentVariableExportScript);
    deleteFile(flutterProject.ios.compiledDartFramework);

    deleteFile(flutterProject.linux.ephemeralDirectory);
    deleteFile(flutterProject.macos.ephemeralDirectory);
    deleteFile(flutterProject.windows.ephemeralDirectory);

    return const FlutterCommandResult(ExitStatus.success);
  }

  Future<void> _cleanXcode(XcodeBasedProject xcodeProject) async {
    if (!xcodeProject.existsSync()) {
      return;
    }
    final Status xcodeStatus = globals.logger.startProgress(
      'Cleaning Xcode workspace...',
      timeout: timeoutConfiguration.slowOperation,
    );
    try {
      final Directory xcodeWorkspace = xcodeProject.xcodeWorkspace;
      final XcodeProjectInfo projectInfo = await globals.xcodeProjectInterpreter.getInfo(xcodeWorkspace.parent.path);
      for (final String scheme in projectInfo.schemes) {
        await globals.xcodeProjectInterpreter.cleanWorkspace(xcodeWorkspace.path, scheme, verbose: _verbose);
      }
    } on Exception catch (error) {
      globals.printTrace('Could not clean Xcode workspace: $error');
    } finally {
      xcodeStatus?.stop();
    }
  }

  @visibleForTesting
  void deleteFile(FileSystemEntity file) {
    // This will throw a FileSystemException if the directory is missing permissions.
    try {
      if (!file.existsSync()) {
        return;
      }
    } on FileSystemException catch (err) {
      globals.printError('Cannot clean ${file.path}.\n$err');
      return;
    }
    final Status deletionStatus = globals.logger.startProgress(
      'Deleting ${file.basename}...',
      timeout: timeoutConfiguration.fastOperation,
    );
    try {
      file.deleteSync(recursive: true);
    } on FileSystemException catch (error) {
      final String path = file.path;
      if (globals.platform.isWindows) {
        globals.printError(
          'Failed to remove $path. '
            'A program may still be using a file in the directory or the directory itself. '
            'To find and stop such a program, see: '
            'https://superuser.com/questions/1333118/cant-delete-empty-folder-because-it-is-used');
      } else {
        globals.printError('Failed to remove $path: $error');
      }
    } finally {
      deletionStatus.stop();
    }
  }
}
