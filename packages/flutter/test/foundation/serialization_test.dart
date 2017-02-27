// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:test/test.dart';

import 'dart:typed_data';

void main() {
  group('Write and read buffer round-trip', () {
    test('of single byte', () {
      final WriteBuffer write = new WriteBuffer();
      write.putUint8(201);
      final ByteData written = write.done();
      expect(written.lengthInBytes, equals(1));
      final ReadBuffer read = new ReadBuffer(written);
      expect(read.getUint8(), equals(201));
    });
    test('of 32-bit integer', () {
      final WriteBuffer write = new WriteBuffer();
      write.putInt32(-9);
      final ByteData written = write.done();
      expect(written.lengthInBytes, equals(4));
      final ReadBuffer read = new ReadBuffer(written);
      expect(read.getInt32(), equals(-9));
    });
    test('of 64-bit integer', () {
      final WriteBuffer write = new WriteBuffer();
      write.putInt64(-9000000000000);
      final ByteData written = write.done();
      expect(written.lengthInBytes, equals(8));
      final ReadBuffer read = new ReadBuffer(written);
      expect(read.getInt64(), equals(-9000000000000));
    });
    test('of double', () {
      final WriteBuffer write = new WriteBuffer();
      write.putFloat64(3.14);
      final ByteData written = write.done();
      expect(written.lengthInBytes, equals(8));
      final ReadBuffer read = new ReadBuffer(written);
      expect(read.getFloat64(), equals(3.14));
    });
    test('of 32-bit int list when unaligned', () {
      final Int32List integers = new Int32List.fromList(<int>[-99, 2, 99]);
      final WriteBuffer write = new WriteBuffer();
      write.putUint8(9);
      write.putInt32List(integers);
      final ByteData written = write.done();
      expect(written.lengthInBytes, equals(16));
      final ReadBuffer read = new ReadBuffer(written);
      read.getUint8();
      expect(read.getInt32List(3), equals(integers));
    });
    test('of 64-bit int list when unaligned', () {
      final Int64List integers = new Int64List.fromList(<int>[-99, 2, 99]);
      final WriteBuffer write = new WriteBuffer();
      write.putUint8(9);
      write.putInt64List(integers);
      final ByteData written = write.done();
      expect(written.lengthInBytes, equals(32));
      final ReadBuffer read = new ReadBuffer(written);
      read.getUint8();
      expect(read.getInt64List(3), equals(integers));
    });
  });
}