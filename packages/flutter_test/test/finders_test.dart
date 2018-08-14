// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('text', () {
    testWidgets('finds Text widgets', (WidgetTester tester) async {
      await tester.pumpWidget(_boilerplate(
        const Text('test'),
      ));
      expect(find.text('test'), findsOneWidget);
    });

    testWidgets('finds Text.rich widgets', (WidgetTester tester) async {
      await tester.pumpWidget(_boilerplate(
        const Text.rich(
          TextSpan(text: 't', children: <TextSpan>[
            TextSpan(text: 'e'),
            TextSpan(text: 'st'),
          ]
        ),
      )));

      expect(find.text('test'), findsOneWidget);
    });
  });

  group('hitTestable', () {
    testWidgets('excludes non-hit-testable widgets', (WidgetTester tester) async {
      await tester.pumpWidget(
        _boilerplate(new IndexedStack(
          sizing: StackFit.expand,
          children: <Widget>[
            new GestureDetector(
              key: const ValueKey<int>(0),
              behavior: HitTestBehavior.opaque,
              onTap: () { },
              child: const SizedBox.expand(),
            ),
            new GestureDetector(
              key: const ValueKey<int>(1),
              behavior: HitTestBehavior.opaque,
              onTap: () { },
              child: const SizedBox.expand(),
            ),
          ],
        )),
      );
      expect(find.byType(GestureDetector), findsNWidgets(2));
      final Finder hitTestable = find.byType(GestureDetector).hitTestable(at: Alignment.center);
      expect(hitTestable, findsOneWidget);
      expect(tester.widget(hitTestable).key, const ValueKey<int>(0));
    });
  });

  testWidgets('ChainedFinders chain properly', (WidgetTester tester) async {
    final GlobalKey key1 = new GlobalKey();
    await tester.pumpWidget(
      _boilerplate(new Column(
        children: <Widget>[
          new Container(
            key: key1,
            child: const Text('1'),
          ),
          new Container(
            child: const Text('2'),
          )
        ],
      )),
    );

    // Get the text back. By correctly chaining the descendant finder's
    // candidates, it should find 1 instead of 2 if it `last` wasn't chaining
    // the descendant's candidates.
    final Text text = find.descendant(
      of: find.byKey(key1),
      matching: find.byType(Text),
    ).last.evaluate().single.widget;

    expect(text.data, '1');
  });
}

Widget _boilerplate(Widget child) {
  return new Directionality(
    textDirection: TextDirection.ltr,
    child: child,
  );
}
