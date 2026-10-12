import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HrPreferences Demographics Baselines', () {
    test('effectiveMaxHr returns explicit maxHr when set', () {
      const prefs = HrPreferences(maxHr: 185, age: 30);
      expect(prefs.effectiveMaxHr, 185);
    });

    test(
      'effectiveMaxHr falls back to (220 - age) when maxHr is null and age is present',
      () {
        const prefs1 = HrPreferences(maxHr: null, age: 30);
        expect(prefs1.effectiveMaxHr, 190);

        const prefs2 = HrPreferences(maxHr: null, age: 25);
        expect(prefs2.effectiveMaxHr, 195);
      },
    );

    test(
      'effectiveMaxHr falls back to 190 when maxHr and age are both null',
      () {
        const prefs = HrPreferences(maxHr: null, age: null);
        expect(prefs.effectiveMaxHr, 190);
      },
    );

    test('thresholdPace returns Duration when thresholdPaceSeconds is set', () {
      const prefs = HrPreferences(thresholdPaceSeconds: 300);
      expect(prefs.thresholdPace, const Duration(seconds: 300));
    });

    test('thresholdPace returns null when thresholdPaceSeconds is null', () {
      const prefs = HrPreferences(thresholdPaceSeconds: null);
      expect(prefs.thresholdPace, isNull);
    });

    test('default restingHr is 60', () {
      const prefs = HrPreferences();
      expect(prefs.restingHr, 60);
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
      expect(restingHr, 60);
    });

    test(
      'saveRestingHr, getRestingHr and clearRestingHr work correctly',
      () async {
        await storage.saveRestingHr(52);
        expect(await storage.getRestingHr(), 52);

        await storage.clearRestingHr();
        expect(await storage.getRestingHr(), 60);
      },
    );

    test(
      'getMaxHr returns null by default, persists custom value, and clears',
      () async {
        expect(await storage.getMaxHr(), isNull);

        await storage.saveMaxHr(195);
        expect(await storage.getMaxHr(), 195);

        await storage.clearMaxHr();
        expect(await storage.getMaxHr(), isNull);
      },
    );

    test(
      'getThresholdPace returns null by default, persists custom value, and clears',
      () async {
        expect(await storage.getThresholdPace(), isNull);

        await storage.saveThresholdPace(285);
        expect(await storage.getThresholdPace(), 285);

        await storage.clearThresholdPace();
        expect(await storage.getThresholdPace(), isNull);
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
        expect(prefs.restingHr, 55);
        expect(prefs.maxHr, 188);
        expect(prefs.thresholdPaceSeconds, 290);
        expect(prefs.thresholdPace, const Duration(seconds: 290));
        expect(prefs.effectiveMaxHr, 188);
        expect(prefs.age, isNotNull);
      },
    );

    test(
      'hasCompletedOnboarding returns false by default when unset',
      () async {
        expect(await storage.hasCompletedOnboarding(), isFalse);
      },
    );

    test(
      'hasCompletedOnboarding returns false when explicitly stored as false',
      () async {
        SharedPreferences.setMockInitialValues({
          'has_completed_onboarding': false,
        });
        expect(await storage.hasCompletedOnboarding(), isFalse);
      },
    );

    test(
      'hasCompletedOnboarding returns true when explicitly stored as true',
      () async {
        SharedPreferences.setMockInitialValues({
          'has_completed_onboarding': true,
        });
        expect(await storage.hasCompletedOnboarding(), isTrue);
      },
    );

    test('setCompletedOnboarding defaults to true and persists flag', () async {
      await storage.setCompletedOnboarding();
      expect(await storage.hasCompletedOnboarding(), isTrue);
    });

    test('setCompletedOnboarding(false) updates flag to false', () async {
      await storage.setCompletedOnboarding(true);
      expect(await storage.hasCompletedOnboarding(), isTrue);

      await storage.setCompletedOnboarding(false);
      expect(await storage.hasCompletedOnboarding(), isFalse);
    });

    test('getDateOfBirth returns saved DOB', () async {
      expect(await storage.getDateOfBirth(), isNull);
      await storage.saveDateOfBirth('1996-05-15');
      expect(await storage.getDateOfBirth(), '1996-05-15');
    });
  });

  group('Tanaka Max HR Formula & Age Calculation', () {
    test(
      'calculateTanakaMaxHr computes expected bpm for known benchmark ages',
      () {
        // Age 20: 208 - (0.7 * 20) = 194 bpm
        expect(calculateTanakaMaxHr(20), 194);
        expect(PreferencesStorage.calculateTanakaMaxHr(20), 194);

        // Age 30: 208 - (0.7 * 30) = 187 bpm
        expect(calculateTanakaMaxHr(30), 187);
        expect(PreferencesStorage.calculateTanakaMaxHr(30), 187);

        // Age 45: 208 - (0.7 * 45) = 176.5 -> 177 bpm
        expect(calculateTanakaMaxHr(45), 177);
        expect(PreferencesStorage.calculateTanakaMaxHr(45), 177);
      },
    );

    test('calculateTanakaMaxHr handles boundary ages', () {
      // Age 5: 208 - (0.7 * 5) = 204.5 -> 205 bpm
      expect(calculateTanakaMaxHr(5), 205);

      // Age 50: 208 - (0.7 * 50) = 173 bpm
      expect(calculateTanakaMaxHr(50), 173);

      // Age 120: 208 - (0.7 * 120) = 124 bpm
      expect(calculateTanakaMaxHr(120), 124);
    });

    test('calculateAge computes exact elapsed years given reference date', () {
      final refDate = DateTime(2026, 10, 12);

      // Birthday already occurred this year
      expect(
        PreferencesStorage.calculateAge(DateTime(1996, 5, 15), refDate),
        30,
      );

      // Birthday is today
      expect(
        PreferencesStorage.calculateAge(DateTime(1996, 10, 12), refDate),
        30,
      );

      // Birthday has not yet occurred this year
      expect(
        PreferencesStorage.calculateAge(DateTime(1996, 11, 20), refDate),
        29,
      );
    });
  });
}
