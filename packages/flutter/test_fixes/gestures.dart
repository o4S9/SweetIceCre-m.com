// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/gestures.dart';

void main() {
  // Change made in https://github.com/flutter/flutter/pull/28602
  final PointerEnterEvent enterEvent = PointerEnterEvent.fromHoverEvent(PointerHoverEvent());

  // Change made in https://github.com/flutter/flutter/pull/28602
  final PointerExitEvent exitEvent = PointerExitEvent.fromHoverEvent(PointerHoverEvent());

  // Changes made in https://github.com/flutter/flutter/pull/66043
  VelocityTracker tracker = VelocityTracker();
  tracker = VelocityTracker(PointerDeviceKind.mouse);

  // Changes made in
  DragGestureRecognizer();
  DragGestureRecognizer(kind: PointerDeviceKind.touch);
  VerticalDragGestureRecognizer();
  VerticalDragGestureRecognizer(kind: PointerDeviceKind.touch);
  HorizontalDragGestureRecognizer();
  HorizontalDragGestureRecognizer(kind: PointerDeviceKind.touch);
  GestureRecognizer();
  GestureRecognizer(kind: PointerDeviceKind.touch);
  OneSequenceGestureRecognizer();
  OneSequenceGestureRecognizer(kind: PointerDeviceKind.touch);
  PrimaryPointerGestureRecognizer();
  PrimaryPointerGestureRecognizer(kind: PointerDeviceKind.touch);
}
