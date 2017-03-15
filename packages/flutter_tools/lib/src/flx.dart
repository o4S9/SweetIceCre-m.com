// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'artifacts.dart';
import 'asset.dart';
import 'base/common.dart';
import 'base/file_system.dart';
import 'base/process.dart';
import 'build_info.dart';
import 'dart/package_map.dart';
import 'devfs.dart';
import 'globals.dart';
import 'zip.dart';

const String defaultMainPath = 'lib/main.dart';
const String defaultAssetBasePath = '.';
const String defaultManifestPath = 'pubspec.yaml';
String get defaultFlxOutputPath => fs.path.join(getBuildDirectory(), 'app.flx');
String get defaultSnapshotPath => fs.path.join(getBuildDirectory(), 'snapshot_blob.bin');
String get defaultDepfilePath => fs.path.join(getBuildDirectory(), 'snapshot_blob.bin.d');
const String defaultPrivateKeyPath = 'privatekey.der';

const String _kKernelKey = 'kernel_blob.bin';
const String _kSnapshotKey = 'snapshot_blob.bin';

Future<int> createSnapshot({
  String mainPath,
  String snapshotPath,
  String depfilePath,
  String packages
}) {
  assert(mainPath != null);
  assert(snapshotPath != null);
  assert(packages != null);
  final String snapshotterPath = artifacts.getArtifactPath(Artifact.genSnapshot, null, BuildMode.debug);
  final String vmSnapshotData = artifacts.getArtifactPath(Artifact.vmSnapshotData);
  final String isolateSnapshotData = artifacts.getArtifactPath(Artifact.isolateSnapshotData);

  final List<String> args = <String>[
    snapshotterPath,
    '--snapshot_kind=script',
    '--vm_snapshot_data=$vmSnapshotData',
    '--isolate_snapshot_data=$isolateSnapshotData',
    '--packages=$packages',
    '--script_snapshot=$snapshotPath'
  ];
  if (depfilePath != null) {
    args.add('--dependencies=$depfilePath');
    fs.file(depfilePath).parent.childFile('gen_snapshot.d').writeAsString('$depfilePath: $snapshotterPath\n');
  }
  args.add(mainPath);
  return runCommandAndStreamOutput(args);
}

/// Build the flx in the build directory and return `localBundlePath` on success.
///
/// Return `null` on failure.
Future<String> buildFlx({
  String mainPath: defaultMainPath,
  DevFSContent kernelContent,
  bool precompiledSnapshot: false,
  bool includeRobotoFonts: true
}) async {
  await build(
    snapshotPath: defaultSnapshotPath,
    outputPath: defaultFlxOutputPath,
    mainPath: mainPath,
    kernelContent: kernelContent,
    precompiledSnapshot: precompiledSnapshot,
    includeRobotoFonts: includeRobotoFonts
  );
  return defaultFlxOutputPath;
}

Future<Null> build({
  String mainPath: defaultMainPath,
  String manifestPath: defaultManifestPath,
  String outputPath,
  String snapshotPath,
  String depfilePath,
  String privateKeyPath: defaultPrivateKeyPath,
  String workingDirPath,
  String packagesPath,
  DevFSContent kernelContent,
  bool precompiledSnapshot: false,
  bool includeRobotoFonts: true,
  bool reportLicensedPackages: false
}) async {
  outputPath ??= defaultFlxOutputPath;
  snapshotPath ??= defaultSnapshotPath;
  depfilePath ??= defaultDepfilePath;
  workingDirPath ??= getAssetBuildDirectory();
  packagesPath ??= fs.path.absolute(PackageMap.globalPackagesPath);
  File snapshotFile;

  if (!precompiledSnapshot) {
    ensureDirectoryExists(snapshotPath);

    // In a precompiled snapshot, the instruction buffer contains script
    // content equivalents
    final int result = await createSnapshot(
      mainPath: mainPath,
      snapshotPath: snapshotPath,
      depfilePath: depfilePath,
      packages: packagesPath
    );
    if (result != 0)
      throwToolExit('Failed to run the Flutter compiler. Exit code: $result', exitCode: result);

    snapshotFile = fs.file(snapshotPath);
  }

  return assemble(
    manifestPath: manifestPath,
    kernelContent: kernelContent,
    snapshotFile: snapshotFile,
    outputPath: outputPath,
    privateKeyPath: privateKeyPath,
    workingDirPath: workingDirPath,
    packagesPath: packagesPath,
    includeRobotoFonts: includeRobotoFonts,
    reportLicensedPackages: reportLicensedPackages
  );
}

Future<Null> assemble({
  String manifestPath,
  DevFSContent kernelContent,
  File snapshotFile,
  String outputPath,
  String privateKeyPath: defaultPrivateKeyPath,
  String workingDirPath,
  String packagesPath,
  bool includeDefaultFonts: true,
  bool includeRobotoFonts: true,
  bool reportLicensedPackages: false
}) async {
  outputPath ??= defaultFlxOutputPath;
  workingDirPath ??= getAssetBuildDirectory();
  packagesPath ??= fs.path.absolute(PackageMap.globalPackagesPath);
  printTrace('Building $outputPath');

  // Build the asset bundle.
  final AssetBundle assetBundle = new AssetBundle();
  final int result = await assetBundle.build(
    manifestPath: manifestPath,
    workingDirPath: workingDirPath,
    packagesPath: packagesPath,
    includeDefaultFonts: includeDefaultFonts,
    includeRobotoFonts: includeRobotoFonts,
    reportLicensedPackages: reportLicensedPackages
  );
  if (result != 0)
    throwToolExit('Error building $outputPath: $result', exitCode: result);

  final ZipBuilder zipBuilder = new ZipBuilder();

  // Add all entries from the asset bundle.
  zipBuilder.entries.addAll(assetBundle.entries);

  if (kernelContent != null)
    zipBuilder.entries[_kKernelKey] = kernelContent;
  if (snapshotFile != null)
    zipBuilder.entries[_kSnapshotKey] = new DevFSFileContent(snapshotFile);

  ensureDirectoryExists(outputPath);

  printTrace('Encoding zip file to $outputPath');
  await zipBuilder.createZip(fs.file(outputPath), fs.directory(workingDirPath));

  printTrace('Built $outputPath.');
}
