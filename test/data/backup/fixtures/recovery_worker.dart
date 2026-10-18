import 'interrupted_process.dart' show markBackupWorkerStarted;
import 'dart:io';
import 'recovery_plan.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';

void main() {
  markBackupWorkerStarted();
  test('disposable restore process', () async {
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
            store == 'training_plans') {
          File('$path/interrupted_at').writeAsStringSync('before', flush: true);
          exit(91);
        }
        if (phase == 'after' && observed == SnapshotPhase.committed) {
          File('$path/interrupted_at').writeAsStringSync('after', flush: true);
          exit(92);
        }
      },
    );
    await service.initialize();
    final before = await service.readLocalState();
    await service.applyLocalState(
      LocalSnapshot(
        revision: before.revision,
        stores: {...before.stores, 'training_plans': recoveryPlan('After')},
      ),
      expectedRevision: before.revision,
    );
    fail('Process interruption was not triggered');
  });
}
