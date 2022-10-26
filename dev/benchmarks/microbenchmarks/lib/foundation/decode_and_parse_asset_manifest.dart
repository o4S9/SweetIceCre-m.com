// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformAssetBundle;
import 'package:flutter/widgets.dart';

import '../common.dart';

const int _kNumIterations = 1000;

void main() async {
  assert(false, "Don't run benchmarks in debug mode! Use 'flutter run --release'.");

  final BenchmarkResultPrinter printer = BenchmarkResultPrinter();
  WidgetsFlutterBinding.ensureInitialized();
  final Stopwatch watch = Stopwatch();
  final PlatformAssetBundle bundle = PlatformAssetBundle();

  final ByteData assetManifestBytes = await bundle.load('money_asset_manifest.bin');
  watch.start();
  for (int i = 0; i < _kNumIterations; i++) {
    // This is effectively a test.
    // ignore: invalid_use_of_visible_for_testing_member
    await AssetImage.decodeAssetManifest(assetManifestBytes);
  }
  watch.stop();

  printer.addResult(
    description: 'Load and Parse Large Asset Manifest',
    value: watch.elapsedMilliseconds.toDouble(),
    unit: 'ms',
    name: 'load_and_parse_large_asset_manifest',
  );

  printer.printToStdout();
}
