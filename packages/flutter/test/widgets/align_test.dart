// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // TODO(Piinks): Remove this after testWidgets'
  //   - state leaks/test dependencies have been fixed.
  //   - or tests are refactored for platform specific behaviors
  defaultPlatformVariant = null;

  testWidgets('Align smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      Align(
        alignment: const Alignment(0.50, 0.50),
        child: Container(),
      ),
    );

    await tester.pumpWidget(
      Align(
        alignment: Alignment.center,
        child: Container(),
      ),
    );

    await tester.pumpWidget(
      const Align(
        alignment: Alignment.topLeft,
      ),
    );
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.rtl,
      child: Align(
        alignment: AlignmentDirectional.topStart,
      ),
    ));
    await tester.pumpWidget(
      const Align(
        alignment: Alignment.topLeft,
      ),
    );
  });

  testWidgets('Align control test (LTR)', (WidgetTester tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(width: 100.0, height: 80.0),
      ),
    ));

    expect(tester.getTopLeft(find.byType(SizedBox)).dx, 0.0);
    expect(tester.getBottomRight(find.byType(SizedBox)).dx, 100.0);

    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 100.0, height: 80.0),
      ),
    ));

    expect(tester.getTopLeft(find.byType(SizedBox)).dx, 0.0);
    expect(tester.getBottomRight(find.byType(SizedBox)).dx, 100.0);
  });

  testWidgets('Align control test (RTL)', (WidgetTester tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.rtl,
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(width: 100.0, height: 80.0),
      ),
    ));

    expect(tester.getTopLeft(find.byType(SizedBox)).dx, 700.0);
    expect(tester.getBottomRight(find.byType(SizedBox)).dx, 800.0);

    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 100.0, height: 80.0),
      ),
    ));

    expect(tester.getTopLeft(find.byType(SizedBox)).dx, 0.0);
    expect(tester.getBottomRight(find.byType(SizedBox)).dx, 100.0);
  });

  testWidgets('Shrink wraps in finite space', (WidgetTester tester) async {
    final GlobalKey alignKey = GlobalKey();
    await tester.pumpWidget(
      SingleChildScrollView(
        child: Align(
          key: alignKey,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 10.0,
            height: 10.0,
          ),
        ),
      ),
    );

    final Size size = alignKey.currentContext!.size!;
    expect(size.width, equals(800.0));
    expect(size.height, equals(10.0));
  });

  testWidgets('Align widthFactor', (WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: const <Widget>[
            Align(
              widthFactor: 0.5,
              child: SizedBox(
                height: 100.0,
                width: 100.0,
              ),
            ),
          ],
        ),
      ),
    );
    final RenderBox box = tester.renderObject<RenderBox>(find.byType(Align));
    expect(box.size.width, equals(50.0));
  });

  testWidgets('Align heightFactor', (WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            Align(
              alignment: Alignment.center,
              heightFactor: 0.5,
              child: SizedBox(
                height: 100.0,
                width: 100.0,
              ),
            ),
          ],
        ),
      ),
    );
    final RenderBox box = tester.renderObject<RenderBox>(find.byType(Align));
    expect(box.size.height, equals(50.0));
  });
}
