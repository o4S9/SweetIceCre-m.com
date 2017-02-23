// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../rendering/src/sector_layout.dart';

void main() {
  test('SectorConstraints', () {
    expect(const SectorConstraints().isTight, isFalse);
  });
}
