import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/usecases/demographics_calculator.dart';

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

  int get effectiveMaxHr => maxHr ?? (age != null ? (220 - age!) : 190);
  Duration? get thresholdPace => thresholdPaceSeconds != null
      ? Duration(seconds: thresholdPaceSeconds!)
      : null;
}

class PreferencesStorage {
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

  Future<int> getRestingHr() async =>
      (await _prefs).getInt(_keyRestingHr) ?? 60;
  Future<int?> getMaxHr() async => (await _prefs).getInt(_keyMaxHr);
  Future<int?> getThresholdPace() async =>
      (await _prefs).getInt(_keyThresholdPace);

  Future<HrPreferences> getPreferences() async {
    final prefs = await _prefs;
    return HrPreferences(
      restingHr: prefs.getInt(_keyRestingHr) ?? 60,
      maxHr: prefs.getInt(_keyMaxHr),
      age: _computeAge(prefs.getString(_keyDateOfBirth)),
      thresholdPaceSeconds: prefs.getInt(_keyThresholdPace),
    );
  }

  Future<void> saveRestingHr(int value) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyRestingHr, value);
  }

  Future<void> clearRestingHr() async {
    final prefs = await _prefs;
    await prefs.remove(_keyRestingHr);
  }

  Future<void> saveMaxHr(int value) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyMaxHr, value);
  }

  Future<void> clearMaxHr() async {
    final prefs = await _prefs;
    await prefs.remove(_keyMaxHr);
  }

  Future<void> saveThresholdPace(int seconds) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyThresholdPace, seconds);
  }

  Future<void> clearThresholdPace() async {
    final prefs = await _prefs;
    await prefs.remove(_keyThresholdPace);
  }

  Future<void> saveDateOfBirth(String value) async {
    final prefs = await _prefs;
    await prefs.setString(_keyDateOfBirth, value);
  }

  Future<String?> getDateOfBirth() async {
    final prefs = await _prefs;
    return prefs.getString(_keyDateOfBirth);
  }

  Future<bool> updateFromStrava({
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
        await prefs.setInt(_keyMaxHr, candidateMaxHr);
        changed = true;
      }
    } else if (activityMaxHr != null && activityMaxHr > storedMaxHr) {
      await prefs.setInt(_keyMaxHr, activityMaxHr);
      changed = true;
    }

    final storedDob = prefs.getString(_keyDateOfBirth);
    if (storedDob == null && athleteDateOfBirth != null) {
      await prefs.setString(_keyDateOfBirth, athleteDateOfBirth);
      changed = true;
    }

    final storedName = prefs.getString(_keyAthleteName);
    if ((storedName == null || storedName.isEmpty) &&
        athleteName != null &&
        athleteName.isNotEmpty) {
      await prefs.setString(_keyAthleteName, athleteName);
      changed = true;
    }

    return changed;
  }

  Future<String?> getAthleteName() async {
    final prefs = await _prefs;
    return prefs.getString(_keyAthleteName);
  }

  Future<void> saveAthleteName(String name) async {
    final prefs = await _prefs;
    await prefs.setString(_keyAthleteName, name);
  }

  Future<int> getWeekInCycle() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyWeekInCycle) ?? 0;
  }

  Future<void> setWeekInCycle(int value) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyWeekInCycle, value);
  }

  Future<DateTime> getCycleStartDate() async {
    final prefs = await _prefs;
    final stored = prefs.getString(_keyCycleStartDate);
    if (stored != null) {
      return DateTime.parse(stored);
    }
    return DateTime.now();
  }

  Future<void> setCycleStartDate(DateTime value) async {
    final prefs = await _prefs;
    await prefs.setString(_keyCycleStartDate, value.toIso8601String());
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
