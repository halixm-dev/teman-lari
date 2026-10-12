import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Represents a single coding standard violation.
class StandardViolation {
  final String filePath;
  final int line;
  final int column;
  final String rule;
  final String message;
  final String codeSnippet;

  const StandardViolation({
    required this.filePath,
    required this.line,
    required this.column,
    required this.rule,
    required this.message,
    required this.codeSnippet,
  });

  @override
  String toString() {
    return '[$rule] $filePath:$line:$column\n'
        '  $message\n'
        '  Code: $codeSnippet';
  }
}

/// Visitor that enforces standards in `lib/`:
/// 1. NO `!` null-assertion operator outside `!.` navigation and generated files.
/// 2. Functions and methods must not exceed 50 lines.
class LibStandardsVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final String source;
  final LineInfo lineInfo;
  final List<StandardViolation> violations = [];

  LibStandardsVisitor({
    required this.filePath,
    required this.source,
    required this.lineInfo,
  });

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if (node.operator.type == TokenType.BANG) {
      final bangOffset = node.operator.offset;
      if (!_isFollowedByDot(bangOffset)) {
        final loc = lineInfo.getLocation(bangOffset);
        violations.add(
          StandardViolation(
            filePath: filePath,
            line: loc.lineNumber,
            column: loc.columnNumber,
            rule: 'no-null-assertion',
            message:
                'Banned "!" null-assertion operator. Use flow analysis (if (x != null)) or "?" per docs/flutter_rules.md.',
            codeSnippet: node.toSource(),
          ),
        );
      }
    }
    super.visitPostfixExpression(node);
  }

  @override
  void visitNullAssertPattern(NullAssertPattern node) {
    final bangOffset = node.operator.offset;
    final loc = lineInfo.getLocation(bangOffset);
    violations.add(
      StandardViolation(
        filePath: filePath,
        line: loc.lineNumber,
        column: loc.columnNumber,
        rule: 'no-null-assertion',
        message:
            'Banned "!" null-assertion pattern. Use nullable flow analysis per docs/flutter_rules.md.',
        codeSnippet: node.toSource(),
      ),
    );
    super.visitNullAssertPattern(node);
  }

  bool _isFollowedByDot(int bangOffset) {
    int nextIdx = bangOffset + 1;
    while (nextIdx < source.length &&
        (source[nextIdx] == ' ' || source[nextIdx] == '\t')) {
      nextIdx++;
    }
    return nextIdx < source.length && source[nextIdx] == '.';
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _checkFunctionLength(
      'Method "${node.name.lexeme}"',
      node.offset,
      node.length,
    );
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _checkFunctionLength(
      'Function "${node.name.lexeme}"',
      node.offset,
      node.length,
    );
    super.visitFunctionDeclaration(node);
  }

  void _checkFunctionLength(String name, int offset, int length) {
    final startLine = lineInfo.getLocation(offset).lineNumber;
    final endLine = lineInfo.getLocation(offset + length).lineNumber;
    final lineCount = endLine - startLine + 1;
    if (lineCount > 50) {
      violations.add(
        StandardViolation(
          filePath: filePath,
          line: startLine,
          column: lineInfo.getLocation(offset).columnNumber,
          rule: 'function-max-50-lines',
          message:
              '$name is $lineCount lines long (max allowed: 50). Extract subwidgets or private helper functions per docs/flutter_rules.md.',
          codeSnippet: '$name ($lineCount lines)',
        ),
      );
    }
  }
}

/// Visitor that enforces standards in test files:
/// Enforces `package:checks` over `expect()` for value assertions.
/// Permitted in widget tests: finder matchers (findsOneWidget, findsNothing, findsWidgets, etc.).
class TestStandardsVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final LineInfo lineInfo;
  final List<StandardViolation> violations = [];

  static const _allowedFinderMatchers = {
    'findsOneWidget',
    'findsNothing',
    'findsWidgets',
    'findsNWidgets',
    'findsAtLeastNWidgets',
    'matchesGoldenFile',
  };

  TestStandardsVisitor({required this.filePath, required this.lineInfo});

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'expect') {
      final args = node.argumentList.arguments;
      if (args.length >= 2) {
        final matcherArg = args[1];
        if (!_isAllowedFinderMatcher(matcherArg)) {
          final loc = lineInfo.getLocation(node.offset);
          violations.add(
            StandardViolation(
              filePath: filePath,
              line: loc.lineNumber,
              column: loc.columnNumber,
              rule: 'package-checks-in-tests',
              message:
                  'Use package:checks (e.g. check(...).equals(...)) instead of expect() for value assertions in tests per docs/flutter_rules.md.',
              codeSnippet: node.toSource(),
            ),
          );
        }
      } else if (args.length == 1) {
        final loc = lineInfo.getLocation(node.offset);
        violations.add(
          StandardViolation(
            filePath: filePath,
            line: loc.lineNumber,
            column: loc.columnNumber,
            rule: 'package-checks-in-tests',
            message:
                'Use package:checks instead of expect() per docs/flutter_rules.md.',
            codeSnippet: node.toSource(),
          ),
        );
      }
    }
    super.visitMethodInvocation(node);
  }

  bool _isAllowedFinderMatcher(Expression expr) {
    if (expr is SimpleIdentifier &&
        _allowedFinderMatchers.contains(expr.name)) {
      return true;
    }
    if (expr is MethodInvocation &&
        _allowedFinderMatchers.contains(expr.methodName.name)) {
      return true;
    }
    final source = expr.toSource();
    for (final matcher in _allowedFinderMatchers) {
      if (source.startsWith(matcher)) return true;
    }
    return false;
  }
}

/// Automated standards verification tool.
class StandardsChecker {
  final List<String> libFiles;
  final List<String> newTestFiles;

  StandardsChecker({required this.libFiles, required this.newTestFiles});

  List<StandardViolation> run() {
    final violations = <StandardViolation>[];

    for (final path in libFiles) {
      final file = File(path);
      if (!file.existsSync()) continue;
      if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) continue;

      final content = file.readAsStringSync();
      try {
        final result = parseString(content: content);
        final visitor = LibStandardsVisitor(
          filePath: path,
          source: content,
          lineInfo: result.lineInfo,
        );
        result.unit.accept(visitor);
        violations.addAll(visitor.violations);
      } catch (e) {
        violations.add(
          StandardViolation(
            filePath: path,
            line: 1,
            column: 1,
            rule: 'parse-error',
            message: 'Failed to parse Dart source: $e',
            codeSnippet: '',
          ),
        );
      }
    }

    for (final path in newTestFiles) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final content = file.readAsStringSync();
      try {
        final result = parseString(content: content);
        final visitor = TestStandardsVisitor(
          filePath: path,
          lineInfo: result.lineInfo,
        );
        result.unit.accept(visitor);
        violations.addAll(visitor.violations);
      } catch (e) {
        violations.add(
          StandardViolation(
            filePath: path,
            line: 1,
            column: 1,
            rule: 'parse-error',
            message: 'Failed to parse Dart source: $e',
            codeSnippet: '',
          ),
        );
      }
    }

    return violations;
  }
}

/// Resolves target files using Git diff or filesystem enumeration.
class FileResolver {
  static String? detectBaseRef() {
    final eventName = Platform.environment['GITHUB_EVENT_NAME'];
    if (eventName == 'push') {
      final res = Process.runSync('git', ['rev-parse', '--verify', 'HEAD~1']);
      if (res.exitCode == 0) return 'HEAD~1';
    }

    final envBase = Platform.environment['GITHUB_BASE_REF'];
    if (envBase != null && envBase.isNotEmpty) {
      return 'origin/$envBase';
    }

    final candidateRefs = [
      'origin/master',
      'origin/main',
      'master',
      'main',
      'HEAD~1',
    ];

    for (final ref in candidateRefs) {
      final res = Process.runSync('git', ['rev-parse', '--verify', ref]);
      if (res.exitCode == 0) return ref;
    }
    return null;
  }

  static ({List<String> libFiles, List<String> newTestFiles}) resolve({
    bool all = false,
    String? baseRef,
    List<String> explicitPaths = const [],
  }) {
    if (explicitPaths.isNotEmpty) {
      final libFiles = <String>[];
      final newTestFiles = <String>[];
      for (final rawPath in explicitPaths) {
        final normalized = _normalizePath(rawPath);
        final entity = FileSystemEntity.typeSync(normalized);
        if (entity == FileSystemEntityType.directory) {
          final dir = Directory(normalized);
          for (final f in dir.listSync(recursive: true)) {
            if (f is File && f.path.endsWith('.dart')) {
              _categorizeFile(
                _normalizePath(f.path),
                libFiles,
                newTestFiles,
                isNewTest: true,
              );
            }
          }
        } else if (entity == FileSystemEntityType.file &&
            normalized.endsWith('.dart')) {
          _categorizeFile(normalized, libFiles, newTestFiles, isNewTest: true);
        }
      }
      return (libFiles: libFiles, newTestFiles: newTestFiles);
    }

    if (all) {
      final libFiles = <String>[];
      final newTestFiles = <String>[];
      final libDir = Directory('lib');
      if (libDir.existsSync()) {
        for (final f in libDir.listSync(recursive: true)) {
          if (f is File && f.path.endsWith('.dart')) {
            libFiles.add(_normalizePath(f.path));
          }
        }
      }
      return (libFiles: libFiles, newTestFiles: newTestFiles);
    }

    // Git Diff Mode
    var effectiveBase = baseRef ?? detectBaseRef();
    final libFiles = <String>{};
    final newTestFiles = <String>{};

    if (effectiveBase != null) {
      // 1. Files modified or added against base
      var diffResult = Process.runSync('git', [
        'diff',
        '--name-only',
        '$effectiveBase...HEAD',
      ]);
      // If diff against base is empty (e.g. pushed commit on master), fall back to HEAD~1
      if (diffResult.exitCode == 0 &&
          (diffResult.stdout as String).trim().isEmpty &&
          effectiveBase != 'HEAD~1') {
        final checkHead = Process.runSync('git', [
          'rev-parse',
          '--verify',
          'HEAD~1',
        ]);
        if (checkHead.exitCode == 0) {
          effectiveBase = 'HEAD~1';
          diffResult = Process.runSync('git', [
            'diff',
            '--name-only',
            'HEAD~1...HEAD',
          ]);
        }
      }

      if (diffResult.exitCode == 0) {
        for (final line in (diffResult.stdout as String).split('\n')) {
          final trimmed = _normalizePath(line.trim());
          if (trimmed.endsWith('.dart') && trimmed.startsWith('lib/')) {
            libFiles.add(trimmed);
          }
        }
      }

      // 2. Newly added test files against base
      final addedDiffResult = Process.runSync('git', [
        'diff',
        '--name-only',
        '--diff-filter=A',
        '$effectiveBase...HEAD',
      ]);
      if (addedDiffResult.exitCode == 0) {
        for (final line in (addedDiffResult.stdout as String).split('\n')) {
          final trimmed = _normalizePath(line.trim());
          if (trimmed.endsWith('.dart') && _isTargetTestDir(trimmed)) {
            newTestFiles.add(trimmed);
          }
        }
      }
    }

    // 3. Staged and unstaged working tree changes
    final statusResult = Process.runSync('git', ['status', '--porcelain']);
    if (statusResult.exitCode == 0) {
      for (final line in (statusResult.stdout as String).split('\n')) {
        if (line.length < 4) continue;
        final statusCode = line.substring(0, 2);
        final filePath = _normalizePath(line.substring(3).trim());
        if (!filePath.endsWith('.dart')) continue;

        if (filePath.startsWith('lib/')) {
          libFiles.add(filePath);
        } else if (_isTargetTestDir(filePath) &&
            (statusCode.contains('A') || statusCode.contains('?'))) {
          newTestFiles.add(filePath);
        }
      }
    }

    return (
      libFiles: libFiles.toList()..sort(),
      newTestFiles: newTestFiles.toList()..sort(),
    );
  }

  static bool _isTargetTestDir(String path) {
    return path.startsWith('test/presentation/screens/') ||
        path.startsWith('test/presentation/widgets/');
  }

  static void _categorizeFile(
    String path,
    List<String> libFiles,
    List<String> newTestFiles, {
    required bool isNewTest,
  }) {
    if (path.startsWith('lib/')) {
      libFiles.add(path);
    } else if (_isTargetTestDir(path) && isNewTest) {
      newTestFiles.add(path);
    }
  }

  static String _normalizePath(String raw) {
    return raw.replaceAll('\\', '/');
  }
}

void main(List<String> args) {
  bool all = false;
  String? baseRef;
  final explicitPaths = <String>[];

  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--all') {
      all = true;
    } else if (arg == '--help' || arg == '-h') {
      stdout.writeln('''
Usage: dart run tool/check_standards.dart [options] [files...]

Enforces mechanical standards from docs/flutter_rules.md:
  1. No "!" null-assertion operator in lib/ (outside "!." and generated files)
  2. Functions and methods <= 50 lines in lib/
  3. package:checks required in new test files under test/presentation/screens/ and test/presentation/widgets/

Options:
  --all            Scan all files in lib/
  --base <ref>     Git base ref for diff mode (defaults to origin/master or GITHUB_BASE_REF)
  -h, --help       Show this help message
''');
      exit(0);
    } else if (arg == '--base') {
      if (i + 1 < args.length) {
        baseRef = args[++i];
      } else {
        stderr.writeln('Error: --base requires a reference argument.');
        exit(64);
      }
    } else if (arg.startsWith('--base=')) {
      baseRef = arg.substring('--base='.length);
    } else if (!arg.startsWith('-')) {
      explicitPaths.add(arg);
    }
  }

  final resolved = FileResolver.resolve(
    all: all,
    baseRef: baseRef,
    explicitPaths: explicitPaths,
  );

  stdout.writeln('Standards Guardrail Verification');
  stdout.writeln('================================');
  stdout.writeln('Target lib files:  ${resolved.libFiles.length}');
  stdout.writeln('Target test files: ${resolved.newTestFiles.length}');
  stdout.writeln('');

  final checker = StandardsChecker(
    libFiles: resolved.libFiles,
    newTestFiles: resolved.newTestFiles,
  );

  final violations = checker.run();

  if (violations.isEmpty) {
    stdout.writeln('✓ PASSED: All code conforms to mechanical standards.');
    exit(0);
  } else {
    stderr.writeln(
      'FAILED: Found ${violations.length} standard violation(s):\n',
    );
    for (int i = 0; i < violations.length; i++) {
      stderr.writeln('${i + 1}. ${violations[i]}\n');
    }
    exit(1);
  }
}
