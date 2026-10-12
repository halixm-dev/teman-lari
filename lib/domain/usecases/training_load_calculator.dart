import '../entities/activity.dart';
import '../entities/running_stats.dart';

class TrainingLoadCalculator {
  /// Note: Running EMA from "first activity" means Fitness and Fatigue will be
  /// heavily suppressed for the first 6-8 weeks of a user's data (cold start problem).
  /// A seed value option could be implemented in the future for users importing historical data.
  List<TrainingLoadPoint> computeLoadHistory(
    List<Activity> sortedActivities, {
    required int maxHr,
    required int restingHr,
    Duration? thresholdPace,
  }) {
    if (sortedActivities.isEmpty) return [];

    final tssByDate = <DateTime, double>{};
    for (final a in sortedActivities) {
      final localDate = a.date.toLocal();
      final day = DateTime(localDate.year, localDate.month, localDate.day);
      final double dailyTss =
          (tssByDate[day] ?? 0) +
          calculateTss(
            a,
            maxHr: maxHr,
            restingHr: restingHr,
            thresholdPace: thresholdPace,
          );
      tssByDate[day] = dailyTss > 500.0 ? 500.0 : dailyTss;
    }

    final firstLocal = sortedActivities.first.date.toLocal();
    final first = DateTime(firstLocal.year, firstLocal.month, firstLocal.day);
    final now = DateTime.now();
    final last = DateTime(now.year, now.month, now.day);

    const fitnessDecay = 1 / 42, fatigueDecay = 1 / 7;
    double fitness = 0, fatigue = 0;
    final result = <TrainingLoadPoint>[];

    for (
      var d = first;
      !d.isAfter(last);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      final tss = tssByDate[d] ?? 0;
      fitness = tss * fitnessDecay + fitness * (1 - fitnessDecay);
      fatigue = tss * fatigueDecay + fatigue * (1 - fatigueDecay);
      result.add(
        TrainingLoadPoint(
          date: d,
          fitness: fitness,
          fatigue: fatigue,
          form: fitness - fatigue,
        ),
      );
    }

    return result;
  }

  /// Calculates Training Stress Score (TSS) for an activity.
  ///
  /// Precedence:
  /// 1. Heart rate reserve formula if [activity.avgHeartRate] is present.
  /// 2. Perceived exertion (RPE) estimation fallback if [activity.perceivedExertion] is present.
  /// 3. Threshold pace intensity factor if [thresholdPace] is present and [activity.pace] > 0.
  /// 4. Duration-based fallback: moving minutes * 0.83.
  ///
  /// Clamped to a maximum of 400.0.
  double calculateTss(
    Activity activity, {
    required int maxHr,
    required int restingHr,
    Duration? thresholdPace,
  }) {
    return _trainingStressScore(
      activity,
      maxHr: maxHr,
      restingHr: restingHr,
      thresholdPace: thresholdPace,
    );
  }

  double _trainingStressScore(
    Activity activity, {
    required int maxHr,
    required int restingHr,
    Duration? thresholdPace,
  }) {
    final hr = activity.avgHeartRate;
    final rpe = activity.perceivedExertion;
    final durationHours = activity.movingTime.inSeconds / 3600.0;
    double tss = 0.0;

    if (hr != null) {
      final hrr = maxHr - restingHr;
      final hrReserve = hrr > 0 ? (hr - restingHr) / hrr : 0.0;
      const thresholdHrReserve = 0.85;
      final intensityFactor = hrReserve / thresholdHrReserve;
      tss = intensityFactor * intensityFactor * durationHours * 100;
    } else if (rpe != null) {
      tss = durationHours * (rpe / 10.0) * (rpe / 10.0) * 100.0;
    } else if (thresholdPace != null && activity.pace.inSeconds > 0) {
      double ifPace = thresholdPace.inSeconds / activity.pace.inSeconds;
      if (ifPace > 1.5) ifPace = 1.5;
      tss = ifPace * ifPace * durationHours * 100;
    } else {
      tss = activity.movingTime.inMinutes * 0.83;
    }

    return tss > 400.0 ? 400.0 : tss;
  }

  int hrToZone(double hr, {required int maxHr, required int restingHr}) {
    final hrr = maxHr - restingHr;
    final hrAboveResting = hr - restingHr;
    final pct = hrr > 0 ? hrAboveResting / hrr : 0;
    if (pct < 0.60) return 1;
    if (pct < 0.70) return 2;
    if (pct < 0.80) return 3;
    if (pct < 0.90) return 4;
    return 5;
  }

  double computeAcwr(
    List<Activity> sortedActivities, {
    required int maxHr,
    required int restingHr,
    Duration? thresholdPace,
    int minAcwrDays = 28,
  }) {
    if (sortedActivities.isEmpty) return 1.0;
    final firstActivityDate = sortedActivities.first.date;
    final now = DateTime.now();
    if (now.difference(firstActivityDate).inDays < minAcwrDays) return 1.0;

    double acuteTss = 0;
    double chronicTss = 0;
    for (final a in sortedActivities) {
      final daysAgo = now.difference(a.date).inDays;
      if (daysAgo < 28 && daysAgo >= 0) {
        final tss = calculateTss(
          a,
          maxHr: maxHr,
          restingHr: restingHr,
          thresholdPace: thresholdPace,
        );
        chronicTss += tss;
        if (daysAgo < 7) {
          acuteTss += tss;
        }
      }
    }
    final chronicAvg = chronicTss / 4;
    if (chronicAvg == 0) return 1.0;
    return acuteTss / chronicAvg;
  }
}
