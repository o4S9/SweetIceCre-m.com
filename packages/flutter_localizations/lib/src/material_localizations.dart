// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n/localizations.dart';

/// Localized strings for the material widgets.
///
/// To include the localizations provided by this class in a [MaterialApp],
/// add [GlobalMaterialLocalizations.delegate] to
/// [MaterialApp.localizationsDelegates], and specify the locales your
/// app supports with [MaterialApp.supportedLocales]:
///
/// ```dart
/// new MaterialApp(
///   localizationsDelegates: [
///     GlobalMaterialLocalizations.delegate,
///   ],
///   supportedLocales: [
///     const Locale('en', 'US'), // English
///     const Locale('he', 'IL'), // Hebrew
///     // ...
///   ],
///   // ...
/// )
/// ```
///
/// This class supports locales with the following [Locale.languageCode]s:
///
///   * ar - Arabic
///   * de - German
///   * en - English
///   * es - Spanish
///   * fa - Farsi
///   * fr - French
///   * he - Hebrew
///   * it - Italian
///   * ja - Japanese
///   * ps - Pashto
///   * pt - Portugese
///   * ru - Russian
///   * sd - Sindhi
///   * ur - Urdu
///   * zh - Simplified Chinese
///
/// See also:
///
///  * The Flutter Internationalization Tutorial,
///    <https://flutter.io/tutorials/internationalization/>.
///  * [DefaultMaterialLocalizations], which only provides US English translations.
class GlobalMaterialLocalizations implements MaterialLocalizations {
  /// Constructs an object that defines the material widgets' localized strings
  /// for the given `locale`.
  ///
  /// [LocalizationsDelegate] implementations typically call the static [load]
  /// function, rather than constructing this class directly.
  GlobalMaterialLocalizations(this.locale)
      : this._localeName = _computeLocaleName(locale) {
    assert(locale != null);
    if (localizations.containsKey(locale.languageCode))
      _nameToValue.addAll(localizations[locale.languageCode]);
    if (localizations.containsKey(_localeName))
      _nameToValue.addAll(localizations[_localeName]);

    if (intl.NumberFormat.localeExists(_localeName)) {
      _decimalFormat = new intl.NumberFormat.decimalPattern(_localeName);
      _twoDigitZeroPaddedFormat = new intl.NumberFormat('00', _localeName);
    } else if (intl.NumberFormat.localeExists(locale.languageCode)) {
      _decimalFormat = new intl.NumberFormat.decimalPattern(locale.languageCode);
      _twoDigitZeroPaddedFormat = new intl.NumberFormat('00', locale.languageCode);
    } else {
      _decimalFormat = new intl.NumberFormat.decimalPattern();
      _twoDigitZeroPaddedFormat = new intl.NumberFormat('00');
    }
  }

  /// The locale for which the values of this class's localized resources
  /// have been translated.
  final Locale locale;

  final String _localeName;

  final Map<String, String> _nameToValue = <String, String>{};

  /// Formats numbers using variable length format with no zero padding.
  ///
  /// See also [_twoDigitZeroPaddedFormat].
  intl.NumberFormat _decimalFormat;

  /// Formats numbers as two-digits.
  ///
  /// If the number is less than 10, zero-pads it.
  intl.NumberFormat _twoDigitZeroPaddedFormat;

  static String _computeLocaleName(Locale locale) {
    final String localeName = locale.countryCode.isEmpty ? locale.languageCode : locale.toString();
    return intl.Intl.canonicalizedLocale(localeName);
  }

  // TODO(hmuller): the rules for mapping from an integer value to
  // "one" or "two" etc. are locale specific and an additional "few" category
  // is needed. See http://cldr.unicode.org/index/cldr-spec/plural-rules
  String _nameToPluralValue(int count, String key) {
    String text;
    if (count == 0)
      text = _nameToValue['${key}Zero'];
    else if (count == 1)
      text = _nameToValue['${key}One'];
    else if (count == 2)
      text = _nameToValue['${key}Two'];
    else if (count > 2)
      text = _nameToValue['${key}Many'];
    text ??= _nameToValue['${key}Other'];
    assert(text != null);
    return text;
  }

  @override
  String formatHour(TimeOfDay timeOfDay) {
    switch (hourFormat(of: timeOfDayFormat)) {
      case HourFormat.HH:
        return _twoDigitZeroPaddedFormat.format(timeOfDay.hour);
      case HourFormat.H:
        return formatDecimal(timeOfDay.hour);
      case HourFormat.h:
        final int hour = timeOfDay.hourOfPeriod;
        return formatDecimal(hour == 0 ? 12 : hour);
    }
    return null;
  }

  @override
  String formatMinute(TimeOfDay timeOfDay) {
    return _twoDigitZeroPaddedFormat.format(timeOfDay.minute);
  }

  /// Formats a [number] using local decimal number format.
  ///
  /// Inserts locale-appropriate thousands separator, if necessary.
  String formatDecimal(int number) {
    return _decimalFormat.format(number);
  }

  @override
  String formatTimeOfDay(TimeOfDay timeOfDay) {
    // Not using intl.DateFormat for two reasons:
    //
    // - DateFormat supports more formats than our material time picker does,
    //   and we want to be consistent across time picker format and the string
    //   formatting of the time of day.
    // - DateFormat operates on DateTime, which is sensitive to time eras and
    //   time zones, while here we want to format hour and minute within one day
    //   no matter what date the day falls on.
    switch (timeOfDayFormat) {
      case TimeOfDayFormat.h_colon_mm_space_a:
        return '${formatHour(timeOfDay)}:${formatMinute(timeOfDay)} ${_formatDayPeriod(timeOfDay)}';
      case TimeOfDayFormat.H_colon_mm:
      case TimeOfDayFormat.HH_colon_mm:
        return '${formatHour(timeOfDay)}:${formatMinute(timeOfDay)}';
      case TimeOfDayFormat.HH_dot_mm:
        return '${formatHour(timeOfDay)}.${formatMinute(timeOfDay)}';
      case TimeOfDayFormat.a_space_h_colon_mm:
        return '${_formatDayPeriod(timeOfDay)} ${formatHour(timeOfDay)}:${formatMinute(timeOfDay)}';
      case TimeOfDayFormat.frenchCanadian:
        return '${formatHour(timeOfDay)} h ${formatMinute(timeOfDay)}';
    }

    return null;
  }

  String _formatDayPeriod(TimeOfDay timeOfDay) {
    switch (timeOfDay.period) {
      case DayPeriod.am:
        return anteMeridiemAbbreviation;
      case DayPeriod.pm:
        return postMeridiemAbbreviation;
    }
    return null;
  }

  @override
  String get openAppDrawerTooltip => _nameToValue['openAppDrawerTooltip'];

  @override
  String get backButtonTooltip => _nameToValue['backButtonTooltip'];

  @override
  String get closeButtonTooltip => _nameToValue['closeButtonTooltip'];

  @override
  String get nextMonthTooltip => _nameToValue['nextMonthTooltip'];

  @override
  String get previousMonthTooltip => _nameToValue['previousMonthTooltip'];

  @override
  String get nextPageTooltip => _nameToValue['nextPageTooltip'];

  @override
  String get previousPageTooltip => _nameToValue['previousPageTooltip'];

  @override
  String get showMenuTooltip => _nameToValue['showMenuTooltip'];

  @override
  String aboutListTileTitle(String applicationName) {
    final String text = _nameToValue['aboutListTileTitle'];
    return text.replaceFirst(r'$applicationName', applicationName);
  }

  @override
  String get licensesPageTitle => _nameToValue['licensesPageTitle'];

  @override
  String pageRowsInfoTitle(int firstRow, int lastRow, int rowCount, bool rowCountIsApproximate) {
    String text = rowCountIsApproximate ? _nameToValue['pageRowsInfoTitleApproximate'] : null;
    text ??= _nameToValue['pageRowsInfoTitle'];
    assert(text != null, 'A $locale localization was not found for pageRowsInfoTitle or pageRowsInfoTitleApproximate');
    // TODO(hansmuller): this could be more efficient.
    return text
      .replaceFirst(r'$firstRow', formatDecimal(firstRow))
      .replaceFirst(r'$lastRow', formatDecimal(lastRow))
      .replaceFirst(r'$rowCount', formatDecimal(rowCount));
  }

  @override
  String get rowsPerPageTitle => _nameToValue['rowsPerPageTitle'];

  @override
  String selectedRowCountTitle(int selectedRowCount) {
    return _nameToPluralValue(selectedRowCount, 'selectedRowCountTitle') // asserts on no match
      .replaceFirst(r'$selectedRowCount', formatDecimal(selectedRowCount));
  }

  @override
  String get cancelButtonLabel => _nameToValue['cancelButtonLabel'];

  @override
  String get closeButtonLabel => _nameToValue['closeButtonLabel'];

  @override
  String get continueButtonLabel => _nameToValue['continueButtonLabel'];

  @override
  String get copyButtonLabel => _nameToValue['copyButtonLabel'];

  @override
  String get cutButtonLabel => _nameToValue['cutButtonLabel'];

  @override
  String get okButtonLabel => _nameToValue['okButtonLabel'];

  @override
  String get pasteButtonLabel => _nameToValue['pasteButtonLabel'];

  @override
  String get selectAllButtonLabel => _nameToValue['selectAllButtonLabel'];

  @override
  String get viewLicensesButtonLabel => _nameToValue['viewLicensesButtonLabel'];

  @override
  String get anteMeridiemAbbreviation => _nameToValue['anteMeridiemAbbreviation'];

  @override
  String get postMeridiemAbbreviation => _nameToValue['postMeridiemAbbreviation'];

  /// The [TimeOfDayFormat] corresponding to one of the following supported
  /// patterns:
  ///
  ///  * `HH:mm`
  ///  * `HH.mm`
  ///  * `HH 'h' mm`
  ///  * `HH:mm น.`
  ///  * `H:mm`
  ///  * `h:mm a`
  ///  * `a h:mm`
  ///  * `ah:mm`
  ///
  /// See also:
  ///
  ///  * http://demo.icu-project.org/icu-bin/locexp?d_=en&_=en_US shows the
  ///    short time pattern used in locale en_US
  @override
  TimeOfDayFormat get timeOfDayFormat {
    final String icuShortTimePattern = _nameToValue['timeOfDayFormat'];

    assert(() {
      if (!_icuTimeOfDayToEnum.containsKey(icuShortTimePattern)) {
        throw new FlutterError(
          '"$icuShortTimePattern" is not one of the ICU short time patterns '
          'supported by the material library. Here is the list of supported '
          'patterns:\n  ' +
          _icuTimeOfDayToEnum.keys.join('\n  ')
        );
      }
      return true;
    }());

    return _icuTimeOfDayToEnum[icuShortTimePattern];
  }

  /// Looks up text geometry defined in [MaterialTextGeometry].
  @override
  TextTheme get localTextGeometry => MaterialTextGeometry.forScriptCategory(_nameToValue["scriptCategory"]);

  /// Creates an object that provides localized resource values for the
  /// for the widgets of the material library.
  ///
  /// This method is typically used to create a [LocalizationsDelegate].
  /// The [MaterialApp] does so by default.
  static Future<MaterialLocalizations> load(Locale locale) {
    return new SynchronousFuture<MaterialLocalizations>(new GlobalMaterialLocalizations(locale));
  }

  /// A [LocalizationsDelegate] that uses [GlobalMaterialLocalizations.load]
  /// to create an instance of this class.
  ///
  /// To include the localizations provided by this class in a [MaterialApp],
  /// add [GlobalMaterialLocalizations.delegate] to
  /// [MaterialApp.localizationsDelegates], and specify the locales your
  /// app supports with [MaterialApp.supportedLocales]:
  ///
  /// ```dart
  /// new MaterialApp(
  ///   localizationsDelegates: [
  ///     GlobalMaterialLocalizations.delegate,
  ///   ],
  ///   supportedLocales: [
  ///     const Locale('en', 'US'), // English
  ///     const Locale('he', 'IL'), // Hebrew
  ///   ],
  ///   // ...
  /// )
  /// ```
  static const LocalizationsDelegate<MaterialLocalizations> delegate = const _MaterialLocalizationsDelegate();
}

const Map<String, TimeOfDayFormat> _icuTimeOfDayToEnum = const <String, TimeOfDayFormat>{
  'HH:mm': TimeOfDayFormat.HH_colon_mm,
  'HH.mm': TimeOfDayFormat.HH_dot_mm,
  "HH 'h' mm": TimeOfDayFormat.frenchCanadian,
  'HH:mm น.': TimeOfDayFormat.HH_colon_mm,
  'H:mm': TimeOfDayFormat.H_colon_mm,
  'h:mm a': TimeOfDayFormat.h_colon_mm_space_a,
  'a h:mm': TimeOfDayFormat.a_space_h_colon_mm,
  'ah:mm': TimeOfDayFormat.a_space_h_colon_mm,
};

class _MaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _MaterialLocalizationsDelegate();

  @override
  Future<MaterialLocalizations> load(Locale locale) => GlobalMaterialLocalizations.load(locale);

  @override
  bool shouldReload(_MaterialLocalizationsDelegate old) => false;
}
