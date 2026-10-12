import 'package:flutter_test/flutter_test.dart';
import 'package:checks/checks.dart';
import 'package:teman_lari/domain/entities/activity.dart';
import 'package:teman_lari/domain/usecases/training_load_calculator.dart';

void main() {
  group('TrainingLoadCalculator', () {
    late TrainingLoadCalculator calculator;

    setUp(() {
      calculator = TrainingLoadCalculator();
    });

    test('should return empty list when no activities', () {
      final result = calculator.computeLoadHistory(
        [],
        maxHr: 190,
        restingHr: 60,
      );
      check(result).isEmpty();
    });

    test(
      'should calculate CTL, ATL, and TSB correctly using standard Coggan decay',
      () {
        // Let's create an activity on Monday, 3 days ago relative to now.
        final now = DateTime.now();
        final monday = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 3));

        final activity = Activity(
          type: ActivityType.run,
          id: 1,
          name: 'Monday Run',
          date: monday,
          distanceKm: 5.0,
          movingTime: const Duration(
            minutes: 34,
          ), // 34 minutes, no HR means TSS = 34 * 0.83 = 28.22
          pace: const Duration(minutes: 6, seconds: 48),
          elevationGainM: 10,
          trainingLoad: TrainingLoad.moderate,
        );

        final result = calculator.computeLoadHistory(
          [activity],
          maxHr: 190,
          restingHr: 60,
        );

        // Verify history has points for each day up to today
        check(result.length).equals(4);

        // Day 0: Monday (run day)
        // Standard Coggan decay factor is 1/42 for CTL and 1/7 for ATL.
        // Day 0 (Monday):
        // CTL = 28.22 * (1/42) = 0.6719...
        // ATL = 28.22 * (1/7) = 4.0314...
        expect(result[0].fitness, closeTo(0.6719, 0.01));
        expect(result[0].fatigue, closeTo(4.0314, 0.01));

        // Day 1: Tuesday (decay day)
        // CTL = 0.6719 * (41/42) = 0.6559...
        // ATL = 4.0314 * (6/7) = 3.4555...
        expect(result[1].fitness, closeTo(0.6559, 0.01));
        expect(result[1].fatigue, closeTo(3.4555, 0.01));

        // Day 2: Wednesday (decay day)
        // CTL = 0.6559 * (41/42) = 0.6402...
        // ATL = 3.4555 * (6/7) = 2.9618...
        expect(result[2].fitness, closeTo(0.6402, 0.01));
        expect(result[2].fatigue, closeTo(2.9618, 0.01));

        // Day 3: Thursday (decay day - today)
        // CTL = 0.6402 * (41/42) = 0.6250...
        // ATL = 2.9618 * (6/7) = 2.5387...
        expect(result[3].fitness, closeTo(0.6250, 0.01));
        expect(result[3].fatigue, closeTo(2.5387, 0.01));
      },
    );

    group('calculateTss and RPE-based estimation', () {
      test('1 hour (3600s) run at RPE 8 yields TSS = 64.0', () {
        final activity = Activity(
          id: -101,
          name: 'Manual 1hr Tempo',
          date: DateTime.now(),
          type: ActivityType.run,
          distanceKm: 10.0,
          movingTime: const Duration(seconds: 3600),
          pace: const Duration(minutes: 6),
          elevationGainM: 0,
          trainingLoad: TrainingLoad.moderate,
          perceivedExertion: 8.0,
        );

        final tss = calculator.calculateTss(
          activity,
          maxHr: 190,
          restingHr: 60,
        );
        expect(tss, closeTo(64.0, 0.001));
      });

      test('30 mins (1800s) run at RPE 5 yields TSS = 12.5', () {
        final activity = Activity(
          id: -102,
          name: 'Manual 30min Recovery',
          date: DateTime.now(),
          type: ActivityType.run,
          distanceKm: 4.5,
          movingTime: const Duration(seconds: 1800),
          pace: const Duration(minutes: 6, seconds: 40),
          elevationGainM: 0,
          trainingLoad: TrainingLoad.easy,
          perceivedExertion: 5.0,
        );

        final tss = calculator.calculateTss(
          activity,
          maxHr: 190,
          restingHr: 60,
        );
        expect(tss, closeTo(12.5, 0.001));
      });

      test(
        'activities with RPE take precedence over pace fallback when HR is absent',
        () {
          // With threshold pace = 300s (5:00/km) and pace = 300s, pace IF = 1.0.
          // For 1 hour (3600s), pace formula would yield TSS = 1.0^2 * 1.0 * 100 = 100.0.
          // But with RPE = 8.0, RPE formula must take precedence and yield 64.0.
          final activity = Activity(
            id: -103,
            name: 'Manual Run with Pace and RPE',
            date: DateTime.now(),
            type: ActivityType.run,
            distanceKm: 12.0,
            movingTime: const Duration(seconds: 3600),
            pace: const Duration(seconds: 300),
            elevationGainM: 0,
            trainingLoad: TrainingLoad.hard,
            perceivedExertion: 8.0,
          );

          final tss = calculator.calculateTss(
            activity,
            maxHr: 190,
            restingHr: 60,
            thresholdPace: const Duration(seconds: 300),
          );
          expect(tss, closeTo(64.0, 0.001));
        },
      );

      test('activities with HR take precedence over RPE', () {
        // 1 hour run with HR = 150 bpm, maxHr = 200, restingHr = 60.
        // HR reserve = (150 - 60) / (200 - 60) = 90 / 140 = 0.642857
        // intensity factor = 0.642857 / 0.85 = 0.7563026
        // HR TSS = (0.7563026)^2 * 1.0 * 100 = 57.199
        // RPE = 8.0 would yield 64.0, but HR must take precedence.
        final activity = Activity(
          id: 104,
          name: 'GPS Run with HR and RPE',
          date: DateTime.now(),
          type: ActivityType.run,
          distanceKm: 10.0,
          movingTime: const Duration(seconds: 3600),
          pace: const Duration(minutes: 6),
          elevationGainM: 50,
          trainingLoad: TrainingLoad.moderate,
          avgHeartRate: 150.0,
          maxHeartRate: 175.0,
          perceivedExertion: 8.0,
        );

        final tss = calculator.calculateTss(
          activity,
          maxHr: 200,
          restingHr: 60,
        );
        expect(tss, closeTo(57.20, 0.05));
        expect(tss, isNot(closeTo(64.0, 0.01)));
      });

      test('clamps TSS to maximum 400.0', () {
        final extremeActivity = Activity(
          id: -105,
          name: 'Ultra Endurance Run',
          date: DateTime.now(),
          type: ActivityType.run,
          distanceKm: 80.0,
          movingTime: const Duration(hours: 10),
          pace: const Duration(minutes: 7, seconds: 30),
          elevationGainM: 1000,
          trainingLoad: TrainingLoad.veryHard,
          perceivedExertion: 10.0,
        );

        final tss = calculator.calculateTss(
          extremeActivity,
          maxHr: 190,
          restingHr: 60,
        );
        expect(tss, equals(400.0));
      });
    });

    test(
      'calculates on-device ATL (7-day), CTL (42-day), and TSB (form = CTL - ATL) decay across mixed GPS and manual runs',
      () {
        final now = DateTime.now();
        final day0 = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 3));
        final day1 = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 2));

        // Day 0: GPS run with HR (movingTime = 3600s, TSS ≈ 57.2)
        final gpsRun = Activity(
          id: 1,
          name: 'GPS Long Run',
          date: day0,
          type: ActivityType.run,
          distanceKm: 10.0,
          movingTime: const Duration(seconds: 3600),
          pace: const Duration(minutes: 6),
          elevationGainM: 20,
          trainingLoad: TrainingLoad.moderate,
          avgHeartRate: 150.0,
          maxHeartRate: 175.0,
        );

        // Day 1: Manual run with RPE 8 (movingTime = 3600s, TSS = 64.0)
        final manualRun = Activity(
          id: -2,
          name: 'Manual Treadmill Run',
          date: day1,
          type: ActivityType.run,
          distanceKm: 10.0,
          movingTime: const Duration(seconds: 3600),
          pace: const Duration(minutes: 6),
          elevationGainM: 0,
          trainingLoad: TrainingLoad.hard,
          perceivedExertion: 8.0,
          isLocal: true,
        );

        final history = calculator.computeLoadHistory(
          [gpsRun, manualRun],
          maxHr: 200,
          restingHr: 60,
        );

        // Exactly 4 points: day0, day1, day2 (rest), day3 (today)
        expect(history.length, equals(4));

        // Mathematical verification of exponential decay:
        // Day 0: TSS ≈ 57.20
        // CTL_0 = TSS * (1/42)
        // ATL_0 = TSS * (1/7)
        final tss0 = calculator.calculateTss(gpsRun, maxHr: 200, restingHr: 60);
        expect(history[0].fitness, closeTo(tss0 / 42.0, 0.001));
        expect(history[0].fatigue, closeTo(tss0 / 7.0, 0.001));
        expect(
          history[0].form,
          closeTo(history[0].fitness - history[0].fatigue, 0.001),
        );

        // Day 1: TSS = 64.0
        // CTL_1 = 64 * (1/42) + CTL_0 * (41/42)
        // ATL_1 = 64 * (1/7) + ATL_0 * (6/7)
        final expectedCtl1 =
            64.0 * (1.0 / 42.0) + history[0].fitness * (41.0 / 42.0);
        final expectedAtl1 =
            64.0 * (1.0 / 7.0) + history[0].fatigue * (6.0 / 7.0);
        expect(history[1].fitness, closeTo(expectedCtl1, 0.001));
        expect(history[1].fatigue, closeTo(expectedAtl1, 0.001));
        expect(
          history[1].form,
          closeTo(history[1].fitness - history[1].fatigue, 0.001),
        );

        // Day 2: Rest day (TSS = 0)
        final expectedCtl2 = history[1].fitness * (41.0 / 42.0);
        final expectedAtl2 = history[1].fatigue * (6.0 / 7.0);
        expect(history[2].fitness, closeTo(expectedCtl2, 0.001));
        expect(history[2].fatigue, closeTo(expectedAtl2, 0.001));
        expect(
          history[2].form,
          closeTo(history[2].fitness - history[2].fatigue, 0.001),
        );

        // Day 3: Today (TSS = 0)
        final expectedCtl3 = history[2].fitness * (41.0 / 42.0);
        final expectedAtl3 = history[2].fatigue * (6.0 / 7.0);
        expect(history[3].fitness, closeTo(expectedCtl3, 0.001));
        expect(history[3].fatigue, closeTo(expectedAtl3, 0.001));
        expect(
          history[3].form,
          closeTo(history[3].fitness - history[3].fatigue, 0.001),
        );

        // Verify TSB equals CTL - ATL dynamically
        for (final point in history) {
          expect(point.form, closeTo(point.fitness - point.fatigue, 0.0001));
        }
      },
    );
  });
}
