import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_standards.dart';

void main() {
  group('StandardsChecker Unit Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('standards_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    File createTempDartFile(String relativePath, String content) {
      final file = File('${tempDir.path}/$relativePath');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
      return file;
    }

    test('flags banned postfix null assertion outside !.', () {
      final file = createTempDartFile('lib/sample.dart', '''
void run(int? value) {
  final res = value!;
  print(res);
}
''');

      final checker = StandardsChecker(libFiles: [file.path], newTestFiles: []);

      final violations = checker.run();
      check(violations.length).equals(1);
      check(violations.first.rule).equals('no-null-assertion');
      check(violations.first.line).equals(2);
    });

    test(
      'permits null-assertion navigation followed immediately by dot (!.)',
      () {
        final file = createTempDartFile('lib/sample.dart', '''
class Item { final int id = 1; }
void run(Item? item) {
  final id = item!.id;
  print(id);
}
''');

        final checker = StandardsChecker(
          libFiles: [file.path],
          newTestFiles: [],
        );

        final violations = checker.run();
        check(violations).isEmpty();
      },
    );

    test(
      'skips generated *.g.dart and *.freezed.dart files for lib standards',
      () {
        final fileG = createTempDartFile('lib/sample.g.dart', '''
void run(int? value) {
  final res = value!;
}
''');
        final fileFreezed = createTempDartFile('lib/sample.freezed.dart', '''
void run(int? value) {
  final res = value!;
}
''');

        final checker = StandardsChecker(
          libFiles: [fileG.path, fileFreezed.path],
          newTestFiles: [],
        );

        final violations = checker.run();
        check(violations).isEmpty();
      },
    );

    test('flags methods and functions exceeding 50 lines', () {
      final buffer = StringBuffer()..writeln('void longFunction() {');
      for (int i = 0; i < 52; i++) {
        buffer.writeln('  final a$i = $i;');
      }
      buffer.writeln('}');

      final file = createTempDartFile('lib/sample.dart', buffer.toString());

      final checker = StandardsChecker(libFiles: [file.path], newTestFiles: []);

      final violations = checker.run();
      check(violations.length).equals(1);
      check(violations.first.rule).equals('function-max-50-lines');
    });

    test('passes methods and functions within 50 lines', () {
      final buffer = StringBuffer()..writeln('void shortFunction() {');
      for (int i = 0; i < 40; i++) {
        buffer.writeln('  final a$i = $i;');
      }
      buffer.writeln('}');

      final file = createTempDartFile('lib/sample.dart', buffer.toString());

      final checker = StandardsChecker(libFiles: [file.path], newTestFiles: []);

      final violations = checker.run();
      check(violations).isEmpty();
    });

    test('flags expect() value assertions in new test files', () {
      final file = createTempDartFile(
        'test/presentation/screens/new_screen_test.dart',
        '''
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('value test', () {
    expect(1 + 1, 2);
    expect(true, isTrue);
  });
}
''',
      );

      final checker = StandardsChecker(libFiles: [], newTestFiles: [file.path]);

      final violations = checker.run();
      check(violations.length).equals(2);
      check(violations[0].rule).equals('package-checks-in-tests');
      check(violations[1].rule).equals('package-checks-in-tests');
    });

    test(
      'permits widget finder matchers (findsOneWidget, etc.) in test files',
      () {
        final file = createTempDartFile(
          'test/presentation/screens/new_screen_test.dart',
          '''
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('widget test', (tester) async {
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('absent'), findsNothing);
    expect(find.byType(Container), findsWidgets);
  });
}
''',
        );

        final checker = StandardsChecker(
          libFiles: [],
          newTestFiles: [file.path],
        );

        final violations = checker.run();
        check(violations).isEmpty();
      },
    );
  });
}
