// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:gen_defaults/template.dart';
import 'package:gen_defaults/token_logger.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  final TokenLogger logger = tokenLogger;
  logger.init(
      allTokens: <String, dynamic>{}, versionMap: <String, List<String>>{});

  test('Templates will append to the end of a file', () {
    final Directory tempDir =
        Directory.systemTemp.createTempSync('gen_defaults');
    try {
      // Create a temporary file with some content.
      final File tempFile = File(path.join(tempDir.path, 'test_template.txt'));
      tempFile.createSync();
      tempFile.writeAsStringSync('''
// This is a file with stuff in it.
// This part shouldn't be changed by
// the template.
''');

      // Have a test template append new parameterized content to the end of
      // the file.
      final Map<String, dynamic> tokens = <String, dynamic>{
        'version': '0.0',
        'foo': 'Foobar',
        'bar': 'Barfoo'
      };
      TestTemplate('Test', tempFile.path, tokens).updateFile();

      expect(tempFile.readAsStringSync(), '''
// This is a file with stuff in it.
// This part shouldn't be changed by
// the template.

// BEGIN GENERATED TOKEN PROPERTIES - Test

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

static final String tokenFoo = 'Foobar';
static final String tokenBar = 'Barfoo';

// END GENERATED TOKEN PROPERTIES - Test
''');
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
      'Templates will update over previously generated code at the end of a file',
      () {
    final Directory tempDir =
        Directory.systemTemp.createTempSync('gen_defaults');
    try {
      // Create a temporary file with some content.
      final File tempFile = File(path.join(tempDir.path, 'test_template.txt'));
      tempFile.createSync();
      tempFile.writeAsStringSync('''
// This is a file with stuff in it.
// This part shouldn't be changed by
// the template.

// BEGIN GENERATED TOKEN PROPERTIES - Test

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

static final String tokenFoo = 'Foobar';
static final String tokenBar = 'Barfoo';

// END GENERATED TOKEN PROPERTIES - Test
''');

      // Have a test template append new parameterized content to the end of
      // the file.
      final Map<String, dynamic> tokens = <String, dynamic>{
        'version': '0.0',
        'foo': 'foo',
        'bar': 'bar'
      };
      TestTemplate('Test', tempFile.path, tokens).updateFile();

      expect(tempFile.readAsStringSync(), '''
// This is a file with stuff in it.
// This part shouldn't be changed by
// the template.

// BEGIN GENERATED TOKEN PROPERTIES - Test

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

static final String tokenFoo = 'foo';
static final String tokenBar = 'bar';

// END GENERATED TOKEN PROPERTIES - Test
''');
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Multiple templates can modify different code blocks in the same file',
      () {
    final Directory tempDir =
        Directory.systemTemp.createTempSync('gen_defaults');
    try {
      // Create a temporary file with some content.
      final File tempFile = File(path.join(tempDir.path, 'test_template.txt'));
      tempFile.createSync();
      tempFile.writeAsStringSync('''
// This is a file with stuff in it.
// This part shouldn't be changed by
// the template.
''');

      // Update file with a template for 'Block 1'
      {
        final Map<String, dynamic> tokens = <String, dynamic>{
          'version': '0.0',
          'foo': 'foo',
          'bar': 'bar'
        };
        TestTemplate('Block 1', tempFile.path, tokens).updateFile();
      }
      expect(tempFile.readAsStringSync(), '''
// This is a file with stuff in it.
// This part shouldn't be changed by
// the template.

// BEGIN GENERATED TOKEN PROPERTIES - Block 1

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

static final String tokenFoo = 'foo';
static final String tokenBar = 'bar';

// END GENERATED TOKEN PROPERTIES - Block 1
''');

      // Update file with a template for 'Block 2', which should append but not
      // disturb the code in 'Block 1'.
      {
        final Map<String, dynamic> tokens = <String, dynamic>{
          'version': '0.0',
          'foo': 'bar',
          'bar': 'foo'
        };
        TestTemplate('Block 2', tempFile.path, tokens).updateFile();
      }
      expect(tempFile.readAsStringSync(), '''
// This is a file with stuff in it.
// This part shouldn't be changed by
// the template.

// BEGIN GENERATED TOKEN PROPERTIES - Block 1

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

static final String tokenFoo = 'foo';
static final String tokenBar = 'bar';

// END GENERATED TOKEN PROPERTIES - Block 1

// BEGIN GENERATED TOKEN PROPERTIES - Block 2

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

static final String tokenFoo = 'bar';
static final String tokenBar = 'foo';

// END GENERATED TOKEN PROPERTIES - Block 2
''');

      // Update 'Block 1' again which should just update that block,
      // leaving 'Block 2' undisturbed.
      {
        final Map<String, dynamic> tokens = <String, dynamic>{
          'version': '0.0',
          'foo': 'FOO',
          'bar': 'BAR'
        };
        TestTemplate('Block 1', tempFile.path, tokens).updateFile();
      }
      expect(tempFile.readAsStringSync(), '''
// This is a file with stuff in it.
// This part shouldn't be changed by
// the template.

// BEGIN GENERATED TOKEN PROPERTIES - Block 1

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

static final String tokenFoo = 'FOO';
static final String tokenBar = 'BAR';

// END GENERATED TOKEN PROPERTIES - Block 1

// BEGIN GENERATED TOKEN PROPERTIES - Block 2

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

static final String tokenFoo = 'bar';
static final String tokenBar = 'foo';

// END GENERATED TOKEN PROPERTIES - Block 2
''');
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Templates can get proper shapes from given data', () {
    const Map<String, dynamic> tokens = <String, dynamic>{
      'foo.shape': 'shape.large',
      'bar.shape': 'shape.full',
      'shape.large': <String, dynamic>{
        'family': 'SHAPE_FAMILY_ROUNDED_CORNERS',
        'topLeft': 1.0,
        'topRight': 2.0,
        'bottomLeft': 3.0,
        'bottomRight': 4.0,
      },
      'shape.full': <String, dynamic>{
        'family': 'SHAPE_FAMILY_CIRCULAR',
      },
    };
    final TestTemplate template = TestTemplate('Test', 'foobar.dart', tokens);
    expect(template.shape('foo'),
        'const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(1.0), topRight: Radius.circular(2.0), bottomLeft: Radius.circular(3.0), bottomRight: Radius.circular(4.0)))');
    expect(template.shape('bar'), 'const StadiumBorder()');
  });

  group('Tokens logger', () {
    final List<String> printLog = List<String>.empty(growable: true);
    final Map<String, List<String>> versionMap = <String, List<String>>{};
    final Map<String, dynamic> allTokens = <String, dynamic>{};

    // Add to printLog instead of printing to stdout
    void Function() overridePrint(void Function() testFn) => () {
          final ZoneSpecification spec =
              ZoneSpecification(print: (_, __, ___, String msg) {
            printLog.add(msg);
          });
          return Zone.current.fork(specification: spec).run<void>(testFn);
        };

    setUp(() {
      logger.init(allTokens: allTokens, versionMap: versionMap);
    });

    tearDown(() {
      logger.clear();
      printLog.clear();
      versionMap.clear();
      allTokens.clear();
    });

    String errorColoredString(String str) => '\x1B[31m$str\x1B[0m';

    const Map<String, List<String>> testVersions = <String, List<String>>{
      'v1.0.0': <String>['file_1.json'],
      'v2.0.0': <String>['file_2.json, file_3.json'],
    };

    test('can print empty usage', overridePrint(() {
      logger.printVersionUsage(verbose: true);
      expect(printLog, contains('Versions used: '));

      logger.printTokensUsage(verbose: true);
      expect(printLog, contains('Tokens used: 0/0'));
    }));

    test('can print version usage', overridePrint(() {
      versionMap.addAll(testVersions);

      logger.printVersionUsage(verbose: false);

      expect(printLog, contains('Versions used: v1.0.0, v2.0.0'));
    }));

    test('can print version usage (verbose)', overridePrint(() {
      versionMap.addAll(testVersions);

      logger.printVersionUsage(verbose: true);

      expect(printLog, contains('Versions used: v1.0.0, v2.0.0'));
      expect(printLog, contains('  v1.0.0:'));
      expect(printLog, contains('    file_1.json'));
      expect(printLog, contains('  v2.0.0:'));
      expect(printLog, contains('    file_2.json, file_3.json'));
    }));

    test('can log and print tokens usage', overridePrint(() {
      allTokens['foo'] = 'value';

      logger.log('foo');
      logger.printTokensUsage(verbose: false);

      expect(printLog, contains('Tokens used: 1/1'));
    }));

    test('can log and print tokens usage (verbose)', overridePrint(() {
      allTokens['foo'] = 'value';

      logger.log('foo');
      logger.printTokensUsage(verbose: true);

      expect(printLog, contains('✅ foo'));
      expect(printLog, contains('Tokens used: 1/1'));
    }));

    test('detects invalid logs', overridePrint(() {
      allTokens['foo'] = 'value';

      logger.log('baz');
      logger.log('foobar');
      logger.printTokensUsage(verbose: true);

      expect(printLog, contains(errorColoredString('Token unavailable: baz')));
      expect(
          printLog, contains(errorColoredString('Token unavailable: foobar')));
      expect(printLog, contains('❌ foo'));
      expect(printLog, contains('Tokens used: 0/1'));
    }));

    test('can log and dump versions & tokens to a file', overridePrint(() {
      versionMap.addAll(testVersions);
      allTokens['foo'] = 'value';
      allTokens['bar'] = 'value';

      logger.log('foo');
      logger.log('bar');
      logger.dumpToFile('test.json');

      final String fileContent = File('test.json').readAsStringSync();
      expect(fileContent, contains('Versions used, v1.0.0, v2.0.0'));
      expect(fileContent, contains('bar,'));
      expect(fileContent, contains('foo'));
    }));

    test('integration test', overridePrint(() {
      allTokens['foo'] = 'value';
      allTokens['bar'] = 'value';

      TestTemplate('block', 'filename', allTokens).generate();
      logger.printTokensUsage(verbose: true);

      expect(printLog, contains('✅ foo'));
      expect(printLog, contains('✅ bar'));
      expect(printLog, contains('Tokens used: 2/2'));
    }));
  });
}

class TestTemplate extends TokenTemplate {
  TestTemplate(super.blockName, super.fileName, super.tokens);

  @override
  String generate() => '''
static final String tokenFoo = '${getToken('foo')}';
static final String tokenBar = '${getToken('bar')}';
''';
}
