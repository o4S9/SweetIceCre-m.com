// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show hashValues, TextAffinity, TextPosition, TextRange;

import 'package:flutter/foundation.dart';

export 'dart:ui' show TextAffinity, TextPosition, TextRange;

/// A range of text that represents a selection.
@immutable
class TextSelection extends TextRange {
  /// Creates a text selection.
  ///
  /// The [baseOffset] and [extentOffset] arguments must not be null.
  const TextSelection({
    required this.baseOffset,
    required this.extentOffset,
    this.affinity = TextAffinity.downstream,
    this.isDirectional = false,
  }) : super(
         start: baseOffset < extentOffset ? baseOffset : extentOffset,
         end: baseOffset < extentOffset ? extentOffset : baseOffset,
       );

  /// Creates a collapsed selection at the given offset.
  ///
  /// A collapsed selection starts and ends at the same offset, which means it
  /// contains zero characters but instead serves as an insertion point in the
  /// text.
  ///
  /// The [offset] argument must not be null.
  const TextSelection.collapsed({
    required int offset,
    this.affinity = TextAffinity.downstream,
  }) : baseOffset = offset,
       extentOffset = offset,
       isDirectional = false,
       super.collapsed(offset);

  /// Creates a collapsed selection at the given text position.
  ///
  /// A collapsed selection starts and ends at the same offset, which means it
  /// contains zero characters but instead serves as an insertion point in the
  /// text.
  TextSelection.fromPosition(TextPosition position)
    : baseOffset = position.offset,
      extentOffset = position.offset,
      affinity = position.affinity,
      isDirectional = false,
      super.collapsed(position.offset);

  /// The offset at which the selection originates.
  ///
  /// Might be larger than, smaller than, or equal to extent.
  final int baseOffset;

  /// The offset at which the selection terminates.
  ///
  /// When the user uses the arrow keys to adjust the selection, this is the
  /// value that changes. Similarly, if the current theme paints a caret on one
  /// side of the selection, this is the location at which to paint the caret.
  ///
  /// Might be larger than, smaller than, or equal to base.
  final int extentOffset;

  /// If the text range is collapsed and has more than one visual location
  /// (e.g., occurs at a line break), which of the two locations to use when
  /// painting the caret.
  final TextAffinity affinity;

  /// Whether this selection has disambiguated its base and extent.
  ///
  /// On some platforms, the base and extent are not disambiguated until the
  /// first time the user adjusts the selection. At that point, either the start
  /// or the end of the selection becomes the base and the other one becomes the
  /// extent and is adjusted.
  final bool isDirectional;

  /// The position at which the selection originates.
  ///
  /// {@template flutter.services.TextSelection.TextAffinity}
  /// The [TextAffinity] of the resulting [TextPosition] is based on the
  /// relative logical position in the text to the other selection endpoint:
  ///  * if [baseOffset] < [extentOffset], [base] will have
  ///    [TextAffinity.downstream] and [extent] will have
  ///    [TextAffinity.upstream].
  ///  * if [baseOffset] > [extentOffset], [base] will have
  ///    [TextAffinity.upstream] and [extent] will have
  ///    [TextAffinity.downstream].
  ///  * if [baseOffset] == [extentOffset], [base] and [extent] will both have
  ///    the collapsed selection's [affinity].
  /// {@endtemplate}
  ///
  /// Might be larger than, smaller than, or equal to extent.
  TextPosition get base {
    final TextAffinity affinity;
    if (!isValid || baseOffset == extentOffset) {
      affinity = this.affinity;
    } else if (baseOffset < extentOffset) {
      affinity = TextAffinity.downstream;
    } else {
      affinity = TextAffinity.upstream;
    }
    return TextPosition(offset: baseOffset, affinity: affinity);
  }

  /// The position at which the selection terminates.
  ///
  /// When the user uses the arrow keys to adjust the selection, this is the
  /// value that changes. Similarly, if the current theme paints a caret on one
  /// side of the selection, this is the location at which to paint the caret.
  ///
  /// {@macro flutter.services.TextSelection.TextAffinity}
  ///
  /// Might be larger than, smaller than, or equal to base.
  TextPosition get extent {
    final TextAffinity affinity;
    if (!isValid || baseOffset == extentOffset) {
      affinity = this.affinity;
    } else if (baseOffset < extentOffset) {
      affinity = TextAffinity.upstream;
    } else {
      affinity = TextAffinity.downstream;
    }
    return TextPosition(offset: extentOffset, affinity: affinity);
  }

  @override
  String toString() {
    final String typeName = objectRuntimeType(this, 'TextSelection');
    if (!isValid) {
      return '$typeName.invalid';
    }
    return isCollapsed
      ? '$typeName.collapsed(offset: $baseOffset, affinity: $affinity, isDirectional: $isDirectional)'
      : '$typeName(baseOffset: $baseOffset, extentOffset: $extentOffset, isDirectional: $isDirectional)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other))
      return true;
    if (other is! TextSelection)
      return false;
    if (!isValid) {
      return !other.isValid;
    }
    return other.baseOffset == baseOffset
        && other.extentOffset == extentOffset
        && (!isCollapsed || other.affinity == affinity)
        && other.isDirectional == isDirectional;
  }

  @override
  int get hashCode {
    if (!isValid) {
      return hashValues(-1.hashCode, -1.hashCode, TextAffinity.downstream.hashCode);
    }

    final int affinityHash = isCollapsed ? affinity.hashCode : TextAffinity.downstream.hashCode;
    return hashValues(baseOffset.hashCode, extentOffset.hashCode, affinityHash, isDirectional.hashCode);
  }


  /// Creates a new [TextSelection] based on the current selection, with the
  /// provided parameters overridden.
  TextSelection copyWith({
    int? baseOffset,
    int? extentOffset,
    TextAffinity? affinity,
    bool? isDirectional,
  }) {
    return TextSelection(
      baseOffset: baseOffset ?? this.baseOffset,
      extentOffset: extentOffset ?? this.extentOffset,
      affinity: affinity ?? this.affinity,
      isDirectional: isDirectional ?? this.isDirectional,
    );
  }

  /// Returns the smallest [TextSelection] that this could expand to in order to
  /// include the given [TextPosition].
  ///
  /// If the given [TextPosition] is already inside of the selection, then
  /// returns `this` without change.
  ///
  /// The returned selection will always be a strict superset of the current
  /// selection. In other words, the selection grows to include the given
  /// [TextPosition].
  ///
  /// If extentAtIndex is true, then the [TextSelection.extentOffset] will be
  /// placed at the given index regardless of the original order of it and
  /// [TextSelection.baseOffset]. Otherwise, their order will be preserved.
  ///
  /// ## Difference with [extendTo]
  /// In contrast with this method, [extendTo] is a pivot; it holds
  /// [TextSelection.baseOffset] fixed while moving [TextSelection.extentOffset]
  /// to the given [TextPosition].  It doesn't strictly grow the selection and
  /// may collapse it or flip its order.
  TextSelection expandTo(TextPosition position, [bool extentAtIndex = false]) {
    // If position is already within in the selection, there's nothing to do.
    if (position.offset >= start && position.offset <= end) {
      return this;
    }

    final bool normalized = baseOffset <= extentOffset;
    if (position.offset <= start) {
      // Here the position is somewhere before the selection: ..|..[...]....
      if (extentAtIndex) {
        return copyWith(
          baseOffset: end,
          extentOffset: position.offset,
          affinity: position.affinity,
        );
      }
      return copyWith(
        baseOffset: normalized ? position.offset : baseOffset,
        extentOffset: normalized ? extentOffset : position.offset,
      );
    }
    // Here the position is somewhere after the selection: ....[...]..|..
    if (extentAtIndex) {
      return copyWith(
        baseOffset: start,
        extentOffset: position.offset,
        affinity: position.affinity,
      );
    }
    return copyWith(
      baseOffset: normalized ? baseOffset : position.offset,
      extentOffset: normalized ? position.offset : extentOffset,
    );
  }

  /// Keeping the selection's [TextSelection.baseOffset] fixed, pivot the
  /// [TextSelection.extentOffset] to the given [TextPosition].
  ///
  /// In some cases, the [TextSelection.baseOffset] and
  /// [TextSelection.extentOffset] may flip during this operation, or the size
  /// of the selection may shrink.
  ///
  /// ## Difference with [expandTo]
  /// In contrast with this method, [expandTo] is strictly growth; the
  /// selection is grown to include the given [TextPosition] and will never
  /// shrink.
  TextSelection extendTo(TextPosition position) {
    // If the selection's extent is at the position already, then nothing
    // happens.
    if (extent == position) {
      return this;
    }

    return copyWith(
      extentOffset: position.offset,
      affinity: position.affinity,
    );
  }
}


/// An abstract class representing a particular configuration of an [Action].
///
/// This class is what the [Shortcuts.shortcuts] map has as values, and is used
/// by an [ActionDispatcher] to look up an action and invoke it, giving it this
/// object to extract configuration information from.
///
/// See also:
///
///  * [Actions.invoke], which invokes the action associated with a specified
///    [Intent] using the [Actions] widget that most tightly encloses the given
///    [BuildContext].
@immutable
abstract class Intent with Diagnosticable {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const Intent();

  /// An intent that is mapped to a [DoNothingAction], which, as the name
  /// implies, does nothing.
  ///
  /// This Intent is mapped to an action in the [WidgetsApp] that does nothing,
  /// so that it can be bound to a key in a [Shortcuts] widget in order to
  /// disable a key binding made above it in the hierarchy.
  static const DoNothingIntent doNothing = DoNothingIntent._();
}

/// An [Intent], that is bound to a [DoNothingAction].
///
/// Attaching a [DoNothingIntent] to a [Shortcuts] mapping is one way to disable
/// a keyboard shortcut defined by a widget higher in the widget hierarchy and
/// consume any key event that triggers it via a shortcut.
///
/// This intent cannot be subclassed.
///
/// See also:
///
///  * [DoNothingAndStopPropagationIntent], a similar intent that will not
///    handle the key event, but will still keep it from being passed to other key
///    handlers in the focus chain.
class DoNothingIntent extends Intent {
  /// Creates a const [DoNothingIntent].
  factory DoNothingIntent() => const DoNothingIntent._();

  // Make DoNothingIntent constructor private so it can't be subclassed.
  const DoNothingIntent._();
}
