import 'dart:convert';
import 'dart:io';

/// Runs the shared backup fixture tests in an isolated Chrome test origin.
Future<void> main() async {
  final fixture = File('test/fixtures/offline-backup-v1-populated.tlbackup');
  if (!await fixture.exists()) {
    stderr.writeln('Run this command from the repository root.');
    exitCode = 64;
    return;
  }
  final temporary = await Directory.systemTemp.createTemp(
    'backup_web_fixture_',
  );
  final definitions = File('${temporary.path}/defines.json');
  try {
    await definitions.writeAsString(
      jsonEncode({
        'BACKUP_FIXTURE_BASE64': base64Encode(await fixture.readAsBytes()),
      }),
    );
    final process = await Process.start(
      'flutter',
      [
        '--no-version-check',
        '--suppress-analytics',
        'test',
        '--no-pub',
        '--platform',
        'chrome',
        '--dart-define-from-file=${definitions.path}',
        'test/backup_platform_browser.dart',
      ],
      runInShell: Platform.isWindows,
      mode: ProcessStartMode.inheritStdio,
    );
    exitCode = await process.exitCode;
  } finally {
    if (await definitions.exists()) await definitions.delete();
    await temporary.delete();
  }
}
