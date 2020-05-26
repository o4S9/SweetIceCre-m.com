// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_inspector_test.dart';

void main() {
  StructuredErrorTestService.runTests();
}

class StructuredErrorTestService extends TestWidgetInspectorService {
  @override
  bool setStructuredErrorsEarly() {
    return true;
  }

  static void runTests() {
    final StructuredErrorTestService service = StructuredErrorTestService();
    WidgetInspectorService.instance = service;

    testWidgets('ext.flutter.inspector.setStructuredErrors', (WidgetTester tester) async {
      final FlutterExceptionHandler oldHandler = FlutterError.onError;
      WidgetInspectorService.instance.setStructuredErrors();

      try {
        List<Map<Object, Object>> flutterErrorEvents = service
            .getEventsDispatched('Flutter.Error');
        expect(flutterErrorEvents, hasLength(0));

        // Create an error.
        FlutterError.reportError(FlutterErrorDetailsForRendering(
          library: 'rendering library',
          context: ErrorDescription('during layout'),
          exception: StackTrace.current,
        ));

        // Validate that we received an error.
        flutterErrorEvents = service.getEventsDispatched('Flutter.Error');
        expect(flutterErrorEvents, hasLength(1));
      } finally {
        FlutterError.onError = oldHandler;
      }
    });
  }
}
