// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Flutter code sample for [WidgetStateMouseCursor].

void main() => runApp(const MaterialStateMouseCursorExampleApp());

class MaterialStateMouseCursorExampleApp extends StatelessWidget {
  const MaterialStateMouseCursorExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('MaterialStateMouseCursor Sample')),
        body: const Center(
          child: MaterialStateMouseCursorExample(),
        ),
      ),
    );
  }
}

class ListTileCursor extends WidgetStateMouseCursor {
  const ListTileCursor();

  @override
  MouseCursor resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return SystemMouseCursors.forbidden;
    }
    return SystemMouseCursors.click;
  }

  @override
  String get debugDescription => 'ListTileCursor()';
}

class MaterialStateMouseCursorExample extends StatelessWidget {
  const MaterialStateMouseCursorExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      title: Text('Disabled ListTile'),
      enabled: false,
      mouseCursor: ListTileCursor(),
    );
  }
}
