enum ActivityType { run, ride, swim, workout, walk, other }

enum TrainingLoad { easy, moderate, hard, veryHard }

class Activity {
  final int id;
  final String name;
  final DateTime date;
  final ActivityType type;
  final double distanceKm;
  final Duration movingTime;
  final Duration pace;
  final double? avgHeartRate;
  final double? maxHeartRate;
  final double elevationGainM;
  final double? avgCadence;
  final int? sufferScore;
  final TrainingLoad trainingLoad;
  final List<double>? heartRateData;
  final bool? _isLocal;

  const Activity({
    required this.id,
    required this.name,
    required this.date,
    required this.type,
    required this.distanceKm,
    required this.movingTime,
    required this.pace,
    required this.elevationGainM,
    required this.trainingLoad,
    this.avgHeartRate,
    this.maxHeartRate,
    this.avgCadence,
    this.sufferScore,
    this.heartRateData,
    bool? isLocal,
  }) : _isLocal = isLocal;

  bool get isLocal => _isLocal ?? (id < 0);
  String get syncStatusLabel => isLocal ? 'Local' : 'Strava';

  String get paceString {
    final totalSeconds = pace.inSeconds;
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')} /km';
  }
}
