// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/clipboard_utils.dart';

void main() {
  final MockClipboard mockClipboard = MockClipboard();

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      mockClipboard.handleMethodCall,
    );
    // Fill the clipboard so that the Paste option is available in the text
    // selection menu.
    await Clipboard.setData(const ClipboardData(text: 'Clipboard data'));
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  testWidgets('Builds the right toolbar on each platform, including web, and shows buttonItems', (WidgetTester tester) async {
    const String buttonText = 'Click me';

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoAdaptiveTextSelectionToolbar.buttonItems(
            anchors: const TextSelectionToolbarAnchors(
              primaryAnchor: Offset.zero,
            ),
            buttonItems: <ContextMenuButtonItem>[
              ContextMenuButtonItem(
                label: buttonText,
                onPressed: () {
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text(buttonText), findsOneWidget);

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        expect(find.byType(CupertinoTextSelectionToolbar), findsOneWidget);
        expect(find.byType(CupertinoDesktopTextSelectionToolbar), findsNothing);
        break;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        expect(find.byType(CupertinoTextSelectionToolbar), findsNothing);
        expect(find.byType(CupertinoDesktopTextSelectionToolbar), findsOneWidget);
        break;
    }
  },
    variant: TargetPlatformVariant.all(),
    skip: isBrowser, // [intended] see https://github.com/flutter/flutter/issues/108382
  );

  testWidgets('Can build children directly as well', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoAdaptiveTextSelectionToolbar(
            anchors: const TextSelectionToolbarAnchors(
              primaryAnchor: Offset.zero,
            ),
            children: <Widget>[
              Container(key: key),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(key), findsOneWidget);
  },
    skip: isBrowser, // [intended] see https://github.com/flutter/flutter/issues/108382
  );

  testWidgets('Can build from EditableTextState', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(CupertinoApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          child: EditableText(
            controller: TextEditingController(),
            backgroundCursorColor: const Color(0xff00ffff),
            focusNode: FocusNode(),
            style: const TextStyle(),
            cursorColor: const Color(0xff00ffff),
            selectionControls: cupertinoTextSelectionHandleControls,
            contextMenuBuilder: (
              BuildContext context,
              EditableTextState editableTextState,
            ) {
              return CupertinoAdaptiveTextSelectionToolbar.editableText(
                key: key,
                editableTextState: editableTextState,
              );
            },
          ),
        ),
      ),
    ));

    await tester.pump(); // Wait for autofocus to take effect.

    expect(find.byKey(key), findsNothing);

    // Long-press to bring up the context menu.
    final Finder textFinder = find.byType(EditableText);
    await tester.longPress(textFinder);
    tester.state<EditableTextState>(textFinder).showToolbar();
    await tester.pumpAndSettle();

    expect(find.byKey(key), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Cut'), findsNothing);
    expect(find.text('Select all'), findsNothing);
    expect(find.text('Paste'), findsOneWidget);

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        expect(find.byType(CupertinoTextSelectionToolbarButton), findsOneWidget);
        break;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        expect(find.byType(CupertinoDesktopTextSelectionToolbarButton), findsOneWidget);
        break;
    }
  },
    skip: kIsWeb, // [intended] on web the browser handles the context menu.
    variant: TargetPlatformVariant.all(),
  );

  testWidgets('Can build for editable text from raw parameters', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(CupertinoApp(
      home: Center(
        child: CupertinoAdaptiveTextSelectionToolbar.editable(
          key: key,
          anchors: const TextSelectionToolbarAnchors(
            primaryAnchor: Offset.zero,
          ),
          clipboardStatus: ClipboardStatus.pasteable,
          liveTextStatus: LiveTextStatus.disabled,
          onCopy: () {},
          onCut: () {},
          onPaste: () {},
          onSelectAll: () {},
          onCaptureText: () {},
        ),
      ),
    ));

    expect(find.byKey(key), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Cut'), findsOneWidget);
    expect(find.text('Select All'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        expect(find.byType(CupertinoTextSelectionToolbarButton), findsNWidgets(4));
        break;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        expect(find.byType(CupertinoDesktopTextSelectionToolbarButton), findsNWidgets(4));
        break;
    }
  },
    skip: kIsWeb, // [intended] on web the browser handles the context menu.
    variant: TargetPlatformVariant.all(),
  );

  testWidgets('Builds the correct button per-platform', (WidgetTester tester) async {
    const String buttonText = 'Click me';

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: Builder(
            builder: (BuildContext context) {
              return Column(
                children: CupertinoAdaptiveTextSelectionToolbar.getAdaptiveButtons(
                  context,
                  <ContextMenuButtonItem>[
                    ContextMenuButtonItem(
                      label: buttonText,
                      onPressed: () {
                      },
                    ),
                  ],
                ).toList(),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text(buttonText), findsOneWidget);

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        expect(find.byType(CupertinoTextSelectionToolbarButton), findsOneWidget);
        expect(find.byType(CupertinoDesktopTextSelectionToolbarButton), findsNothing);
        break;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        expect(find.byType(CupertinoTextSelectionToolbarButton), findsNothing);
        expect(find.byType(CupertinoDesktopTextSelectionToolbarButton), findsOneWidget);
        break;
    }
  },
    variant: TargetPlatformVariant.all(),
  );
}
