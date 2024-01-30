// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

void main() {
  // Change made in https://github.com/flutter/flutter/pull/109014
  InteractiveViewer(alignPanAxis: false);
  InteractiveViewer.builder(alignPanAxis: false);
}
