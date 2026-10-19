import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Runs an actual disposable worker and reaps its Flutter runner after the
/// durable crash marker, including Windows descendants that inherit pipes.
Future<void> runInterruptedBackupWorker({
  required String worker,
  required String directory,
  required String phase,
  Map<String, String> environment = const {},
}) async {
  final process = await _startWorker(worker, directory, phase, environment);
  var exited = false;
  final exitCode = process.exitCode.then((code) {
    exited = true;
    return code;
  });
  final stdout = _BoundedOutput();
  final stderr = _BoundedOutput();
  final output = process.stdout.listen(stdout.add);
  final errors = process.stderr.listen(stderr.add);
  try {
    await _waitForCrash(
      exitCode,
      File('$directory/interrupted_at'),
      phase,
      () => 'stdout:\n$stdout\nstderr:\n$stderr',
    );
  } finally {
    try {
      if (!exited) await _reap(process);
    } finally {
      await output.cancel();
      await errors.cancel();
    }
  }
}

Future<Process> _startWorker(
  String worker,
  String directory,
  String phase,
  Map<String, String> environment,
) async {
  for (final name in ['worker_started', 'interrupted_at']) {
    final marker = File('$directory/$name');
    if (await marker.exists()) await marker.delete();
  }
  final sdk = File(
    Platform.resolvedExecutable,
  ).parent.parent.parent.parent.parent.parent.path;
  final dart = Platform.isWindows ? 'dart.exe' : 'dart';
  return Process.start(
    '$sdk/bin/cache/dart-sdk/bin/$dart',
    [
      '--packages=$sdk/packages/flutter_tools/.dart_tool/package_config.json',
      '$sdk/bin/cache/flutter_tools.snapshot',
      '--no-version-check',
      '--suppress-analytics',
      'test',
      '--no-pub',
      '--no-test-assets',
      worker,
    ],
    environment: {
      ...environment,
      'BACKUP_RECOVERY_DIRECTORY': directory,
      'BACKUP_CRASH_PHASE': phase,
    },
  );
}

void markBackupWorkerStarted() {
  final directory = Platform.environment['BACKUP_RECOVERY_DIRECTORY'];
  if (directory != null) {
    File('$directory/worker_started').writeAsStringSync('started', flush: true);
  }
}

Future<void> _waitForCrash(
  Future<int> exitCode,
  File sentinel,
  String phase,
  String Function() diagnostics,
) async {
  final startup = Stopwatch()..start();
  final started = File('${sentinel.parent.path}/worker_started');
  Stopwatch? execution;
  while (true) {
    if (await sentinel.exists() && await sentinel.readAsString() == phase) {
      await exitCode.timeout(const Duration(seconds: 2), onTimeout: () => -1);
      return;
    }
    if (await started.exists()) {
      execution ??= Stopwatch()..start();
      if (execution.elapsed >= const Duration(seconds: 60)) {
        throw TimeoutException(
          'Worker started but did not reach $phase. ${diagnostics()}',
        );
      }
    } else if (startup.elapsed >= const Duration(minutes: 2)) {
      throw TimeoutException('Worker did not start. ${diagnostics()}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

Future<void> _reap(Process process) async {
  if (Platform.isWindows) {
    await Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
  } else {
    process.kill(ProcessSignal.sigkill);
  }
  await process.exitCode.timeout(const Duration(seconds: 10));
}

class _BoundedOutput {
  final _bytes = <int>[];
  void add(List<int> bytes) {
    _bytes.addAll(bytes);
    if (_bytes.length > 16384) _bytes.removeRange(0, _bytes.length - 16384);
  }

  @override
  String toString() => utf8.decode(_bytes, allowMalformed: true);
}
