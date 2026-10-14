import 'package:json_annotation/json_annotation.dart';
import '../snapshot_store.dart';
import 'archive_profile.dart';

part 'training_plan_section.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class TrainingPlanArchive {
  final List<TrainingPlanArchiveRecord> plans;
  final ArchivePreference weekInCycle;
  final ArchivePreference cycleStartDate;
  final DateTime? modifiedAt;
  const TrainingPlanArchive({
    required this.plans,
    required this.weekInCycle,
    required this.cycleStartDate,
    required this.modifiedAt,
  });
  int get recordCount => plans.length;
  factory TrainingPlanArchive.fromJson(Map<String, dynamic> json) =>
      _$TrainingPlanArchiveFromJson(json);
  Map<String, dynamic> toJson() => _$TrainingPlanArchiveToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class TrainingPlanArchiveRecord {
  final String id;
  const TrainingPlanArchiveRecord({required this.id});
  factory TrainingPlanArchiveRecord.fromJson(Map<String, dynamic> json) =>
      _$TrainingPlanArchiveRecordFromJson(json);
  Map<String, dynamic> toJson() => _$TrainingPlanArchiveRecordToJson(this);
}

class TrainingPlanSectionCodec {
  const TrainingPlanSectionCodec();
  TrainingPlanArchive encode(LocalSnapshot snapshot) {
    final records = snapshot.stores['training_plans'];
    if (records == null || records.isNotEmpty) {
      throw StateError('Stored Training Plans cannot yet be exported safely.');
    }
    final prefs = snapshot.stores['preferences'] ?? {};
    return TrainingPlanArchive(
      plans: [],
      weekInCycle: archivePreference(prefs, 'week_in_cycle'),
      cycleStartDate: archivePreference(prefs, 'cycle_start_date'),
      modifiedAt: null,
    );
  }
}
