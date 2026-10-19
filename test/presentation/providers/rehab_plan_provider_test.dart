import 'dart:io';
import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'package:teman_lari/data/datasources/local_activity_datasource.dart';
import 'package:teman_lari/domain/entities/training_plan.dart';
import 'package:teman_lari/presentation/providers/activities_provider.dart';
import 'package:teman_lari/presentation/providers/backup_provider.dart';
import 'package:teman_lari/presentation/providers/rehab_provider.dart';
import 'package:teman_lari/presentation/providers/training_plan_provider.dart';
import '../../domain/usecases/rehab_progression_test.dart'
    show rehabProgram, rehabRun, clearedFeedback;
import '../../data/backup/snapshot_archive_export_test.dart' show activity;
import '../screens/run_session_screen_test.dart' show FakeActivityRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'a saved ordinary plan reacts to newly recorded rehab feedback',
    () async {
      final directory = await Directory.systemTemp.createTemp('rehab_plan_');
      Hive.init(directory.path);
      SharedPreferences.setMockInitialValues({});
      final service = SnapshotBackupService(
        coordinator: LocalDataCoordinator(),
        clock: () => DateTime.utc(2026, 10, 30),
      );
      await service.initialize();
      await LocalActivityDataSource(
        coordinator: service.coordinator,
      ).saveActivity(
        activity(-1, 'Run').copyWith(startDate: '2026-10-02T08:00:00Z'),
      );
      final container = ProviderContainer(
        overrides: [
          snapshotBackupServiceProvider.overrideWithValue(service),
          activityRepositoryProvider.overrideWithValue(
            FakeActivityRepository()..activities.add(rehabRun(-1, 2)),
          ),
          rehabTimeProvider.overrideWith(
            (ref) => Stream.value(DateTime.utc(2026, 10, 3, 9)),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await Hive.close();
        await directory.delete(recursive: true);
      });
      final subscription = container.listen(trainingPlanProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(trainingPlanProvider.future);
      final journal = container.read(rehabJournalProvider.notifier);
      await journal.start(rehabProgram());
      await journal.saveFeedback(clearedFeedback(-1, 2, pain: 6));
      final plan = await container.read(trainingPlanProvider.future);

      check(
        plan.days.take(3).every((d) => d.type == WorkoutType.crossTraining),
      ).isTrue();
    },
  );
}
