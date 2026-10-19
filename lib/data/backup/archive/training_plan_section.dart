import 'package:json_annotation/json_annotation.dart';
import '../snapshot_store.dart';
import 'archive_profile.dart';
import 'training_plan_content_archive.dart';
import 'training_plan_config_archive.dart';
import 'training_plan_validation.dart';
import '../../../domain/entities/rehab_program.dart';

part 'training_plan_section.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class TrainingPlanArchive {
  final List<TrainingPlanArchiveRecord> plans;
  final String? activePlanId;
  final TrainingPlanConfigArchive? configuration;
  final ArchivePreference weekInCycle;
  final ArchivePreference cycleStartDate;
  final DateTime? modifiedAt;
  @JsonKey(includeIfNull: false)
  final RehabProgram? rehabilitation;
  const TrainingPlanArchive({
    required this.plans,
    required this.activePlanId,
    required this.configuration,
    required this.weekInCycle,
    required this.cycleStartDate,
    required this.modifiedAt,
    this.rehabilitation,
  });
  int get recordCount => plans.length;
  factory TrainingPlanArchive.fromJson(Map<String, dynamic> json) {
    validateTrainingPlanMetadata(json);
    final state = _$TrainingPlanArchiveFromJson(json);
    validateTrainingCycle(state);
    if (state.plans.isNotEmpty && state.configuration == null ||
        state.plans.length > 1 ||
        state.plans.any((plan) => plan.id.isEmpty) ||
        (state.plans.isEmpty
            ? state.activePlanId != null
            : state.activePlanId != state.plans.single.id)) {
      throw StateError('Invalid active Training Plan.');
    }
    if (state.modifiedAt case final timestamp?) {
      if (!timestamp.isUtc) {
        throw StateError('Plan modification time must be UTC.');
      }
    }
    return state;
  }
  Map<String, dynamic> toJson() => _$TrainingPlanArchiveToJson(this);

  TrainingPlanArchive withRehabilitation(RehabProgram program, DateTime time) =>
      TrainingPlanArchive(
        plans: plans,
        activePlanId: activePlanId,
        configuration: configuration,
        weekInCycle: weekInCycle,
        cycleStartDate: cycleStartDate,
        modifiedAt: time.toUtc(),
        rehabilitation: program,
      );
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class TrainingPlanArchiveRecord {
  final String id;
  final TrainingPlanContentArchive plan;
  const TrainingPlanArchiveRecord({required this.id, required this.plan});
  factory TrainingPlanArchiveRecord.fromJson(Map<String, dynamic> json) =>
      _$TrainingPlanArchiveRecordFromJson(json);
  Map<String, dynamic> toJson() => _$TrainingPlanArchiveRecordToJson(this);
}

class TrainingPlanSectionCodec {
  const TrainingPlanSectionCodec();
  TrainingPlanArchive encode(LocalSnapshot snapshot) {
    final records = snapshot.stores['training_plans'];
    if (records == null) throw StateError('Missing Training Plan store.');
    final prefs = snapshot.stores['preferences'] ?? {};
    validatePlanInstant(prefs['cycle_start_date'], requireUtc: false);
    validatePlanInstant(prefs['cycle_start_date_modified_at']);
    validatePlanInstant(prefs['week_in_cycle_modified_at']);
    if (records.isEmpty) {
      return TrainingPlanArchive(
        plans: [],
        activePlanId: null,
        configuration: null,
        weekInCycle: archivePreference(prefs, 'week_in_cycle'),
        cycleStartDate: archivePreference(prefs, 'cycle_start_date'),
        modifiedAt: null,
      );
    }
    try {
      if (records.length != 1 || !records.containsKey('active_state')) {
        throw StateError('Unsupported stored Training Plan.');
      }
      return TrainingPlanArchive.fromJson(
        Map<String, dynamic>.from(records['active_state'] as Map),
      );
    } catch (error) {
      throw StateError('Stored Training Plan is invalid: $error');
    }
  }

  /// Validated imports replace the whole coherent unit, including its mirrors.
  Map<String, Object?> decode(TrainingPlanArchive archive) => {
    'active_state': TrainingPlanArchive.fromJson(archive.toJson()).toJson(),
  };

  Map<String, Object?> cyclePreferences(TrainingPlanArchive archive) {
    final values = <String, Object?>{};
    for (final entry in {
      'week_in_cycle': archive.weekInCycle,
      'cycle_start_date': archive.cycleStartDate,
    }.entries) {
      if (entry.value.value case final value?) values[entry.key] = value;
      if (entry.value.modifiedAt case final time?) {
        values['${entry.key}_modified_at'] = time.toUtc().toIso8601String();
      }
    }
    return values;
  }
}

void validateTrainingCycle(TrainingPlanArchive state) {
  for (final entry in {
    'week_in_cycle': state.weekInCycle,
    'cycle_start_date': state.cycleStartDate,
  }.entries) {
    final time = entry.value.modifiedAt;
    if (time != null && !time.isUtc) {
      throw StateError('Cycle modification time must be UTC.');
    }
    archivePreference({
      entry.key: entry.value.value,
      if (time != null) '${entry.key}_modified_at': time.toIso8601String(),
    }, entry.key);
  }
}
