// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Tracks picture layers accurately when painting is interleaved with a pushLayer', (WidgetTester tester) async {
    // Creates a RenderObject that will paint into multiple picture layers.
    // Asserts that both layers get a handle, and that all layers get correctly
    // released.
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      child: CustomPaint(
        key: key,
        painter: SimplePainter(),
        child: const RepaintBoundary(child: Placeholder()),
        foregroundPainter: SimplePainter(),
      ),
    ));

    final List<Layer> layers = tester.binding.renderView.debugLayer!.depthFirstIterateChildren();

    final RenderObject renderObject = key.currentContext!.findRenderObject()!;
    expect(renderObject.debugPictureLayerCount, 2);

    for (final Layer layer in layers) {
      expect(layer.debugReleasedRetainedResources, false);
    }

    await tester.pumpWidget(const SizedBox());

    for (final Layer layer in layers) {
      expect(layer.debugReleasedRetainedResources, true);
    }
    expect(renderObject.debugDisposed, true);
    expect(renderObject.debugPictureLayerCount, 0);
  });
}

class SimplePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPaint(Paint());
  }

  @override
  bool shouldRepaint(SimplePainter oldDelegate) => true;
}
