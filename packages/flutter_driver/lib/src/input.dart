// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'message.dart';
import 'find.dart';

/// Sets [text] in a text input widget.
class SetInputText extends CommandWithTarget {
  @override
  final String kind = 'setInputText';

  /// Creates a command.
  ///
  /// [finder] identifies the text input widget. [text] is the string that is
  /// set as the value of the text input.
  SetInputText(SerializableFinder finder, this.text) : super(finder);

  /// The value of the text input to set.
  final String text;

  /// Deserializes this command from JSON generated by [serialize].
  SetInputText.deserialize(Map<String, String> json)
      : this.text = json['text'],
        super.deserialize(json);

  @override
  Map<String, String> serialize() {
    Map<String, String> json = super.serialize();
    json['text'] = text;
    return json;
  }
}

/// The result of a [SetInputText] command.
class SetInputTextResult extends Result {
  /// Deserializes this result from JSON.
  static SetInputTextResult fromJson(Map<String, dynamic> json) {
    return new SetInputTextResult();
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{};
}

/// Submits text entered in a text input widget.
///
/// The definition of submitting input text can be found
/// [here](https://docs.flutter.io/flutter/material/Input/onSubmitted.html).
class SubmitInputText extends CommandWithTarget {
  @override
  final String kind = 'submitInputText';

  /// Create a command that submits text on input widget identified by [finder].
  SubmitInputText(SerializableFinder finder) : super(finder);

  /// Deserializes this command from JSON generated by [serialize].
  SubmitInputText.deserialize(Map<String, String> json)
      : super.deserialize(json);
}

/// The result of a [SubmitInputText] command.
class SubmitInputTextResult extends Result {
  /// Creates a result with [text] as the submitted value.
  SubmitInputTextResult(this.text);

  /// The submitted value.
  final String text;

  /// Deserializes this result from JSON.
  static SubmitInputTextResult fromJson(Map<String, dynamic> json) {
    return new SubmitInputTextResult(json['text']);
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'text': text
  };
}
