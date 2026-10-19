import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';

Future<Uint8List> loadCompatibilityFixture() async {
  const source = String.fromEnvironment('BACKUP_FIXTURE_BASE64');
  if (source.isEmpty) {
    throw StateError(
      'Browser tests require the canonical BACKUP_FIXTURE_BASE64 fixture.',
    );
  }
  return base64Decode(source);
}

Future<String> createCompatibilityStorage() async {
  await deleteCompatibilityStorage('');
  return 'backup-platform-test';
}

Future<void> deleteCompatibilityStorage(String path) async {
  // Flutter's disposable test-runner origin owns these databases.
  for (final name in [
    'activities',
    'hr_streams',
    'training_plans',
    'equipment',
    'rehab_feedback',
    'snapshot_preferences',
    'snapshot_recovery',
  ]) {
    await Hive.deleteBoxFromDisk(name);
  }
}
