import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter/painting.dart' show MatrixUtils;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'route.dart';

/// A full-screen menu that can be activated for the given child.
///
/// Long pressing or 3d touching on the child will open in up in a full-screen
/// overlay menu.
// TODO(justinmc): Set up type param here for return value.
class ContextMenu extends StatefulWidget {
  /// Create a context menu.
  const ContextMenu({
    Key key,
    this.child,
  }) : super(key: key);

  /// The widget that can be opened in a ContextMenu.
  ///
  /// This widget will be displayed at its normal position in the widget tree,
  /// but long pressing or 3d touching on it will cause the ContextMenu to open.
  final Widget child;

  @override
  _ContextMenuState createState() => _ContextMenuState();
}

class _ContextMenuState extends State<ContextMenu> with TickerProviderStateMixin {
  // TODO(justinmc): Replace with real system colors when dark mode is
  // supported for iOS.
  //static const Color _darkModeMaskColor = Color(0xAAFFFFFF);
  static const Color _lightModeMaskColor = Color(0xAAAAAAAA);

  final GlobalKey _childGlobalKey = GlobalKey();

  Animation<Matrix4> _transform;
  AnimationController _controller;
  double _scaleStart;
  // TODO(justinmc): Get mask flash working again.
  bool _isMasked = false;
  bool _isOpen = false;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _controller.addStatusListener(_onAnimationChangeStatus);
    super.initState();
  }

  void _onAnimationChangeStatus(AnimationStatus animationStatus) {
    if (animationStatus == AnimationStatus.completed) {
      _openContextMenu();
    }
  }

  void _onTapDown(TapDownDetails details) {
    _transform = Tween<Matrix4>(
      begin: Matrix4.identity(),
      // TODO(justinmc): Make end centered instead of using alignment.
      end: Matrix4.identity()..scale(1.2),//..translate(-100.0),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInBack,
      ),
    );
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _openContextMenu() async {
    setState(() {
      _isOpen = true;
    });

    // Get the current position of the child
    assert(_childGlobalKey.currentContext != null);
    final RenderRepaintBoundary renderBox = _childGlobalKey.currentContext.findRenderObject();
    ui.Image image = await renderBox.toImage();

    final Offset offset = renderBox.localToGlobal(renderBox.paintBounds.topLeft);
    final Rect originalRect = offset & renderBox.paintBounds.size;
    final Rect rect = MatrixUtils.transformRect(_transform.value, originalRect);
    // TODO(justinmc): Ignoring transform, rect is significantly off. Not sure
    // why.

    await Navigator.of(context, rootNavigator: true).push(
      _ContextMenuRoute<void>(
        barrierLabel: 'Dismiss',
        filter: ui.ImageFilter.blur(
          sigmaX: 5.0,
          sigmaY: 5.0,
        ),
        rect: rect,
        builder: (BuildContext context) {
          // TODO(justinmc): Can't duplicate widget like this because can't have
          // two of the same global key. Screenshotting it works, but when
          // enlarging, is blurry.
          //return _childGlobalKey.currentWidget;
          return CustomPaint(
            painter: _ContextMenuChildPainter(
              image: image,
            ),
          );
        },
      ),
    );

    // TODO(justinmc): This happens when the transition starts and the child is
    // still in the scene.  Should happen when the transition ends.
    setState(() {
      _isOpen = false;
    });
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.reset();
    _transform = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      child: AnimatedBuilder(
        builder: _buildAnimation,
        animation: _controller,
      ),
    );
  }

  Widget _buildAnimation(BuildContext context, Widget child) {
    final Color maskColor = _isMasked ? _lightModeMaskColor : const Color(0xFFFFFFFF);

    return Transform(
      //alignment: FractionalOffset.center,
      transform: _transform?.value ?? Matrix4.identity(),
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[maskColor, maskColor],
          ).createShader(bounds);
        },
        child: Opacity(
          // TODO(justinmc): Hardcoding this just for debugging the position.
          // Restore the ternary later.
          opacity: 1.0,//_isOpen ? 0.0 : 1.0,
          child: RepaintBoundary(
            key: _childGlobalKey,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Color(0xff0000ff),
                  width: 1.0,
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContextMenuRoute<T> extends PopupRoute<T> {
  _ContextMenuRoute({
    this.barrierLabel,
    this.builder,
    ui.ImageFilter filter,
    Rect rect,
    RouteSettings settings,
  }) : _rect = rect,
       super(
         filter: filter,
         settings: settings,
       );

  // Barrier color for a Cupertino modal barrier.
  static const Color _kModalBarrierColor = Color(0x6604040F);
  // The duration of the transition used when a modal popup is shown.
  static const Duration _kModalPopupTransitionDuration = Duration(milliseconds: 1335);

  final WidgetBuilder builder;

  // The rect containing the widget that should show in the ContextMenu.
  final Rect _rect;

  @override
  final String barrierLabel;

  @override
  Color get barrierColor => _kModalBarrierColor;

  @override
  bool get barrierDismissible => true;

  @override
  bool get semanticsDismissible => false;

  @override
  Duration get transitionDuration => _kModalPopupTransitionDuration;

  Animation<double> _animation;

  Tween<Matrix4> _matrix4Tween;

  @override
  Animation<double> createAnimation() {
    assert(_animation == null);
    _animation = CurvedAnimation(
      parent: super.createAnimation(),

      // These curves were initially measured from native iOS horizontal page
      // route animations and seemed to be a good match here as well.
      curve: Curves.linearToEaseOut,
      reverseCurve: Curves.linearToEaseOut.flipped,
    );

    _matrix4Tween = Tween<Matrix4>(
      // TODO(justinmc): Reuse constant scale values or something from above.
      begin: Matrix4.identity()..translate(_rect.left, _rect.top)..scale(1.2),
      end: Matrix4.identity()..translate(_rect.left, _rect.top)..scale(1.8),
    );

    return _animation;
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return builder(context);
    /*
    // TODO(justinmc): Positioning using the animation above, so shouldn't need
    // all of this.
    return Stack(
      children: <Widget>[
        Positioned(
          left: _rect.left,
          top: _rect.top,
          child: SizedBox(
            width: _rect.width,
            height: _rect.height,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Color(0xffff0000),
                  width: 1.0,
                ),
              ),
              child: builder(context),
            ),
          ),
        ),
      ],
    );
    */
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return Transform(
      transform: _matrix4Tween.evaluate(_animation),
      child: child,
    );
  }
}

// Paint the given image.
class _ContextMenuChildPainter extends CustomPainter {
  const _ContextMenuChildPainter({
    ui.Image image,
  }) : _image = image;

  final ui.Image _image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(_image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
