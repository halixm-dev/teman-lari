import 'dart:convert';
import '../../domain/entities/activity.dart';
import '../../domain/entities/rehab_feedback.dart';
import '../../domain/entities/rehab_journal.dart';
import '../models/activity_model.dart';
import '../backup/snapshot_store.dart';
import '../backup/archive/training_plan_section.dart';

RehabJournal rehabJournalFromSnapshot(LocalSnapshot snapshot) => RehabJournal(
  program: const TrainingPlanSectionCodec().encode(snapshot).rehabilitation,
  activities: [
    for (final row in (snapshot.stores['activities'] ?? {}).values)
      if (_model(row).type == 'Run') _run(_model(row)),
  ],
  feedback: [
    for (final row in (snapshot.stores['rehab_feedback'] ?? {}).values)
      RehabFeedback.fromJson(Map<String, dynamic>.from(row as Map)),
  ],
);

ActivityModel _model(Object? row) => ActivityModel.fromJson(
  jsonDecode((row as Map)['data'] as String) as Map<String, dynamic>,
);

/// The journal needs run identity/timing; training-load analytics use the repo.
Activity _run(ActivityModel model) => Activity(
  id: model.id,
  name: model.name,
  date: DateTime.parse(model.startDate).toLocal(),
  type: ActivityType.run,
  distanceKm: model.distance / 1000,
  movingTime: Duration(seconds: model.movingTime),
  pace: model.averageSpeed > 0
      ? Duration(seconds: (1000 / model.averageSpeed).round())
      : Duration.zero,
  elevationGainM: model.totalElevationGain,
  trainingLoad: TrainingLoad.moderate,
);
