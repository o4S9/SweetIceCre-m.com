// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Codec, FrameInfo;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../image_data.dart';
import '../rendering/rendering_tester.dart';

void main() {
  TestRenderingFlutterBinding();

  Future<Codec>  _basicDecoder(Uint8List bytes, {int? cacheWidth, int? cacheHeight, bool? allowUpscaling}) {
    return PaintingBinding.instance!.instantiateImageCodec(bytes, cacheWidth: cacheWidth, cacheHeight: cacheHeight, allowUpscaling: allowUpscaling ?? false);
  }

  late _FakeHttpClient httpClient;

  setUp(() {
    httpClient = _FakeHttpClient();
    debugNetworkImageHttpClientProvider = () => httpClient;
  });

  tearDown(() {
    debugNetworkImageHttpClientProvider = null;
    PaintingBinding.instance!.imageCache!.clear();
    PaintingBinding.instance!.imageCache!.clearLiveImages();
  });

  test('Expect thrown exception with statusCode - evicts from cache and drains', () async {
    final int errorStatusCode = HttpStatus.notFound;
    const String requestUrl = 'foo-url';

    httpClient.request.response.statusCode = errorStatusCode;

    final Completer<dynamic> caughtError = Completer<dynamic>();

    final ImageProvider imageProvider = NetworkImage(nonconst(requestUrl));
    expect(imageCache!.pendingImageCount, 0);
    expect(imageCache!.statusForKey(imageProvider).untracked, true);

    final ImageStream result = imageProvider.resolve(ImageConfiguration.empty);

    expect(imageCache!.pendingImageCount, 1);
    expect(imageCache!.statusForKey(imageProvider).pending, true);

    result.addListener(ImageStreamListener((ImageInfo info, bool syncCall) {
    }, onError: (dynamic error, StackTrace? stackTrace) {
      caughtError.complete(error);
    }));

    final dynamic err = await caughtError.future;

    expect(imageCache!.pendingImageCount, 0);
    expect(imageCache!.statusForKey(imageProvider).untracked, true);

    expect(
      err,
      isA<NetworkImageLoadException>()
        .having((NetworkImageLoadException e) => e.statusCode, 'statusCode', errorStatusCode)
        .having((NetworkImageLoadException e) => e.uri, 'uri', Uri.base.resolve(requestUrl)),
    );
    expect(httpClient.request.response.drained, true);
  }, skip: isBrowser); // Browser implementation does not use HTTP client but an <img> tag.

  test('Uses the HttpClient provided by debugNetworkImageHttpClientProvider if set', () async {
    httpClient.thrownError = 'client1';
    final List<dynamic> capturedErrors = <dynamic>[];

    Future<void> loadNetworkImage() async {
      final NetworkImage networkImage = NetworkImage(nonconst('foo'));
      final ImageStreamCompleter completer = networkImage.load(networkImage, _basicDecoder);
      completer.addListener(ImageStreamListener(
        (ImageInfo image, bool synchronousCall) { },
        onError: (dynamic error, StackTrace? stackTrace) {
          capturedErrors.add(error);
        },
      ));
      await Future<void>.value();
    }

    await loadNetworkImage();
    expect(capturedErrors, <dynamic>['client1']);
    final _FakeHttpClient client2 = _FakeHttpClient();
    client2.thrownError = 'client2';
    debugNetworkImageHttpClientProvider = () => client2;
    await loadNetworkImage();
    expect(capturedErrors, <dynamic>['client1', 'client2']);
  }, skip: isBrowser); // Browser implementation does not use HTTP client but an <img> tag.

  test('Propagates http client errors during resolve()', () async {
    httpClient.thrownError = Error();
    bool uncaught = false;

    final FlutterExceptionHandler? oldError = FlutterError.onError;
    await runZoned(() async {
      const ImageProvider imageProvider = NetworkImage('asdasdasdas');
      final Completer<bool> caughtError = Completer<bool>();
      FlutterError.onError = (FlutterErrorDetails details) {
        throw Error();
      };
      final ImageStream result = imageProvider.resolve(ImageConfiguration.empty);
      result.addListener(ImageStreamListener((ImageInfo info, bool syncCall) {
      }, onError: (dynamic error, StackTrace? stackTrace) {
        caughtError.complete(true);
      }));
      expect(await caughtError.future, true);
    }, zoneSpecification: ZoneSpecification(
      handleUncaughtError: (Zone zone, ZoneDelegate zoneDelegate, Zone parent, Object error, StackTrace stackTrace) {
        uncaught = true;
      },
    ));
    expect(uncaught, false);
    FlutterError.onError = oldError;
  });

  test('Notifies listeners of chunk events', () async {
    const int chunkSize = 8;
    final List<Uint8List> chunks = <Uint8List>[
      for (int offset = 0; offset < kTransparentImage.length; offset += chunkSize)
        Uint8List.fromList(kTransparentImage.skip(offset).take(chunkSize).toList()),
    ];
    final Completer<void> imageAvailable = Completer<void>();

    httpClient.request.response
      ..statusCode = HttpStatus.ok
      ..contentLength = kTransparentImage.length
      ..content = chunks;

    final ImageProvider imageProvider = NetworkImage(nonconst('foo'));
    final ImageStream result = imageProvider.resolve(ImageConfiguration.empty);
    final List<ImageChunkEvent> events = <ImageChunkEvent>[];
    result.addListener(ImageStreamListener(
      (ImageInfo image, bool synchronousCall) {
        imageAvailable.complete();
      },
      onChunk: (ImageChunkEvent event) {
        events.add(event);
      },
      onError: (dynamic error, StackTrace? stackTrace) {
        imageAvailable.completeError(error as Object, stackTrace);
      },
    ));
    await imageAvailable.future;
    expect(events.length, chunks.length);
    for (int i = 0; i < events.length; i++) {
      expect(events[i].cumulativeBytesLoaded, math.min((i + 1) * chunkSize, kTransparentImage.length));
      expect(events[i].expectedTotalBytes, kTransparentImage.length);
    }
  }, skip: isBrowser); // Browser loads images through <img> not Http.

  test('NetworkImage is evicted from cache on SocketException', () async {
    final _FakeHttpClient mockHttpClient = _FakeHttpClient();
    mockHttpClient.thrownError = const SocketException('test exception');
    debugNetworkImageHttpClientProvider = () => mockHttpClient;

    final ImageProvider imageProvider = NetworkImage(nonconst('testing.url'));
    expect(imageCache!.pendingImageCount, 0);
    expect(imageCache!.statusForKey(imageProvider).untracked, true);

    final ImageStream result = imageProvider.resolve(ImageConfiguration.empty);

    expect(imageCache!.pendingImageCount, 1);
    expect(imageCache!.statusForKey(imageProvider).pending, true);
    final Completer<dynamic> caughtError = Completer<dynamic>();
    result.addListener(ImageStreamListener(
      (ImageInfo info, bool syncCall) {},
      onError: (dynamic error, StackTrace? stackTrace) {
        caughtError.complete(error);
      },
    ));

    final dynamic err = await caughtError.future;

    expect(err, isA<SocketException>());

    expect(imageCache!.pendingImageCount, 0);
    expect(imageCache!.statusForKey(imageProvider).untracked, true);
    expect(imageCache!.containsKey(result), isFalse);

    debugNetworkImageHttpClientProvider = null;
  }, skip: isBrowser); // Browser does not resolve images this way.

  Future<Codec> _decoder(Uint8List bytes, {int? cacheWidth, int? cacheHeight, bool? allowUpscaling}) async {
    return FakeCodec();
  }

  test('Network image sets tag', () async {
    const String url = 'http://test.png';
    const int chunkSize = 8;
    final List<Uint8List> chunks = <Uint8List>[
      for (int offset = 0; offset < kTransparentImage.length; offset += chunkSize)
        Uint8List.fromList(kTransparentImage.skip(offset).take(chunkSize).toList()),
    ];
    httpClient.request.response
      ..statusCode = HttpStatus.ok
      ..contentLength = kTransparentImage.length
      ..content = chunks;

    const NetworkImage provider = NetworkImage(url);

    final MultiFrameImageStreamCompleter completer = provider.load(provider, _decoder) as MultiFrameImageStreamCompleter;

    expect(completer.debugLabel, url);
  });

  test('Different zones have different HttpClients', () async {
    debugNetworkImageHttpClientProvider = null;
    final Object error1 = Object();
    final Object error2 = Object();

    // assert that a configured fake http client throws the expected error
    // within an HttpOverrides zone.
    Future<void> expectError(Object expected) async {
      await HttpOverrides.runZoned(() async {
        final Completer<Object> completer = Completer<Object>();
        final ImageStreamListener listener = ImageStreamListener((ImageInfo data, bool syncCall) {
          // Do nothing.
        }, onError: (dynamic error, StackTrace? stackTrace) {
          completer.complete(error);
        });
        final ImageProvider imageProvider = NetworkImage(nonconst('testing.url'));
        final ImageStream stream = imageProvider.resolve(ImageConfiguration.empty);
        stream.addListener(listener);

        final Object value = await completer.future;
        if (!identical(await completer.future, expected)) {
          throw StateError('Expected $expected|${expected.hashCode} to be thrown but it was $value|${value.hashCode}.');
        }
      }, createHttpClient: (SecurityContext? context) {
        return _FakeHttpClient()..thrownError = expected;
      });
    }

    await expectError(error1);
    // Freshly created client should throw the new error instead of the previously
    // configured value.
    await expectError(error2);
  }, skip: isBrowser); // Browser implementation does not use HTTP client but an <img> tag.
}

class _FakeHttpClient extends Fake implements HttpClient {
  final _FakeHttpClientRequest request = _FakeHttpClientRequest();
  Object? thrownError;

  @override
  bool autoUncompress = false;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    if (thrownError != null) {
      throw thrownError!;
    }
    return request;
  }
}
class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  final _FakeHttpClientResponse response = _FakeHttpClientResponse();

  @override
  Future<HttpClientResponse> close() async {
    return response;
  }
}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  bool drained = false;

  @override
  int statusCode = HttpStatus.ok;

  @override
  int contentLength = 0;

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  List<List<int>> content = <List<int>>[];

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData, {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.fromIterable(content).listen(
      onData,
      onDone: onDone,
      onError: onError,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<E> drain<E>([E? futureValue]) async {
    drained = true;
    return futureValue ?? <int>[] as E;
  }
}

class FakeCodec implements Codec {
  @override
  void dispose() {}

  @override
  int get frameCount => throw UnimplementedError();

  @override
  Future<FrameInfo> getNextFrame() {
    throw UnimplementedError();
  }

  @override
  int get repetitionCount => throw UnimplementedError();
}
