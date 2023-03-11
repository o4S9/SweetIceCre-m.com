// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';

import 'page_transitions_theme.dart';
import 'theme.dart';

/// A modal route that replaces the entire screen with a platform-adaptive
/// transition.
///
/// {@macro flutter.material.materialRouteTransitionMixin}
///
/// By default, when a modal route is replaced by another, the previous route
/// remains in memory. To free all the resources when this is not necessary, set
/// [maintainState] to false.
///
/// The `fullscreenDialog` property specifies whether the incoming route is a
/// fullscreen modal dialog. On iOS, those routes animate from the bottom to the
/// top rather than horizontally.
///
/// The type `T` specifies the return type of the route which can be supplied as
/// the route is popped from the stack via [Navigator.pop] by providing the
/// optional `result` argument.
///
/// See also:
///
///  * [MaterialRouteTransitionMixin], which provides the material transition
///    for this route.
///  * [MaterialPage], which is a [Page] of this class.
class MaterialPageRoute<T> extends PageRoute<T> with MaterialRouteTransitionMixin<T> {
  /// Construct a MaterialPageRoute whose contents are defined by [builder].
  ///
  /// The values of [builder], [maintainState], and [PageRoute.fullscreenDialog]
  /// must not be null.
  MaterialPageRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
    super.fullscreenDialog,
    super.allowSnapshotting = true,
  }) {
    assert(opaque);
  }

  /// Builds the primary contents of the route.
  final WidgetBuilder builder;

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  final bool maintainState;

  @override
  String get debugLabel => '${super.debugLabel}(${settings.name})';
}


/// A mixin that provides platform-adaptive transitions for a [PageRoute].
///
/// {@template flutter.material.materialRouteTransitionMixin}
/// For Android, the entrance transition for the page zooms in and fades in
/// while the exiting page zooms out and fades out. The exit transition is similar,
/// but in reverse.
///
/// For iOS, the page slides in from the right and exits in reverse. The page
/// also shifts to the left in parallax when another page enters to cover it.
/// (These directions are flipped in environments with a right-to-left reading
/// direction.)
/// {@endtemplate}
///
/// See also:
///
///  * [PageTransitionsTheme], which defines the default page transitions used
///    by the [MaterialRouteTransitionMixin.buildTransitions].
///  * [ZoomPageTransitionsBuilder], which is the default page transition used
///    by the [PageTransitionsTheme].
///  * [CupertinoPageTransitionsBuilder], which is the default page transition
///    for iOS and macOS.
mixin MaterialRouteTransitionMixin<T> on PageRoute<T> {
  TargetPlatform? _prevTargetPlatform;

  /// Builds the primary contents of the route.
  @protected
  Widget buildContent(BuildContext context);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    // Don't perform outgoing animation if the next route is a fullscreen dialog.
    return (nextRoute is MaterialRouteTransitionMixin && !nextRoute.fullscreenDialog)
      || (nextRoute is CupertinoRouteTransitionMixin && !nextRoute.fullscreenDialog);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final Widget result = buildContent(context);
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: result,
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final ThemeData themeData = Theme.of(context);
    return ValueListenableBuilder<bool>(
        valueListenable: navigator!.userGestureInProgressNotifier,
        builder: (BuildContext context, bool useGestureInProgress, Widget? _) {
          final bool usePrevTargetPlatform;
          if (useGestureInProgress) {
            // The platform should be kept unchanged during an user gesture.
            usePrevTargetPlatform = _prevTargetPlatform != null && _prevTargetPlatform != themeData.platform;
          } else {
            _prevTargetPlatform = themeData.platform;
            usePrevTargetPlatform = false;
          }
          return _PlatformOfBuilder(
            platform: usePrevTargetPlatform ? _prevTargetPlatform : null,
            builder: (BuildContext context, Widget? child) {
              assert(child != null);
              return themeData.pageTransitionsTheme.buildTransitions<T>(this, context, animation, secondaryAnimation, child!);
            },
            child: child,
          );
        });
  }
}

/// Modify only the [platform] of the [builder], not the [child]
class _PlatformOfBuilder extends StatefulWidget {
  const _PlatformOfBuilder({
    required this.builder,
    required this.child,
    required this.platform,
  });

  final TargetPlatform? platform;
  final TransitionBuilder builder;
  final Widget child;

  @override
  State<_PlatformOfBuilder> createState() => _PlatformOfBuilderState();
}

class _PlatformOfBuilderState extends State<_PlatformOfBuilder> {
  final GlobalKey _globalKey = GlobalKey();
  @override
  Widget build(BuildContext context) {
    if (widget.platform == null) {
      // No need to modify the platform, return early
      // Use globalKey to prevent losing state after subtree changes.
      return Builder(
        key: _globalKey,
        builder: (BuildContext context) => widget.builder(context, widget.child),
      );
    }
    final ThemeData themeData = Theme.of(context);
    return Theme(
      // modify the platform of builder
      data: themeData.copyWith(platform: widget.platform),
      child: Builder(
        key: _globalKey,
        builder: (BuildContext context) => widget.builder(
          context,
          Builder(
            builder: (BuildContext context) => Theme(
              // Restore the platform of child
              data: Theme.of(context).copyWith(platform: themeData.platform),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A page that creates a material style [PageRoute].
///
/// {@macro flutter.material.materialRouteTransitionMixin}
///
/// By default, when the created route is replaced by another, the previous
/// route remains in memory. To free all the resources when this is not
/// necessary, set [maintainState] to false.
///
/// The `fullscreenDialog` property specifies whether the created route is a
/// fullscreen modal dialog. On iOS, those routes animate from the bottom to the
/// top rather than horizontally.
///
/// The type `T` specifies the return type of the route which can be supplied as
/// the route is popped from the stack via [Navigator.transitionDelegate] by
/// providing the optional `result` argument to the
/// [RouteTransitionRecord.markForPop] in the [TransitionDelegate.resolve].
///
/// See also:
///
///  * [MaterialPageRoute], which is the [PageRoute] version of this class
class MaterialPage<T> extends Page<T> {
  /// Creates a material page.
  const MaterialPage({
    required this.child,
    this.maintainState = true,
    this.fullscreenDialog = false,
    this.allowSnapshotting = true,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  /// The content to be shown in the [Route] created by this page.
  final Widget child;

  /// {@macro flutter.widgets.ModalRoute.maintainState}
  final bool maintainState;

  /// {@macro flutter.widgets.PageRoute.fullscreenDialog}
  final bool fullscreenDialog;

  /// {@macro flutter.widgets.TransitionRoute.allowSnapshotting}
  final bool allowSnapshotting;

  @override
  Route<T> createRoute(BuildContext context) {
    return _PageBasedMaterialPageRoute<T>(page: this, allowSnapshotting: allowSnapshotting);
  }
}

// A page-based version of MaterialPageRoute.
//
// This route uses the builder from the page to build its content. This ensures
// the content is up to date after page updates.
class _PageBasedMaterialPageRoute<T> extends PageRoute<T> with MaterialRouteTransitionMixin<T> {
  _PageBasedMaterialPageRoute({
    required MaterialPage<T> page,
    super.allowSnapshotting,
  }) : super(settings: page) {
    assert(opaque);
  }

  MaterialPage<T> get _page => settings as MaterialPage<T>;

  @override
  Widget buildContent(BuildContext context) {
    return _page.child;
  }

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';
}
