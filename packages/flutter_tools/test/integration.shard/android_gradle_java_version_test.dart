// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/android/gradle_utils.dart'
    show getGradlewFileName;
import 'package:flutter_tools/src/base/io.dart';

import '../src/common.dart';
import 'test_utils.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = createResolvedTempDirectorySync('run_test.');
  });

  tearDown(() async {
    tryToDelete(tempDir);
  });

  testWithoutContext(
      'gradle task exists named javaVersion that prints jdk version', () async {
    // Create a new flutter project.
    final String flutterBin =
        fileSystem.path.join(getFlutterRoot(), 'bin', 'flutter');
    ProcessResult result = await processManager.run(<String>[
      flutterBin,
      'create',
      tempDir.path,
      '--project-name=testapp',
    ], workingDirectory: tempDir.path);
    expect(result.exitCode, 0);
    // Ensure that gradle files exists from templates.
    result = await processManager.run(<String>[
      flutterBin,
      'build',
      'apk',
      '--config-only',
    ], workingDirectory: tempDir.path);
    expect(result.exitCode, 0);

    final Directory androidApp = tempDir.childDirectory('android');
    result = await processManager.run(<String>[
      './${getGradlewFileName(platform)}',
      ...getLocalEngineArguments(),
      '-q', // quiet output.
      'javaVersion',
    ], workingDirectory: androidApp.path);
    // Verify that gradlew has a javaVersion task.
    expect(result.exitCode, 0);
    // Verify the format is a number on its own line.
    expect(result.stdout.toString(), matches(RegExp(r'\d\n')));
  });
}
