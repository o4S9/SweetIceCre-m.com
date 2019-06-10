// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show hashValues;

import 'package:flutter/foundation.dart';

/// A description of an icon fulfilled by a font glyph.
///
/// See [Icons] for a number of predefined icons available for material
/// design applications.
@immutable
class IconData {
  /// Creates icon data.
  ///
  /// Rarely used directly. Instead, consider using one of the predefined icons
  /// like the [Icons] collection.
  ///
  /// The [fontPackage] argument must be non-null when using a font family that
  /// is included in a package. This is used when selecting the font.
  const IconData(
    this.codePoint, {
    this.fontFamily,
    this.fontPackage,
    this.matchTextDirection = false,
  });

  /// The Unicode code point at which this icon is stored in the icon font.
  final int codePoint;

  /// The font family from which the glyph for the [codePoint] will be selected.
  final String fontFamily;

  /// The name of the package from which the font family is included.
  ///
  /// The name is used by the [Icon] widget when configuring the [TextStyle] so
  /// that the given [fontFamily] is obtained from the appropriate asset.
  ///
  /// See also:
  ///
  ///  * [TextStyle], which describes how to use fonts from other packages.
  final String fontPackage;

  /// Whether this icon should be automatically mirrored in right-to-left
  /// environments.
  ///
  /// The [Icon] widget respects this value by mirroring the icon when the
  /// [Directionality] is [TextDirection.rtl].
  final bool matchTextDirection;

  @override
  bool operator ==(dynamic other) {
    if (runtimeType != other.runtimeType)
      return false;
    final IconData typedOther = other;
    return codePoint == typedOther.codePoint
        && fontFamily == typedOther.fontFamily
        && fontPackage == typedOther.fontPackage
        && matchTextDirection == typedOther.matchTextDirection;
  }

  @override
  int get hashCode => hashValues(codePoint, fontFamily, fontPackage, matchTextDirection);

  @override
  String toString() => 'IconData(U+${codePoint.toRadixString(16).toUpperCase().padLeft(5, '0')})';
}

/// [DiagnosticsProperty] that has an [IconData] as value.
class IconDataDiagnosticsProperty extends DiagnosticsProperty<IconData> {
  /// Create a diagnostics property for strings.
  ///
  /// The [showName], [style], and [level] arguments must not be null.
  IconDataDiagnosticsProperty(
    String name,
    IconData value, {
      String description,
      String ifNull,
      bool showName = true,
      Object defaultValue = kNoDefaultValue,
      String tooltip,
      DiagnosticsTreeStyle style = DiagnosticsTreeStyle.singleLine,
      DiagnosticLevel level = DiagnosticLevel.info,
  }) : assert(showName != null),
       assert(style != null),
       assert(level != null),
       super(name, value,
         description: description,
         defaultValue: defaultValue,
         tooltip: tooltip,
         showName: showName,
         ifNull: ifNull,
         style: style,
         level: level,
       );

  @override
  Map<String, Object> toJsonMap(DiagnosticsSerialisationDelegate delegate) {
    final Map<String, Object> json = super.toJsonMap(delegate);
    if (value != null) {
      json['valueProperties'] = <String, Object>{
        'codePoint': value.codePoint,
      };
    }
    return json;
  }
}
