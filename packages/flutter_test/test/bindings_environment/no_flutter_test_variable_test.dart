// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('$WidgetsBinding initializes with $LiveTestWidgetsFlutterBinding when the environment does not contain FLUTTER_TEST', () {
    TestWidgetsFlutterBinding.ensureInitialized(<String, String>{});
    expect(WidgetsBinding.instance, isInstanceOf<LiveTestWidgetsFlutterBinding>());
  });
}
