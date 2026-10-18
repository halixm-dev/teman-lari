import 'interrupted_process.dart' show markBackupWorkerStarted;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';

void main() {
  markBackupWorkerStarted();
  test('disposable confirmed import process', () async {
    final path = Platform.environment['BACKUP_RECOVERY_DIRECTORY'];
    final phase = Platform.environment['BACKUP_CRASH_PHASE'];
    if (path == null) return;
    Hive.init(path);
    SharedPreferences.setMockInitialValues({'athlete_name': 'Before'});
    final service = SnapshotBackupService(
      coordinator: LocalDataCoordinator(),
      onPhase: (observed, store) async {
        if (phase == 'before' &&
                observed == SnapshotPhase.storeWritten &&
                store == 'training_plans' ||
            phase == 'after' && observed == SnapshotPhase.committed) {
          File('$path/interrupted_at').writeAsStringSync('$phase', flush: true);
          exit(91);
        }
      },
    );
    await service.initialize();
    final bytes = await File(
      'test/fixtures/offline-backup-v1-populated.tlbackup',
    ).readAsBytes();
    final preview = await service.prepareImport(Uint8List.fromList(bytes));
    await service.applyImport(preview);
    fail('Process interruption was not triggered');
  });
}
