// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'recorder.dart';

const List<int> kTransparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
];

/// An animated GIF image with 3 1x1 pixel frames (a red, green, and blue
/// frames). The GIF animates forever, and each frame has a 100ms delay.
const List<int> kAnimatedGif = <int> [
  0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0xa1, 0x03, 0x00,
  0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0xff, 0x00, 0xff, 0xff, 0xff, 0x21,
  0xff, 0x0b, 0x4e, 0x45, 0x54, 0x53, 0x43, 0x41, 0x50, 0x45, 0x32, 0x2e, 0x30,
  0x03, 0x01, 0x00, 0x00, 0x00, 0x21, 0xf9, 0x04, 0x00, 0x0a, 0x00, 0xff, 0x00,
  0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x4c,
  0x01, 0x00, 0x21, 0xf9, 0x04, 0x00, 0x0a, 0x00, 0xff, 0x00, 0x2c, 0x00, 0x00,
  0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x54, 0x01, 0x00, 0x21,
  0xf9, 0x04, 0x00, 0x0a, 0x00, 0xff, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00, 0x01,
  0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3b,
];

/// Measures expense of constructing Image widgets.
class BenchBuildImage extends WidgetRecorder {
  BenchBuildImage() : super(name: benchmarkName);

  static const String benchmarkName = 'draw_image';

  @override
  Widget createWidget() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: _RotatingWidget(
        child: Row(children: <Widget>[
          Image.memory(Uint8List.fromList(kTransparentImage)),
          Image.memory(Uint8List.fromList(kAnimatedGif)),
        ]),
      ),
    );
  }
}

class _RotatingWidget extends StatefulWidget {
  const _RotatingWidget({this.child, Key key}) : super(key: key);

  final Widget child;

  @override
  _RotatingWidgetState createState() => _RotatingWidgetState();
}

class _RotatingWidgetState extends State<_RotatingWidget> with SingleTickerProviderStateMixin {
  AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget child) {
        return Transform(
          transform: Matrix4.identity()..rotateZ(2 * math.pi * controller.value),
          child: widget.child,
        );
      },
    );
  }

}
