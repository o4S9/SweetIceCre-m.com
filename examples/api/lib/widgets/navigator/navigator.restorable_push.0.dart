// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Flutter code sample for [Navigator.restorablePush].

void main() => runApp(const RestorablePushExampleApp());

class RestorablePushExampleApp extends StatelessWidget {
  const RestorablePushExampleApp({super.key});

  static const String _title = 'Navigator Sample';

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: _title,
      home: RestorablePushExample(),
    );
  }
}

class RestorablePushExample extends StatefulWidget {
  const RestorablePushExample({super.key});

  @override
  State<RestorablePushExample> createState() => _RestorablePushExampleState();
}

class _RestorablePushExampleState extends State<RestorablePushExample> {
  @pragma('vm:entry-point')
  static Route<void> _myRouteBuilder(BuildContext context, Object? arguments) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => const RestorablePushExample(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sample Code'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.restorablePush(context, _myRouteBuilder),
        tooltip: 'Increment Counter',
        child: const Icon(Icons.add),
      ),
    );
  }
}
