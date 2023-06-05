// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'framework.dart';
import 'navigator.dart';
import 'routes.dart';

/// A callback type for informing that a navigation pop has happened.
///
/// Accepts a success boolean indicating whether or not back navigation
/// succeded.
typedef OnPoppedCallback = void Function(bool success);

// TODO(justinmc): Change name to match popEnabled  more?
/// Manages system back gestures.
///
/// [popEnabled] can be used to disable system back gestures, while [onPopped]
/// reports when they occur.
///
/// {@tool dartpad}
/// This sample demonstrates how to use this widget to properly handle system
/// back gestures when using nested [Navigator]s.
///
/// ** See code in examples/api/lib/widgets/can_pop_scope/nested_navigators.0.dart **
/// {@end-tool}
///
/// See also:
///
///  * [NavigatorPopHandler], which is a less verbose way to handle system back
///    gestures in the case of nested [Navigator]s.
///  * [ModalRoute.registerCanPopScope] and [ModalRoute.unregisterCanPopScope],
///    which this widget uses to integrate with Flutter's navigation system.
///  * [Form.popEnabled] and [Form.onPopped], which can be used to handle system
///    back gestures in the case of a form with unsaved data.
class CanPopScope extends StatefulWidget {
  /// Creates a widget that registers a callback to veto attempts by the user to
  /// dismiss the enclosing [ModalRoute].
  ///
  /// The [child] argument must not be null.
  const CanPopScope({
    super.key,
    required this.child,
    this.popEnabled = true,
    this.onPopped,
  });

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  /// {@macro flutter.widgets.navigator.onPopped}
  ///
  /// See also:
  ///
  ///  * [Route.onPopped], which is similar.
  final OnPoppedCallback? onPopped;

  /// {@template flutter.widgets.CanPopScope.popEnabled}
  /// When false, blocks the current route from being popped.
  ///
  /// This includes the root route, where upon popping, the Flutter app would
  /// exit.
  ///
  /// If multiple CanPopScope widgets appear in a route's widget subtree, then
  /// each and every `popEnabled` must be `true` in order for the route to be
  /// able to pop.
  ///
  /// This may have implications for route transitions that allow some
  /// interaction before committing to popping the route. For example,
  /// [Android's predictive back](https://developer.android.com/guide/navigation/predictive-back-gesture)
  /// feature will not animate at all when this boolean is true.
  /// {@endtemplate}
  final bool popEnabled;

  @override
  State<CanPopScope> createState() => _CanPopScopeState();
}

class _CanPopScopeState extends State<CanPopScope> {
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    _route?.registerCanPopScope(widget);
  }

  @override
  void didUpdateWidget(CanPopScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _route = ModalRoute.of(context);
    _route?.unregisterCanPopScope(oldWidget);
    _route?.registerCanPopScope(widget);
  }

  @override
  void dispose() {
    _route?.unregisterCanPopScope(widget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
