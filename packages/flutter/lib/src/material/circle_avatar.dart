// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'constants.dart';
import 'theme.dart';
import 'theme_data.dart';

// Examples can assume:
// String userAvatarUrl;

/// A circle that represents a user.
///
/// Typically used with a user's profile image, or, in the absence of
/// such an image, the user's initials. A given user's initials should
/// always be paired with the same background color, for consistency.
///
/// ## Sample code
///
/// If the avatar is to have an image, the image should be specified in the
/// [backgroundImage] property:
///
/// ```dart
/// new CircleAvatar(
///   backgroundImage: new NetworkImage(userAvatarUrl),
/// )
/// ```
///
/// The image will be cropped to have a circle shape.
///
/// If the avatar is to just have the user's initials, they are typically
/// provided using a [Text] widget as the [child] and a [backgroundColor]:
///
/// ```dart
/// new CircleAvatar(
///   backgroundColor: Colors.brown.shade800,
///   child: new Text('AH'),
/// )
/// ```
///
/// See also:
///
///  * [Chip], for representing users or concepts in long form.
///  * [ListTile], which can combine an icon (such as a [CircleAvatar]) with
///    some text for a fixed height list entry.
///  * <https://material.google.com/components/chips.html#chips-contact-chips>
class CircleAvatar extends StatelessWidget {
  /// Creates a circle that represents a user.
  const CircleAvatar({
    Key key,
    this.child,
    this.backgroundColor,
    this.backgroundImage,
    this.foregroundColor,
    this.radius,
    this.minRadius,
    this.maxRadius,
  })  : assert(radius == null || (minRadius == null && maxRadius == null)),
        super(key: key);

  /// The widget below this widget in the tree.
  ///
  /// Typically a [Text] widget. If the [CircleAvatar] is to have an image, use
  /// [backgroundImage] instead.
  final Widget child;

  /// The color with which to fill the circle. Changing the background
  /// color will cause the avatar to animate to the new color.
  ///
  /// If a background color is not specified, the theme's light primary color
  /// is used with dark foreground colors, and the dark primary color with light
  /// foreground colors.
  final Color backgroundColor;

  /// The default text color for text in the circle.
  ///
  /// Defaults to the primary text theme color if no [backgroundColor] is
  /// specified.
  ///
  /// If a [backgroundColor] is specified, this falls back to the light primary
  /// color for dark background colors or the dark primary color for light
  /// background colors.
  final Color foregroundColor;

  /// The background image of the circle. Changing the background
  /// image will cause the avatar to animate to the new image.
  ///
  /// If the [CircleAvatar] is to have the user's initials, use [child] instead.
  final ImageProvider backgroundImage;

  /// The size of the avatar. Changing the radius will cause the
  /// avatar to animate to the new size.
  ///
  /// If radius is specified, then [minRadius] and [maxRadius] may not be
  /// specified. Specifying radius is equivalent to specifying a [minRadius] and
  /// [maxRadius], both with the value of radius.
  ///
  /// Defaults to 20 logical pixels.
  final double radius;

  /// The minimum size of the avatar.
  ///
  /// Changing the minRadius may cause the avatar to animate to the new size, if
  /// constraints allow.
  ///
  /// If minRadius is specified, then [radius] may not also be specified.
  ///
  /// Defaults to zero.
  final double minRadius;

  /// The maximum size of the avatar.
  ///
  /// Changing the maxRadius will cause the avatar to animate to the new size,
  /// if constraints allow.
  ///
  /// If maxRadius is specified, then [radius] may not also be specified.
  ///
  /// Defaults to [double.infinity].
  final double maxRadius;

  static const double _defaultRadius = 20.0;
  static const double _defaultMinRadius = 0.0;
  static const double _defaultMaxRadius = double.infinity;

  double get _minDiameter {
    double minDiameter = _defaultRadius * 2.0;
    if (radius != null) {
      minDiameter = radius * 2.0;
    } else if (minRadius != null || maxRadius != null) {
      minDiameter = 2.0 * (minRadius ?? _defaultMinRadius);
    }
    return minDiameter;
  }

  double get _maxDiameter {
    double maxDiameter = _defaultRadius * 2.0;
    if (radius != null) {
      maxDiameter = radius * 2.0;
    } else if (minRadius != null || maxRadius != null) {
      maxDiameter = 2.0 * (maxRadius ?? _defaultMaxRadius);
    }
    return maxDiameter;
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    final ThemeData theme = Theme.of(context);
    TextStyle textStyle = theme.primaryTextTheme.title.copyWith(color: foregroundColor);
    Color effectiveBackgroundColor = backgroundColor;
    if (effectiveBackgroundColor != null) {
      switch (ThemeData.estimateBrightnessForColor(backgroundColor)) {
        case Brightness.dark:
          textStyle = textStyle.copyWith(color: theme.primaryColorLight);
          break;
        case Brightness.light:
          textStyle = textStyle.copyWith(color: theme.primaryColorDark);
          break;
      }
    } else {
      switch (ThemeData.estimateBrightnessForColor(textStyle.color)) {
        case Brightness.dark:
          effectiveBackgroundColor = theme.primaryColorLight;
          break;
        case Brightness.light:
          effectiveBackgroundColor = theme.primaryColorDark;
          break;
      }
    }
    final double minDiameter = _minDiameter;
    final double maxDiameter = _maxDiameter;
    return new AnimatedContainer(
      constraints: new BoxConstraints(
        minHeight: minDiameter,
        minWidth: minDiameter,
        maxWidth: maxDiameter,
        maxHeight: maxDiameter,
      ),
      duration: kThemeChangeDuration,
      decoration: new BoxDecoration(
        color: effectiveBackgroundColor,
        image: backgroundImage != null ? new DecorationImage(image: backgroundImage) : null,
        shape: BoxShape.circle,
      ),
      child: child != null
          ? new Center(
              child: new MediaQuery(
                // Need to ignore the ambient textScaleFactor here so that the
                // text doesn't escape the avatar when the textScaleFactor is large.
                data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
                child: new IconTheme(
                  data: theme.iconTheme.copyWith(color: textStyle.color),
                  child: new DefaultTextStyle(
                    style: textStyle,
                    child: child,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
