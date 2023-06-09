// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

void main() {
  // Change made in https://github.com/flutter/flutter/pull/128522
  SelectableText();
  SelectableText.rich();
  SelectableText.rich(textScaleFactor: 2.0);
  SelectableText(textScaleFactor: 2.0)
    .textScaleFactor;
}
