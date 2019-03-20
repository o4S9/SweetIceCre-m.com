// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

void main() {
  group(FocusNode, () {
    setUp((){
      // Reset the focus manager between tests, to avoid leaking state.
      WidgetsBinding.instance.focusManager.reset();
    });
    testWidgets('Can add children.', (WidgetTester tester) async {
      final FocusNode parent = FocusNode(context: null);
      final FocusNode child1 = FocusNode(context: null);
      final FocusNode child2 = FocusNode(context: null);
      tester.binding.focusManager.rootFocusable.reparent(parent);
      parent.reparent(child1);
      expect(child1.parent, equals(parent));
      expect(parent.children.first, equals(child1));
      expect(parent.children.last, equals(child1));
      parent.reparent(child2);
      expect(child1.parent, equals(parent));
      expect(child2.parent, equals(parent));
      expect(parent.children.first, equals(child1));
      expect(parent.children.last, equals(child2));
    });
    testWidgets('Can remove children.', (WidgetTester tester) async {
      final FocusNode parent = FocusNode(context: null);
      final FocusNode child1 = FocusNode(context: null);
      final FocusNode child2 = FocusNode(context: null);
      tester.binding.focusManager.rootFocusable.reparent(parent);
      parent.reparent(child1);
      parent.reparent(child2);
      expect(child1.parent, equals(parent));
      expect(child2.parent, equals(parent));
      expect(parent.children.first, equals(child1));
      expect(parent.children.last, equals(child2));
      parent.removeChild(child1);
      expect(child1.parent, isNull);
      expect(child2.parent, equals(parent));
      expect(parent.children.first, equals(child2));
      expect(parent.children.last, equals(child2));
      parent.removeChild(child2);
      expect(child1.parent, isNull);
      expect(child2.parent, isNull);
      expect(parent.children, isEmpty);
    });
    testWidgets('Removing a node removes it from scope.', (WidgetTester tester) async {
      final FocusScopeNode scope = FocusScopeNode(context: null);
      final FocusNode parent = FocusNode(context: null);
      final FocusNode child1 = FocusNode(context: null);
      final FocusNode child2 = FocusNode(context: null);
      tester.binding.focusManager.rootFocusable.reparent(scope);
      scope.reparent(parent);
      parent.reparent(child1);
      parent.reparent(child2);
      child1.requestFocus();
      await tester.pump();
      expect(scope.hasFocus, isTrue);
      expect(child1.hasFocus, isTrue);
      expect(child1.hasPrimaryFocus, isTrue);
      expect(scope.focusedChild, equals(child1));
      parent.removeChild(child1);
      expect(scope.hasFocus, isFalse);
      expect(scope.focusedChild, isNull);
    });
    testWidgets('Can add children to scope and focus', (WidgetTester tester) async {
      final FocusScopeNode scope = FocusScopeNode(context: null);
      final FocusNode parent = FocusNode(context: null);
      final FocusNode child1 = FocusNode(context: null);
      final FocusNode child2 = FocusNode(context: null);
      tester.binding.focusManager.rootFocusable.reparent(scope);
      scope.reparent(parent);
      parent.reparent(child1);
      parent.reparent(child2);
      expect(scope.isScope, isTrue);
      expect(scope.children.first, equals(parent));
      expect(parent.parent, equals(scope));
      expect(child1.parent, equals(parent));
      expect(child2.parent, equals(parent));
      expect(parent.children.first, equals(child1));
      expect(parent.children.last, equals(child2));
      child1.requestFocus();
      await tester.pump();
      expect(scope.focusedChild, equals(child1));
      expect(parent.hasFocus, isTrue);
      expect(parent.hasPrimaryFocus, isFalse);
      expect(child1.hasFocus, isTrue);
      expect(child1.hasPrimaryFocus, isTrue);
      expect(child2.hasFocus, isFalse);
      expect(child2.hasPrimaryFocus, isFalse);
      child2.requestFocus();
      await tester.pump();
      expect(scope.focusedChild, equals(child2));
      expect(parent.hasFocus, isTrue);
      expect(parent.hasPrimaryFocus, isFalse);
      expect(child1.hasFocus, isFalse);
      expect(child1.hasPrimaryFocus, isFalse);
      expect(child2.hasFocus, isTrue);
      expect(child2.hasPrimaryFocus, isTrue);
    });
    testWidgets('Autofocus works.', (WidgetTester tester) async {
      final FocusScopeNode scope = FocusScopeNode(context: null);
      final FocusNode parent = FocusNode(context: null);
      final FocusNode child1 = FocusNode(context: null);
      final FocusNode child2 = FocusNode(context: null, autofocus: true);
      tester.binding.focusManager.rootFocusable.reparent(scope);
      scope.reparent(parent);
      parent.reparent(child1);
      parent.reparent(child2);

      await tester.pump();

      expect(scope.focusedChild, equals(child2));
      expect(parent.hasFocus, isTrue);
      expect(child1.hasFocus, isFalse);
      expect(child1.hasPrimaryFocus, isFalse);
      expect(child2.hasFocus, isTrue);
      expect(child2.hasPrimaryFocus, isTrue);
      child1.requestFocus();

      await tester.pump();

      expect(scope.focusedChild, equals(child1));
      expect(parent.hasFocus, isTrue);
      expect(child1.hasFocus, isTrue);
      expect(child1.hasPrimaryFocus, isTrue);
      expect(child2.hasFocus, isFalse);
      expect(child2.hasPrimaryFocus, isFalse);
    });
    testWidgets('Adding a focusedChild to a scope sets scope as focusedChild in parent scope', (WidgetTester tester) async {
      final FocusScopeNode scope1 = FocusScopeNode(context: null);
      final FocusScopeNode scope2 = FocusScopeNode(context: null);
      final FocusNode child1 = FocusNode(context: null);
      final FocusNode child2 = FocusNode(context: null);
      tester.binding.focusManager.rootFocusable.reparent(scope1);
      scope1.reparent(scope2);
      scope1.reparent(child1);
      scope2.reparent(child2);
      child2.requestFocus();
      await tester.pump();
      expect(scope2.focusedChild, equals(child2));
      expect(scope1.focusedChild, equals(scope2));
      expect(child1.hasFocus, isFalse);
      expect(child1.hasPrimaryFocus, isFalse);
      expect(child2.hasFocus, isTrue);
      expect(child2.hasPrimaryFocus, isTrue);
      child1.requestFocus();
      await tester.pump();
      expect(scope2.focusedChild, equals(child2));
      expect(scope1.focusedChild, equals(child1));
      expect(child1.hasFocus, isTrue);
      expect(child1.hasPrimaryFocus, isTrue);
      expect(child2.hasFocus, isFalse);
      expect(child2.hasPrimaryFocus, isFalse);
    });
    testWidgets('Can move node with focus without losing focus', (WidgetTester tester) async {
      final FocusScopeNode scope = FocusScopeNode(context: null);
      final FocusNode parent1 = FocusNode(context: null);
      final FocusNode parent2 = FocusNode(context: null);
      final FocusNode child1 = FocusNode(context: null);
      final FocusNode child2 = FocusNode(context: null);
      tester.binding.focusManager.rootFocusable.reparent(scope);
      scope.reparent(parent1);
      scope.reparent(parent2);
      parent1.reparent(child1);
      parent1.reparent(child2);
      expect(scope.isScope, isTrue);
      expect(scope.children.first, equals(parent1));
      expect(scope.children.last, equals(parent2));
      expect(parent1.parent, equals(scope));
      expect(parent2.parent, equals(scope));
      expect(child1.parent, equals(parent1));
      expect(child2.parent, equals(parent1));
      expect(parent1.children.first, equals(child1));
      expect(parent1.children.last, equals(child2));
      child1.requestFocus();
      parent2.reparent(child1);
      await tester.pump();
      expect(scope.focusedChild, equals(child1));
      expect(child1.parent, equals(parent2));
      expect(child2.parent, equals(parent1));
      expect(parent1.children.first, equals(child2));
      expect(parent2.children.first, equals(child1));
    });
    testWidgets('Can move node between scopes and lose scope focus', (WidgetTester tester) async {
      final FocusScopeNode scope1 = FocusScopeNode(context: null);
      final FocusScopeNode scope2 = FocusScopeNode(context: null);
      final FocusNode parent1 = FocusNode(context: null);
      final FocusNode parent2 = FocusNode(context: null);
      final FocusNode child1 = FocusNode(context: null);
      final FocusNode child2 = FocusNode(context: null);
      final FocusNode child3 = FocusNode(context: null);
      final FocusNode child4 = FocusNode(context: null);
      tester.binding.focusManager.rootFocusable.reparent(scope1);
      tester.binding.focusManager.rootFocusable.reparent(scope2);
      scope1.reparent(parent1);
      scope2.reparent(parent2);
      parent1.reparent(child1);
      parent1.reparent(child2);
      parent2.reparent(child3);
      parent2.reparent(child4);

      child1.requestFocus();
      await tester.pump();
      expect(scope1.focusedChild, equals(child1));
      expect(parent2.children.contains(child1), isFalse);

      parent2.reparent(child1);
      await tester.pump();
      expect(scope1.focusedChild, isNull);
      expect(parent2.children.contains(child1), isTrue);
    });
    testWidgets('Can move focus between scopes and keep focus', (WidgetTester tester) async {
      final FocusScopeNode scope1 = FocusScopeNode(context: null);
      final FocusScopeNode scope2 = FocusScopeNode(context: null);
      final FocusNode parent1 = FocusNode(context: null);
      final FocusNode parent2 = FocusNode(context: null);
      final FocusNode child1 = FocusNode(context: null);
      final FocusNode child2 = FocusNode(context: null);
      final FocusNode child3 = FocusNode(context: null);
      final FocusNode child4 = FocusNode(context: null);
      tester.binding.focusManager.rootFocusable.reparent(scope1);
      tester.binding.focusManager.rootFocusable.reparent(scope2);
      scope1.reparent(parent1);
      scope2.reparent(parent2);
      parent1.reparent(child1);
      parent1.reparent(child2);
      parent2.reparent(child3);
      parent2.reparent(child4);
      child4.requestFocus();
      await tester.pump();
      child1.requestFocus();
      await tester.pump();
      expect(child4.hasFocus, isFalse);
      expect(child4.hasPrimaryFocus, isFalse);
      expect(child1.hasFocus, isTrue);
      expect(child1.hasPrimaryFocus, isTrue);
      expect(scope1.hasFocus, isTrue);
      expect(scope1.hasPrimaryFocus, isFalse);
      expect(scope2.hasFocus, isFalse);
      expect(scope2.hasPrimaryFocus, isFalse);
      expect(parent1.hasFocus, isTrue);
      expect(parent2.hasFocus, isFalse);
      expect(scope1.focusedChild, equals(child1));
      expect(scope2.focusedChild, equals(child4));
      scope2.requestFocus();
      await tester.pump();
      expect(child4.hasFocus, isTrue);
      expect(child4.hasPrimaryFocus, isTrue);
      expect(child1.hasFocus, isFalse);
      expect(child1.hasPrimaryFocus, isFalse);
      expect(scope1.hasFocus, isFalse);
      expect(scope1.hasPrimaryFocus, isFalse);
      expect(scope2.hasFocus, isTrue);
      expect(scope2.hasPrimaryFocus, isFalse);
      expect(parent1.hasFocus, isFalse);
      expect(parent2.hasFocus, isTrue);
      expect(scope1.focusedChild, equals(child1));
      expect(scope2.focusedChild, equals(child4));
    });
  });
}
