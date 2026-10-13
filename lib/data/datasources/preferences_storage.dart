import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/usecases/demographics_calculator.dart';
import '../backup/local_data_coordinator.dart';
import '../backup/durable_preference_checkpoint.dart';

class HrPreferences {
  final int? maxHr;
  final int restingHr;
  final int? age;
  final int? thresholdPaceSeconds;

  const HrPreferences({
    this.maxHr,
    this.restingHr = 60,
    this.age,
    this.thresholdPaceSeconds,
  });

  int get effectiveMaxHr {
    final fixedMax = maxHr;
    if (fixedMax != null) return fixedMax;
    final athleteAge = age;
    if (athleteAge != null) {
      return DemographicsCalculator.calculateFoxMaxHr(athleteAge);
    }
    return 190;
  }

  Duration? get thresholdPace {
    final pace = thresholdPaceSeconds;
    return pace != null ? Duration(seconds: pace) : null;
  }
}

class PreferencesStorage {
  final LocalDataCoordinator coordinator;
  final DateTime Function() clock;

  PreferencesStorage({
    LocalDataCoordinator? coordinator,
    DateTime Function()? clock,
  }) : coordinator = coordinator ?? LocalDataCoordinator.shared,
       clock = clock ?? DateTime.now;

  static const _keyRestingHr = 'resting_hr';
  static const _keyMaxHr = 'max_hr';
  static const _keyThresholdPace = 'threshold_pace_sec';
  static const _keyDateOfBirth = 'date_of_birth';
  static const _keyAthleteName = 'athlete_name';
  static const _keyWeekInCycle = 'week_in_cycle';
  static const _keyCycleStartDate = 'cycle_start_date';
  static const _keyHasCompletedOnboarding = 'has_completed_onboarding';

  /// Calculates estimated Maximum Heart Rate using the clinically validated Tanaka formula:
  /// HR_max = round(208 - 0.7 * age)
  static int calculateTanakaMaxHr(int age) {
    return DemographicsCalculator.calculateTanakaMaxHr(age);
  }

  /// Calculates elapsed age in years from birth date given an optional reference date.
  static int calculateAge(DateTime birthDate, [DateTime? referenceDate]) {
    return DemographicsCalculator.calculateAge(birthDate, referenceDate);
  }

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> hasCompletedOnboarding() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyHasCompletedOnboarding) ?? false;
  }

  Future<void> setCompletedOnboarding([bool completed = true]) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyHasCompletedOnboarding, completed);
  }

  Future<int> _getRestingHr() async =>
      (await _prefs).getInt(_keyRestingHr) ?? 60;
  Future<int?> _getMaxHr() async => (await _prefs).getInt(_keyMaxHr);
  Future<int?> _getThresholdPace() async =>
      (await _prefs).getInt(_keyThresholdPace);

  Future<HrPreferences> _getPreferences() async {
    final prefs = await _prefs;
    return HrPreferences(
      restingHr: prefs.getInt(_keyRestingHr) ?? 60,
      maxHr: prefs.getInt(_keyMaxHr),
      age: _computeAge(prefs.getString(_keyDateOfBirth)),
      thresholdPaceSeconds: prefs.getInt(_keyThresholdPace),
    );
  }

  Future<void> _saveRestingHr(int value) async {
    final prefs = await _prefs;
    await _persist(prefs, _keyRestingHr, prefs.setInt(_keyRestingHr, value));
  }

  Future<void> _clearRestingHr() async {
    final prefs = await _prefs;
    await _persist(prefs, _keyRestingHr, prefs.remove(_keyRestingHr));
  }

  Future<void> _saveMaxHr(int value) async {
    final prefs = await _prefs;
    await _persist(prefs, _keyMaxHr, prefs.setInt(_keyMaxHr, value));
  }

  Future<void> _clearMaxHr() async {
    final prefs = await _prefs;
    await _persist(prefs, _keyMaxHr, prefs.remove(_keyMaxHr));
  }

  Future<void> _saveThresholdPace(int seconds) async {
    final prefs = await _prefs;
    await _persist(
      prefs,
      _keyThresholdPace,
      prefs.setInt(_keyThresholdPace, seconds),
    );
  }

  Future<void> _clearThresholdPace() async {
    final prefs = await _prefs;
    await _persist(prefs, _keyThresholdPace, prefs.remove(_keyThresholdPace));
  }

  Future<void> _saveDateOfBirth(String value) async {
    final prefs = await _prefs;
    await _persist(
      prefs,
      _keyDateOfBirth,
      prefs.setString(_keyDateOfBirth, value),
    );
  }

  Future<String?> _getDateOfBirth() async {
    final prefs = await _prefs;
    return prefs.getString(_keyDateOfBirth);
  }

  Future<bool> _updateFromStrava({
    int? activityMaxHr,
    double? athleteMaxHr,
    String? athleteDateOfBirth,
    String? athleteName,
  }) async {
    final prefs = await _prefs;
    bool changed = false;
    final storedMaxHr = prefs.getInt(_keyMaxHr);
    if (storedMaxHr == null) {
      final candidateMaxHr = _pickBestMaxHr(
        stored: null,
        activityMaxHr: activityMaxHr,
        athleteMaxHr: athleteMaxHr,
      );
      if (candidateMaxHr != null) {
        await _persist(
          prefs,
          _keyMaxHr,
          prefs.setInt(_keyMaxHr, candidateMaxHr),
        );
        changed = true;
      }
    } else if (activityMaxHr != null && activityMaxHr > storedMaxHr) {
      await _persist(prefs, _keyMaxHr, prefs.setInt(_keyMaxHr, activityMaxHr));
      changed = true;
    }
    final storedDob = prefs.getString(_keyDateOfBirth);
    if (storedDob == null && athleteDateOfBirth != null) {
      await _persist(
        prefs,
        _keyDateOfBirth,
        prefs.setString(_keyDateOfBirth, athleteDateOfBirth),
      );
      changed = true;
    }
    final storedName = prefs.getString(_keyAthleteName);
    if ((storedName == null || storedName.isEmpty) &&
        athleteName != null &&
        athleteName.isNotEmpty) {
      await _persist(
        prefs,
        _keyAthleteName,
        prefs.setString(_keyAthleteName, athleteName),
      );
      changed = true;
    }
    return changed;
  }

  Future<String?> _getAthleteName() async {
    final prefs = await _prefs;
    return prefs.getString(_keyAthleteName);
  }

  Future<void> _saveAthleteName(String name) async {
    final prefs = await _prefs;
    await _persist(
      prefs,
      _keyAthleteName,
      prefs.setString(_keyAthleteName, name),
    );
  }

  Future<int> _getWeekInCycle() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyWeekInCycle) ?? 0;
  }

  Future<void> _setWeekInCycle(int value) async {
    final prefs = await _prefs;
    await _persist(
      prefs,
      _keyWeekInCycle,
      prefs.setInt(_keyWeekInCycle, value),
    );
  }

  Future<DateTime> _getCycleStartDate() async {
    final prefs = await _prefs;
    final stored = prefs.getString(_keyCycleStartDate);
    if (stored != null) {
      return DateTime.parse(stored);
    }
    return DateTime.now();
  }

  Future<void> _setCycleStartDate(DateTime value) async {
    final prefs = await _prefs;
    await _persist(
      prefs,
      _keyCycleStartDate,
      prefs.setString(_keyCycleStartDate, value.toIso8601String()),
    );
  }

  Future<int> getRestingHr() => coordinator.read(() => _getRestingHr());

  Future<int?> getMaxHr() => coordinator.read(() => _getMaxHr());

  Future<int?> getThresholdPace() =>
      coordinator.read(() => _getThresholdPace());

  Future<HrPreferences> getPreferences() =>
      coordinator.read(() => _getPreferences());

  Future<void> saveRestingHr(int value) =>
      coordinator.write(() => _saveRestingHr(value));

  Future<void> clearRestingHr() => coordinator.write(() => _clearRestingHr());

  Future<void> saveMaxHr(int value) =>
      coordinator.write(() => _saveMaxHr(value));

  Future<void> clearMaxHr() => coordinator.write(() => _clearMaxHr());

  Future<void> saveThresholdPace(int seconds) =>
      coordinator.write(() => _saveThresholdPace(seconds));

  Future<void> clearThresholdPace() =>
      coordinator.write(() => _clearThresholdPace());

  Future<void> saveDateOfBirth(String value) =>
      coordinator.write(() => _saveDateOfBirth(value));

  Future<String?> getDateOfBirth() => coordinator.read(() => _getDateOfBirth());

  Future<bool> updateFromStrava({
    int? activityMaxHr,
    double? athleteMaxHr,
    String? athleteDateOfBirth,
    String? athleteName,
  }) => coordinator.write(
    () => _updateFromStrava(
      activityMaxHr: activityMaxHr,
      athleteMaxHr: athleteMaxHr,
      athleteDateOfBirth: athleteDateOfBirth,
      athleteName: athleteName,
    ),
  );

  Future<String?> getAthleteName() => coordinator.read(() => _getAthleteName());

  Future<void> saveAthleteName(String name) =>
      coordinator.write(() => _saveAthleteName(name));

  Future<int> getWeekInCycle() => coordinator.read(() => _getWeekInCycle());

  Future<void> setWeekInCycle(int value) =>
      coordinator.write(() => _setWeekInCycle(value));

  Future<DateTime> getCycleStartDate() =>
      coordinator.read(() => _getCycleStartDate());

  Future<void> setCycleStartDate(DateTime value) =>
      coordinator.write(() => _setCycleStartDate(value));

  Future<void> _persist(
    SharedPreferences prefs,
    String key,
    Future<bool> operation,
  ) async {
    if (!await operation) throw StateError('Could not save $key');
    final timestamp = clock().toUtc().toIso8601String();
    if (!await prefs.setString('${key}_modified_at', timestamp)) {
      throw StateError('Could not save modification time for $key');
    }
    if (DurablePreferenceCheckpoint.isInitialized) {
      await DurablePreferenceCheckpoint.record(prefs, key, timestamp);
    }
  }

  int? _pickBestMaxHr({int? stored, int? activityMaxHr, double? athleteMaxHr}) {
    final values = <int>[];
    if (stored != null) values.add(stored);
    if (activityMaxHr != null) values.add(activityMaxHr);
    if (athleteMaxHr != null) values.add(athleteMaxHr.round());
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }

  int? _computeAge(String? dateOfBirth) {
    if (dateOfBirth == null) return null;
    final parts = dateOfBirth.split('-');
    if (parts.length != 3) {
      final directAge = int.tryParse(dateOfBirth);
      if (directAge != null) return directAge;
      return null;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return calculateAge(DateTime(year, month, day));
  }
}

/// Tanaka formula calculation: round(208 - 0.7 * age)
int calculateTanakaMaxHr(int age) =>
    PreferencesStorage.calculateTanakaMaxHr(age);
