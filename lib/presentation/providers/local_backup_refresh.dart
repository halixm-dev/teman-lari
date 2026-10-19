import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'activities_provider.dart';
import 'backup_provider.dart';
import 'equipment_provider.dart';
import 'preferences_provider.dart';
import 'training_plan_provider.dart';
import 'rehab_provider.dart';

part 'local_backup_refresh.g.dart';

@Riverpod(keepAlive: true)
class LocalBackupRefreshEpoch extends _$LocalBackupRefreshEpoch {
  @override
  int build() => 0;

  void advance() => state++;
}

/// Rebuilds local views without rechecking OAuth or requesting remote data.
void refreshLocalBackupProviders(WidgetRef ref) {
  ref.invalidate(activitiesProvider);
  ref.invalidate(hrPreferencesProvider);
  ref.invalidate(athleteNameProvider);
  ref.invalidate(cycleStartDateProvider);
  ref.invalidate(weekInCycleProvider);
  ref.invalidate(trainingPlanProvider);
  ref.invalidate(rehabJournalProvider);
  ref.invalidate(rehabProgressProvider);
  ref.invalidate(runningStatsProvider);
  ref.invalidate(equipmentProvider);
  ref.invalidate(backupCountsProvider);
  ref.read(localBackupRefreshEpochProvider.notifier).advance();
}
