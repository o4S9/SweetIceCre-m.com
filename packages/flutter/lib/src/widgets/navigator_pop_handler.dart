// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'can_pop_scope.dart';
import 'framework.dart';
import 'navigator.dart';
import 'notification_listener.dart';

/// Enables the handling of system back gestures.
///
/// Typically wraps a nested [Navigator] widget and allows it to handle system
/// back gestures in the [onPopped] callback.
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
///  * [CanPopScope], which allows toggling the ability of a [Navigator] to
///    handle pops.
///  * [NavigationNotification], which indicates whether a [Navigator] in a
///    subtree can handle pops.
class NavigatorPopHandler extends StatefulWidget {
  /// Creates an instance of [NavigatorPophandler].
  const NavigatorPopHandler({
    super.key,
    required this.child,
    this.onPopped,
  });

  /// The widget to place below this in the widget tree.
  ///
  /// Typically this is a [Navigator] that will handle the pop when [onPopped] is
  /// called.
  final Widget child;

  /// {@macro flutter.widgets.navigator.onPopped}
  ///
  /// Typically this is used to pop the [Navigator] in [child].  See the sample
  /// code on [Navigator] for a full example of this.
  ///
  /// See also:
  ///
  ///  * [CanPopScope.onPopped], which is similar.
  final OnPoppedCallback? onPopped;

  @override
  State<NavigatorPopHandler> createState() => _NavigatorPopHandlerState();
}

class _NavigatorPopHandlerState extends State<NavigatorPopHandler> {
  bool _popEnabled = true;

  @override
  Widget build(BuildContext context) {
    // When the widget subtree indicates it can handle a pop, disable popping
    // here, so that it can be manually handled in canPop.
    return CanPopScope(
      popEnabled: _popEnabled,
      onPopped: (bool success) {
        if (_popEnabled) {
          return;
        }
        widget.onPopped?.call(success);
      },
      // Listen to changes in the navigation stack in the widget subtree.
      child: NotificationListener<NavigationNotification>(
        onNotification: (NavigationNotification notification) {
          final bool nextPopEnabled = !notification.canPop;
          if (nextPopEnabled != _popEnabled) {
            setState(() {
              _popEnabled = nextPopEnabled;
            });
          }
          return false;
        },
        child: widget.child,
      ),
    );
  }
}
