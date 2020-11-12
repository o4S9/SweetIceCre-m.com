// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'material_state.dart';
import 'theme.dart';
import 'theme_data.dart';

/// Defines default property values for descendant [Radio] widgets.
///
/// Descendant widgets obtain the current [RadioThemeData] object using
/// `RadioTheme.of(context)`. Instances of [RadioThemeData] can be customized
/// with [RadioThemeData.copyWith].
///
/// Typically a [RadioThemeData] is specified as part of the overall [Theme]
/// with [ThemeData.radioTheme].
///
/// All [RadioThemeData] properties are `null` by default. When null, the
/// [Radio] will use the values from [ThemeData] if they exist, otherwise it
/// will provide its own defaults based on the overall [Theme]'s colorScheme.
/// See the individual [Radio] properties for details.
///
/// See also:
///
///  * [ThemeData], which describes the overall theme information for the
///    application.
@immutable
class RadioThemeData with Diagnosticable {
  /// Creates a theme that can be used for [ThemeData.radioTheme].
  const RadioThemeData({
    this.mouseCursor,
    this.fillColor,
    this.focusColor,
    this.hoverColor,
    this.splashRadius,
    this.materialTapTargetSize,
    this.visualDensity,
  });

  /// {@macro flutter.material.radio.mouseCursor}
  ///
  /// If specified, overrides the default value of [Radio.mouseCursor].
  final MouseCursor? mouseCursor;

  /// {@macro flutter.material.radio.fillColor}
  ///
  /// If specified, overrides the default value of [Radio.fillColor].
  final MaterialStateProperty<Color?>? fillColor;

  /// {@macro flutter.material.radio.focusColor}
  ///
  /// If specified, overrides the default value of [Radio.focusColor].
  final Color? focusColor;

  /// {@macro flutter.material.radio.hoverColor}
  ///
  /// If specified, overrides the default value of [Radio.hoverColor].
  final Color? hoverColor;

  /// {@macro flutter.material.radio.splashRadius}
  ///
  /// If specified, overrides the default value of [Radio.splashRadius].
  final double? splashRadius;

  /// {@macro flutter.material.radio.materialTapTargetSize}
  ///
  /// If specified, overrides the default value of
  /// [Radio.materialTapTargetSize].
  final MaterialTapTargetSize? materialTapTargetSize;

  /// {@macro flutter.material.radio.visualDensity}
  ///
  /// If specified, overrides the default value of [Radio.visualDensity].
  final VisualDensity? visualDensity;

  /// Creates a copy of this object but with the given fields replaced with the
  /// new values.
  RadioThemeData copyWith({
    MouseCursor? mouseCursor,
    MaterialStateProperty<Color?>? fillColor,
    Color? focusColor,
    Color? hoverColor,
    double? splashRadius,
    MaterialTapTargetSize? materialTapTargetSize,
    VisualDensity? visualDensity,
  }) {
    return RadioThemeData(
      mouseCursor: mouseCursor ?? this.mouseCursor,
      fillColor: fillColor ?? this.fillColor,
      focusColor: focusColor ?? this.focusColor,
      hoverColor: hoverColor ?? this.hoverColor,
      splashRadius: splashRadius ?? this.splashRadius,
      materialTapTargetSize: materialTapTargetSize ?? this.materialTapTargetSize,
      visualDensity: visualDensity ?? this.visualDensity,
    );
  }

  /// Linearly interpolate between two [RadioThemeData]s.
  ///
  /// {@macro dart.ui.shadow.lerp}
  static RadioThemeData lerp(RadioThemeData? a, RadioThemeData? b, double t) {
    return RadioThemeData(
      mouseCursor: t < 0.5 ? a?.mouseCursor : b?.mouseCursor,
      fillColor: _lerpProperties<Color?>(a?.fillColor, b?.fillColor, t, Color.lerp),
      materialTapTargetSize: t < 0.5 ? a?.materialTapTargetSize : b?.materialTapTargetSize,
      focusColor: Color.lerp(a?.focusColor, b?.focusColor, t),
      hoverColor: Color.lerp(a?.hoverColor, b?.hoverColor, t),
      splashRadius: lerpDouble(a?.splashRadius, b?.splashRadius, t),
      visualDensity: t < 0.5 ? a?.visualDensity : b?.visualDensity,
    );
  }

  @override
  int get hashCode {
    return hashValues(
      mouseCursor,
      fillColor,
      focusColor,
      hoverColor,
      splashRadius,
      materialTapTargetSize,
      visualDensity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other))
      return true;
    if (other.runtimeType != runtimeType)
      return false;
    return other is RadioThemeData
      && other.mouseCursor == mouseCursor
      && other.fillColor == fillColor
      && other.focusColor == focusColor
      && other.hoverColor == hoverColor
      && other.splashRadius == splashRadius
      && other.materialTapTargetSize == materialTapTargetSize
      && other.visualDensity == visualDensity;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MouseCursor>('mouseCursor', mouseCursor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('fillColor', fillColor, defaultValue: null));
    properties.add(DiagnosticsProperty<Color>('focusColor', focusColor, defaultValue: null));
    properties.add(DiagnosticsProperty<Color>('hoverColor', hoverColor, defaultValue: null));
    properties.add(DoubleProperty('splashRadius', splashRadius, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialTapTargetSize>('materialTapTargetSize', materialTapTargetSize, defaultValue: null));
    properties.add(DiagnosticsProperty<VisualDensity>('visualDensity', visualDensity, defaultValue: null));
  }

  static MaterialStateProperty<T>? _lerpProperties<T>(
    MaterialStateProperty<T>? a,
    MaterialStateProperty<T>? b,
    double t,
    T Function(T?, T?, double) lerpFunction,
  ) {
    // Avoid creating a _LerpProperties object for a common case.
    if (a == null && b == null)
      return null;
    return _LerpProperties<T>(a, b, t, lerpFunction);
  }
}

class _LerpProperties<T> implements MaterialStateProperty<T> {
  const _LerpProperties(this.a, this.b, this.t, this.lerpFunction);

  final MaterialStateProperty<T>? a;
  final MaterialStateProperty<T>? b;
  final double t;
  final T Function(T?, T?, double) lerpFunction;

  @override
  T resolve(Set<MaterialState> states) {
    final T? resolvedA = a?.resolve(states);
    final T? resolvedB = b?.resolve(states);
    return lerpFunction(resolvedA, resolvedB, t);
  }
}

/// Applies a radio theme to descendant [Radio] widgets.
///
/// Descendant widgets obtain the current theme's [RadioTheme] object using
/// [RadioTheme.of]. When a widget uses [RadioTheme.of], it is automatically
/// rebuilt if the theme later changes.
///
/// A radio theme can be specified as part of the overall Material theme using
/// [ThemeData.radioTheme].
///
/// See also:
///
///  * [RadioThemeData], which describes the actual configuration of a radio
///    theme.
class RadioTheme extends InheritedWidget {
  /// Constructs a radio theme that configures all descendant [Radio] widgets.
  const RadioTheme({
    Key? key,
    required this.data,
    required Widget child,
  }) : super(key: key, child: child);

  /// The properties used for all descendant [Radio] widgets.
  final RadioThemeData data;

  /// Returns the configuration [data] from the closest [RadioTheme] ancestor.
  /// If there is no ancestor, it returns [ThemeData.radioTheme].
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// RadioThemeData theme = RadioTheme.of(context);
  /// ```
  static RadioThemeData of(BuildContext context) {
    final RadioTheme? radioTheme = context.dependOnInheritedWidgetOfExactType<RadioTheme>();
    return radioTheme?.data ?? Theme.of(context).radioTheme;
  }

  @override
  bool updateShouldNotify(RadioTheme oldWidget) => data != oldWidget.data;
}
