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
  });
}
