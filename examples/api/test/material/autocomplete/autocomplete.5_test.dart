// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_api_samples/material/autocomplete/autocomplete.5.dart'
    as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'can display initial, loading, and no options found messages',
      (WidgetTester tester) async {
    await tester.pumpWidget(const example.AutocompleteExampleApp());

    expect(find.text('aardvark'), findsNothing);
    expect(find.text('bobcat'), findsNothing);
    expect(find.text('chameleon'), findsNothing);
    expect(find.text('loading...'), findsNothing);
    expect(find.text('Type something'), findsNothing);
    expect(find.text('no options found!'), findsNothing);

    // Field is focused for the first time.
    await tester.enterText(find.byType(TextFormField), '');
    await tester.pump();

    expect(find.text('aardvark'), findsNothing);
    expect(find.text('bobcat'), findsNothing);
    expect(find.text('chameleon'), findsNothing);
    expect(find.text('loading...'), findsNothing);
    expect(find.text('Type something'), findsOneWidget);
    expect(find.text('no options found!'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'a');
    await tester.pump();

    // Display loading message as text is entered.
    expect(find.text('loading...'), findsOneWidget);

    await tester.pump(example.fakeAPIDuration);

    // No results yet, need to also wait for the debounce duration.
    // Loading message is still displayed.
    expect(find.text('aardvark'), findsNothing);
    expect(find.text('bobcat'), findsNothing);
    expect(find.text('chameleon'), findsNothing);
    expect(find.text('loading...'), findsOneWidget);
    expect(find.text('Type something'), findsNothing);
    expect(find.text('no options found!'), findsNothing);

    await tester.pump(example.debounceDuration);

    expect(find.text('aardvark'), findsOneWidget);
    expect(find.text('bobcat'), findsOneWidget);
    expect(find.text('chameleon'), findsOneWidget);
    expect(find.text('loading...'), findsNothing);
    expect(find.text('Type something'), findsNothing);
    expect(find.text('no options found!'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'aa');
    await tester.pump(example.debounceDuration + example.fakeAPIDuration);

    expect(find.text('aardvark'), findsOneWidget);
    expect(find.text('bobcat'), findsNothing);
    expect(find.text('chameleon'), findsNothing);
    expect(find.text('loading...'), findsNothing);
    expect(find.text('Type something'), findsNothing);
    expect(find.text('no options found!'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'aax');
    await tester.pump(example.debounceDuration + example.fakeAPIDuration);

    // No results were found.
    expect(find.text('aardvark'), findsNothing);
    expect(find.text('bobcat'), findsNothing);
    expect(find.text('chameleon'), findsNothing);
    expect(find.text('loading...'), findsNothing);
    expect(find.text('Type something'), findsNothing);
    expect(find.text('no options found!'), findsOneWidget);
  });


  testWidgets('can display loading message if debounce is reset each time a character is entered',
      (WidgetTester tester) async {
    await tester.pumpWidget(const example.AutocompleteExampleApp());

    await tester.enterText(find.byType(TextFormField), 'c');
    await tester.pump();
    expect(find.text('loading...'), findsOneWidget);
    await tester
        .pump(example.debounceDuration - const Duration(milliseconds: 100));

    expect(find.text('aardvark'), findsNothing);
    expect(find.text('bobcat'), findsNothing);
    expect(find.text('chameleon'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'ch');
    await tester.pump();
    expect(find.text('loading...'), findsOneWidget);
    await tester
        .pump(example.debounceDuration - const Duration(milliseconds: 100));

    expect(find.text('aardvark'), findsNothing);
    expect(find.text('bobcat'), findsNothing);
    expect(find.text('chameleon'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'cha');
    await tester.pump();
    expect(find.text('loading...'), findsOneWidget);
    await tester
        .pump(example.debounceDuration - const Duration(milliseconds: 100));

    expect(find.text('aardvark'), findsNothing);
    expect(find.text('bobcat'), findsNothing);
    expect(find.text('chameleon'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'cham');
    await tester.pump();
    expect(find.text('loading...'), findsOneWidget);
    await tester
        .pump(example.debounceDuration - const Duration(milliseconds: 100));

    // Despite the total elapsed time being greater than debounceDuration +
    // fakeAPIDuration, the search has not yet completed, because the debounce
    // was reset each time text input happened.
    expect(find.text('aardvark'), findsNothing);
    expect(find.text('bobcat'), findsNothing);
    expect(find.text('chameleon'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'chame');
    await tester.pump(example.debounceDuration + example.fakeAPIDuration);

    expect(find.text('aardvark'), findsNothing);
    expect(find.text('bobcat'), findsNothing);
    expect(find.text('chameleon'), findsOneWidget);
    expect(find.text('loading...'), findsNothing);
  });

  testWidgets('can display loading message with multiple pending requests', (WidgetTester tester) async {
    await tester.pumpWidget(const example.AutocompleteExampleApp());

    await tester.enterText(find.byType(TextFormField), 'a');
    await tester.pump();
    expect(find.text('loading...'), findsOneWidget);

    // Wait until the debounce duration has expired, but the request is still
    // pending.
    await tester.pump(example.debounceDuration);

    expect(find.text('aardvark'), findsNothing);
    expect(find.text('bobcat'), findsNothing);
    expect(find.text('chameleon'), findsNothing);
    expect(find.text('loading...'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'aa');
    await tester.pump();
    expect(find.text('loading...'), findsOneWidget);

    // Wait until the first request has completed.
    await tester.pump(example.fakeAPIDuration - example.debounceDuration);

    // The results from the first request are thrown away since the query has
    // changed.
    expect(find.text('aardvark'), findsNothing);
    expect(find.text('bobcat'), findsNothing);
    expect(find.text('chameleon'), findsNothing);
    expect(find.text('loading...'), findsOneWidget);

    // Wait until the second request has completed.
    await tester.pump(example.fakeAPIDuration);

    // The results of the second request are reflected.
    expect(find.text('aardvark'), findsOneWidget);
    expect(find.text('bobcat'), findsNothing);
    expect(find.text('chameleon'), findsNothing);
    expect(find.text('loading...'), findsNothing);
  });
}
