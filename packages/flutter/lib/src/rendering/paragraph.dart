// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui show Gradient, Shader, TextBox, Offsetff, PlaceholderAlignment;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';


import 'box.dart';
import 'debug.dart';
import 'object.dart';

/// How overflowing text should be handled.
enum TextOverflow {
  /// Clip the overflowing text to fix its container.
  clip,

  /// Fade the overflowing text to transparent.
  fade,

  /// Use an ellipsis to indicate that the text has overflowed.
  ellipsis,

  /// Render overflowing text outside of its container.
  visible,
}

const String _kEllipsis = '\u2026';

/// Parent data for use with [RenderParagraph].
class TextParentData extends ContainerBoxParentData<RenderBox> {
  @override
  String toString() {
    final List<String> values = <String>[];
    if (offset != null)
      values.add('offset=$offset');
    values.add(super.toString());
    return values.join('; ');
  }
}

/// A render object that displays a paragraph of text
class RenderParagraph extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, TextParentData>,
             RenderBoxContainerDefaultsMixin<RenderBox, TextParentData> {
  /// Creates a paragraph render object.
  ///
  /// The [text], [textAlign], [textDirection], [overflow], [softWrap], and
  /// [textScaleFactor] arguments must not be null.
  ///
  /// The [maxLines] property may be null (and indeed defaults to null), but if
  /// it is not null, it must be greater than zero.
  RenderParagraph(InlineSpan text, {
    TextAlign textAlign = TextAlign.start,
    @required TextDirection textDirection,
    bool softWrap = true,
    TextOverflow overflow = TextOverflow.clip,
    double textScaleFactor = 1.0,
    int maxLines,
    Locale locale,
    StrutStyle strutStyle,
    List<RenderBox> children,
  }) : assert(text != null),
       assert(text.debugAssertIsValid()),
       assert(textAlign != null),
       assert(textDirection != null),
       assert(softWrap != null),
       assert(overflow != null),
       assert(textScaleFactor != null),
       assert(maxLines == null || maxLines > 0),
       _softWrap = softWrap,
       _overflow = overflow,
       _textPainter = TextPainter(
         text: text,
         textAlign: textAlign,
         textDirection: textDirection,
         textScaleFactor: textScaleFactor,
         maxLines: maxLines,
         ellipsis: overflow == TextOverflow.ellipsis ? _kEllipsis : null,
         locale: locale,
         strutStyle: strutStyle,
       ) {
   addAll(children);
   _extractPlaceholderSpans(text);
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! TextParentData)
      child.parentData = TextParentData();
  }

  final TextPainter _textPainter;
  bool _needsLayout = true;


  /// The text to display
  InlineSpan get text => _textPainter.text;
  set text(InlineSpan value) {
    assert(value != null);
    switch (_textPainter.text.compareTo(value)) {
      case RenderComparison.identical:
      case RenderComparison.metadata:
        return;
      case RenderComparison.paint:
        _textPainter.text = value;
        markNeedsPaint();
        markNeedsSemanticsUpdate();
        break;
      case RenderComparison.layout:
        _textPainter.text = value;
        _overflowShader = null;
        markNeedsLayout();
        break;
    }
  }

  List<PlaceholderSpan> _placeholderSpans;
  // Traverses the InlineSpan tree and depth-first collects the list of
  // child WidgetsSpans. Populates _placeholderSpans.
  void _extractPlaceholderSpans(InlineSpan span) {
    _placeholderSpans = [];
    span.visitChildren((InlineSpan span) {
      if (span is PlaceholderSpan) {
        PlaceholderSpan placeholderSpan = span;
        _placeholderSpans.add(placeholderSpan);
      }
      return true;
    });
  }

  /// How the text should be aligned horizontally.
  TextAlign get textAlign => _textPainter.textAlign;
  set textAlign(TextAlign value) {
    assert(value != null);
    if (_textPainter.textAlign == value)
      return;
    _textPainter.textAlign = value;
    markNeedsPaint();
  }

  /// The directionality of the text.
  ///
  /// This decides how the [TextAlign.start], [TextAlign.end], and
  /// [TextAlign.justify] values of [textAlign] are interpreted.
  ///
  /// This is also used to disambiguate how to render bidirectional text. For
  /// example, if the [text] is an English phrase followed by a Hebrew phrase,
  /// in a [TextDirection.ltr] context the English phrase will be on the left
  /// and the Hebrew phrase to its right, while in a [TextDirection.rtl]
  /// context, the English phrase will be on the right and the Hebrew phrase on
  /// its left.
  ///
  /// This must not be null.
  TextDirection get textDirection => _textPainter.textDirection;
  set textDirection(TextDirection value) {
    assert(value != null);
    if (_textPainter.textDirection == value)
      return;
    _textPainter.textDirection = value;
    markNeedsLayout();
  }

  /// Whether the text should break at soft line breaks.
  ///
  /// If false, the glyphs in the text will be positioned as if there was
  /// unlimited horizontal space.
  ///
  /// If [softWrap] is false, [overflow] and [textAlign] may have unexpected
  /// effects.
  bool get softWrap => _softWrap;
  bool _softWrap;
  set softWrap(bool value) {
    assert(value != null);
    if (_softWrap == value)
      return;
    _softWrap = value;
    markNeedsLayout();
  }

  /// How visual overflow should be handled.
  TextOverflow get overflow => _overflow;
  TextOverflow _overflow;
  set overflow(TextOverflow value) {
    assert(value != null);
    if (_overflow == value)
      return;
    _overflow = value;
    _textPainter.ellipsis = value == TextOverflow.ellipsis ? _kEllipsis : null;
    markNeedsLayout();
  }

  /// The number of font pixels for each logical pixel.
  ///
  /// For example, if the text scale factor is 1.5, text will be 50% larger than
  /// the specified font size.
  double get textScaleFactor => _textPainter.textScaleFactor;
  set textScaleFactor(double value) {
    assert(value != null);
    if (_textPainter.textScaleFactor == value)
      return;
    _textPainter.textScaleFactor = value;
    _overflowShader = null;
    markNeedsLayout();
  }

  /// An optional maximum number of lines for the text to span, wrapping if necessary.
  /// If the text exceeds the given number of lines, it will be truncated according
  /// to [overflow] and [softWrap].
  int get maxLines => _textPainter.maxLines;
  /// The value may be null. If it is not null, then it must be greater than zero.
  set maxLines(int value) {
    assert(value == null || value > 0);
    if (_textPainter.maxLines == value)
      return;
    _textPainter.maxLines = value;
    _overflowShader = null;
    markNeedsLayout();
  }

  /// Used by this paragraph's internal [TextPainter] to select a locale-specific
  /// font.
  ///
  /// In some cases the same Unicode character may be rendered differently depending
  /// on the locale. For example the '骨' character is rendered differently in
  /// the Chinese and Japanese locales. In these cases the [locale] may be used
  /// to select a locale-specific font.
  Locale get locale => _textPainter.locale;
  /// The value may be null.
  set locale(Locale value) {
    if (_textPainter.locale == value)
      return;
    _textPainter.locale = value;
    _overflowShader = null;
    markNeedsLayout();
  }

  /// {@macro flutter.painting.textPainter.strutStyle}
  StrutStyle get strutStyle => _textPainter.strutStyle;
  /// The value may be null.
  set strutStyle(StrutStyle value) {
    if (_textPainter.strutStyle == value)
      return;
    _textPainter.strutStyle = value;
    _overflowShader = null;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (!_canComputeIntrinsics())
      return 0;
    if (_needsLayout) {
      _computeChildrenWidthWithMinIntrinsics(height);
      _layoutText();
      // Purposefully not markNeedsLayout(). markNeedsLayout() calls
      // super.markNeedsLayout(), which we do not want to do as this
      // layout run is temporary and not a real layout run. It does
      // not effect the final layout of parents.
      _needsLayout = true;
    }
    double minWidth = _textPainter.minIntrinsicWidth;
    return minWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (!_canComputeIntrinsics())
      return 0;
    if (_needsLayout) {
      _computeChildrenWidthWithMaxIntrinsics(height);
      _layoutText(); // layout with infinite width.
      // Purposefully not markNeedsLayout(). markNeedsLayout() calls
      // super.markNeedsLayout(), which we do not want to do as this
      // layout run is temporary and not a real layout run. It does
      // not effect the final layout of parents.
      _needsLayout = true;
    }
    double maxWidth = _textPainter.maxIntrinsicWidth;
    return maxWidth;
  }

  double _computeIntrinsicHeight(double width) {
    if (!_canComputeIntrinsics())
      return 0;
    _computeChildrenHeightWithMinIntrinsics(width);
    _layoutText(minWidth: width, maxWidth: width);
    // Purposefully not markNeedsLayout(). markNeedsLayout() calls
    // super.markNeedsLayout(), which we do not want to do as this
    // layout run is temporary and not a real layout run. It does
    // not effect the final layout of parents.
    _needsLayout = true;
    double height = _textPainter.height;
    return height;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return _computeIntrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _computeIntrinsicHeight(width);
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    assert(!debugNeedsLayout);
    assert(constraints != null);
    assert(constraints.debugAssertIsValid());
    _layoutTextWithConstraints(constraints);
    return _textPainter.computeDistanceToActualBaseline(baseline);
  }

  /// Intrinsics cannot be calculated without a full layout for
  /// alignments that require the baseline (baseline, aboveBaseline,
  /// belowBaseline).
  bool _canComputeIntrinsics() {
    for (PlaceholderSpan span in _placeholderSpans) {
      switch (span.alignment) {
        case ui.PlaceholderAlignment.baseline:
        case ui.PlaceholderAlignment.aboveBaseline:
        case ui.PlaceholderAlignment.belowBaseline: {
          assert(RenderObject.debugCheckingIntrinsics,
            'Intrinsics are not available for PlaceholderAlignment.baseline, '
            'PlaceholderAlignment.aboveBaseline, or PlaceholderAlignment.belowBaseline,');
          return false;
        }
        case ui.PlaceholderAlignment.top:
        case ui.PlaceholderAlignment.middle:
        case ui.PlaceholderAlignment.bottom: {
          continue;
        }
      }
    }
    return true;
  }

  void _computeChildrenWidthWithMaxIntrinsics(double height) {
    RenderBox child = firstChild;
    List<PlaceholderDimensions> placeholderDimensions = List(childCount);
    int childIndex = 0;
    while (child != null) {
      // Height and baseline is irrelevant as all text will be laid
      // out in a single line.
      placeholderDimensions[childIndex] = PlaceholderDimensions(
        size: Size(child.getMaxIntrinsicWidth(height), height),
        alignment: _placeholderSpans[childIndex].alignment,
        baseline: _placeholderSpans[childIndex].baseline,
      );
      child = childAfter(child);
      childIndex += 1;
    }
    _textPainter.setPlaceholderDimensions(placeholderDimensions);
  }

  void _computeChildrenWidthWithMinIntrinsics(double height) {
    RenderBox child = firstChild;
    List<PlaceholderDimensions> placeholderDimensions = List(childCount);
    int childIndex = 0;
    while (child != null) {
      double intrinsicWidth = child.getMinIntrinsicWidth(height);
      double intrinsicHeight = child.getMinIntrinsicHeight(intrinsicWidth);
      placeholderDimensions[childIndex] = PlaceholderDimensions(
        size: Size(intrinsicWidth, intrinsicHeight),
        alignment: _placeholderSpans[childIndex].alignment,
        baseline: _placeholderSpans[childIndex].baseline,
      );
      child = childAfter(child);
      childIndex += 1;
    }
    _textPainter.setPlaceholderDimensions(placeholderDimensions);
  }

  void _computeChildrenHeightWithMinIntrinsics(double width) {
    RenderBox child = firstChild;
    List<PlaceholderDimensions> placeholderDimensions = List(childCount);
    int childIndex = 0;
    while (child != null) {
      double intrinsicHeight = child.getMinIntrinsicHeight(width);
      double intrinsicWidth = child.getMinIntrinsicWidth(intrinsicHeight);
      placeholderDimensions[childIndex] = PlaceholderDimensions(
        size: Size(intrinsicWidth, intrinsicHeight),
        alignment: _placeholderSpans[childIndex].alignment,
        baseline: _placeholderSpans[childIndex].baseline,
      );
      child = childAfter(child);
      childIndex += 1;
    }
    _textPainter.setPlaceholderDimensions(placeholderDimensions);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(HitTestResult result, { Offset position }) {
    RenderBox child = firstChild;
    int childIndex = 0;
    while (child != null) {
      final TextParentData textParentData = child.parentData;
      final Offset adjustedPosition = position - textParentData.offset;
      if (child.hitTest(result, position: adjustedPosition)) {
        result.add(BoxHitTestEntry(child, adjustedPosition));
        return true;
      }
      child = childAfter(child);
      childIndex += 1;
    }
    return false;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    if (event is! PointerDownEvent)
      return;
    _layoutTextWithConstraints(constraints);
    final Offset offset = entry.localPosition;
    final TextPosition position = _textPainter.getPositionForOffset(offset);
    final TextSpan span = _textPainter.text.getSpanForPosition(position);
    span?.recognizer?.addPointer(event);
  }

  bool _needsClipping = false;
  ui.Shader _overflowShader;

  /// Whether this paragraph currently has a [dart:ui.Shader] for its overflow
  /// effect.
  ///
  /// Used to test this object. Not for use in production.
  @visibleForTesting
  bool get debugHasOverflowShader => _overflowShader != null;

  void _layoutText({ double minWidth = 0.0, double maxWidth = double.infinity }) {
    final bool widthMatters = softWrap || overflow == TextOverflow.ellipsis;
    _textPainter.layout(minWidth: minWidth, maxWidth: widthMatters ? maxWidth : double.infinity);
  }

  void _layoutTextWithConstraints(BoxConstraints constraints) {
    _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
  }

  // Layout the child inline widgets. We then pass the dimensions of the
  // children to _textPainter so that appropriate placeholders can be inserted
  // into the LibTxt layout. This does not do anything if no inline widgets were
  // specified.
  void _layoutChildren(BoxConstraints constraints) {
    RenderBox child = firstChild;
    List<PlaceholderDimensions> placeholderDimensions = List(childCount);
    int childIndex = 0;
    while (child != null) {
      // Set min constraints to 0, since the text min constraints don't apply
      // to the inline widgets.
      child.layout(
        BoxConstraints(
          minWidth: 0,
          minHeight: 0,
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight
        ),
        parentUsesSize: true
      );
      double baselineOffset;
      switch (_placeholderSpans[childIndex].alignment) {
        case ui.PlaceholderAlignment.baseline: {
          baselineOffset = child.getDistanceToBaseline(_placeholderSpans[childIndex].baseline);
          break;
        }
        default: {
          baselineOffset = null;
          break;
        }
      }
      placeholderDimensions[childIndex] = PlaceholderDimensions(
        size: child.size,
        alignment: _placeholderSpans[childIndex].alignment,
        baseline: _placeholderSpans[childIndex].baseline,
        baselineOffset: baselineOffset,
      );
      child = childAfter(child);
      childIndex += 1;
    }
    _textPainter.setPlaceholderDimensions(placeholderDimensions);
  }

  // Iterate through the laid-out children and set the parentData offsets based
  // off of the placeholders inserted for each child.
  void _setParentData() {
    RenderBox child = firstChild;
    int childIndex = 0;
    while (child != null) {
      final TextParentData textParentData = child.parentData;
      textParentData.offset = Offset(
        _textPainter.inlinePlaceholderBoxes[childIndex].left,
        _textPainter.inlinePlaceholderBoxes[childIndex].top
      );
      child = childAfter(child);
      childIndex += 1;
    }
  }

  @override
  void markNeedsLayout() {
    super.markNeedsLayout();
    _needsLayout = true;
  }

  @override
  void performLayout() {
    _layoutChildren(constraints);
    _layoutTextWithConstraints(constraints);
    _setParentData();

    _needsLayout = false;

    // We grab _textPainter.size and _textPainter.didExceedMaxLines here because
    // assigning to `size` will trigger us to validate our intrinsic sizes,
    // which will change _textPainter's layout because the intrinsic size
    // calculations are destructive. Other _textPainter state will also be
    // affected. See also RenderEditable which has a similar issue.
    final Size textSize = _textPainter.size;
    final bool textDidExceedMaxLines = _textPainter.didExceedMaxLines;
    size = constraints.constrain(textSize);

    final bool didOverflowHeight = size.height < textSize.height || textDidExceedMaxLines;
    final bool didOverflowWidth = size.width < textSize.width;
    // TODO(abarth): We're only measuring the sizes of the line boxes here. If
    // the glyphs draw outside the line boxes, we might think that there isn't
    // visual overflow when there actually is visual overflow. This can become
    // a problem if we start having horizontal overflow and introduce a clip
    // that affects the actual (but undetected) vertical overflow.
    final bool hasVisualOverflow = didOverflowWidth || didOverflowHeight;
    if (hasVisualOverflow) {
      switch (_overflow) {
        case TextOverflow.visible:
          _needsClipping = false;
          _overflowShader = null;
          break;
        case TextOverflow.clip:
        case TextOverflow.ellipsis:
          _needsClipping = true;
          _overflowShader = null;
          break;
        case TextOverflow.fade:
          assert(textDirection != null);
          _needsClipping = true;
          final TextPainter fadeSizePainter = TextPainter(
            text: TextSpan(style: _textPainter.text.style, text: '\u2026'),
            textDirection: textDirection,
            textScaleFactor: textScaleFactor,
            locale: locale,
          )..layout();
          if (didOverflowWidth) {
            double fadeEnd, fadeStart;
            switch (textDirection) {
              case TextDirection.rtl:
                fadeEnd = 0.0;
                fadeStart = fadeSizePainter.width;
                break;
              case TextDirection.ltr:
                fadeEnd = size.width;
                fadeStart = fadeEnd - fadeSizePainter.width;
                break;
            }
            _overflowShader = ui.Gradient.linear(
              Offset(fadeStart, 0.0),
              Offset(fadeEnd, 0.0),
              <Color>[const Color(0xFFFFFFFF), const Color(0x00FFFFFF)],
            );
          } else {
            final double fadeEnd = size.height;
            final double fadeStart = fadeEnd - fadeSizePainter.height / 2.0;
            _overflowShader = ui.Gradient.linear(
              Offset(0.0, fadeStart),
              Offset(0.0, fadeEnd),
              <Color>[const Color(0xFFFFFFFF), const Color(0x00FFFFFF)],
            );
          }
          break;
      }
    } else {
      _needsClipping = false;
      _overflowShader = null;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Ideally we could compute the min/max intrinsic width/height with a
    // non-destructive operation. However, currently, computing these values
    // will destroy state inside the painter. If that happens, we need to
    // get back the correct state by calling _layout again.
    //
    // TODO(abarth): Make computing the min/max intrinsic width/height
    // a non-destructive operation.
    //
    // If you remove this call, make sure that changing the textAlign still
    // works properly.
    _layoutTextWithConstraints(constraints);

    assert(() {
      if (debugRepaintTextRainbowEnabled) {
        final Paint paint = Paint()
          ..color = debugCurrentRepaintColor.toColor();
        context.canvas.drawRect(offset & size, paint);
      }
      return true;
    }());

    if (_needsClipping) {
      final Rect bounds = offset & size;
      if (_overflowShader != null) {
        // This layer limits what the shader below blends with to be just the text
        // (as opposed to the text and its background).
        context.canvas.saveLayer(bounds, Paint());
      } else {
        context.canvas.save();
      }
      context.canvas.clipRect(bounds);
    }
    _textPainter.paint(context.canvas, offset);

    RenderBox child = firstChild;
    int childIndex = 0;
    while (child != null) {
      assert(childIndex < _textPainter.inlinePlaceholderBoxes.length);
      TextParentData textParentData = child.parentData as TextParentData;
      context.paintChild(
        child,
        offset + textParentData.offset
      );
      child = childAfter(child);
      childIndex++;
    }
    if (_needsClipping) {
      if (_overflowShader != null) {
        context.canvas.translate(offset.dx, offset.dy);
        final Paint paint = Paint()
          ..blendMode = BlendMode.modulate
          ..shader = _overflowShader;
        context.canvas.drawRect(Offset.zero & size, paint);
      }
      context.canvas.restore();
    }
  }

  /// Returns the offset at which to paint the caret.
  ///
  /// Valid only after [layout].
  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype) {
    assert(!debugNeedsLayout);
    _layoutTextWithConstraints(constraints);
    return _textPainter.getOffsetForCaret(position, caretPrototype);
  }

  /// Returns a list of rects that bound the given selection.
  ///
  /// A given selection might have more than one rect if this text painter
  /// contains bidirectional text because logically contiguous text might not be
  /// visually contiguous.
  ///
  /// Valid only after [layout].
  List<ui.TextBox> getBoxesForSelection(TextSelection selection) {
    assert(!debugNeedsLayout);
    _layoutTextWithConstraints(constraints);
    return _textPainter.getBoxesForSelection(selection);
  }

  /// Returns the position within the text for the given pixel offset.
  ///
  /// Valid only after [layout].
  TextPosition getPositionForOffset(Offset offset) {
    assert(!debugNeedsLayout);
    _layoutTextWithConstraints(constraints);
    return _textPainter.getPositionForOffset(offset);
  }

  /// Returns the text range of the word at the given offset. Characters not
  /// part of a word, such as spaces, symbols, and punctuation, have word breaks
  /// on both sides. In such cases, this method will return a text range that
  /// contains the given text position.
  ///
  /// Word boundaries are defined more precisely in Unicode Standard Annex #29
  /// <http://www.unicode.org/reports/tr29/#Word_Boundaries>.
  ///
  /// Valid only after [layout].
  TextRange getWordBoundary(TextPosition position) {
    assert(!debugNeedsLayout);
    _layoutTextWithConstraints(constraints);
    return _textPainter.getWordBoundary(position);
  }

  /// Returns the size of the text as laid out.
  ///
  /// This can differ from [size] if the text overflowed or if the [constraints]
  /// provided by the parent [RenderObject] forced the layout to be bigger than
  /// necessary for the given [text].
  ///
  /// This returns the [TextPainter.size] of the underlying [TextPainter].
  ///
  /// Valid only after [layout].
  Size get textSize {
    assert(!debugNeedsLayout);
    return _textPainter.size;
  }

  // The byte offsets for each span that requires custom semantics.
  final List<int> _inlineSemanticsOffsets = <int>[];
  // Holds either [GestureRecognizer] or null (for placeholders) to generate
  // proper semnatics configurations.
  final List<dynamic> _inlineSemanticsElements = <dynamic>[];

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    _inlineSemanticsOffsets.clear();
    _inlineSemanticsElements.clear();
    int offset = 0;
    text.visitChildren((InlineSpan span) {
      if (span is TextSpan) {
        TextSpan textSpan = span as TextSpan;
        if (textSpan.recognizer != null && (textSpan.recognizer is TapGestureRecognizer || textSpan.recognizer is LongPressGestureRecognizer)) {
          final int length = textSpan.semanticsLabel?.length ?? textSpan.text.length;
          _inlineSemanticsOffsets.add(offset);
          _inlineSemanticsOffsets.add(offset + length);
          _inlineSemanticsElements.add(textSpan.recognizer);
        }
        offset += textSpan.text != null ? textSpan.text.length : 0;
      } else if (span is PlaceholderSpan) {
        // Add this to the list of inline elements that need custom semantics.
        _inlineSemanticsOffsets.add(offset);
        _inlineSemanticsOffsets.add(offset + 1);
        _inlineSemanticsElements.add(null); // null indicates this is a placeholder.
        offset += 1;
      }
      return true;
    });
    if (_inlineSemanticsOffsets.isNotEmpty) {
      config.explicitChildNodes = true;
      config.isSemanticBoundary = true;
    } else {
      config.label = text.toPlainText();
      config.textDirection = textDirection;
    }
  }

  @override
  void assembleSemanticsNode(SemanticsNode node, SemanticsConfiguration config, Iterable<SemanticsNode> children) {
    assert(_inlineSemanticsOffsets.isNotEmpty);
    assert(_inlineSemanticsOffsets.length.isEven);
    assert(_inlineSemanticsElements.isNotEmpty);
    final List<SemanticsNode> newChildren = <SemanticsNode>[];
    final String rawLabel = text.toPlainText();
    int current = 0;
    double order = -1.0;
    TextDirection currentDirection = textDirection;
    Rect currentRect;

    SemanticsConfiguration buildSemanticsConfig(int start, int end, { bool includeText = true }) {
      final TextDirection initialDirection = currentDirection;
      final TextSelection selection = TextSelection(baseOffset: start, extentOffset: end);
      final List<ui.TextBox> rects = getBoxesForSelection(selection);
      Rect rect;
      for (ui.TextBox textBox in rects) {
        rect ??= textBox.toRect();
        rect = rect.expandToInclude(textBox.toRect());
        currentDirection = textBox.direction;
      }
      // round the current rectangle to make this API testable and add some
      // padding so that the accessibility rects do not overlap with the text.
      // TODO(jonahwilliams): implement this for all text accessibility rects.
      currentRect = Rect.fromLTRB(
        rect.left.floorToDouble() - 4.0,
        rect.top.floorToDouble() - 4.0,
        rect.right.ceilToDouble() + 4.0,
        rect.bottom.ceilToDouble() + 4.0,
      );
      order += 1;
      SemanticsConfiguration configuration = SemanticsConfiguration()
        ..sortKey = OrdinalSortKey(order)
        ..textDirection = initialDirection;
      if (includeText) {
        configuration.label = rawLabel.substring(start, end);
      }
      return configuration;
    }

    int childIndex = 0;
    for (int i = 0, j = 0; i < _inlineSemanticsOffsets.length; i += 2, j++) {
      final int start = _inlineSemanticsOffsets[i];
      final int end = _inlineSemanticsOffsets[i + 1];
      // Add semantics for any text between the previous recognizer/widget and this one.
      if (current != start) {
        final SemanticsNode node = SemanticsNode();
        final SemanticsConfiguration configuration = buildSemanticsConfig(current, start);
        node.updateWith(config: configuration);
        node.rect = currentRect;
        newChildren.add(node);
      }
      final dynamic inlineElement = _inlineSemanticsElements[j];
      final SemanticsConfiguration configuration = buildSemanticsConfig(start, end, includeText: false);
      if (inlineElement != null) {
        // Add semantics for this recognizer.
        final SemanticsNode node = SemanticsNode();
        if (inlineElement is TapGestureRecognizer) {
          final TapGestureRecognizer recognizer = inlineElement as GestureRecognizer;
          configuration.onTap = recognizer.onTap;
        } else if (inlineElement is LongPressGestureRecognizer) {
          final LongPressGestureRecognizer recognizer = inlineElement as GestureRecognizer;
          configuration.onLongPress = recognizer.onLongPress;
        } else {
          assert(false);
        }
        node.updateWith(config: configuration);
        node.rect = currentRect;
        newChildren.add(node);
      } else if (childIndex < children.length) {
        // Add semantics for this placeholder. Semantics are precomputed in the children
        // argument.
        newChildren.add(children.elementAt(childIndex));
        childIndex += 1;
      }
      current = end;
    }
    if (current < rawLabel.length) {
      final SemanticsNode node = SemanticsNode();
      final SemanticsConfiguration configuration = buildSemanticsConfig(current, rawLabel.length);
      node.updateWith(config: configuration);
      node.rect = currentRect;
      newChildren.add(node);
    }
    node.updateWith(config: config, childrenInInversePaintOrder: newChildren);
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return <DiagnosticsNode>[text.toDiagnosticsNode(name: 'text', style: DiagnosticsTreeStyle.transition)];
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<TextAlign>('textAlign', textAlign));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection));
    properties.add(FlagProperty('softWrap', value: softWrap, ifTrue: 'wrapping at box width', ifFalse: 'no wrapping except at line break characters', showName: true));
    properties.add(EnumProperty<TextOverflow>('overflow', overflow));
    properties.add(DoubleProperty('textScaleFactor', textScaleFactor, defaultValue: 1.0));
    properties.add(DiagnosticsProperty<Locale>('locale', locale, defaultValue: null));
    properties.add(IntProperty('maxLines', maxLines, ifNull: 'unlimited'));
  }
}
