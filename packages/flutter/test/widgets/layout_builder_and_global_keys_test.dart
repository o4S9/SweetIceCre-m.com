// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/src/rendering/sliver.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class StatefulWrapper extends StatefulWidget {
  const StatefulWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  final Widget child;

  @override
  StatefulWrapperState createState() => StatefulWrapperState();
}

class StatefulWrapperState extends State<StatefulWrapper> {

  void trigger() {
    setState(() { /* for test purposes */ });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

void main() {
  // TODO(Piinks): Remove this after testWidgets'
  //   - state leaks/test dependencies have been fixed.
  //   - or tests are refactored for platform specific behaviors
  defaultPlatformVariant = null;

  testWidgets('Moving global key inside a LayoutBuilder', (WidgetTester tester) async {
    final GlobalKey<StatefulWrapperState> key = GlobalKey<StatefulWrapperState>();
    await tester.pumpWidget(
      LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
        return Wrapper(
          child: StatefulWrapper(key: key, child: Container(height: 100.0)),
        );
      }),
    );
    await tester.pumpWidget(
      LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
        key.currentState!.trigger();
        return StatefulWrapper(key: key, child: Container(height: 100.0));
      }),
    );

    expect(tester.takeException(), null);
  });

  testWidgets('Moving global key inside a SliverLayoutBuilder', (WidgetTester tester) async {
    final GlobalKey<StatefulWrapperState> key = GlobalKey<StatefulWrapperState>();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverLayoutBuilder(
              builder: (BuildContext context, SliverConstraints constraint) {
                return SliverToBoxAdapter(
                  child: Wrapper(child: StatefulWrapper(key: key, child: Container(height: 100.0))),
                );
              },
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverLayoutBuilder(
              builder: (BuildContext context, SliverConstraints constraint) {
                key.currentState!.trigger();
                return SliverToBoxAdapter(
                  child: StatefulWrapper(key: key, child: Container(height: 100.0)),
                );
              },
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), null);
  });
}
