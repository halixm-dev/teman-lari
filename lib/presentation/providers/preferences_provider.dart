import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/datasources/preferences_storage.dart';
import 'core_provider.dart';

part 'preferences_provider.g.dart';

@riverpod
class HrPreferencesNotifier extends _$HrPreferencesNotifier {
  @override
  Future<HrPreferences> build() async {
    return ref.read(preferencesStorageProvider).getPreferences();
  }

  Future<void> saveRestingHr(int value) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(preferencesStorageProvider).saveRestingHr(value);
      return ref.read(preferencesStorageProvider).getPreferences();
    });
  }

  Future<void> clearRestingHr() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(preferencesStorageProvider).clearRestingHr();
      return ref.read(preferencesStorageProvider).getPreferences();
    });
  }

  Future<void> saveMaxHr(int value) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(preferencesStorageProvider).saveMaxHr(value);
      return ref.read(preferencesStorageProvider).getPreferences();
    });
  }

  Future<void> clearMaxHr() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(preferencesStorageProvider).clearMaxHr();
      return ref.read(preferencesStorageProvider).getPreferences();
    });
  }

  Future<void> saveThresholdPace(int seconds) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(preferencesStorageProvider).saveThresholdPace(seconds);
      return ref.read(preferencesStorageProvider).getPreferences();
    });
  }

  Future<void> clearThresholdPace() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(preferencesStorageProvider).clearThresholdPace();
      return ref.read(preferencesStorageProvider).getPreferences();
    });
  }

  Future<void> updateFromStrava({
    int? activityMaxHr,
    double? athleteMaxHr,
    String? athleteDateOfBirth,
    String? athleteName,
  }) async {
    final changed = await ref
        .read(preferencesStorageProvider)
        .updateFromStrava(
          activityMaxHr: activityMaxHr,
          athleteMaxHr: athleteMaxHr,
          athleteDateOfBirth: athleteDateOfBirth,
          athleteName: athleteName,
        );
    if (changed) {
      ref.invalidateSelf();
    }
  }
}

@riverpod
Future<String?> athleteName(Ref ref) async {
  return ref.read(preferencesStorageProvider).getAthleteName();
}
