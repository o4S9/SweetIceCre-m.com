// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

import 'context.dart';
import 'file_system.dart';
import 'process.dart';
import 'process_manager.dart';

/// Returns [OperatingSystemUtils] active in the current app context (i.e. zone).
OperatingSystemUtils get os => context[OperatingSystemUtils];

abstract class OperatingSystemUtils {
  factory OperatingSystemUtils() {
    if (io.Platform.isWindows) {
      return new _WindowsUtils();
    } else {
      return new _PosixUtils();
    }
  }

  OperatingSystemUtils._private();

  String get operatingSystem => io.Platform.operatingSystem;

  bool get isMacOS => operatingSystem == 'macos';
  bool get isWindows => operatingSystem == 'windows';
  bool get isLinux => operatingSystem == 'linux';

  /// Make the given file executable. This may be a no-op on some platforms.
  io.ProcessResult makeExecutable(File file);

  /// Return the path (with symlinks resolved) to the given executable, or `null`
  /// if `which` was not able to locate the binary.
  File which(String execName);

  /// Return the File representing a new pipe.
  File makePipe(String path);

  void unzip(File file, Directory targetDirectory);
}

class _PosixUtils extends OperatingSystemUtils {
  _PosixUtils() : super._private();

  @override
  io.ProcessResult makeExecutable(File file) {
    return processManager.runSync('chmod', <String>['a+x', file.path]);
  }

  /// Return the path to the given executable, or `null` if `which` was not able
  /// to locate the binary.
  @override
  File which(String execName) {
    io.ProcessResult result = processManager.runSync('which', <String>[execName]);
    if (result.exitCode != 0)
      return null;
    String path = result.stdout.trim().split('\n').first.trim();
    return fs.file(path);
  }

  // unzip -o -q zipfile -d dest
  @override
  void unzip(File file, Directory targetDirectory) {
    runSync(<String>['unzip', '-o', '-q', file.path, '-d', targetDirectory.path]);
  }

  @override
  File makePipe(String path) {
    runSync(<String>['mkfifo', path]);
    return fs.file(path);
  }
}

class _WindowsUtils extends OperatingSystemUtils {
  _WindowsUtils() : super._private();

  // This is a no-op.
  @override
  io.ProcessResult makeExecutable(File file) {
    return new io.ProcessResult(0, 0, null, null);
  }

  @override
  File which(String execName) {
    io.ProcessResult result = processManager.runSync('where', <String>[execName]);
    if (result.exitCode != 0)
      return null;
    return fs.file(result.stdout.trim().split('\n').first.trim());
  }

  @override
  void unzip(File file, Directory targetDirectory) {
    Archive archive = new ZipDecoder().decodeBytes(file.readAsBytesSync());

    for (ArchiveFile archiveFile in archive.files) {
      // The archive package doesn't correctly set isFile.
      if (!archiveFile.isFile || archiveFile.name.endsWith('/'))
        continue;

      File destFile = fs.file(path.join(targetDirectory.path, archiveFile.name));
      if (!destFile.parent.existsSync())
        destFile.parent.createSync(recursive: true);
      destFile.writeAsBytesSync(archiveFile.content);
    }
  }

  @override
  File makePipe(String path) {
    throw new UnsupportedError('makePipe is not implemented on Windows.');
  }
}

Future<int> findAvailablePort() async {
  io.ServerSocket socket = await io.ServerSocket.bind(io.InternetAddress.LOOPBACK_IP_V4, 0);
  int port = socket.port;
  await socket.close();
  return port;
}

const int _kMaxSearchIterations = 20;

/// This method will attempt to return a port close to or the same as
/// [defaultPort]. Failing that, it will return any available port.
Future<int> findPreferredPort(int defaultPort, { int searchStep: 2 }) async {
  int iterationCount = 0;

  while (iterationCount < _kMaxSearchIterations) {
    int port = defaultPort + iterationCount * searchStep;
    if (await _isPortAvailable(port))
      return port;
    iterationCount++;
  }

  return findAvailablePort();
}

Future<bool> _isPortAvailable(int port) async {
  try {
    io.ServerSocket socket = await io.ServerSocket.bind(io.InternetAddress.LOOPBACK_IP_V4, port);
    await socket.close();
    return true;
  } catch (error) {
    return false;
  }
}

/// Find and return the project root directory relative to the specified
/// directory or the current working directory if none specified.
/// Return `null` if the project root could not be found
/// or if the project root is the flutter repository root.
String findProjectRoot([String directory]) {
  const String kProjectRootSentinel = 'pubspec.yaml';
  directory ??= fs.currentDirectory.path;
  while (true) {
    if (fs.isFileSync(path.join(directory, kProjectRootSentinel)))
      return directory;
    String parent = path.dirname(directory);
    if (directory == parent) return null;
    directory = parent;
  }
}
