import 'dart:async';

import 'package:flutter/services.dart';

/// A mock stream handler for an [EventChannel]
abstract class MockStreamHandler {
  /// Handler for the listen event
  void onListen(dynamic arguments, MockStreamHandlerEventSink events);

  /// Handler for the cancel event
  void onCancel(dynamic arguments);
}

/// A mock event sink for a [MockStreamHandler]
class MockStreamHandlerEventSink {
  /// Constructor
  MockStreamHandlerEventSink(this._sink);

  final EventSink<dynamic> _sink;

  /// Send a success event
  void success(dynamic event) => _sink.add(event);

  /// Send an error event
  void error({
    required String code,
    String? message,
    Object? details,
  }) =>
      _sink.addError(
        PlatformException(code: code, message: message, details: details),
      );

  /// Send an end of stream event
  void endOfStream() => _sink.close();
}
