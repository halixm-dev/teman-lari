import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
import 'package:teman_lari/domain/usecases/demographics_calculator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HrPreferences Demographics Baselines', () {
    test('effectiveMaxHr returns explicit maxHr when set', () {
      const prefs = HrPreferences(maxHr: 185, age: 30);
      check(prefs.effectiveMaxHr).equals(185);
    });

    test(
      'effectiveMaxHr falls back to (220 - age) when maxHr is null and age is present',
      () {
        const prefs1 = HrPreferences(maxHr: null, age: 30);
        check(prefs1.effectiveMaxHr).equals(190);

        const prefs2 = HrPreferences(maxHr: null, age: 25);
        check(prefs2.effectiveMaxHr).equals(195);
      },
    );

    test(
      'effectiveMaxHr falls back to 190 when maxHr and age are both null',
      () {
        const prefs = HrPreferences(maxHr: null, age: null);
        check(prefs.effectiveMaxHr).equals(190);
      },
    );

    test('thresholdPace returns Duration when thresholdPaceSeconds is set', () {
      const prefs = HrPreferences(thresholdPaceSeconds: 300);
      check(prefs.thresholdPace).equals(const Duration(seconds: 300));
    });

    test('thresholdPace returns null when thresholdPaceSeconds is null', () {
      const prefs = HrPreferences(thresholdPaceSeconds: null);
      check(prefs.thresholdPace).isNull();
    });

    test('default restingHr is 60', () {
      const prefs = HrPreferences();
      check(prefs.restingHr).equals(60);
    });
  });

  group('PreferencesStorage Demographic Accessors & Persistence', () {
    late PreferencesStorage storage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storage = PreferencesStorage();
    });

    test('getRestingHr returns default 60 bpm when unconfigured', () async {
      final restingHr = await storage.getRestingHr();
      check(restingHr).equals(60);
    });

    test(
      'saveRestingHr, getRestingHr and clearRestingHr work correctly',
      () async {
        await storage.saveRestingHr(52);
        check(await storage.getRestingHr()).equals(52);

        await storage.clearRestingHr();
        check(await storage.getRestingHr()).equals(60);
      },
    );

    test(
      'getMaxHr returns null by default, persists custom value, and clears',
      () async {
        check(await storage.getMaxHr()).isNull();

        await storage.saveMaxHr(195);
        check(await storage.getMaxHr()).equals(195);

        await storage.clearMaxHr();
        check(await storage.getMaxHr()).isNull();
      },
    );

    test(
      'getThresholdPace returns null by default, persists custom value, and clears',
      () async {
        check(await storage.getThresholdPace()).isNull();

        await storage.saveThresholdPace(285);
        check(await storage.getThresholdPace()).equals(285);

        await storage.clearThresholdPace();
        check(await storage.getThresholdPace()).isNull();
      },
    );

    test(
      'getPreferences properly aggregates demographic values into HrPreferences',
      () async {
        await storage.saveRestingHr(55);
        await storage.saveMaxHr(188);
        await storage.saveThresholdPace(290);
        await storage.saveDateOfBirth('1994-05-15');

        final prefs = await storage.getPreferences();
        check(prefs.restingHr).equals(55);
        check(prefs.maxHr).equals(188);
        check(prefs.thresholdPaceSeconds).equals(290);
        check(prefs.thresholdPace).equals(const Duration(seconds: 290));
        check(prefs.effectiveMaxHr).equals(188);
        check(prefs.age).isNotNull();
      },
    );

    test(
      'hasCompletedOnboarding returns false by default when unset',
      () async {
        check(await storage.hasCompletedOnboarding()).isFalse();
      },
    );

    test(
      'hasCompletedOnboarding returns false when explicitly stored as false',
      () async {
        SharedPreferences.setMockInitialValues({
          'has_completed_onboarding': false,
        });
        check(await storage.hasCompletedOnboarding()).isFalse();
      },
    );

    test(
      'hasCompletedOnboarding returns true when explicitly stored as true',
      () async {
        SharedPreferences.setMockInitialValues({
          'has_completed_onboarding': true,
        });
        check(await storage.hasCompletedOnboarding()).isTrue();
      },
    );

    test('setCompletedOnboarding defaults to true and persists flag', () async {
      await storage.setCompletedOnboarding();
      check(await storage.hasCompletedOnboarding()).isTrue();
    });

    test('setCompletedOnboarding(false) updates flag to false', () async {
      await storage.setCompletedOnboarding(true);
      check(await storage.hasCompletedOnboarding()).isTrue();

      await storage.setCompletedOnboarding(false);
      check(await storage.hasCompletedOnboarding()).isFalse();
    });

    test('getDateOfBirth returns saved DOB', () async {
      check(await storage.getDateOfBirth()).isNull();
      await storage.saveDateOfBirth('1996-05-15');
      check(await storage.getDateOfBirth()).equals('1996-05-15');
    });
  });

  group('Tanaka Max HR Formula & Age Calculation (Domain & Storage)', () {
    test(
      'calculateTanakaMaxHr computes expected bpm for known benchmark ages',
      () {
        // Age 20: 208 - (0.7 * 20) = 194 bpm
        check(DemographicsCalculator.calculateTanakaMaxHr(20)).equals(194);
        check(calculateTanakaMaxHr(20)).equals(194);
        check(PreferencesStorage.calculateTanakaMaxHr(20)).equals(194);

        // Age 30: 208 - (0.7 * 30) = 187 bpm
        check(DemographicsCalculator.calculateTanakaMaxHr(30)).equals(187);
        check(calculateTanakaMaxHr(30)).equals(187);
        check(PreferencesStorage.calculateTanakaMaxHr(30)).equals(187);

        // Age 45: 208 - (0.7 * 45) = 176.5 -> 177 bpm
        check(DemographicsCalculator.calculateTanakaMaxHr(45)).equals(177);
        check(calculateTanakaMaxHr(45)).equals(177);
        check(PreferencesStorage.calculateTanakaMaxHr(45)).equals(177);
      },
    );

    test('calculateTanakaMaxHr handles boundary ages', () {
      // Age 5: 208 - (0.7 * 5) = 204.5 -> 205 bpm
      check(DemographicsCalculator.calculateTanakaMaxHr(5)).equals(205);
      check(calculateTanakaMaxHr(5)).equals(205);

      // Age 50: 208 - (0.7 * 50) = 173 bpm
      check(DemographicsCalculator.calculateTanakaMaxHr(50)).equals(173);
      check(calculateTanakaMaxHr(50)).equals(173);

      // Age 120: 208 - (0.7 * 120) = 124 bpm
      check(DemographicsCalculator.calculateTanakaMaxHr(120)).equals(124);
      check(calculateTanakaMaxHr(120)).equals(124);
    });

    test('calculateAge computes exact elapsed years given reference date', () {
      final refDate = DateTime(2026, 10, 12);

      // Birthday already occurred this year
      check(
        DemographicsCalculator.calculateAge(DateTime(1996, 5, 15), refDate),
      ).equals(30);
      check(
        PreferencesStorage.calculateAge(DateTime(1996, 5, 15), refDate),
      ).equals(30);

      // Birthday is today
      check(
        DemographicsCalculator.calculateAge(DateTime(1996, 10, 12), refDate),
      ).equals(30);
      check(
        PreferencesStorage.calculateAge(DateTime(1996, 10, 12), refDate),
      ).equals(30);

      // Birthday has not yet occurred this year
      check(
        DemographicsCalculator.calculateAge(DateTime(1996, 11, 20), refDate),
      ).equals(29);
      check(
        PreferencesStorage.calculateAge(DateTime(1996, 11, 20), refDate),
      ).equals(29);
    });
  });
}
