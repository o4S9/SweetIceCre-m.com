// Copyright 2020 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Defines default property values for descendant [NavigationRail]
/// widgets.
///
/// Descendant widgets obtain the current [NavigationRailThemeData] object
/// using `Theme.of(context).navigationRailTheme`. Instances of
/// [NavigationRailThemeData] can be customized with
/// [NavigationRailThemeData.copyWith].
///
/// Typically a [NavigationRailThemeData] is specified as part of the
/// overall [Theme] with [ThemeData.navigationRailTheme].
///
/// All [NavigationRailThemeData] properties are `null` by default.
/// When null, the [NavigationRail] will use the values from [ThemeData]
/// if they exist, otherwise it will provide its own defaults.
///
/// See also:
///
///  * [ThemeData], which describes the overall theme information for the
///    application.
class NavigationRailThemeData extends Diagnosticable {
  /// Creates a theme that can be used for [ThemeData.navigationRailTheme].
  const NavigationRailThemeData({
    this.backgroundColor,
    this.elevation,
    this.unselectedLabelTextStyle,
    this.selectedLabelTextStyle,
    this.unselectedIconTheme,
    this.selectedIconTheme,
    this.groupAlignment,
    this.labelType,
  });

  /// Color to be used for the unselected, enabled [NavigationRail]'s
  /// background.
  final Color backgroundColor;

  /// The z-coordinate to be used for the unselected, enabled
  /// [NavigationRail]'s elevation foreground.
  final double elevation;

  /// The style on which to base the destination label, when the destination
  /// is not selected.
  final TextStyle unselectedLabelTextStyle;

  /// The style on which to base the destination label, when the destination
  /// is selected.
  final TextStyle selectedLabelTextStyle;

  /// The theme on which to base the destination icon, when the destination
  /// is not selected.
  final IconThemeData unselectedIconTheme;

  /// The theme on which to base the destination icon, when the destination
  /// is selected.
  final IconThemeData selectedIconTheme;

  /// The alignment for the [NavigationRailDestination]s as they are positioned
  /// within the [NavigationRail].
  final NavigationRailGroupAlignment groupAlignment;

  /// The type that defines the layout and behavior of the labels in the
  /// [NavigationRail].
  final NavigationRailLabelType labelType;

  /// Creates a copy of this object with the given fields replaced with the
  /// new values.
  NavigationRailThemeData copyWith({
    Color backgroundColor,
    double elevation,
    TextStyle unselectedLabelTextStyle,
    TextStyle selectedLabelTextStyle,
    IconThemeData unselectedIconTheme,
    IconThemeData selectedIconTheme,
    NavigationRailGroupAlignment groupAlignment,
    NavigationRailLabelType labelType,
  }) {
    return NavigationRailThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      elevation: elevation ?? this.elevation,
      unselectedLabelTextStyle: unselectedLabelTextStyle ?? this.unselectedLabelTextStyle,
      selectedLabelTextStyle: selectedLabelTextStyle ?? this.selectedLabelTextStyle,
      unselectedIconTheme: unselectedIconTheme ?? this.unselectedIconTheme,
      selectedIconTheme: selectedIconTheme ?? this.selectedIconTheme,
      groupAlignment: groupAlignment ?? this.groupAlignment,
      labelType: labelType ?? this.labelType,
    );
  }

  /// Linearly interpolate between two navigation rail themes.
  ///
  /// If both arguments are null then null is returned.
  ///
  /// {@macro dart.ui.shadow.lerp}
  static NavigationRailThemeData lerp(NavigationRailThemeData a, NavigationRailThemeData b, double t) {
    assert(t != null);
    if (a == null && b == null)
      return null;
    return NavigationRailThemeData(
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      unselectedLabelTextStyle: TextStyle.lerp(a?.unselectedLabelTextStyle, b?.unselectedLabelTextStyle, t),
      selectedLabelTextStyle: TextStyle.lerp(a?.selectedLabelTextStyle, b?.selectedLabelTextStyle, t),
      unselectedIconTheme: IconThemeData.lerp(a?.unselectedIconTheme, b?.unselectedIconTheme, t),
      selectedIconTheme: IconThemeData.lerp(a?.selectedIconTheme, b?.selectedIconTheme, t),
      groupAlignment:  t < 0.5 ? a.groupAlignment : b.groupAlignment,
      labelType:  t < 0.5 ? a.labelType : b.labelType,
    );
  }

  @override
  int get hashCode {
    return hashValues(
      backgroundColor,
      elevation,
      unselectedLabelTextStyle,
      selectedLabelTextStyle,
      unselectedIconTheme,
      selectedIconTheme,
      groupAlignment,
      labelType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other))
      return true;
    if (other.runtimeType != runtimeType)
      return false;
    return other is NavigationRailThemeData
        && other.backgroundColor == backgroundColor
        && other.elevation == elevation
        && other.unselectedLabelTextStyle == unselectedLabelTextStyle
        && other.selectedLabelTextStyle == selectedLabelTextStyle
        && other.unselectedIconTheme == unselectedIconTheme
        && other.selectedIconTheme == selectedIconTheme
        && other.groupAlignment == groupAlignment
        && other.labelType == labelType;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    const NavigationRailThemeData defaultData = NavigationRailThemeData();

    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: defaultData.backgroundColor));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: defaultData.elevation));
    properties.add(DiagnosticsProperty<TextStyle>('unselectedLabelTextStyle', unselectedLabelTextStyle, defaultValue: defaultData.unselectedLabelTextStyle));
    properties.add(DiagnosticsProperty<TextStyle>('selectedLabelTextStyle', selectedLabelTextStyle, defaultValue: defaultData.selectedLabelTextStyle));
    properties.add(DiagnosticsProperty<IconThemeData>('unselectedIconTheme', unselectedIconTheme, defaultValue: defaultData.unselectedIconTheme));
    properties.add(DiagnosticsProperty<IconThemeData>('selectedIconTheme', selectedIconTheme, defaultValue: defaultData.selectedIconTheme));
    properties.add(DiagnosticsProperty<NavigationRailGroupAlignment>('groupAlignment', groupAlignment, defaultValue: defaultData.groupAlignment));
    properties.add(DiagnosticsProperty<NavigationRailLabelType>('labelType', labelType, defaultValue: defaultData.labelType));
  }
}
