// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' show Quad, Vector3, Matrix3;
import 'package:flutter/gestures.dart' show kMinFlingVelocity;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

// A single user event can only represent one of these gestures. The user can't
// do multiple at the same time, which results in more precise transformations.
enum _GestureType {
  translate,
  scale,
  rotate,
}

// TODO(justinmc): Is this necessary?
final GlobalKey _childKey = GlobalKey();

// Returns the closest point to the given point on the given line segment.
@visibleForTesting
Vector3 getNearestPointOnLine(Vector3 point, Vector3 l1, Vector3 l2) {
  final double lengthSquared = math.pow(l2.x - l1.x, 2) + math.pow(l2.y - l1.y, 2);

  // In this case, l1 == l2.
  if (lengthSquared == 0) {
    return l1;
  }

  // Calculate how far down the line segment the closest point is and return
  // the point.
  final Vector3 L1P = point - l1;
  final Vector3 L1L2 = l2 - l1;
  final double fraction = (L1P.dot(L1L2) / lengthSquared).clamp(0.0, 1.0);
  return l1 + L1L2 * fraction;
}

// Given a quad, return its axis aligned bounding box.
@visibleForTesting
Quad getAxisAlignedBoundingBox(Quad quad) {
  final double minX = math.min(
    quad.point0.x,
    math.min(
      quad.point1.x,
      math.min(
        quad.point2.x,
        quad.point3.x,
      ),
    ),
  );
  final double minY = math.min(
    quad.point0.y,
    math.min(
      quad.point1.y,
      math.min(
        quad.point2.y,
        quad.point3.y,
      ),
    ),
  );
  final double maxX = math.max(
    quad.point0.x,
    math.max(
      quad.point1.x,
      math.max(
        quad.point2.x,
        quad.point3.x,
      ),
    ),
  );
  final double maxY = math.max(
    quad.point0.y,
    math.max(
      quad.point1.y,
      math.max(
        quad.point2.y,
        quad.point3.y,
      ),
    ),
  );
  return Quad.points(
    Vector3(minX, minY, 0),
    Vector3(maxX, minY, 0),
    Vector3(maxX, maxY, 0),
    Vector3(minX, maxY, 0),
  );
}

// Returns true iff the point is inside the rectangle given by the Quad,
// inclusively.
// Algorithm from https://math.stackexchange.com/a/190373.
@visibleForTesting
bool pointIsInside(Vector3 point, Quad quad) {
  final Vector3 AM = point - quad.point0;
  final Vector3 AB = quad.point1 - quad.point0;
  final Vector3 AD = quad.point3 - quad.point0;

  final double AMAB = AM.dot(AB);
  final double ABAB = AB.dot(AB);
  final double AMAD = AM.dot(AD);
  final double ADAD = AD.dot(AD);

  return 0 <= AMAB && AMAB <= ABAB && 0 <= AMAD && AMAD <= ADAD;
}

Rect quadToRect(Quad quad) {
  return Rect.fromLTRB(
    math.min(quad.point0.x, math.min(quad.point1.x, math.min(quad.point2.x, quad.point3.x))),
    math.min(quad.point0.y, math.min(quad.point1.y, math.min(quad.point2.y, quad.point3.y))),
    math.max(quad.point0.x, math.max(quad.point1.x, math.max(quad.point2.x, quad.point3.x))),
    math.max(quad.point0.y, math.max(quad.point1.y, math.max(quad.point2.y, quad.point3.y))),
  );
}

// Get the point inside (inclusively) the given Quad that is nearest to the
// given Vector3.
@visibleForTesting
Vector3 getNearestPointInside(Vector3 point, Quad quad) {
  // If the point is inside the axis aligned bounding box, then it's ok where
  // it is.
  if (pointIsInside(point, quad)) {
    return point;
  }

  // Otherwise, return the nearest point on the quad.
  final List<Vector3> closestPoints = <Vector3>[
    getNearestPointOnLine(point, quad.point0, quad.point1),
    getNearestPointOnLine(point, quad.point1, quad.point2),
    getNearestPointOnLine(point, quad.point2, quad.point3),
    getNearestPointOnLine(point, quad.point3, quad.point0),
  ];
  // TODO(justinmc): I confirmed that getNearestPointOnLine is returning the
  // right values in practice.
  double minDistance = double.infinity;
  Vector3 closestOverall;
  // TODO(justinmc): I also confirmed that this closest point finding is right.
  for (Vector3 closePoint in closestPoints) {
    final double distance = math.sqrt(
      math.pow(point.x - closePoint.x, 2) + math.pow(point.y - closePoint.y, 2),
    );
    if (distance < minDistance) {
      minDistance = distance;
      closestOverall = closePoint;
    }
  }
  return closestOverall;
}

/// A widget that enables pan, zoom, and rotate interactions with its child.
///
/// The user can transform the child by dragging to pan or pinching to zoom and
/// rotate.
///
/// All event callbacks for GestureDetector are supported, and the coordinates
/// that are given are untransformed and in relation to the original position of
/// the child.
@immutable
class InteractiveViewer extends StatelessWidget {
  /// Create an InteractiveViewer.
  ///
  /// The [child] parameter must not be null.
  const InteractiveViewer({
    Key key,
    @required this.child,
    this.maxScale = 2.5,
    this.minScale = 0.8,
    // TODO(justinmc): Google Photos and Apple Photos both have some effects
    // when transforming beyond the boundaries that aren't currently possible
    // with InteractiveViewer. There is either a rubber band effect when
    // exceeding the boundaries, or a strong enough gesture causes a navigation
    // change.
    this.boundaryMargin = EdgeInsets.zero,
    this.disableRotation = false,
    this.disableScale = false,
    this.disableTranslation = false,
    this.onTapDown,
    this.onTapUp,
    this.onTap,
    this.onTapCancel,
    this.onDoubleTap,
    this.onLongPress,
    this.onLongPressUp,
    this.onVerticalDragDown,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
    this.onHorizontalDragDown,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
    this.onPanDown,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.transformationController,
  }) : assert(child != null),
       assert(minScale != null),
       assert(minScale > 0),
       assert(disableTranslation != null),
       assert(disableScale != null),
       assert(disableRotation != null),
       super(key: key);

  // TODO(justinmc): Is this the best way to specify boundaries? I wanted to
  // avoid requiring the user to know the size of the child and the constraints.
  /// A margin for the visible boundaries of the child.
  ///
  /// Any transformation that results in the viewport being able to view outside
  /// of the boundaries will be stopped at the boundary. The boundaries do not
  /// rotate with the rest of the scene, so they are always aligned with the
  /// viewport.
  ///
  /// To produce no boundaries at all, pass infinite [EdgeInsets], such as
  /// `EdgeInsets.all(double.infinity)`.
  ///
  /// Defaults to EdgeInsets.zero, which results in boundaries that are the
  /// exact same size and position as the constraints.
  final EdgeInsets boundaryMargin;

  /// The child to perform the transformations on.
  ///
  /// [child] should usually have an intrinsic size. This is used to calculate
  /// the boundary (see [boundaryMargin]).
  ///
  /// Cannot be null.
  final Widget child;

  /// If true, the user will be prevented from translating.
  ///
  /// Defaults to false.
  ///
  /// See also:
  ///   * [disableScale]
  ///   * [disableRotation]
  final bool disableTranslation;

  /// If true, the user will be prevented from scaling.
  ///
  /// Defaults to false.
  ///
  /// See also:
  ///   * [disableTranslation]
  ///   * [disableRotation]
  final bool disableScale;

  /// If true, the user will be prevented from rotating.
  ///
  /// Defaults to false.
  ///
  /// See also:
  ///   * [disableTranslation]
  ///   * [disableScale]
  final bool disableRotation;

  /// The maximum allowed scale.
  ///
  /// The scale will be clamped between this and [minScale].
  ///
  /// A maxScale of null, the default, has no bounds.
  final double maxScale;

  /// The minimum allowed scale.
  ///
  /// The scale will be clamped between this and [maxScale].
  ///
  /// A minScale of null, the default, has no bounds.
  final double minScale;

  /// A pre-transformation proxy for [GestureDetector.onDoubleTap].
  final GestureTapCallback onDoubleTap;

  /// A pre-transformation proxy for [GestureDetector.onHorizontalDragCancel].
  final GestureDragCancelCallback onHorizontalDragCancel;

  /// A pre-transformation proxy for [GestureDetector.onHorizontalDragDown].
  final GestureDragDownCallback onHorizontalDragDown;

  /// A pre-transformation proxy for [GestureDetector.onHorizontalDragEnd].
  final GestureDragEndCallback onHorizontalDragEnd;

  /// A pre-transformation proxy for [GestureDetector.onHorizontalDragStart].
  final GestureDragStartCallback onHorizontalDragStart;

  /// A pre-transformation proxy for [GestureDetector.onHorizontalDragUpdate].
  final GestureDragUpdateCallback onHorizontalDragUpdate;

  /// A pre-transformation proxy for [GestureDetector.onLongPress].
  final GestureLongPressCallback onLongPress;

  /// A pre-transformation proxy for [GestureDetector.onLongPressUp].
  final GestureLongPressUpCallback onLongPressUp;

  /// A pre-transformation proxy for [GestureDetector.onPanCancel].
  final GestureDragCancelCallback onPanCancel;

  /// A pre-transformation proxy for [GestureDetector.onPanDown].
  final GestureDragDownCallback onPanDown;

  /// A pre-transformation proxy for [GestureDetector.onPanEnd].
  final GestureDragEndCallback onPanEnd;

  /// A pre-transformation proxy for [GestureDetector.onPanStart].
  final GestureDragStartCallback onPanStart;

  /// A pre-transformation proxy for [GestureDetector.onPanUpdate].
  final GestureDragUpdateCallback onPanUpdate;

  /// A pre-transformation proxy for [GestureDetector.onScaleEnd].
  final GestureScaleEndCallback onScaleEnd;

  /// A pre-transformation proxy for [GestureDetector.onScaleStart].
  final GestureScaleStartCallback onScaleStart;

  /// A pre-transformation proxy for [GestureDetector.onScaleUpdate].
  final GestureScaleUpdateCallback onScaleUpdate;

  /// A pre-transformation proxy for [GestureDetector.onTap].
  final GestureTapCallback onTap;

  /// A pre-transformation proxy for [GestureDetector.onTapCancel].
  final GestureTapCancelCallback onTapCancel;

  /// A pre-transformation proxy for [GestureDetector.onTapDown].
  final GestureTapDownCallback onTapDown;

  /// A pre-transformation proxy for [GestureDetector.onTapUp].
  final GestureTapUpCallback onTapUp;

  /// A pre-transformation proxy for [GestureDetector.onVerticalDragCancel].
  final GestureDragCancelCallback onVerticalDragCancel;

  /// A pre-transformation proxy for [GestureDetector.onVerticalDragDown].
  final GestureDragDownCallback onVerticalDragDown;

  /// A pre-transformation proxy for [GestureDetector.onVerticalDragEnd].
  final GestureDragEndCallback onVerticalDragEnd;

  /// A pre-transformation proxy for [GestureDetector.onVerticalDragStart].
  final GestureDragStartCallback onVerticalDragStart;

  /// A pre-transformation proxy for [GestureDetector.onVerticalDragStart].
  final GestureDragUpdateCallback onVerticalDragUpdate;

  /// A controller for the transformation performed on the child.
  ///
  /// Whenever the child is transformed, the [Matrix4] value is updated and all
  /// listeners are notified. The value can also be set by the parent.
  ///
  /// {@tool sample}
  /// This example shows how transformationController can be used to animate the
  /// transformation back to its starting position.
  ///
  /// ```dart
  /// final ValueNotifier<Matrix4> _transformationController = ValueNotifier<Matrix4>(null);
  /// Animation<Matrix4> _animationHome;
  /// AnimationController _controllerHome;
  ///
  /// @override
  /// void initState() {
  ///   super.initState();
  ///   _controllerReset = AnimationController(
  ///     vsync: this,
  ///   );
  /// }
  ///
  /// // Calling this will animate the child from whatever transformation it's
  /// // currently in back to its starting position (the identity matrix).
  /// void _animateHome() {
  ///   _controllerHome.reset();
  ///   _animationHome = Matrix4Tween(
  ///     begin: _transformationController.value,
  ///     end: Matrix4.identity(),
  ///   ).animate(_controllerHome);
  ///   _controllerHome.duration = const Duration(milliseconds: 400);
  ///   _animationHome.addListener(_onAnimateHome);
  ///   _controllerHome.forward();
  /// }
  ///
  /// // Every time the animation sends a new value, set it to the controller's
  /// // value.
  /// void _onAnimateHome() {
  ///   setState(() {
  ///     _transformationController.value = _animationHome.value;
  ///   });
  ///   if (!_controllerHome.isAnimating) {
  ///     _animationHome?.removeListener(_onAnimateHome);
  ///     _animationHome = null;
  ///     _controllerHome.reset();
  ///   }
  /// }
  ///
  /// @override
  /// Widget build(BuildContext context) {
  ///   return InteractiveViewer(
  ///     transformationController: _transformationController,
  ///     child: child,
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// See also:
  ///
  ///  * [ValueNotifier].
  ///  * [TextEditingController] for an example of another similar pattern.
  final ValueNotifier<Matrix4> transformationController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return _InteractiveViewerSized(
          child: child,
          maxScale: maxScale,
          minScale: minScale,
          boundaryMargin: boundaryMargin,
          disableTranslation: disableTranslation,
          disableScale: disableScale,
          disableRotation: disableRotation,
          onTapDown: onTapDown,
          onTapUp: onTapUp,
          onTap: onTap,
          onTapCancel: onTapCancel,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
          onLongPressUp: onLongPressUp,
          onVerticalDragDown: onVerticalDragDown,
          onVerticalDragStart: onVerticalDragStart,
          onVerticalDragUpdate: onVerticalDragUpdate,
          onVerticalDragEnd: onVerticalDragEnd,
          onVerticalDragCancel: onVerticalDragCancel,
          onHorizontalDragDown: onHorizontalDragDown,
          onHorizontalDragStart: onHorizontalDragStart,
          onHorizontalDragUpdate: onHorizontalDragUpdate,
          onHorizontalDragEnd: onHorizontalDragEnd,
          onHorizontalDragCancel: onHorizontalDragCancel,
          onPanDown: onPanDown,
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          onPanCancel: onPanCancel,
          onScaleStart: onScaleStart,
          onScaleUpdate: onScaleUpdate,
          onScaleEnd: onScaleEnd,
          size: Size(constraints.maxWidth, constraints.maxHeight),
          transformationController: transformationController ?? ValueNotifier<Matrix4>(Matrix4.identity()),
        );
      },
    );
  }
}

@immutable
class _InteractiveViewerSized extends StatefulWidget {
  const _InteractiveViewerSized({
    this.boundaryMargin,
    @required this.child,
    @required this.disableRotation,
    @required this.disableScale,
    @required this.disableTranslation,
    this.maxScale,
    @required this.minScale,
    this.onTapDown,
    this.onTapUp,
    this.onTap,
    this.onTapCancel,
    this.onDoubleTap,
    this.onLongPress,
    this.onLongPressUp,
    this.onVerticalDragDown,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
    this.onHorizontalDragDown,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
    this.onPanDown,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    @required this.size,
    @required this.transformationController,
  }) : assert(child != null),
       assert(minScale != null),
       assert(minScale > 0),
       assert(disableTranslation != null),
       assert(disableScale != null),
       assert(disableRotation != null),
       assert(transformationController != null);

  final Widget child;
  // The size available to the widget.
  final Size size;
  final GestureTapDownCallback onTapDown;
  final GestureTapUpCallback onTapUp;
  final GestureTapCallback onTap;
  final GestureTapCancelCallback onTapCancel;
  final GestureTapCallback onDoubleTap;
  final GestureLongPressCallback onLongPress;
  final GestureLongPressUpCallback onLongPressUp;
  final GestureDragDownCallback onVerticalDragDown;
  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final GestureDragCancelCallback onVerticalDragCancel;
  final GestureDragDownCallback onHorizontalDragDown;
  final GestureDragStartCallback onHorizontalDragStart;
  final GestureDragUpdateCallback onHorizontalDragUpdate;
  final GestureDragEndCallback onHorizontalDragEnd;
  final GestureDragCancelCallback onHorizontalDragCancel;
  final GestureDragDownCallback onPanDown;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final GestureDragCancelCallback onPanCancel;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;
  final GestureScaleEndCallback onScaleEnd;
  final double maxScale;
  final double minScale;
  final EdgeInsets boundaryMargin;
  final bool disableTranslation;
  final bool disableScale;
  final bool disableRotation;
  final ValueNotifier<Matrix4> transformationController;

  @override _InteractiveViewerState createState() => _InteractiveViewerState();
}

// This is public only for access from a unit test.
class _InteractiveViewerState extends State<_InteractiveViewerSized> with TickerProviderStateMixin {
  Animation<Offset> _animation;
  AnimationController _controller;
  // The translation that will be applied to the scene (not viewport).
  // A positive x offset moves the scene right, viewport left.
  // A positive y offset moves the scene down, viewport up.
  Offset _translateFromScene; // Point where a single translation began.
  double _scaleStart; // Scale value at start of scaling gesture.
  double _rotationStart = 0.0; // Rotation at start of rotation gesture.
  double _currentRotation = 0.0;
  _GestureType gestureType;

  // This value was eyeballed as something that feels right for a photo viewer.
  static const double _kDrag = 0.0000135;

  // Given a velocity and drag, calculate the time at which motion will come to
  // a stop, within the margin of effectivelyMotionless.
  static double _getFinalTime(double velocity, double drag) {
    const double effectivelyMotionless = 10.0;
    return math.log(effectivelyMotionless / velocity) / math.log(drag / 100);
  }

  // Decide which type of gesture this is by comparing the amount of scale
  // and rotation in the gesture, if any. Scale starts at 1 and rotation
  // starts at 0. Translate will have 0 scale and 0 rotation because it uses
  // only one finger.
  static _GestureType _getGestureType(double scale, double rotation) {
    if ((scale - 1).abs() > rotation.abs()) {
      return _GestureType.scale;
    } else if (rotation != 0) {
      return _GestureType.rotate;
    } else {
      return _GestureType.translate;
    }
  }

  // Return the translation from the Matrix4 as an Offset.
  static Offset _getMatrixTranslation(Matrix4 matrix) {
    final Vector3 nextTranslation = matrix.getTranslation();
    return Offset(nextTranslation.x, nextTranslation.y);
  }

  // Return the scene point at the given viewport point.
  static Offset fromViewport(Offset viewportPoint, Matrix4 transform) {
    // On viewportPoint, perform the inverse transformation of the scene to get
    // where the point would be in the scene before the transformation.
    final Matrix4 inverseMatrix = Matrix4.inverted(transform);
    final Vector3 untransformed = inverseMatrix.transform3(Vector3(
      viewportPoint.dx,
      viewportPoint.dy,
      0,
    ));
    return Offset(untransformed.x, untransformed.y);
  }

  // Get the offset of the current widget from the global screen coordinates.
  static Offset getOffset(BuildContext context) {
    final RenderBox renderObject = context.findRenderObject() as RenderBox;
    return renderObject.localToGlobal(Offset.zero);
  }

  // Get the size of the child given its RenderBox and the viewport's Size.
  //
  // In some cases (i.e. a Table that's wider and/or taller than the viewport),
  // renderBox.size will give the size of the viewport, even though the child is
  // drawn beyond the viewport. The intrinsic size can then be used to set the
  // boundary to the full size of the child.
  //
  // In other cases (i.e. an Image whose original size is larger than the
  // viewport but is being fit to the viewport), renderBox.size will also give
  // the size of the viewport, and the boundary should remain at the viewport.
  // The intrinsic size is not used.
  Size _getChildSize(RenderBox renderBox, Size viewportSize) {
    double width = renderBox.size.width;
    double height = renderBox.size.height;
    final double minIntrinsicWidth = renderBox.getMinIntrinsicWidth(viewportSize.height);
    final double maxIntrinsicWidth = renderBox.getMaxIntrinsicWidth(viewportSize.height);
    final double minIntrinsicHeight = renderBox.getMinIntrinsicHeight(viewportSize.width);
    final double maxIntrinsicHeight = renderBox.getMaxIntrinsicHeight(viewportSize.width);

    if (minIntrinsicWidth == maxIntrinsicWidth) {
      width = minIntrinsicWidth;
    }
    if (minIntrinsicHeight == maxIntrinsicHeight) {
      height = minIntrinsicHeight;
    }

    return Size(width, height);
  }

  Rect _boundaryRectCached;
  Rect get _boundaryRect {
    if (_boundaryRectCached != null) {
      return _boundaryRectCached;
    }
    assert(_childKey.currentContext != null);

    
    final Size childSize = _getChildSize(
      _childKey.currentContext.findRenderObject(),
      widget.size,
    );
    _boundaryRectCached = Rect.fromLTRB(
      -widget.boundaryMargin.left,
      -widget.boundaryMargin.top,
      childSize.width + widget.boundaryMargin.right,
      childSize.height + widget.boundaryMargin.bottom,
    );
    return _boundaryRectCached;
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(_InteractiveViewerSized oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != oldWidget.child
      || widget.boundaryMargin != oldWidget.boundaryMargin) {
      _boundaryRectCached = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // A GestureDetector allows the detection of panning and zooming gestures on
    // the child.
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // Necessary when translating off screen
      onTapDown: widget.onTapDown == null ? null : (TapDownDetails details) {
        widget.onTapDown(TapDownDetails(
          globalPosition: fromViewport(
            details.globalPosition - getOffset(context),
            widget.transformationController.value,
          ),
        ));
      },
      onTapUp: widget.onTapUp == null ? null : (TapUpDetails details) {
        widget.onTapUp(TapUpDetails(
          globalPosition: fromViewport(
            details.globalPosition - getOffset(context),
            widget.transformationController.value,
          ),
        ));
      },
      onTap: widget.onTap,
      onTapCancel: widget.onTapCancel,
      onDoubleTap: widget.onDoubleTap,
      onLongPress: widget.onLongPress,
      onLongPressUp: widget.onLongPressUp,
      onVerticalDragDown: widget.onVerticalDragDown == null ? null : (DragDownDetails details) {
        widget.onVerticalDragDown(DragDownDetails(
          globalPosition: fromViewport(
            details.globalPosition - getOffset(context),
            widget.transformationController.value,
          ),
        ));
      },
      onVerticalDragStart: widget.onVerticalDragStart == null ? null : (DragStartDetails details) {
        widget.onVerticalDragStart(DragStartDetails(
          globalPosition: fromViewport(
            details.globalPosition - getOffset(context),
            widget.transformationController.value,
          ),
        ));
      },
      onVerticalDragUpdate: widget.onVerticalDragUpdate == null ? null : (DragUpdateDetails details) {
        widget.onVerticalDragUpdate(DragUpdateDetails(
          globalPosition: fromViewport(
            details.globalPosition - getOffset(context),
            widget.transformationController.value,
          ),
        ));
      },
      onVerticalDragEnd: widget.onVerticalDragEnd,
      onVerticalDragCancel: widget.onVerticalDragCancel,
      onHorizontalDragDown: widget.onHorizontalDragDown == null ? null : (DragDownDetails details) {
        widget.onHorizontalDragDown(DragDownDetails(
          globalPosition: fromViewport(
            details.globalPosition - getOffset(context),
            widget.transformationController.value,
          ),
        ));
      },
      onHorizontalDragStart: widget.onHorizontalDragStart == null ? null : (DragStartDetails details) {
        widget.onHorizontalDragStart(DragStartDetails(
          globalPosition: fromViewport(
            details.globalPosition - getOffset(context),
            widget.transformationController.value,
          ),
        ));
      },
      onHorizontalDragUpdate: widget.onHorizontalDragUpdate == null ? null : (DragUpdateDetails details) {
        widget.onHorizontalDragUpdate(DragUpdateDetails(
          globalPosition: fromViewport(
            details.globalPosition - getOffset(context),
            widget.transformationController.value,
          ),
        ));
      },
      onHorizontalDragEnd: widget.onHorizontalDragEnd,
      onHorizontalDragCancel: widget.onHorizontalDragCancel,
      onPanDown: widget.onPanDown == null ? null : (DragDownDetails details) {
        widget.onPanDown(DragDownDetails(
          globalPosition: fromViewport(
            details.globalPosition - getOffset(context),
            widget.transformationController.value,
          ),
        ));
      },
      onPanStart: widget.onPanStart == null ? null : (DragStartDetails details) {
        widget.onPanStart(DragStartDetails(
          globalPosition: fromViewport(
            details.globalPosition - getOffset(context),
            widget.transformationController.value,
          ),
        ));
      },
      onPanUpdate: widget.onPanUpdate == null ? null : (DragUpdateDetails details) {
        widget.onPanUpdate(DragUpdateDetails(
          globalPosition: fromViewport(
            details.globalPosition - getOffset(context),
            widget.transformationController.value,
          ),
        ));
      },
      onPanEnd: widget.onPanEnd,
      onPanCancel: widget.onPanCancel,
      onScaleEnd: _onScaleEnd,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,

      // Wrapping a Widget in an InteractiveViewer does not change how the
      // widget is initially rendered. It should look identical whether or not
      // the InteractiveViewer is there, until the transformation is changed.
      child: Transform(
        transform: widget.transformationController.value,
        child: KeyedSubtree(
          key: _childKey,
          child: widget.child,
        ),
      ),
    );
  }

  // Given the viewport boundaries, return a Quad representing the boundaries
  // for translation values.
  static Quad _getTranslationBoundaries(Rect viewportBoundaries, double scale, Matrix3 rotation) {
    // Translation is reversed (a positive translation moves the scene to the
    // right, viewport to the left).
    final Rect rect = Rect.fromLTRB(
      -viewportBoundaries.right,
      -viewportBoundaries.bottom,
      -viewportBoundaries.left,
      -viewportBoundaries.top,
    );
    return Quad.points(
      rotation.transform(Vector3(rect.topLeft.dx, rect.topLeft.dy, 0)),
      rotation.transform(Vector3(rect.topRight.dx, rect.topRight.dy, 0)),
      rotation.transform(Vector3(rect.bottomRight.dx, rect.bottomRight.dy, 0)),
      rotation.transform(Vector3(rect.bottomLeft.dx, rect.bottomLeft.dy, 0)),
    );
  }

  // Return a new matrix representing the given matrix after applying the given
  // translation.
  // TODO(justinmc): This widget needs to update itself if the screen
  // orientation/size changes. Currently, if you rotate the screen, the boundary
  // may be off.
  Matrix4 matrixTranslate(Matrix4 matrix, Offset translation) {
    if (widget.disableTranslation || translation == Offset.zero) {
      return matrix;
    }

    // Clamp translation so the viewport remains inside _boundaryRect.
    final double scale = widget.transformationController.value.getMaxScaleOnAxis();
    final Size scaledSize = widget.size / scale;
    // Add 1 pixel because Rect.contains excludes its bottom and right edges.
    final Rect viewportBoundaries = Rect.fromLTRB(
      _boundaryRect.left,
      _boundaryRect.top,
      _boundaryRect.right - scaledSize.width,
      _boundaryRect.bottom - scaledSize.height,
    );

    final Quad translationBoundaries = _getTranslationBoundaries(
      viewportBoundaries,
      scale,
      matrix.getRotation(),
    );
    // TODO(justinmc): Can I simplify the aabb calculation like quadToRect?
    final Quad translationBoundariesAabb = getAxisAlignedBoundingBox(translationBoundaries);

    // If the translation fits within the boundaries then it's valid.
    final Matrix4 nextMatrix = matrix.clone()..translate(
      translation.dx,
      translation.dy,
    );
    final Offset nextTotalTranslation = _getMatrixTranslation(nextMatrix);
    if (quadToRect(translationBoundaries).contains(nextTotalTranslation)) {
      return nextMatrix;
    }

    // Desired translation goes out of bounds, so translate to the nearest
    // in-bounds point instead.
    final Vector3 validTotalTranslation = getNearestPointInside(
      Vector3(nextTotalTranslation.dx, nextTotalTranslation.dy, 0),
      translationBoundariesAabb,
    );

    return matrix.clone()..setTranslation(validTotalTranslation);
  }

  // Return a new matrix representing the given matrix after applying the given
  // scale transform.
  Matrix4 matrixScale(Matrix4 matrix, double scale) {
    if (widget.disableScale || scale == 1) {
      return matrix;
    }
    assert(scale != 0);

    // Don't allow a scale that results in an overall scale beyond min/max
    // scale.
    final double currentScale = widget.transformationController.value.getMaxScaleOnAxis();
    final double totalScale = currentScale * scale;
    final double clampedTotalScale = totalScale.clamp(
      widget.minScale,
      widget.maxScale,
    ) as double;
    final double clampedScale = clampedTotalScale / currentScale;
    final Matrix4 nextMatrix = matrix.clone()..scale(clampedScale);

    // Ensure that the scale cannot make the child so big that it can't fit
    // inside the boundaries (in either direction).
    final Size currentViewportSize = widget.size / currentScale;
    final double minScale = math.max(
      widget.size.width / _boundaryRect.width,
      widget.size.height / _boundaryRect.height,
    );
    if (clampedTotalScale < minScale) {
      final double minCurrentScale = minScale / currentScale;
      return matrix.clone()..scale(minCurrentScale);
    }

    return nextMatrix;
  }

  // Return a new matrix representing the given matrix after applying the given
  // rotation transform.
  // Rotating the scene cannot cause the viewport to view beyond _boundaryRect.
  Matrix4 matrixRotate(Matrix4 matrix, double rotation, Offset focalPoint) {
    if (widget.disableRotation || rotation == 0) {
      return matrix;
    }
    final Offset focalPointScene = fromViewport(focalPoint, matrix);
    return matrix
      ..translate(focalPointScene.dx, focalPointScene.dy)
      ..rotateZ(-rotation)
      ..translate(-focalPointScene.dx, -focalPointScene.dy);
  }

  // Handle the start of a gesture of _GestureType.
  void _onScaleStart(ScaleStartDetails details) {
    if (widget.onScaleStart != null) {
      widget.onScaleStart(details);
    }

    if (_controller.isAnimating) {
      _controller.stop();
      _controller.reset();
      _animation?.removeListener(_onAnimate);
      _animation = null;
    }

    gestureType = null;
    setState(() {
      _scaleStart = widget.transformationController.value.getMaxScaleOnAxis();
      _translateFromScene = fromViewport(
        details.focalPoint,
        widget.transformationController.value,
      );
      _rotationStart = _currentRotation;
    });
  }

  // Handle an update to an ongoing gesture of _GestureType.
  void _onScaleUpdate(ScaleUpdateDetails details) {
    double scale = widget.transformationController.value.getMaxScaleOnAxis();
    if (widget.onScaleUpdate != null) {
      widget.onScaleUpdate(ScaleUpdateDetails(
        focalPoint: fromViewport(
          details.focalPoint,
          widget.transformationController.value,
        ),
        scale: details.scale,
        rotation: details.rotation,
      ));
    }
    final Offset focalPointScene = fromViewport(
      details.focalPoint,
      widget.transformationController.value,
    );
    gestureType ??= _getGestureType(
      widget.disableScale ? 1.0 : details.scale,
      widget.disableRotation ? 0.0 : details.rotation,
    );
    setState(() {
      if (gestureType == _GestureType.scale && _scaleStart != null) {
        // details.scale gives us the amount to change the scale as of the
        // start of this gesture, so calculate the amount to scale as of the
        // previous call to _onScaleUpdate.
        final double desiredScale = _scaleStart * details.scale;
        final double scaleChange = desiredScale / scale;
        widget.transformationController.value = matrixScale(
          widget.transformationController.value,
          scaleChange,
        );
        scale = widget.transformationController.value.getMaxScaleOnAxis();

        // While scaling, translate such that the user's two fingers stay on the
        // same places in the scene. That means that the focal point of the
        // scale should be on the same place in the scene before and after the
        // scale.
        final Offset focalPointSceneNext = fromViewport(
          details.focalPoint,
          widget.transformationController.value,
        );
        widget.transformationController.value = matrixTranslate(
          widget.transformationController.value,
          focalPointSceneNext - focalPointScene,
        );
      } else if (gestureType == _GestureType.rotate && details.rotation != 0.0) {
        final double desiredRotation = _rotationStart + details.rotation;
        widget.transformationController.value = matrixRotate(
          widget.transformationController.value,
          _currentRotation - desiredRotation,
          details.focalPoint,
        );
        _currentRotation = desiredRotation;
      } else if (_translateFromScene != null && details.scale == 1.0) {
        // Translate so that the same point in the scene is underneath the
        // focal point before and after the movement.
        final Offset translationChange = focalPointScene - _translateFromScene;
        widget.transformationController.value = matrixTranslate(
          widget.transformationController.value,
          translationChange,
        );
        _translateFromScene = fromViewport(
          details.focalPoint,
          widget.transformationController.value,
        );
      }
    });
  }

  // Handle the end of a gesture of _GestureType.
  void _onScaleEnd(ScaleEndDetails details) {
    if (widget.onScaleEnd != null) {
      widget.onScaleEnd(details);
    }
    setState(() {
      _scaleStart = null;
      _rotationStart = null;
      _translateFromScene = null;
    });

    _animation?.removeListener(_onAnimate);
    _controller.reset();

    // If the scale ended with enough velocity, animate inertial movement.
    if (details.velocity.pixelsPerSecond.distance < kMinFlingVelocity) {
      return;
    }

    final Vector3 translationVector = widget.transformationController.value.getTranslation();
    final Offset translation = Offset(translationVector.x, translationVector.y);
    final FrictionSimulation frictionSimulationX = FrictionSimulation(
      _kDrag,
      translation.dx,
      details.velocity.pixelsPerSecond.dx,
    );
    final FrictionSimulation frictionSimulationY = FrictionSimulation(
      _kDrag,
      translation.dy,
      details.velocity.pixelsPerSecond.dy,
    );
    final double tFinal = _getFinalTime(
      details.velocity.pixelsPerSecond.distance,
      _kDrag,
    );
    _animation = Tween<Offset>(
      begin: translation,
      end: Offset(frictionSimulationX.finalX, frictionSimulationY.finalX),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.decelerate,
    ));
    _controller.duration = Duration(milliseconds: (tFinal * 1000).round());
    _animation.addListener(_onAnimate);
    _controller.forward();
  }

  // Handle inertia drag animation.
  void _onAnimate() {
    if (!_controller.isAnimating) {
      _animation?.removeListener(_onAnimate);
      _animation = null;
      _controller.reset();
      return;
    }
    setState(() {
      // Translate such that the resulting translation is _animation.value.
      final Vector3 translationVector = widget.transformationController.value.getTranslation();
      final Offset translation = Offset(translationVector.x, translationVector.y);
      final Offset translationScene = fromViewport(
        translation,
        widget.transformationController.value,
      );
      final Offset animationScene = fromViewport(
        _animation.value,
        widget.transformationController.value,
      );
      final Offset translationChangeScene = animationScene - translationScene;
      widget.transformationController.value = matrixTranslate(
        widget.transformationController.value,
        translationChangeScene,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
