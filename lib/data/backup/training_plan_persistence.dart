import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/training_plan.dart';
import '../../domain/usecases/training_plan_config.dart';
import '../datasources/preferences_storage.dart';
import 'snapshot_backup_service.dart';
import 'archive/archive_profile.dart';
import 'archive/training_plan_section.dart';
import 'archive/training_plan_content_archive.dart';
import 'archive/training_plan_config_archive.dart';

/// Remembers current inputs only after loading saved state. An imported plan is
/// authoritative on first read, even if its source activities differ locally.
class TrainingPlanPersistence {
  final SnapshotBackupService service;
  String? _inputs;
  String? _stored;
  String? _configurationInput;
  int _epoch = 0;
  TrainingPlanPersistence(this.service);

  Future<TrainingPlanArchive?> _read() => service.coordinator.read(() async {
    final box = Hive.isBoxOpen('training_plans')
        ? Hive.box('training_plans')
        : await Hive.openBox('training_plans');
    final raw = box.get('active_state');
    return raw == null
        ? null
        : TrainingPlanArchive.fromJson(
            Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)) as Map),
          );
  });

  Future<TrainingPlan> resolve({
    required String inputs,
    required TrainingPlanConfig configuration,
    required Future<TrainingPlan> Function(TrainingPlanConfig) generate,
  }) async {
    if (!service.coordinator.initialized) return generate(configuration);
    final epoch = _epoch;
    final saved = await _read();
    if (epoch != _epoch) return _restoredPlan();
    final stored = saved == null ? null : jsonEncode(saved.toJson());
    final plan = saved?.plans.firstOrNull;
    final configInput = jsonEncode(
      TrainingPlanConfigArchive.fromDomain(configuration).toJson(),
    );
    if (plan != null &&
        (_inputs == null || _stored != stored || _inputs == inputs)) {
      _inputs = inputs;
      _configurationInput = configInput;
      _stored = stored;
      return plan.plan.toDomain();
    }
    return _generateAndSave(
      inputs,
      configuration,
      generate,
      saved,
      configInput,
      epoch,
    );
  }

  Future<TrainingPlan> _generateAndSave(
    String inputs,
    TrainingPlanConfig configuration,
    Future<TrainingPlan> Function(TrainingPlanConfig) generate,
    TrainingPlanArchive? saved,
    String configInput,
    int epoch,
  ) async {
    final revision = service.coordinator.revision;
    final effectiveConfig =
        _configurationInput != null && _configurationInput != configInput
        ? configuration
        : saved?.configuration?.toDomain() ?? configuration;
    final generated = await generate(effectiveConfig);
    if (epoch != _epoch) return _restoredPlan();
    if (revision != service.coordinator.revision) {
      return resolve(
        inputs: inputs,
        configuration: configuration,
        generate: generate,
      );
    }
    try {
      await _save(generated, effectiveConfig, revision);
    } on SnapshotRevisionConflict {
      if (epoch != _epoch) return _restoredPlan();
      return resolve(
        inputs: inputs,
        configuration: configuration,
        generate: generate,
      );
    }
    final current = await _read();
    if (epoch != _epoch) return _restoredPlan();
    _inputs = inputs;
    _configurationInput = configInput;
    _stored = jsonEncode(current?.toJson());
    return generated;
  }

  Future<void> _save(
    TrainingPlan plan,
    TrainingPlanConfig config,
    int revision,
  ) async {
    await service.transformLocalState((snapshot) {
      final prefs = snapshot.stores['preferences'] ?? {};
      final timestamp = service.clock().toUtc();
      _initializeCycle(prefs, plan, timestamp);
      snapshot.stores['preferences'] = prefs;
      final state = TrainingPlanArchive(
        plans: [
          TrainingPlanArchiveRecord(
            id: 'active',
            plan: TrainingPlanContentArchive.fromDomain(plan),
          ),
        ],
        activePlanId: 'active',
        configuration: TrainingPlanConfigArchive.fromDomain(config),
        weekInCycle: archivePreference(prefs, 'week_in_cycle'),
        cycleStartDate: archivePreference(prefs, 'cycle_start_date'),
        modifiedAt: timestamp,
      );
      snapshot.stores['training_plans'] = const TrainingPlanSectionCodec()
          .decode(state);
      return snapshot;
    }, expectedRevision: revision);
  }

  void _initializeCycle(
    Map<String, Object?> preferences,
    TrainingPlan plan,
    DateTime timestamp,
  ) {
    final initialValues = {
      'cycle_start_date': timestamp.toIso8601String(),
      'week_in_cycle': plan.weekInCycle < 0 ? 0 : plan.weekInCycle,
    };
    for (final entry in initialValues.entries) {
      if (preferences.containsKey(entry.key) ||
          preferences.containsKey('${entry.key}_modified_at')) {
        continue;
      }
      preferences[entry.key] = entry.value;
      preferences['${entry.key}_modified_at'] = timestamp.toIso8601String();
    }
  }

  Future<TrainingPlan> _restoredPlan() async {
    final epoch = _epoch;
    final saved = await _read();
    if (epoch != _epoch) return _restoredPlan();
    final plan = saved?.plans.firstOrNull;
    if (plan == null) throw SnapshotRevisionConflict();
    return plan.plan.toDomain();
  }

  void resetBaseline() {
    _epoch++;
    _inputs = null;
    _stored = null;
    _configurationInput = null;
  }

  Future<void> resetCycle(DateTime date) async {
    await service.transformLocalState((snapshot) {
      final timestamp = service.clock().toUtc();
      final state = TrainingPlanArchive(
        plans: [],
        activePlanId: null,
        configuration: const TrainingPlanSectionCodec()
            .encode(snapshot)
            .configuration,
        weekInCycle: ArchivePreference(value: 0, modifiedAt: timestamp),
        cycleStartDate: ArchivePreference(
          value: date.toUtc().toIso8601String(),
          modifiedAt: timestamp,
        ),
        modifiedAt: timestamp,
      );
      final prefs = snapshot.stores['preferences'] ?? {};
      prefs.addAll(const TrainingPlanSectionCodec().cyclePreferences(state));
      snapshot.stores['preferences'] = prefs;
      snapshot.stores['training_plans'] = const TrainingPlanSectionCodec()
          .decode(state);
      return snapshot;
    });
    resetBaseline();
  }
}

final _persistence = Expando<TrainingPlanPersistence>();

extension TrainingPlanBackupOperations on SnapshotBackupService {
  TrainingPlanPersistence get _plans =>
      _persistence[this] ??= TrainingPlanPersistence(this);

  void resetTrainingPlanBaseline() => _persistence[this]?.resetBaseline();

  Future<TrainingPlan> resolveTrainingPlan({
    required String inputs,
    required TrainingPlanConfig configuration,
    required Future<TrainingPlan> Function(TrainingPlanConfig) generate,
  }) => _plans.resolve(
    inputs: inputs,
    configuration: configuration,
    generate: generate,
  );

  Future<void> resetTrainingCycle(DateTime date) async {
    if (!coordinator.initialized) {
      await PreferencesStorage(
        coordinator: coordinator,
        clock: clock,
      ).setCycleStartDate(date);
      return;
    }
    await _plans.resetCycle(date);
  }
}
