// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Provides an API to test Flutter applications on Fuchsia devices and
/// emulators.
///
/// The application runs in a separate process from the actual test.

import 'dart:async';
import 'dart:core';

import 'package:logging/logging.dart';

import '../flutter_fuchsia.dart';

/// Runs through a simple usage of the flutter_fuchsia library: connects to a
/// remote machine at the ipv4 address in argument 1 to list all active flutter
/// views running on fuchsia.
Future<Null> main(List<String> args) async {
  // Sets up a basic logger to see what's happening.
  Logger.root.onRecord.listen((LogRecord rec) {
    print('[${rec.level.name}] -- ${rec.time}: ${rec.message}');
  });
  final List<FuchsiaFlutterView> views =
      await getFlutterViews(args[0], '../../', 'release-x86-64');
  print(views.map((FuchsiaFlutterView view) => view.name ?? view.id));
}
