// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'framework.dart';
import 'gesture_detector.dart';
import 'icon.dart';
import 'icon_data.dart';
import 'implicit_animations.dart';
import 'scroll_delegate.dart';
import 'sliver.dart';
import 'text.dart';
import 'ticker_provider.dart';

const double _kDefaultRowExtent = 40.0;

/// A data structure for configuring children of a [SliverTreeList].
///
/// A [SliverTreeNode.content] can be of any type, but must correspond with the
/// same type of the [SliverTreeList].
///
/// The values returned by [depth], [parent] and [isExpanded] getters are
/// managed by the [SliverTreeList]'s state.
class SliverTreeNode<T> {
  /// Creates a [SliverTreeNode] instance for use in a [SliverTreeList].
  SliverTreeNode(
    T content, {
    List<SliverTreeNode<T>>? children,
    bool expanded = false,
  }) : _expanded = children != null && children.isNotEmpty && expanded,
       _content = content,
       _children = children ?? <SliverTreeNode<T>>[];

  /// The subject matter of the node.
  ///
  /// Must correspond with the type of [SliverTreeList].
  T get content => _content;
  final T _content;

  /// Other [SliverTreeNode]s this node will be [parent] to.
  List<SliverTreeNode<T>> get children => _children;
  final List<SliverTreeNode<T>> _children;

  /// Whether or not this node is expanded in the tree.
  ///
  /// Cannot be expanded if there are no children.
  bool get isExpanded => _expanded;
  bool _expanded;

  /// The number of parent nodes between this node and the root of the tree.
  int? get depth => _depth;
  int? _depth;

  /// The parent [SliverTreeNode] of this node.
  SliverTreeNode<T>? get parent => _parent;
  SliverTreeNode<T>? _parent;

  @override
  String toString() {
    return 'SliverTreeNode: $content, depth: ${depth == 0 ? 'root' : depth}, '
      '${children.isEmpty ? 'leaf' : 'parent, expanded: $isExpanded'}';
  }
}

/// Signature for a function that creates a [Widget] to represent the given
/// [SliverTreeNode] in the [SliverTreeList].
///
/// Used by [SliverTreeList.treeNodeBuilder] to build rows on demand for the
/// tree.
typedef SliverTreeNodeBuilder = Widget Function(
  BuildContext context,
  SliverTreeNode<dynamic> node, {
  AnimationStyle? animationStyle,
});

/// Signature for a function that returns an extent for the given
/// [SliverTreeNode] in the [SliverTreeList].
///
/// Used by [SliverTreeList.treeRowExtentBuilder] to size rows on demand in the
/// tree. The provided [SliverLayoutDimensions] provide information about the
/// current scroll state and [Viewport] dimensions.
///
/// See also:
///
///   * [SliverVariedExtentList], which uses a similar item extent builder for
///     dynamic child sizing in the list.
typedef SliverTreeRowExtentBuilder = double Function(
  SliverTreeNode<dynamic> node,
  SliverLayoutDimensions dimensions,
);

/// Signature for a function that is called when a [SliverTreeNode] is toggled,
/// changing its expanded state.
///
/// See also:
///
///   * [SliverTreeList.onNodeToggle], for controlling node expansion
///     programmatically.
typedef SliverTreeNodeCallback = void Function(SliverTreeNode<dynamic> node);

/// A mixin for classes implementing a tree structure as expected by a
/// [SliverTreeController].
///
/// Used by [SliverTreeList] to implement an interface for the
/// [SliverTreeController].
///
/// This allows the [SliverTreeController] to be used in other widgets that
/// implement this interface.
mixin SliverTreeStateMixin<T> {
  /// Returns whether or not the given [SliverTreeNode] is expanded.
  bool isExpanded(SliverTreeNode<T> node);

  /// Returns whether or not the given [SliverTreeNode] is enclosed within its
  /// parent [SliverTreeNode].
  ///
  /// If the [SliverTreeNode.parent] [isExpanded], or this is a root node, the
  /// given node is active and this method will return true. This does not
  /// reflect whether or not the node is visible in the [Viewport].
  bool isActive(SliverTreeNode<T> node);

  /// Switches the given [SliverTreeNode]s expanded state.
  ///
  /// May trigger an animation to reveal or hide the node's children based on
  /// the [SliverTreeList.animationStyle].
  ///
  /// If the node does not have any children, nothing will happen.
  void toggleNode(SliverTreeNode<T> node);

  /// Closes all parent [SliverTreeNode]s in the tree.
  void collapseAll();

  /// Expands all parent [SliverTreeNode]s in the tree.
  void expandAll();

  /// Retrieves the [SliverTreeNode] containing the associated content, if it
  /// exists.
  ///
  /// If no node exists, this will return null. This does not reflect whether
  /// or not a node [isActive], or if it is visible in the viewport.
  SliverTreeNode<T>? getNodeFor(T content);

  /// Returns the current row index of the given [SliverTreeNode].
  ///
  /// If the node is not currently active in the tree, meaning its parent is
  /// collapsed, this will return null.
  int? getActiveIndexFor(SliverTreeNode<T> node);
}

/// Enables control over the [SliverTreeNode]s of a [SliverTreeList].
///
/// It can be useful to expand or collapse nodes of the tree
/// programmatically, for example to reconfigure an existing node
/// based on a system event. To do so, create an [SliverTreeList]
/// with an [SliverTreeController] that's owned by a stateful widget
/// or look up the tree's automatically created [SliverTreeController]
/// with [SliverTreeController.of]
///
/// The controller's methods to expand or collapse nodes cause the
/// the [SliverTreeList] to rebuild, so they may not be called from
/// a build method.
class SliverTreeController {
  /// Create a controller to be used with [SliverTreeList.controller].
  SliverTreeController();

  SliverTreeStateMixin<dynamic>? _state;

  /// Whether the given [SliverTreeNode] built with this controller is in an
  /// expanded state.
  ///
  /// See also:
  ///
  ///  * [expandNode], which expands a given [SliverTreeNode].
  ///  * [collapseNode], which collapses a given [SliverTreeNode].
  ///  * [SliverTreeList.controller] to create an SliverTree with a controller.
  bool isExpanded(SliverTreeNode<dynamic> node) {
    assert(_state != null);
    return _state!.isExpanded(node);
  }

  /// Whether or not the given [SliverTreeNode] is enclosed within its parent
  /// [SliverTreeNode].
  ///
  /// If the [SliverTreeNode.parent] [isExpanded], or this is a root node, the given
  /// node is active and this method will return true. This does not reflect
  /// whether or not the node is visible in the [Viewport].
  bool isActive(SliverTreeNode<dynamic> node) {
    assert(_state != null);
    return _state!.isActive(node);
  }

  /// Returns the [SliverTreeNode] containing the associated content, if it
  /// exists.
  ///
  /// If no node exists, this will return null. This does not reflect whether
  /// or not a node [isActive], or if it is currently visible in the viewport.
  SliverTreeNode<dynamic>? getNodeFor(dynamic content) {
    assert(_state != null);
    return _state!.getNodeFor(content);
  }

  /// Switches the given [SliverTreeNode]s expanded state.
  ///
  /// May trigger an animation to reveal or hide the node's children based on
  /// the [SliverTreeList.animationStyle].
  ///
  /// If the node does not have any children, nothing will happen.
  void toggleNode(SliverTreeNode<dynamic> node) {
    assert(_state != null);
    return _state!.toggleNode(node);
  }

  /// Expands the [SliverTreeNode] that was built with this controller.
  ///
  /// If the node is already in the expanded state (see [isExpanded]), calling
  /// this method has no effect.
  ///
  /// Calling this method may cause the [SliverTreeList] to rebuild, so it may
  /// not be called from a build method.
  ///
  /// Calling this method will trigger the [SliverTreeList.onNodeToggle]
  /// callback.
  ///
  /// See also:
  ///
  ///  * [collapseNode], which collapses the [SliverTreeNode].
  ///  * [isExpanded] to check whether the tile is expanded.
  ///  * [SliverTreeList.controller] to create an SliverTree with a controller.
  void expandNode(SliverTreeNode<dynamic> node) {
    assert(_state != null);
    if (!node.isExpanded) {
      _state!.toggleNode(node);
    }
  }

  /// Expands all parent [SliverTreeNode]s in the tree.
  void expandAll() {
    assert(_state != null);
    _state!.expandAll();
  }

  /// Closes all parent [SliverTreeNode]s in the tree.
  void collapseAll() {
    assert(_state != null);
    _state!.collapseAll();
  }

  /// Collapses the [SliverTreeNode] that was built with this controller.
  ///
  /// If the node is already in the collapsed state (see [isExpanded]), calling
  /// this method has no effect.
  ///
  /// Calling this method may cause the [SliverTreeList] to rebuild, so it may
  /// not be called from a build method.
  ///
  /// Calling this method will trigger the [SliverTreeList.onNodeToggle]
  /// callback.
  ///
  /// See also:
  ///
  ///  * [expandNode], which expands the tile.
  ///  * [isExpanded] to check whether the tile is expanded.
  ///  * [SliverTreeList.controller] to create an SliverTree with a controller.
  void collapseNode(SliverTreeNode<dynamic> node) {
    assert(_state != null);
    if (node.isExpanded) {
      _state!.toggleNode(node);
    }
  }

  /// Returns the current row index of the given [SliverTreeNode].
  ///
  /// If the node is not currently active in the tree, meaning its parent is
  /// collapsed, this will return null.
  int? getActiveIndexFor(SliverTreeNode<dynamic> node) {
    assert(_state != null);
    return _state!.getActiveIndexFor(node);
  }

  /// Finds the [SliverTreeController] for the closest [SliverTreeList] instance
  /// that encloses the given context.
  ///
  /// If no [SliverTreeList] encloses the given context, calling this
  /// method will cause an assert in debug mode, and throw an
  /// exception in release mode.
  ///
  /// To return null if there is no [SliverTreeList] use [maybeOf] instead.
  ///
  /// Typical usage of the [SliverTreeController.of] function is to call it
  /// from within the `build` method of a descendant of an [SliverTreeList].
  ///
  /// When the [SliverTreeList] is actually created in the same `build`
  /// function as the callback that refers to the controller, then the
  /// `context` argument to the `build` function can't be used to find
  /// the [SliverTreeController] (since it's "above" the widget
  /// being returned in the widget tree). In cases like that you can
  /// add a [Builder] widget, which provides a new scope with a
  /// [BuildContext] that is "under" the [SliverTreeList].
  static SliverTreeController of(BuildContext context) {
    final _SliverTreeListState<dynamic>? result =
        context.findAncestorStateOfType<_SliverTreeListState<dynamic>>();
    if (result != null) {
      return result.controller;
    }
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary(
        'TreeController.of() called with a context that does not contain a '
        'SliverTree.',
      ),
      ErrorDescription(
        'No SliverTree ancestor could be found starting from the context that '
        'was passed to TreeController.of(). '
        'This usually happens when the context provided is from the same '
        'StatefulWidget as that whose build function actually creates the '
        'SliverTree widget being sought.',
      ),
      ErrorHint(
        'There are several ways to avoid this problem. The simplest is to use '
        'a Builder to get a context that is "under" the SliverTree.',
      ),
      ErrorHint(
        'A more efficient solution is to split your build function into '
        'several widgets. This introduces a new context from which you can '
        'obtain the SliverTree. In this solution, you would have an outer '
        'widget that creates the SliverTree populated by instances of your new '
        'inner widgets, and then in these inner widgets you would use '
        'TreeController.of().',
      ),
      context.describeElement('The context used was'),
    ]);
  }

  /// Finds the [SliverTreeList] from the closest instance of this class that
  /// encloses the given context and returns its [SliverTreeController].
  ///
  /// If no [SliverTreeList] encloses the given context then return null.
  /// To throw an exception instead, use [of] instead of this function.
  ///
  /// See also:
  ///
  ///  * [of], a similar function to this one that throws if no [SliverTreeList]
  ///    encloses the given context. Also includes some sample code in its
  ///    documentation.
  static SliverTreeController? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<_SliverTreeListState<dynamic>>()?.controller;
  }
}

int _kDefaultSemanticIndexCallback(Widget _, int localIndex) => localIndex;

/// A sliver for lazily displaying [SliverTreeNode]s that expand and collapse in
/// a vertically scrolling [Viewport].
///
/// The rows of the tree are laid out on demand, using
/// [SliverTreeList.treeNodeBuilder]. This will only be called for the nodes
/// that are visible, or within the [Viewport.cacheExtent].
///
/// Only [Viewport]s that scroll with and axis direction of [AxisDirection.down]
/// can use SliverTree.
///
///{@tool dartpad}
/// This example uses a [SliverTreeList] to display nodes, highlighting nodes as
/// they are selected.
///
/// ** See code in examples/api/lib/widgets/sliver/sliver_tree.0.dart **
/// {@end-tool}
///
/// {@tool dartpad}
/// This example shows a highly customized [SliverTreeList] configured to
/// [SliverTreeIndentationType.none]. This allows the indentation to be handled
/// by the developer in [SliverTreeList.treeNodeBuilder], where a decoration is
/// used to fill the indented space.
///
/// ** See code in examples/api/lib/widgets/sliver/sliver_tree.1.dart **
/// {@end-tool}
class SliverTreeList<T> extends StatefulWidget {
  /// Creates an instance of a [SliverTreeList] for displaying [SliverTreeNode]s
  /// that animate expanding and collapsing of nodes.
  const SliverTreeList({
    super.key,
    required this.tree,
    this.treeNodeBuilder = SliverTreeList.defaultTreeNodeBuilder,
    this.treeRowExtentBuilder = SliverTreeList.defaultTreeRowExtentBuilder,
    this.controller,
    this.onNodeToggle,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.semanticIndexCallback = _kDefaultSemanticIndexCallback,
    this.semanticIndexOffset = 0,
    this.findChildIndexCallback,
    this.animationStyle,
    this.traversalOrder = SliverTreeTraversalOrder.depthFirst,
    this.indentation = SliverTreeIndentationType.standard,
  });

  /// The list of [SliverTreeNode]s that may be displayed in the [SliverTreeList].
  ///
  /// Beyond root nodes, whether or not a given [SliverTreeNode] is displayed
  /// depends on the [SliverTreeNode.isExpanded] value of its parent. The
  /// [SliverTreeList] will set the [SliverTreeNode.parent] and
  /// [SliverTreeNode.depth] as nodes are built on demand to ensure the
  /// integrity of the tree.
  final List<SliverTreeNode<T>> tree;

  /// Called to build and entry of the [SliverTreeList] for the given node.
  ///
  /// By default, if this is unset, the [SliverTreeList.defaultTreeNodeBuilder]
  /// is used.
  final SliverTreeNodeBuilder treeNodeBuilder;

  /// Called to calculate the extent of the widget built for the given
  /// [SliverTreeNode].
  ///
  /// By default, if this is unset, the
  /// [SliverTreeList.defaultTreeRowExtentBuilder] is used.
  ///
  /// See also:
  ///
  ///   * [SliverVariedExtentList.itemExtentBuilder], a very similar method that
  ///     allows users to dynamically compute extents on demand.
  final SliverTreeRowExtentBuilder treeRowExtentBuilder;

  /// If provided, the controller can be used to expand and collapse
  /// [SliverTreeNode]s, or lookup information about the current state of the
  /// [SliverTreeList].
  final SliverTreeController? controller;

  /// Called when a [SliverTreeNode] expands or collapses.
  ///
  /// This will not be called if a [SliverTreeNode] does not have any children.
  final SliverTreeNodeCallback? onNodeToggle;

  /// {@macro flutter.widgets.SliverChildBuilderDelegate.addAutomaticKeepAlives}
  final bool addAutomaticKeepAlives;

  /// {@macro flutter.widgets.SliverChildBuilderDelegate.addRepaintBoundaries}
  final bool addRepaintBoundaries;

  /// {@macro flutter.widgets.SliverChildBuilderDelegate.addSemanticIndexes}
  final bool addSemanticIndexes;

  /// {@macro flutter.widgets.SliverChildBuilderDelegate.semanticIndexCallback}
  final SemanticIndexCallback semanticIndexCallback;

  /// {@macro flutter.widgets.SliverChildBuilderDelegate.semanticIndexOffset}
  final int semanticIndexOffset;

  /// {@macro flutter.widgets.SliverChildBuilderDelegate.findChildIndexCallback}
  final int? Function(Key)? findChildIndexCallback;

  /// Used to override the toggle animation's curve and duration.
  ///
  /// If [AnimationStyle.duration] is provided, it will be used to override
  /// the [SliverTreeList.defaultAnimationDuration], which is 150
  /// milliseconds.
  ///
  /// If [AnimationStyle.curve] is provided, it will be used to override
  /// the [SliverTreeList.defaultAnimationCurve], which is [Curves.linear].
  ///
  /// To disable the tree animation, use [AnimationStyle.noAnimation].
  final AnimationStyle? animationStyle;

  /// A default of [Curves.linear], which is used in the tree's expanding and
  /// collapsing node animation.
  static const Curve defaultAnimationCurve = Curves.linear;

  /// A default [Duration] of 150 milliseconds, which is used in the tree's
  /// expanding and collapsing node animation.
  static const Duration defaultAnimationDuration = Duration(milliseconds: 150);

  /// The order in which [SliverTreeNode]s are visited.
  ///
  /// Defaults to [SliverTreeTraversalOrder.depthFirst].
  final SliverTreeTraversalOrder traversalOrder;

  /// The number of pixels children will be offset by in the cross axis based on
  /// their [SliverTreeNode.depth].
  ///
  /// {@macro flutter.rendering.SliverTreeIndentationType}
  final SliverTreeIndentationType indentation;

  /// A wrapper method for triggering the expansion or collapse of a
  /// [SliverTreeNode].
  ///
  /// Used as part of [SliverTreeList.defaultTreeNodeBuilder] to wrap the leading
  /// icon of parent [SliverTreeNode]s such that tapping on it triggers the
  /// animation.
  ///
  /// If defining your own [SliverTreeList.treeNodeBuilder], this method can be used
  /// to wrap any part, or all, of the returned widget in order to trigger the
  /// change in state for the node.
  static Widget toggleNodeWith({
    required SliverTreeNode<dynamic> node,
    required Widget child,
  }) {
    return Builder(builder: (BuildContext context) {
      return GestureDetector(
        onTap: () {
          SliverTreeController.of(context).toggleNode(node);
        },
        child: child,
      );
    });
  }

  /// Returns the fixed default extent for rows in the tree, which is 40 pixels.
  ///
  /// Used by [SliverTreeList.defaultTreeRowExtentBuilder].
  static double defaultTreeRowExtentBuilder(
    SliverTreeNode<dynamic> node,
    SliverLayoutDimensions dimensions,
  ) {
    return _kDefaultRowExtent;
  }

  /// Returns the default tree row for a given [SliverTreeNode].
  ///
  /// Used by [SliverTreeList.treeNodeBuilder].
  ///
  /// This will return a [Row] containing the [toString] of
  /// [SliverTreeNode.content]. If the [SliverTreeNode] is a parent of
  /// additional nodes, a arrow icon will precede the content, and will trigger
  /// an expand and collapse animation when tapped.
  static Widget defaultTreeNodeBuilder(
    BuildContext context,
    SliverTreeNode<dynamic> node, {
    AnimationStyle? animationStyle
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(children: <Widget>[
        // Icon for parent nodes
        SliverTreeList.toggleNodeWith(
          node: node,
          child: SizedBox.square(
            dimension: 30.0,
            child: node.children.isNotEmpty
                ? AnimatedRotation(
                    key: Key(node.content.toString()),
                    turns: node.isExpanded ? 0.25 : 0.0,
                    duration: animationStyle?.duration ?? SliverTreeList.defaultAnimationDuration,
                    curve: animationStyle?.curve ?? SliverTreeList.defaultAnimationCurve,
                    child: const Icon(IconData(0x25BA), size: 14),
                  )
                : null,
          ),
        ),
        // Spacer
        const SizedBox(width: 8.0),
        // Content
        Text(node.content.toString()),
      ]),
    );
  }

  @override
  State<SliverTreeList<T>> createState() => _SliverTreeListState<T>();
}

// Used in _SliverTreeState for code simplicity.
typedef _AnimationRecord = ({
  AnimationController controller,
  Animation<double> animation,
  UniqueKey key,
});

class _SliverTreeListState<T> extends State<SliverTreeList<T>> with TickerProviderStateMixin, SliverTreeStateMixin<T> {
  SliverTreeController get controller => _treeController!;
  SliverTreeController? _treeController;

  final List<SliverTreeNode<T>> _activeNodes = <SliverTreeNode<T>>[];
  bool _shouldUnpackNode(SliverTreeNode<T> node) {
    if (node.children.isEmpty) {
      // No children to unpack.
      return false;
    }
    if (_currentAnimationForParent[node] != null) {
      // Whether expanding or collapsing, the child nodes are still active, so
      // unpack.
      return true;
    }
    // If we are not animating, respect node.isExpanded;
    return node.isExpanded;
  }
  void _unpackActiveNodes({
    int depth = 0,
    List<SliverTreeNode<T>>? nodes,
    SliverTreeNode<T>? parent,
  }) {
    if (nodes == null) {
      _activeNodes.clear();
      nodes = widget.tree;
    }
    for (final SliverTreeNode<T> node in nodes) {
      node._depth = depth;
      node._parent = parent;
      _activeNodes.add(node);
      if (_shouldUnpackNode(node)) {
        _unpackActiveNodes(
          depth: depth + 1,
          nodes: node.children,
          parent: node,
        );
      }
    }
  }

  final Map<SliverTreeNode<T>, _AnimationRecord> _currentAnimationForParent = <SliverTreeNode<T>, _AnimationRecord>{};
  final Map<UniqueKey, SliverTreeNodesAnimation> _activeAnimations = <UniqueKey, SliverTreeNodesAnimation>{};

  @override
  void initState() {
    _unpackActiveNodes();
    assert(widget.controller?._state == null);
    _treeController = widget.controller ?? SliverTreeController();
    _treeController!._state = this;
    super.initState();
  }

  @override
  void didUpdateWidget(SliverTreeList<T> oldWidget) {
    // Internal or provided, there is always a tree controller.
    assert(_treeController != null);
    if (oldWidget.controller == null && widget.controller != null) {
      // A new tree controller has been provided, update and dispose of the
      // internally generated one.
      _treeController!._state = null;
      _treeController = widget.controller;
      _treeController!._state = this;
    } else if (oldWidget.controller != null && widget.controller == null) {
      // A tree controller had been provided, but was removed. We need to create
      // one internally.
      assert(oldWidget.controller == _treeController);
      oldWidget.controller!._state = null;
      _treeController = SliverTreeController();
      _treeController!._state = this;
    } else if (oldWidget.controller != widget.controller) {
      assert(oldWidget.controller != null);
      assert(widget.controller != null);
      assert(oldWidget.controller == _treeController);
      // The tree is still being provided a controller, but it has changed. Just
      // update it.
      _treeController!._state = null;
      _treeController = widget.controller;
      _treeController!._state = this;
    }
    // Internal or provided, there is always a tree controller.
    assert(_treeController != null);
    assert(_treeController!._state != null);
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _treeController!._state = null;
    for (final _AnimationRecord record in _currentAnimationForParent.values) {
      record.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SliverTree(
      itemCount: _activeNodes.length,
      activeAnimations: _activeAnimations,
      itemBuilder: (BuildContext context, int index) {
        final SliverTreeNode<T> node = _activeNodes[index];
        Widget child = widget.treeNodeBuilder(
          context,
          node,
          animationStyle: widget.animationStyle,
        );

        if (widget.addRepaintBoundaries) {
          child = RepaintBoundary(child: child);
        }
        if (widget.addSemanticIndexes) {
          final int? semanticIndex = widget.semanticIndexCallback(child, index);
          if (semanticIndex != null) {
            child = IndexedSemantics(
              index: semanticIndex + widget.semanticIndexOffset,
              child: child,
            );
          }
        }

        return _TreeNodeParentDataWidget(
          depth: node.depth!,
          child: child,
        );
      },
      itemExtentBuilder: (int index, SliverLayoutDimensions dimensions) {
        return widget.treeRowExtentBuilder(_activeNodes[index], dimensions);
      },
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      findChildIndexCallback: widget.findChildIndexCallback,
      traversalOrder: widget.traversalOrder,
      indentation: widget.indentation.value,
    );
  }

  // TreeStateMixin Implementation

  @override
  bool isExpanded(SliverTreeNode<T> node) {
    return _getNode(node.content, widget.tree)?.isExpanded ?? false;
  }

  @override
  bool isActive(SliverTreeNode<T> node) => _activeNodes.contains(node);

  @override
  SliverTreeNode<T>? getNodeFor(T content) => _getNode(content, widget.tree);
  SliverTreeNode<T>? _getNode(T content, List<SliverTreeNode<T>> tree) {
    final List<SliverTreeNode<T>> nextDepth = <SliverTreeNode<T>>[];
    for (final SliverTreeNode<T> node in tree) {
      if (node.content == content) {
        return node;
      }
      if (node.children.isNotEmpty) {
        nextDepth.addAll(node.children);
      }
    }
    if (nextDepth.isNotEmpty) {
      return _getNode(content, nextDepth);
    }
    return null;
  }

  @override
  int? getActiveIndexFor(SliverTreeNode<T> node) {
    if (_activeNodes.contains(node)) {
      return _activeNodes.indexOf(node);
    }
    return null;
  }

  final List<SliverTreeNode<T>> _activeNodesToExpand = <SliverTreeNode<T>>[];
  @override
  void expandAll() {
    _activeNodesToExpand.clear();
    _expandAll(widget.tree);
    _activeNodesToExpand.reversed.forEach(toggleNode);
  }
  void _expandAll(List<SliverTreeNode<T>> tree) {
    for (final SliverTreeNode<T> node in tree) {
      if (node.children.isNotEmpty) {
        // This is a parent node.
        // Expand all the children, and their children.
        _expandAll(node.children);
        if (!node.isExpanded) {
          // The node itself needs to be expanded.
          if (_activeNodes.contains(node)) {
            // This is an active node in the tree, add to
            // the list to toggle once all hidden nodes
            // have been handled.
            _activeNodesToExpand.add(node);
          } else {
            // This is a hidden node. Update its expanded state.
            node._expanded = true;
          }
        }
      }
    }
  }

  final List<SliverTreeNode<T>> _activeNodesToCollapse = <SliverTreeNode<T>>[];
  @override
  void collapseAll() {
    _activeNodesToCollapse.clear();
    _collapseAll(widget.tree);
    _activeNodesToCollapse.reversed.forEach(toggleNode);
  }
  void _collapseAll(List<SliverTreeNode<T>> tree) {
    for (final SliverTreeNode<T> node in tree) {
      if (node.children.isNotEmpty) {
        // This is a parent node.
        // Collapse all the children, and their children.
        _collapseAll(node.children);
        if (node.isExpanded) {
          // The node itself needs to be collapsed.
          if (_activeNodes.contains(node)) {
            // This is an active node in the tree, add to
            // the list to toggle once all hidden nodes
            // have been handled.
            _activeNodesToCollapse.add(node);
          } else {
            // This is a hidden node. Update its expanded state.
            node._expanded = false;
          }
        }
      }
    }
  }

  void _updateActiveAnimations() {
    // The indexes of various child node animations can change constantly based
    // on more nodes being expanded or collapsed. Compile the indexes and their
    // animations keys each time we build with an updated active node list.
    _activeAnimations.clear();
    for (final SliverTreeNode<T> node in _currentAnimationForParent.keys) {
      final _AnimationRecord animationRecord = _currentAnimationForParent[node]!;
      final int leadingChildIndex = _activeNodes.indexOf(node) + 1;
      final SliverTreeNodesAnimation animatingChildren = (
        fromIndex: leadingChildIndex,
        toIndex: leadingChildIndex + node.children.length - 1,
        value: animationRecord.animation.value,
      );
      _activeAnimations[animationRecord.key] = animatingChildren;
    }
  }

  @override
  void toggleNode(SliverTreeNode<T> node) {
    assert(_activeNodes.contains(node));
    if (node.children.isEmpty) {
      // No state to change.
      return;
    }
    setState(() {
      node._expanded = !node._expanded;
      if (widget.onNodeToggle != null) {
        widget.onNodeToggle!(node);
      }
      final AnimationController controller = _currentAnimationForParent[node]?.controller
        ?? AnimationController(
          value: node._expanded ? 0.0 : 1.0,
          vsync: this,
          duration: widget.animationStyle?.duration ?? SliverTreeList.defaultAnimationDuration,
        )..addStatusListener((AnimationStatus status) {
          switch (status) {
            case AnimationStatus.dismissed:
            case AnimationStatus.completed:
              _currentAnimationForParent[node]!.controller.dispose();
              _currentAnimationForParent.remove(node);
              _updateActiveAnimations();
            case AnimationStatus.forward:
            case AnimationStatus.reverse:
          }
        })..addListener(() {
          setState((){
            _updateActiveAnimations();
          });
        });

      switch (controller.status) {
        case AnimationStatus.forward:
        case AnimationStatus.reverse:
          // We're interrupting an animation already in progress.
          controller.stop();
        case AnimationStatus.dismissed:
        case AnimationStatus.completed:
      }

      final Animation<double> newAnimation = CurvedAnimation(
        parent: controller,
        curve: widget.animationStyle?.curve ?? SliverTreeList.defaultAnimationCurve,
      );
      _currentAnimationForParent[node] = (
        controller: controller,
        animation: newAnimation,
        // This key helps us keep track of the lifetime of this animation in the
        // render object, since the indexes can change at any time.
        key: UniqueKey(),
      );
      switch (node._expanded) {
        case true:
          // Expanding
          _unpackActiveNodes();
          controller.forward();
        case false:
          // Collapsing
          controller.reverse().then((_) {
            _unpackActiveNodes();
          });
      }
    });
  }
}

class _TreeNodeParentDataWidget extends ParentDataWidget<TreeNodeParentData> {
  const _TreeNodeParentDataWidget({
    required this.depth,
    required super.child,
  }) : assert(depth >= 0);

  final int depth;

  @override
  void applyParentData(RenderObject renderObject) {
    final TreeNodeParentData parentData = renderObject.parentData! as TreeNodeParentData;
    bool needsLayout = false;

    if (parentData.depth != depth) {
      assert(depth >= 0);
      parentData.depth = depth;
      needsLayout = true;
    }

    if (needsLayout) {
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _SliverTree;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('depth', depth));
  }
}

class _SliverTree extends SliverVariedExtentList {
  _SliverTree({
    required NullableIndexedWidgetBuilder itemBuilder,
    required super.itemExtentBuilder,
    required this.activeAnimations,
    this.traversalOrder = SliverTreeTraversalOrder.depthFirst,
    required this.indentation,
    ChildIndexGetter? findChildIndexCallback,
    required int itemCount,
    bool addAutomaticKeepAlives = true,
  }) : super(delegate: SliverChildBuilderDelegate(
    itemBuilder,
    findChildIndexCallback: findChildIndexCallback,
    childCount: itemCount,
    addAutomaticKeepAlives: addAutomaticKeepAlives,
    addRepaintBoundaries: false, // Added in the _SliverTreeState
    addSemanticIndexes: false, // Added in the _SliverTreeState
  ));

  final Map<UniqueKey, SliverTreeNodesAnimation> activeAnimations;
  final SliverTreeTraversalOrder traversalOrder;
  final double indentation;

  @override
  RenderSliverTree createRenderObject(BuildContext context) {
    final SliverMultiBoxAdaptorElement element = context as SliverMultiBoxAdaptorElement;
    return RenderSliverTree(
      itemExtentBuilder: itemExtentBuilder,
      activeAnimations: activeAnimations,
      traversalOrder: traversalOrder,
      indentation: indentation,
      childManager: element,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderSliverTree renderObject) {
    renderObject
      ..itemExtentBuilder = itemExtentBuilder
      ..activeAnimations = activeAnimations
      ..traversalOrder = traversalOrder
      ..indentation = indentation;
  }
}
