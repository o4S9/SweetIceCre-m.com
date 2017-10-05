// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class FooMaterialLocalizations extends GlobalMaterialLocalizations {
  FooMaterialLocalizations(Locale locale) : super(locale);

  @override
  String get backButtonTooltip => 'foo';
}

class FooMaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const FooMaterialLocalizationsDelegate();

  @override
  Future<FooMaterialLocalizations> load(Locale locale) {
    return new SynchronousFuture<FooMaterialLocalizations>(new FooMaterialLocalizations(locale));
  }

  @override
  bool shouldReload(FooMaterialLocalizationsDelegate old) => false;
}

Widget buildFrame({
  Locale locale,
  Iterable<LocalizationsDelegate<dynamic>> delegates: const <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
  ],
  WidgetBuilder buildContent,
  LocaleResolutionCallback localeResolutionCallback,
  Iterable<Locale> supportedLocales: const <Locale>[
    const Locale('en', 'US'),
    const Locale('es', 'es'),
  ],
}) {
  return new MaterialApp(
    color: const Color(0xFFFFFFFF),
    locale: locale,
    supportedLocales: supportedLocales,
    localizationsDelegates: delegates,
    localeResolutionCallback: localeResolutionCallback,
    onGenerateRoute: (RouteSettings settings) {
      return new MaterialPageRoute<Null>(
        builder: (BuildContext context) {
          return buildContent(context);
        }
      );
    },
  );
}

void main() {
  testWidgets('Locale fallbacks', (WidgetTester tester) async {
    final Key textKey = new UniqueKey();

    await tester.pumpWidget(
      buildFrame(
        buildContent: (BuildContext context) {
          return new Text(
            MaterialLocalizations.of(context).backButtonTooltip,
            key: textKey,
          );
        }
      )
    );

    expect(tester.widget<Text>(find.byKey(textKey)).data, 'Back');

    // Unrecognized locale falls back to 'en'
    await tester.binding.setLocale('foo', 'bar');
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(textKey)).data, 'Back');

    // Spanish Bolivia locale, falls back to just 'es'
    await tester.binding.setLocale('es', 'bo');
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(textKey)).data, 'Espalda');
  });

  testWidgets('Localizations.override widget tracks parent\'s locale', (WidgetTester tester) async {
    Widget buildLocaleFrame(Locale locale) {
      return buildFrame(
        locale: locale,
        buildContent: (BuildContext context) {
          return new Localizations.override(
            context: context,
            child: new Builder(
              builder: (BuildContext context) {
                // No MaterialLocalizations are defined for the first Localizations
                // ancestor, so we should get the values from the default one, i.e.
                // the one created by WidgetsApp via the LocalizationsDelegate
                // provided by MaterialApp.
                return new Text(MaterialLocalizations.of(context).backButtonTooltip);
              },
            ),
          );
        }
      );
    }

    await tester.pumpWidget(buildLocaleFrame(const Locale('en', 'US')));
    expect(find.text('Back'), findsOneWidget);

    await tester.pumpWidget(buildLocaleFrame(const Locale('de', 'DE')));
    expect(find.text('Zurück'), findsOneWidget);

    await tester.pumpWidget(buildLocaleFrame(const Locale('zh', 'CN')));
    expect(find.text('返回'), findsOneWidget);
  });

  testWidgets('Localizations.override widget with hardwired locale', (WidgetTester tester) async {
    Widget buildLocaleFrame(Locale locale) {
      return buildFrame(
        locale: locale,
        buildContent: (BuildContext context) {
          return new Localizations.override(
            context: context,
            locale: const Locale('en', 'US'),
            child: new Builder(
              builder: (BuildContext context) {
                // No MaterialLocalizations are defined for the Localizations.override
                // ancestor, so we should get all values from the default one, i.e.
                // the one created by WidgetsApp via the LocalizationsDelegate
                // provided by MaterialApp.
                return new Text(MaterialLocalizations.of(context).backButtonTooltip);
              },
            ),
          );
        }
      );
    }

    await tester.pumpWidget(buildLocaleFrame(const Locale('en', 'US')));
    expect(find.text('Back'), findsOneWidget);

    await tester.pumpWidget(buildLocaleFrame(const Locale('de', 'DE')));
    expect(find.text('Back'), findsOneWidget);

    await tester.pumpWidget(buildLocaleFrame(const Locale('zh', 'CN')));
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('MaterialApp overrides MaterialLocalizations', (WidgetTester tester) async {
    final Key textKey = new UniqueKey();

    await tester.pumpWidget(
      buildFrame(
        // Accept whatever locale we're given
        localeResolutionCallback: (Locale locale, Iterable<Locale> supportedLocales) => locale,
        delegates: <FooMaterialLocalizationsDelegate>[
          const FooMaterialLocalizationsDelegate(),
        ],
        buildContent: (BuildContext context) {
          // Should always be 'foo', no matter what the locale is
          return new Text(
            MaterialLocalizations.of(context).backButtonTooltip,
            key: textKey,
          );
        }
      )
    );

    expect(tester.widget<Text>(find.byKey(textKey)).data, 'foo');

    await tester.binding.setLocale('zh', 'CN');
    await tester.pump();
    expect(find.text('foo'), findsOneWidget);

    await tester.binding.setLocale('de', 'DE');
    await tester.pump();
    expect(find.text('foo'), findsOneWidget);
  });

  testWidgets('deprecated Android/Java locales are modernized', (WidgetTester tester) async {
    final Key textKey = new UniqueKey();

    await tester.pumpWidget(
      buildFrame(
        supportedLocales: <Locale>[
          const Locale('en', 'US'),
          const Locale('he', 'IL'),
          const Locale('yi', 'IL'),
          const Locale('id', 'JV'),
        ],
        buildContent: (BuildContext context) {
          return new Text(
            '${Localizations.localeOf(context)}',
            key: textKey,
          );
        },
      )
    );

    expect(tester.widget<Text>(find.byKey(textKey)).data, 'en_US');

    // Hebrew was iw (ISO-639) is he (ISO-639-1)
    await tester.binding.setLocale('iw', 'IL');
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(textKey)).data, 'he_IL');

    // Yiddish was ji (ISO-639) is yi (ISO-639-1)
    await tester.binding.setLocale('ji', 'IL');
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(textKey)).data, 'yi_IL');

    // Indonesian was in (ISO-639) is id (ISO-639-1)
    await tester.binding.setLocale('in', 'JV');
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(textKey)).data, 'id_JV');
  });
}
