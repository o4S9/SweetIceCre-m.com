// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'scroll_metrics.dart';

const double _kMinThumbExtent = 18.0;

/// A [CustomPainter] for painting scrollbars.
///
/// Unlike [CustomPainter]s that subclasses [CustomPainter] and only repaint
/// when [shouldRepaint] returns true (which requires this [CustomPainter] to
/// be rebuilt), this painter has the added optimization of repainting and not
/// rebuilding when:
///
///  * the scroll position changes; and
///  * when the scrollbar fades away.
///
/// Calling [update] with the new [ScrollMetrics] will repaint the new scrollbar
/// position.
///
/// Updating the value on the provided [fadeoutOpacityAnimation] will repaint
/// with the new opacity.
///
/// You must call [dispose] on this [ScrollbarPainter] when it's no longer used.
///
/// See also:
///
///  * [Scrollbar] for a widget showing a scrollbar around a [Scrollable] in the
///    Material Design style.
///  * [CupertinoScrollbar] for a widget showing a scrollbar around a
///    [Scrollable] in the iOS style.
class ScrollbarPainter extends ChangeNotifier implements CustomPainter {
  /// Creates a scrollbar with customizations given by construction arguments.
  ScrollbarPainter({
    @required this.color,
    @required this.textDirection,
    @required this.thickness,
    @required this.fadeoutOpacityAnimation,
    this.padding = EdgeInsets.zero,
    this.mainAxisMargin = 0.0,
    this.crossAxisMargin = 0.0,
    this.radius,
    this.minLength = _kMinThumbExtent,
    this.minOverscrollLength = _kMinThumbExtent,
  }) : assert(color != null),
       assert(textDirection != null),
       assert(thickness != null),
       assert(fadeoutOpacityAnimation != null),
       assert(mainAxisMargin != null),
       assert(crossAxisMargin != null),
       assert(minLength != null),
       assert(padding != null),
       assert(padding.top >= 0),
       assert(padding.right >= 0),
       assert(padding.bottom >= 0),
       assert(padding.left >= 0) {
    fadeoutOpacityAnimation.addListener(notifyListeners);
  }

  /// [Color] of the thumb. Mustn't be null.
  final Color color;

  /// [TextDirection] of the [BuildContext] which dictates the side of the
  /// screen the scrollbar appears in (the trailing side). Mustn't be null.
  final TextDirection textDirection;

  /// Thickness of the scrollbar in its cross-axis in pixels. Mustn't be null.
  final double thickness;

  /// An opacity [Animation] that dictates the opacity of the thumb.
  /// Changes in value of this [Listenable] will automatically trigger repaints.
  /// Mustn't be null.
  final Animation<double> fadeoutOpacityAnimation;

  /// Distance from the scrollbar's start and end to the edge of the viewport in
  /// pixels. Mustn't be null.
  final double mainAxisMargin;

  /// Distance from the scrollbar's side to the nearest edge in pixels. Must not
  /// be null.
  final double crossAxisMargin;

  /// [Radius] of corners if the scrollbar should have rounded corners.
  ///
  /// Scrollbar will be rectangular if [radius] is null.
  final Radius radius;

  /// The amount of space by which to inset the scrollbar's start and end, as
  /// well as its side to the nearest edge, in pixels.
  ///
  /// This is typically set to the current [MediaQueryData.padding] to avoid
  /// partial obstructions such as display notches. If you want additonal
  /// margins around the scrollbar, see [mainAxisMargin] or [crossAxisMargin].
  ///
  /// Defaults to [EdgeInsets.zero]. Must not be null and offsets from all four
  /// directions must be greater than or equal to zero.
  final EdgeInsets padding;

  /// The smallest size the scrollbar can shrink to when the total scrollable
  /// extent is large and the current visible viewport is small, and the
  /// viewport is not overscrolled. Mustn't be null.
  final double minLength;

  /// The smallest size the scrollbar can shrink to when viewport is
  /// overscrolled. Mustn't be null and the value is typically less than
  /// or equal to [minLength].
  final double minOverscrollLength;

  ScrollMetrics _lastMetrics;
  AxisDirection _lastAxisDirection;

  /// Update with new [ScrollMetrics]. The scrollbar will show and redraw itself
  /// based on these new metrics.
  ///
  /// The scrollbar will remain on screen.
  void update(
    ScrollMetrics metrics,
    AxisDirection axisDirection,
  ) {
    _lastMetrics = metrics;
    _lastAxisDirection = axisDirection;
    notifyListeners();
  }

  Paint get _paint {
    return Paint()..color =
        color.withOpacity(color.opacity * fadeoutOpacityAnimation.value);
  }

  double _getThumbX(Size size) {
    assert(textDirection != null);
    switch (textDirection) {
      case TextDirection.rtl:
        return crossAxisMargin + padding.left;
      case TextDirection.ltr:
        return size.width - thickness - crossAxisMargin - padding.right;
    }
    return null;
  }

  void _paintVerticalThumb(Canvas canvas, Size size, double thumbOffset, double thumbExtent) {
    final Offset thumbOrigin = Offset(_getThumbX(size), thumbOffset);
    final Size thumbSize = Size(thickness, thumbExtent);
    final Rect thumbRect = thumbOrigin & thumbSize;
    if (radius == null)
      canvas.drawRect(thumbRect, _paint);
    else
      canvas.drawRRect(RRect.fromRectAndRadius(thumbRect, radius), _paint);
  }

  void _paintHorizontalThumb(Canvas canvas, Size size, double thumbOffset, double thumbExtent) {
    final Offset thumbOrigin = Offset(thumbOffset, size.height - thickness);
    final Size thumbSize = Size(thumbExtent, thickness);
    final Rect thumbRect = thumbOrigin & thumbSize;
    if (radius == null)
      canvas.drawRect(thumbRect, _paint);
    else
      canvas.drawRRect(RRect.fromRectAndRadius(thumbRect, radius), _paint);
  }

  void _paintThumb(
    double beforeInset,
    double before,
    double inside,
    double afterInset,
    double after,
    double viewport,
    Canvas canvas,
    Size size,
    void painter(Canvas canvas, Size size, double thumbOffset, double thumbExtent),
  ) {
    final double totalInset = beforeInset + afterInset;

    // Skip painting if there's not enough space.
    if (viewport <= totalInset || viewport <= totalInset + 2 * mainAxisMargin) {
      return;
    }

    final double effectiveInside = inside - totalInset;
    // Because viewport <= inside this is guaranteed to be greater than or equal to 0.
    final double effectiveViewport = viewport - totalInset;

    // Establish the minimum size possible.
    double thumbExtent = math.min(effectiveViewport, minOverscrollLength);

    // Thumb extent reflects fraction of content visible, as long as this
    // isn't less than the absolute minimum size.
    final double fractionVisible = effectiveInside / (before + inside + after);
    thumbExtent = math.max(
      thumbExtent,
      effectiveViewport * fractionVisible - 2 * mainAxisMargin,
    );
    // Thumb extent is no smaller than minLength if scrolling normally.
    if (before > 0 && after > 0) {
      thumbExtent = math.max(
        minLength,
        thumbExtent,
      );
    }
    // User is overscrolling. Thumb extent can be less than minLength
    // but no smaller than minOverscrollLength. We can't use the
    // fractionVisible to produce intermediate values between minLength and
    // minOverscrollLength when the user is transitioning from regular
    // scrolling to overscrolling, so we instead use the percentage of the
    // content that is still in the viewport to determine the size of the
    // thumb. iOS behavior appears to have the thumb reach its minimum size
    // with ~20% of overscroll. We map the percentage of minLength from
    // [0.8, 1.0] to [0.0, 1.0], so 0% to 20% of overscroll will produce
    // values for the thumb that range between minLength and the smallest
    // possible value, minOverscrollLength.
    else {
      thumbExtent = math.max(
        thumbExtent,
        minLength * (((effectiveInside / effectiveViewport) - 0.8) / 0.2),
      );
    }

    // Prevent the scrollbar from scrolling towards the wrong direction when
    // `mainAxisMargin` gets too large.
    thumbExtent = math.min(thumbExtent, effectiveViewport - 2 * mainAxisMargin);

    final double fractionPast = (before + after > 0.0) ? before / (before + after) : 0;
    final double thumbOffset = fractionPast * (effectiveViewport - thumbExtent - 2 * mainAxisMargin) + mainAxisMargin + beforeInset;

    painter(canvas, size, thumbOffset, thumbExtent);
  }

  @override
  void dispose() {
    fadeoutOpacityAnimation.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_lastAxisDirection == null
        || _lastMetrics == null
        || fadeoutOpacityAnimation.value == 0.0)
      return;

    switch (_lastAxisDirection) {
      case AxisDirection.down:
        _paintThumb(
          padding.top,
          _lastMetrics.extentBefore,
          _lastMetrics.extentInside,
          padding.bottom,
          _lastMetrics.extentAfter,
          size.height,
          canvas,
          size,
          _paintVerticalThumb
        );
        break;
      case AxisDirection.up:
        _paintThumb(
          padding.bottom,
          _lastMetrics.extentAfter,
          _lastMetrics.extentInside,
          padding.top,
          _lastMetrics.extentBefore,
          size.height,
          canvas,
          size,
          _paintVerticalThumb
        );
        break;
      case AxisDirection.right:
        _paintThumb(
          padding.left,
          _lastMetrics.extentBefore,
          _lastMetrics.extentInside,
          padding.right,
          _lastMetrics.extentAfter,
          size.width,
          canvas,
          size,
          _paintHorizontalThumb
        );
        break;
      case AxisDirection.left:
        _paintThumb(
          padding.right,
          _lastMetrics.extentAfter,
          _lastMetrics.extentInside,
          padding.left,
          _lastMetrics.extentBefore,
          size.width,
          canvas,
          size,
          _paintHorizontalThumb
        );
        break;
    }
  }

  // Scrollbars are (currently) not interactive.
  @override
  bool hitTest(Offset position) => null;

  @override
  bool shouldRepaint(ScrollbarPainter old) {
    // Should repaint if any properties changed.
    return color != old.color
        || textDirection != old.textDirection
        || thickness != old.thickness
        || fadeoutOpacityAnimation != old.fadeoutOpacityAnimation
        || mainAxisMargin != old.mainAxisMargin
        || crossAxisMargin != old.crossAxisMargin
        || radius != old.radius
        || minLength != old.minLength
        || padding != old.padding;
  }

  @override
  bool shouldRebuildSemantics(CustomPainter oldDelegate) => false;

  @override
  SemanticsBuilderCallback get semanticsBuilder => null;
}
