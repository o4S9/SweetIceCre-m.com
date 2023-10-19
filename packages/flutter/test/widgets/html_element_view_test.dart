// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('chrome')
library;

import 'dart:async';
import 'dart:ui_web' as ui_web;

import 'package:collection/collection.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/_html_element_view_web.dart'
    show debugOverridePlatformViewRegistry;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:web/web.dart' as web;

import 'view_utils.dart';

final Object _mockHtmlElement = Object();
Object _mockViewFactory(int id, {Object? params}) {
  return _mockHtmlElement;
}

void main() {
  late FakePlatformViewRegistry fakePlatformViewRegistry;

  setUp(() {
    fakePlatformViewRegistry = FakePlatformViewRegistry();

    // Simulate the engine registering default factores.
    fakePlatformViewRegistry.registerViewFactory(ui_web.PlatformViewRegistry.defaultVisibleViewType, (int viewId, {Object? params}) {
      params!;
      params as Map<Object?, Object?>;
      return web.document.createElement(params['tagName']! as String);
    });
    fakePlatformViewRegistry.registerViewFactory(ui_web.PlatformViewRegistry.defaultInvisibleViewType, (int viewId, {Object? params}) {
      params!;
      params as Map<Object?, Object?>;
      return web.document.createElement(params['tagName']! as String);
    });
  });

  group('HtmlElementView', () {
    testWidgetsWithLeakTracking('Create HTML view', (WidgetTester tester) async {
      final int currentViewId = platformViewsRegistry.getNextPlatformViewId();
      fakePlatformViewRegistry.registerViewFactory('webview', _mockViewFactory);

      await tester.pumpWidgetWithoutViewWrapper(
        View(
          view: tester.view,
          child: const Center(
            child: SizedBox(
              width: 200.0,
              height: 100.0,
              child: HtmlElementView(viewType: 'webview'),
            ),
          ),
        ),
      );

      expect(
        fakePlatformViewRegistry.views,
        unorderedEquals(<FakePlatformView>[
          (platformViewId: currentViewId + 1, platformViewType: 'webview', params: null, htmlElement: _mockHtmlElement, viewId: tester.view.viewId),
        ]),
      );
    });

    testWidgetsWithLeakTracking('Create HTML view with PlatformViewCreatedCallback', (WidgetTester tester) async {
      final int currentViewId = platformViewsRegistry.getNextPlatformViewId();
      fakePlatformViewRegistry.registerViewFactory('webview', _mockViewFactory);

      bool hasPlatformViewCreated = false;
      void onPlatformViewCreatedCallBack(int id) {
        hasPlatformViewCreated = true;
      }

      await tester.pumpWidgetWithoutViewWrapper(
        View(
          view: tester.view,
          child: Center(
            child: SizedBox(
              width: 200.0,
              height: 100.0,
              child: HtmlElementView(
                viewType: 'webview',
                onPlatformViewCreated: onPlatformViewCreatedCallBack,
              ),
            ),
          ),
        ),
      );

      // Check the onPlatformViewCreatedCallBack has been called.
      expect(hasPlatformViewCreated, true);

      expect(
        fakePlatformViewRegistry.views,
        unorderedEquals(<FakePlatformView>[
          (platformViewId: currentViewId + 1, platformViewType: 'webview', params: null, htmlElement: _mockHtmlElement, viewId: tester.view.viewId),
        ]),
      );
    });

    testWidgetsWithLeakTracking('Create HTML view with creation params', (WidgetTester tester) async {
      final int currentViewId = platformViewsRegistry.getNextPlatformViewId();
      fakePlatformViewRegistry.registerViewFactory('webview', _mockViewFactory);
      await tester.pumpWidgetWithoutViewWrapper(
        View(
          view: tester.view,
          child: const Column(
            children: <Widget>[
              SizedBox(
                width: 200.0,
                height: 100.0,
                child: HtmlElementView(
                  viewType: 'webview',
                  creationParams: 'foobar',
                ),
              ),
              SizedBox(
                width: 200.0,
                height: 100.0,
                child: HtmlElementView(
                  viewType: 'webview',
                  creationParams: 123,
                ),
              ),
            ],
          ),
        ),
      );

      expect(
        fakePlatformViewRegistry.views,
        unorderedEquals(<FakePlatformView>[
          (platformViewId: currentViewId + 1, platformViewType: 'webview', params: 'foobar', htmlElement: _mockHtmlElement, viewId: tester.view.viewId),
          (platformViewId: currentViewId + 2, platformViewType: 'webview', params: 123, htmlElement: _mockHtmlElement, viewId: tester.view.viewId),
        ]),
      );
    });

    testWidgetsWithLeakTracking('Resize HTML view', (WidgetTester tester) async {
      final int currentViewId = platformViewsRegistry.getNextPlatformViewId();
      fakePlatformViewRegistry.registerViewFactory('webview', _mockViewFactory);
      await tester.pumpWidgetWithoutViewWrapper(
        View(
          view: tester.view,
          child: const Center(
            child: SizedBox(
              width: 200.0,
              height: 100.0,
              child: HtmlElementView(viewType: 'webview'),
            ),
          ),
        ),
      );

      final Completer<void> resizeCompleter = Completer<void>();

      await tester.pumpWidgetWithoutViewWrapper(
        View(
          view: tester.view,
          child: const Center(
            child: SizedBox(
              width: 100.0,
              height: 50.0,
              child: HtmlElementView(viewType: 'webview'),
            ),
          ),
        ),
      );

      resizeCompleter.complete();
      await tester.pump();

      expect(
        fakePlatformViewRegistry.views,
        unorderedEquals(<FakePlatformView>[
          (platformViewId: currentViewId + 1, platformViewType: 'webview', params: null, htmlElement: _mockHtmlElement, viewId: tester.view.viewId),
        ]),
      );
    });

    testWidgetsWithLeakTracking('Change HTML view type', (WidgetTester tester) async {
      final int currentViewId = platformViewsRegistry.getNextPlatformViewId();
      fakePlatformViewRegistry.registerViewFactory('webview', _mockViewFactory);
      fakePlatformViewRegistry.registerViewFactory('maps', _mockViewFactory);
      await tester.pumpWidgetWithoutViewWrapper(
        View(
          view: tester.view,
          child: const Center(
            child: SizedBox(
              width: 200.0,
              height: 100.0,
              child: HtmlElementView(viewType: 'webview'),
            ),
          ),
        ),
      );

      await tester.pumpWidgetWithoutViewWrapper(
        View(
          view: tester.view,
          child: const Center(
            child: SizedBox(
              width: 200.0,
              height: 100.0,
              child: HtmlElementView(viewType: 'maps'),
            ),
          ),
        ),
      );

      expect(
        fakePlatformViewRegistry.views,
        unorderedEquals(<FakePlatformView>[
          (platformViewId: currentViewId + 2, platformViewType: 'maps', params: null, htmlElement: _mockHtmlElement, viewId: tester.view.viewId),
        ]),
      );
    });

    testWidgetsWithLeakTracking('Dispose HTML view', (WidgetTester tester) async {
      fakePlatformViewRegistry.registerViewFactory('webview', _mockViewFactory);
      await tester.pumpWidgetWithoutViewWrapper(
        View(
          view: tester.view,
          child: const Center(
            child: SizedBox(
              width: 200.0,
              height: 100.0,
              child: HtmlElementView(viewType: 'webview'),
            ),
          ),
        ),
      );

      await tester.pumpWidgetWithoutViewWrapper(
        View(
          view: tester.view,
          child: const Center(
            child: SizedBox(
              width: 200.0,
              height: 100.0,
            ),
          ),
        ),
      );

      expect(
        fakePlatformViewRegistry.views,
        isEmpty,
      );
    });

    testWidgetsWithLeakTracking('HTML view survives widget tree change', (WidgetTester tester) async {
      final int currentViewId = platformViewsRegistry.getNextPlatformViewId();
      fakePlatformViewRegistry.registerViewFactory('webview', _mockViewFactory);
      final GlobalKey key = GlobalKey();
      await tester.pumpWidgetWithoutViewWrapper(
        View(
          view: tester.view,
          child: Center(
            child: SizedBox(
              width: 200.0,
              height: 100.0,
              child: HtmlElementView(viewType: 'webview', key: key),
            ),
          ),
        ),
      );

      await tester.pumpWidgetWithoutViewWrapper(
        View(
          view: tester.view,
          child: Center(
            child: SizedBox(
              width: 200.0,
              height: 100.0,
              child: HtmlElementView(viewType: 'webview', key: key),
            ),
          ),
        ),
      );

      expect(
        fakePlatformViewRegistry.views,
        unorderedEquals(<FakePlatformView>[
          (platformViewId: currentViewId + 1, platformViewType: 'webview', params: null, htmlElement: _mockHtmlElement, viewId: tester.view.viewId),
        ]),
      );
    });

    testWidgetsWithLeakTracking('HtmlElementView has correct semantics', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final int currentViewId = platformViewsRegistry.getNextPlatformViewId();
      expect(currentViewId, greaterThanOrEqualTo(0));
      fakePlatformViewRegistry.registerViewFactory('webview', _mockViewFactory);

      await tester.pumpWidgetWithoutViewWrapper(
        View(
          view: tester.view,
          child: Semantics(
            container: true,
            child: const Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(
                width: 200.0,
                height: 100.0,
                child: HtmlElementView(
                  viewType: 'webview',
                ),
              ),
            ),
          ),
        ),
      );
      // First frame is before the platform view was created so the render object
      // is not yet in the tree.
      await tester.pump();

      // The platform view ID is set on the child of the HtmlElementView render object.
      final SemanticsNode semantics = tester.getSemantics(find.byType(PlatformViewSurface));

      expect(semantics.platformViewId, currentViewId + 1);
      expect(semantics.rect, const Rect.fromLTWH(0, 0, 200, 100));
      // A 200x100 rect positioned at bottom right of a 800x600 box.
      expect(semantics.transform, Matrix4.translationValues(600, 500, 0));
      expect(semantics.childrenCount, 0);

      handle.dispose();
    });
  });

  group('HtmlElementView.fromTagName', () {
    setUp(() {
      debugOverridePlatformViewRegistry = fakePlatformViewRegistry;
    });

    tearDown(() {
      debugOverridePlatformViewRegistry = null;
    });

    testWidgetsWithLeakTracking('Create platform view from tagName', (WidgetTester tester) async {
      final int currentViewId = platformViewsRegistry.getNextPlatformViewId();

      await tester.pumpWidgetWithoutViewWrapper(
        View(
          view: tester.view,
          child: Center(
            child: SizedBox(
              width: 200.0,
              height: 100.0,
              child: HtmlElementView.fromTagName(tagName: 'div'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakePlatformViewRegistry.views, hasLength(1));
      final FakePlatformView fakePlatformView = fakePlatformViewRegistry.views.single;
      expect(fakePlatformView.platformViewId, currentViewId + 1);
      expect(fakePlatformView.platformViewType, ui_web.PlatformViewRegistry.defaultVisibleViewType);
      expect(fakePlatformView.params, <dynamic, dynamic>{'tagName': 'div'});

      // The HTML element should be a div.
      final web.HTMLElement htmlElement = fakePlatformView.htmlElement as web.HTMLElement;
      expect(htmlElement.tagName, equalsIgnoringCase('div'));
    });

    testWidgetsWithLeakTracking('Create invisible platform view', (WidgetTester tester) async {
      final int currentViewId = platformViewsRegistry.getNextPlatformViewId();

      await tester.pumpWidgetWithoutViewWrapper(
        View(
          view: tester.view,
          child: Center(
            child: SizedBox(
              width: 200.0,
              height: 100.0,
              child: HtmlElementView.fromTagName(tagName: 'script', isVisible: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakePlatformViewRegistry.views, hasLength(1));
      final FakePlatformView fakePlatformView = fakePlatformViewRegistry.views.single;
      expect(fakePlatformView.platformViewId, currentViewId + 1);
      // The view should be invisible.
      expect(fakePlatformView.platformViewType, ui_web.PlatformViewRegistry.defaultInvisibleViewType);
      expect(fakePlatformView.params, <dynamic, dynamic>{'tagName': 'script'});

      // The HTML element should be a script.
      final web.HTMLElement htmlElement = fakePlatformView.htmlElement as web.HTMLElement;
      expect(htmlElement.tagName, equalsIgnoringCase('script'));
    });

    testWidgetsWithLeakTracking('onElementCreated', (WidgetTester tester) async {
      final List<Object> createdElements = <Object>[];
      void onElementCreated(Object element) {
        createdElements.add(element);
      }

      await tester.pumpWidgetWithoutViewWrapper(
        View(
          view: tester.view,
          child: Center(
            child: SizedBox(
              width: 200.0,
              height: 100.0,
              child: HtmlElementView.fromTagName(
                tagName: 'table',
                onElementCreated: onElementCreated,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakePlatformViewRegistry.views, hasLength(1));
      final FakePlatformView fakePlatformView = fakePlatformViewRegistry.views.single;

      expect(createdElements, hasLength(1));
      final Object createdElement = createdElements.single;

      expect(createdElement, fakePlatformView.htmlElement);
    });
  });
}

typedef FakeViewFactory = ({
  String viewType,
  bool isVisible,
  Function viewFactory,
});

typedef FakePlatformView = ({
  int platformViewId,
  String platformViewType,
  Object? params,
  Object htmlElement,
  int viewId,
});

class FakePlatformViewRegistry implements ui_web.PlatformViewRegistry {
  FakePlatformViewRegistry() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform_views, _onMethodCall);
  }

  Set<FakePlatformView> get views => Set<FakePlatformView>.unmodifiable(_views);
  final Set<FakePlatformView> _views = <FakePlatformView>{};

  final Set<FakeViewFactory> _registeredViewTypes = <FakeViewFactory>{};

  @override
  bool registerViewFactory(String viewType, Function viewFactory, {bool isVisible = true}) {
    if (_findRegisteredViewFactory(viewType) != null) {
      return false;
    }
    _registeredViewTypes.add((
      viewType: viewType,
      isVisible: isVisible,
      viewFactory: viewFactory,
    ));
    return true;
  }

  @override
  Object getViewById(int viewId) {
    return _findViewById(viewId)!.htmlElement;
  }

  FakeViewFactory? _findRegisteredViewFactory(String viewType) {
    return _registeredViewTypes.singleWhereOrNull(
      (FakeViewFactory registered) => registered.viewType == viewType,
    );
  }

  FakePlatformView? _findViewById(int platformViewId) {
    return _views.singleWhereOrNull(
      (FakePlatformView view) => view.platformViewId == platformViewId,
    );
  }

  Future<dynamic> _onMethodCall(MethodCall call) {
    switch (call.method) {
      case 'create':
        return _create(call);
      case 'dispose':
        return _dispose(call);
    }
    return Future<dynamic>.sync(() => null);
  }

  Future<dynamic> _create(MethodCall call) async {
    final Map<dynamic, dynamic> args = call.arguments as Map<dynamic, dynamic>;
    final int platformViewId = args['platformViewId'] as int;
    final String platformViewType = args['platformViewType'] as String;
    final Object? params = args['params'];
    final int viewId = args['viewId'] as int;

    if (_findViewById(platformViewId) != null) {
      throw PlatformException(
        code: 'error',
        message: 'Trying to create an already created platform view, view id: $platformViewId',
      );
    }

    final FakeViewFactory? registered = _findRegisteredViewFactory(platformViewType);
    if (registered == null) {
      throw PlatformException(
        code: 'error',
        message: 'Trying to create a platform view of unregistered type: $platformViewType',
      );
    }

    final ui_web.ParameterizedPlatformViewFactory viewFactory =
        registered.viewFactory as ui_web.ParameterizedPlatformViewFactory;

    _views.add((
      platformViewId: platformViewId,
      platformViewType: platformViewType,
      params: params,
      htmlElement: viewFactory(platformViewId, params: params),
      viewId: viewId,
    ));
    return null;
  }

  Future<dynamic> _dispose(MethodCall call) async {
    final Map<dynamic, dynamic> args = call.arguments as Map<dynamic, dynamic>;
    final int platformViewId = args['platformViewId'] as int;
    final int viewId = args['viewId'] as int;

    final FakePlatformView? view = _findViewById(platformViewId);
    if (view == null) {
      throw PlatformException(
        code: 'error',
        message: 'Trying to dispose a platform view with unknown id: $platformViewId',
      );
    }

    expect(view.viewId, viewId);

    _views.remove(view);
    return null;
  }
}
