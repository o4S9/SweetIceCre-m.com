// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'colors.dart';
import 'theme.dart';

// Slides the page upwards and fades it in, starting from 1/4 screen
// below the top. The transition is intended to match the default for
// Android O.
class _FadeUpwardsPageTransition extends StatelessWidget {
  _FadeUpwardsPageTransition({
    required Animation<double> routeAnimation, // The route's linear 0.0 - 1.0 animation.
    required this.child,
  }) : _positionAnimation = routeAnimation.drive(_bottomUpTween.chain(_fastOutSlowInTween)),
       _opacityAnimation = routeAnimation.drive(_easeInTween);

  // Fractional offset from 1/4 screen below the top to fully on screen.
  static final Tween<Offset> _bottomUpTween = Tween<Offset>(
    begin: const Offset(0.0, 0.25),
    end: Offset.zero,
  );
  static final Animatable<double> _fastOutSlowInTween = CurveTween(curve: Curves.fastOutSlowIn);
  static final Animatable<double> _easeInTween = CurveTween(curve: Curves.easeIn);

  final Animation<Offset> _positionAnimation;
  final Animation<double> _opacityAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _positionAnimation,
      // TODO(ianh): tell the transform to be un-transformed for hit testing
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: child,
      ),
    );
  }
}

// This transition is intended to match the default for Android P.
class _OpenUpwardsPageTransition extends StatelessWidget {
  const _OpenUpwardsPageTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  // The new page slides upwards just a little as its clip
  // rectangle exposes the page from bottom to top.
  static final Tween<Offset> _primaryTranslationTween = Tween<Offset>(
    begin: const Offset(0.0, 0.05),
    end: Offset.zero,
  );

  // The old page slides upwards a little as the new page appears.
  static final Tween<Offset> _secondaryTranslationTween = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(0.0, -0.025),
  );

  // The scrim obscures the old page by becoming increasingly opaque.
  static final Tween<double> _scrimOpacityTween = Tween<double>(
    begin: 0.0,
    end: 0.25,
  );

  // Used by all of the transition animations.
  static const Curve _transitionCurve = Cubic(0.20, 0.00, 0.00, 1.00);

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;

        final CurvedAnimation primaryAnimation = CurvedAnimation(
          parent: animation,
          curve: _transitionCurve,
          reverseCurve: _transitionCurve.flipped,
        );

        // Gradually expose the new page from bottom to top.
        final Animation<double> clipAnimation = Tween<double>(
          begin: 0.0,
          end: size.height,
        ).animate(primaryAnimation);

        final Animation<double> opacityAnimation = _scrimOpacityTween.animate(primaryAnimation);
        final Animation<Offset> primaryTranslationAnimation = _primaryTranslationTween.animate(primaryAnimation);

        final Animation<Offset> secondaryTranslationAnimation = _secondaryTranslationTween.animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: _transitionCurve,
            reverseCurve: _transitionCurve.flipped,
          ),
        );

        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? child) {
            return Container(
              color: Colors.black.withOpacity(opacityAnimation.value),
              alignment: Alignment.bottomLeft,
              child: ClipRect(
                child: SizedBox(
                  height: clipAnimation.value,
                  child: OverflowBox(
                    alignment: Alignment.bottomLeft,
                    maxHeight: size.height,
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: AnimatedBuilder(
            animation: secondaryAnimation,
            child: FractionalTranslation(
              translation: primaryTranslationAnimation.value,
              child: child,
            ),
            builder: (BuildContext context, Widget? child) {
              return FractionalTranslation(
                translation: secondaryTranslationAnimation.value,
                child: child,
              );
            },
          ),
        );
      },
    );
  }
}

// Zooms and fades a new page in, zooming out the previous page. This transition
// is designed to match the Android Q activity transition.
class _ZoomPageTransition extends StatelessWidget {
  /// Creates a [_ZoomPageTransition].
  ///
  /// The [animation] and [secondaryAnimation] argument are required and must
  /// not be null.
  const _ZoomPageTransition({
    required this.animation,
    required this.secondaryAnimation,
    this.child,
  }) : assert(animation != null),
       assert(secondaryAnimation != null);

  // A curve sequence that is similar to the 'fastOutExtraSlowIn' curve used in
  // the native transition.
  static final List<TweenSequenceItem<double>> fastOutExtraSlowInTweenSequenceItems = <TweenSequenceItem<double>>[
    TweenSequenceItem<double>(
      tween: Tween<double>(begin: 0.0, end: 0.4)
        .chain(CurveTween(curve: const Cubic(0.05, 0.0, 0.133333, 0.06))),
      weight: 0.166666,
    ),
    TweenSequenceItem<double>(
      tween: Tween<double>(begin: 0.4, end: 1.0)
        .chain(CurveTween(curve: const Cubic(0.208333, 0.82, 0.25, 1.0))),
      weight: 1.0 - 0.166666,
    ),
  ];
  static final TweenSequence<double> _scaleCurveSequence = TweenSequence<double>(fastOutExtraSlowInTweenSequenceItems);

  /// The animation that drives the [child]'s entrance and exit.
  ///
  /// See also:
  ///
  ///  * [TransitionRoute.animation], which is the value given to this property
  ///    when the [_ZoomPageTransition] is used as a page transition.
  final Animation<double> animation;

  /// The animation that transitions [child] when new content is pushed on top
  /// of it.
  ///
  /// See also:
  ///
  ///  * [TransitionRoute.secondaryAnimation], which is the value given to this
  ///    property when the [_ZoomPageTransition] is used as a page transition.
  final Animation<double> secondaryAnimation;

  /// The widget below this widget in the tree.
  ///
  /// This widget will transition in and out as driven by [animation] and
  /// [secondaryAnimation].
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder: (
        BuildContext context,
        Animation<double> animation,
        Widget? child,
      ) {
        return _ZoomEnterTransition(
          animation: animation,
          child: child,
        );
      },
      reverseBuilder: (
        BuildContext context,
        Animation<double> animation,
        Widget? child,
      ) {
        return _ZoomExitTransition(
          animation: animation,
          reverse: true,
          child: child,
        );
      },
      child: DualTransitionBuilder(
        animation: ReverseAnimation(secondaryAnimation),
        forwardBuilder: (
          BuildContext context,
          Animation<double> animation,
          Widget? child,
        ) {
          return _ZoomEnterTransition(
            animation: animation,
            reverse: true,
            child: child,
          );
        },
        reverseBuilder: (
          BuildContext context,
          Animation<double> animation,
          Widget? child,
        ) {
          return _ZoomExitTransition(
            animation: animation,
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}

abstract class _RadicallyAwesomeRenderObject extends RenderProxyBox {
  _RadicallyAwesomeRenderObject(Animation<double> animation, bool reverse)
    : _animation = animation, _reverse = reverse {
    animation.addListener(markNeedsPaint);
    animation.addStatusListener(_updateStatus);
    _updateStatus(animation.status);
  }

  void paintImage(PaintingContext context, ui.Image image, Rect area, Animation<double> animation);

  AnimationStatus _status = AnimationStatus.completed;

  void _updateStatus(AnimationStatus newStatus, [bool painting = false]) {
    if (newStatus == _status) {
      return;
    }
    childImage?.dispose();
    childImage = null;
    _status = newStatus;
    assert(_status == animation.status);
    if (!painting) {
      markNeedsPaint();
    }
  }

  Animation<double> get animation => _animation;
  Animation<double> _animation;
  set animation(Animation<double> value) {
    if (value == animation) {
      return;
    }
    animation.removeListener(markNeedsPaint);
    animation.removeStatusListener(_updateStatus);
    _animation = value;
    animation.addStatusListener(_updateStatus);
    animation.addListener(markNeedsPaint);
    _updateStatus(animation.status);
    markNeedsPaint();
  }

  bool get reverse => _reverse;
  bool _reverse;
  set reverse(bool value) {
    if (value == reverse) {
      return;
    }
    _reverse = value;
    markNeedsPaint();
  }

  @override
  void dispose() {
    animation.removeListener(markNeedsPaint);
    animation.removeStatusListener(_updateStatus);
    super.dispose();
  }

  @override
  void attach(covariant PipelineOwner owner) {
    animation.addListener(markNeedsPaint);
    animation.addStatusListener(_updateStatus);
    _updateStatus(animation.status);
    super.attach(owner);
  }

  @override
  void detach() {
    animation.removeListener(markNeedsPaint);
    animation.removeStatusListener(_updateStatus);
    super.detach();
  }

  @override
  bool get isRepaintBoundary => child != null;

  ui.Image? childImage;

  void _paintChildIntoLayer(Offset offset) {
    final PaintingContext context = PaintingContext(layer!, offset & size);
    super.paint(context, Offset.zero);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _updateStatus(animation.status, true);
    switch (_status) {
      case AnimationStatus.dismissed:
      case AnimationStatus.completed:
        super.paint(context, offset);
        return;
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        break;
    }

    if (childImage == null) {
      _paintChildIntoLayer(offset);
      childImage = (layer! as OffsetLayer).toGpuImage(offset & size);
    }

    paintImage(context, childImage!, offset & size, animation);
  }
}

class _ZoomEnterTransition extends SingleChildRenderObjectWidget {
  const _ZoomEnterTransition({
    required this.animation,
    this.reverse = false,
    super.child,
  }) : assert(animation != null),
       assert(reverse != null);

  final Animation<double> animation;
  final bool reverse;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderZoomEnterTransition(animation, reverse);
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderZoomEnterTransition renderObject) {
    renderObject
      ..animation = animation
      ..reverse = reverse;
  }
}

class _RenderZoomEnterTransition extends _RadicallyAwesomeRenderObject {
  _RenderZoomEnterTransition(super.animation, super.reverse);

  static final Animatable<double> _fadeInTransition = Tween<double>(
    begin: 0.0,
    end: 1.00,
  ).chain(CurveTween(curve: const Interval(0.125, 0.250)));

  static final Animatable<double> _scaleDownTransition = Tween<double>(
    begin: 1.10,
    end: 1.00,
  ).chain(_ZoomPageTransition._scaleCurveSequence);

  static final Animatable<double> _scaleUpTransition = Tween<double>(
    begin: 0.85,
    end: 1.00,
  ).chain(_ZoomPageTransition._scaleCurveSequence);

  static final Animatable<double?> _scrimOpacityTween = Tween<double?>(
    begin: 0.0,
    end: 0.60,
  ).chain(CurveTween(curve: const Interval(0.2075, 0.4175)));

  @override
  void paintImage(PaintingContext context, ui.Image image, Rect area, Animation<double> animation) {
    final double fade = reverse
      ? 1.0
      : _fadeInTransition.evaluate(animation);
    final double scale = (reverse
      ? _scaleDownTransition
      : _scaleUpTransition
    ).evaluate(animation);

    double opacity = 0;
    // The transition's scrim opacity only increases on the forward transition.
    // In the reverse transition, the opacity should always be 0.0.
    //
    // Therefore, we need to only apply the scrim opacity animation when
    // the transition is running forwards.
    //
    // The reason that we check that the animation's status is not `completed`
    // instead of checking that it is `forward` is that this allows
    // the interrupted reversal of the forward transition to smoothly fade
    // the scrim away. This prevents a disjointed removal of the scrim.
    if (!reverse && animation.status != AnimationStatus.completed) {
      opacity = _scrimOpacityTween.evaluate(animation)!;
    }

    context.canvas.drawRect(area, Paint()..color = Colors.black.withOpacity(opacity));
    final Rect src = area;
    final double newWidth = src.width * scale;
    final double newHeight = src.height * scale;
    final double leftOffset = (src.width - newWidth) / 2;
    final double topOffset = (src.height - newHeight) / 2;
    final Rect dst = Rect.fromLTWH(src.left + leftOffset, src.top + topOffset,newWidth, newHeight);
    context.canvas.drawImageRect(childImage!, src, dst, Paint()..color = const Color(0xFF000000).withOpacity(fade));
  }
}

class _ZoomExitTransition extends SingleChildRenderObjectWidget {
  const _ZoomExitTransition({
    required this.animation,
    this.reverse = false,
    super.child,
  }) : assert(animation != null),
       assert(reverse != null);

  final Animation<double> animation;
  final bool reverse;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderZoomExitTransition(animation, reverse);
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderZoomExitTransition renderObject) {
    renderObject
      ..animation = animation
      ..reverse = reverse;
  }
}

class _RenderZoomExitTransition extends _RadicallyAwesomeRenderObject {
  _RenderZoomExitTransition(super.animation, super.reverse);

  static final Animatable<double> _fadeOutTransition = Tween<double>(
    begin: 1.0,
    end: 0.0,
  ).chain(CurveTween(curve: const Interval(0.0825, 0.2075)));

  static final Animatable<double> _scaleUpTransition = Tween<double>(
    begin: 1.00,
    end: 1.05,
  ).chain(_ZoomPageTransition._scaleCurveSequence);

  static final Animatable<double> _scaleDownTransition = Tween<double>(
    begin: 1.00,
    end: 0.90,
  ).chain(_ZoomPageTransition._scaleCurveSequence);

  @override
  void paintImage(PaintingContext context, ui.Image image, Rect rect, Animation<double> animation) {
    final double fade = reverse
      ? _fadeOutTransition.evaluate(animation)
      : 1.0;
    final double scale = (reverse
      ? _scaleDownTransition
      : _scaleUpTransition
    ).evaluate(animation);

    final Rect src = rect;
    final double newWidth = src.width * scale;
    final double newHeight = src.height * scale;
    final double leftOffset = (src.width - newWidth) / 2;
    final double topOffset = (src.height - newHeight) / 2;
    final Rect dst = Rect.fromLTWH(src.left + leftOffset, src.top + topOffset,newWidth, newHeight);
    context.canvas.drawImageRect(childImage!, src, dst, Paint()..color = const Color(0xFF000000).withOpacity(fade));
  }
}

/// Used by [PageTransitionsTheme] to define a [MaterialPageRoute] page
/// transition animation.
///
/// Apps can configure the map of builders for [ThemeData.pageTransitionsTheme]
/// to customize the default [MaterialPageRoute] page transition animation
/// for different platforms.
///
/// See also:
///
///  * [FadeUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android O.
///  * [OpenUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android P.
///  * [ZoomPageTransitionsBuilder], which defines the default page transition
///    that's similar to the one provided in Android Q.
///  * [CupertinoPageTransitionsBuilder], which defines a horizontal page
///    transition that matches native iOS page transitions.
abstract class PageTransitionsBuilder {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const PageTransitionsBuilder();

  /// Wraps the child with one or more transition widgets which define how [route]
  /// arrives on and leaves the screen.
  ///
  /// The [MaterialPageRoute.buildTransitions] method looks up the
  /// current [PageTransitionsTheme] with `Theme.of(context).pageTransitionsTheme`
  /// and delegates to this method with a [PageTransitionsBuilder] based
  /// on the theme's [ThemeData.platform].
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  );
}

/// Used by [PageTransitionsTheme] to define a vertically fading
/// [MaterialPageRoute] page transition animation that looks like
/// the default page transition used on Android O.
///
/// The animation fades the new page in while translating it upwards,
/// starting from about 25% below the top of the screen.
///
/// See also:
///
///  * [OpenUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android P.
///  * [ZoomPageTransitionsBuilder], which defines the default page transition
///    that's similar to the one provided in Android Q.
///  * [CupertinoPageTransitionsBuilder], which defines a horizontal page
///    transition that matches native iOS page transitions.
class FadeUpwardsPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Constructs a page transition animation that slides the page up.
  const FadeUpwardsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double>? secondaryAnimation,
    Widget child,
  ) {
    return _FadeUpwardsPageTransition(routeAnimation: animation, child: child);
  }
}

/// Used by [PageTransitionsTheme] to define a vertical [MaterialPageRoute] page
/// transition animation that looks like the default page transition
/// used on Android P.
///
/// See also:
///
///  * [FadeUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android O.
///  * [ZoomPageTransitionsBuilder], which defines the default page transition
///    that's similar to the one provided in Android Q.
///  * [CupertinoPageTransitionsBuilder], which defines a horizontal page
///    transition that matches native iOS page transitions.
class OpenUpwardsPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Constructs a page transition animation that matches the transition used on
  /// Android P.
  const OpenUpwardsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _OpenUpwardsPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// Used by [PageTransitionsTheme] to define a zooming [MaterialPageRoute] page
/// transition animation that looks like the default page transition used on
/// Android Q.
///
/// See also:
///
///  * [FadeUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android O.
///  * [OpenUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android P.
///  * [CupertinoPageTransitionsBuilder], which defines a horizontal page
///    transition that matches native iOS page transitions.
class ZoomPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Constructs a page transition animation that matches the transition used on
  /// Android Q.
  const ZoomPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget? child,
  ) {
    return _ZoomPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// Used by [PageTransitionsTheme] to define a horizontal [MaterialPageRoute]
/// page transition animation that matches native iOS page transitions.
///
/// See also:
///
///  * [FadeUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android O.
///  * [OpenUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android P.
///  * [ZoomPageTransitionsBuilder], which defines the default page transition
///    that's similar to the one provided in Android Q.
class CupertinoPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Constructs a page transition animation that matches the iOS transition.
  const CupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return CupertinoRouteTransitionMixin.buildPageTransitions<T>(route, context, animation, secondaryAnimation, child);
  }
}

/// Defines the page transition animations used by [MaterialPageRoute]
/// for different [TargetPlatform]s.
///
/// The [MaterialPageRoute.buildTransitions] method looks up the
/// current [PageTransitionsTheme] with `Theme.of(context).pageTransitionsTheme`
/// and delegates to [buildTransitions].
///
/// If a builder with a matching platform is not found, then the
/// [FadeUpwardsPageTransitionsBuilder] is used.
///
/// See also:
///
///  * [ThemeData.pageTransitionsTheme], which defines the default page
///    transitions for the overall theme.
///  * [FadeUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android O.
///  * [OpenUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android P.
///  * [ZoomPageTransitionsBuilder], which defines the default page transition
///    that's similar to the one provided by Android Q.
///  * [CupertinoPageTransitionsBuilder], which defines a horizontal page
///    transition that matches native iOS page transitions.
@immutable
class PageTransitionsTheme with Diagnosticable {
  /// Constructs an object that selects a transition based on the platform.
  ///
  /// By default the list of builders is: [ZoomPageTransitionsBuilder]
  /// for [TargetPlatform.android], and [CupertinoPageTransitionsBuilder] for
  /// [TargetPlatform.iOS] and [TargetPlatform.macOS].
  const PageTransitionsTheme({ Map<TargetPlatform, PageTransitionsBuilder> builders = _defaultBuilders }) : _builders = builders;

  static const Map<TargetPlatform, PageTransitionsBuilder> _defaultBuilders = <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: ZoomPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
  };

  /// The [PageTransitionsBuilder]s supported by this theme.
  Map<TargetPlatform, PageTransitionsBuilder> get builders => _builders;
  final Map<TargetPlatform, PageTransitionsBuilder> _builders;

  /// Delegates to the builder for the current [ThemeData.platform]
  /// or [ZoomPageTransitionsBuilder].
  ///
  /// [MaterialPageRoute.buildTransitions] delegates to this method.
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    TargetPlatform platform = Theme.of(context).platform;

    if (CupertinoRouteTransitionMixin.isPopGestureInProgress(route)) {
      platform = TargetPlatform.iOS;
    }

    final PageTransitionsBuilder matchingBuilder =
      builders[platform] ?? const ZoomPageTransitionsBuilder();
    return matchingBuilder.buildTransitions<T>(route, context, animation, secondaryAnimation, child);
  }

  // Just used to the builders Map to a list with one PageTransitionsBuilder per platform
  // for the operator == overload.
  List<PageTransitionsBuilder?> _all(Map<TargetPlatform, PageTransitionsBuilder> builders) {
    return TargetPlatform.values.map((TargetPlatform platform) => builders[platform]).toList();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    if (other is PageTransitionsTheme && identical(builders, other.builders)) {
      return true;
    }
    return other is PageTransitionsTheme
        && listEquals<PageTransitionsBuilder?>(_all(other.builders), _all(builders));
  }

  @override
  int get hashCode => Object.hashAll(_all(builders));

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<Map<TargetPlatform, PageTransitionsBuilder>>(
        'builders',
        builders,
        defaultValue: PageTransitionsTheme._defaultBuilders,
      ),
    );
  }
}
