import 'dart:convert';
import 'dart:async';
import 'package:teman_lari/domain/entities/training_plan.dart';
import 'package:teman_lari/domain/entities/running_stats.dart';
import 'package:teman_lari/domain/entities/run_walk_phase.dart';
import 'dart:io';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'package:teman_lari/data/backup/archive/training_plan_config_archive.dart';
import 'package:teman_lari/domain/usecases/training_plan_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SnapshotBackupService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('plan_archive_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({});
    service = SnapshotBackupService(coordinator: LocalDataCoordinator());
    await service.initialize();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test('plan storage failure propagates without repeated generation', () async {
    var generations = 0;
    final failing = SnapshotBackupService(
      coordinator: service.coordinator,
      checkAvailableSpace: (_) async => false,
    );
    final result = failing.resolveTrainingPlan(
      inputs: 'new plan',
      configuration: TrainingPlanConfig.defaultConfig,
      generate: (_) async {
        generations++;
        if (generations > 1) throw StateError('Unexpected regeneration');
        return detailedPlan();
      },
    );
    await check(result).throws<StateError>();
    check(generations).equals(1);
    check((await service.readBackupCounts())['training_plans']).equals(0);
  });
  test(
    'unknown Training Plan store records cannot replace local state',
    () async {
      final snapshot = await service.readLocalState();
      snapshot.stores['training_plans'] = {'unsupported': 'invalid'};
      await check(
        service.applyLocalState(snapshot, expectedRevision: snapshot.revision),
      ).throws<StateError>();
      check((await service.readBackupCounts())['training_plans']).equals(0);
    },
  );
  test('invalid cycle instants cannot replace local state', () async {
    for (final invalid in [
      '2026-10-14T12:30:00+99:99',
      '2026-10-14T12:30:00+07:90',
      '2026-10-14T24:00:00Z',
      '2026-02-31T12:30:00Z',
    ]) {
      final snapshot = await service.readLocalState();
      snapshot.stores['preferences'] = {'cycle_start_date': invalid};
      await check(
        service.applyLocalState(snapshot, expectedRevision: snapshot.revision),
      ).throws<StateError>();
    }
  });
  test(
    'legacy local cycle exports UTC without changing saved recency',
    () async {
      final snapshot = await service.readLocalState();
      snapshot.stores['preferences'] = {
        'cycle_start_date': '2026-10-14T12:30:00',
        'cycle_start_date_modified_at': '2026-10-10T00:00:00.000Z',
      };
      await service.applyLocalState(
        snapshot,
        expectedRevision: snapshot.revision,
      );
      final before = (await service.readLocalState()).stores['preferences'];
      final state = await exportedPlan(service);
      check(
        (state['cycle_start_date'] as Map)['value'],
      ).equals(DateTime(2026, 10, 14, 12, 30).toUtc().toIso8601String());
      check(
        (state['cycle_start_date'] as Map)['modified_at'],
      ).equals('2026-10-10T00:00:00.000Z');
      await Hive.close();
      Hive.init(directory.path);
      final reopened = SnapshotBackupService(
        coordinator: LocalDataCoordinator(),
      );
      await reopened.initialize();
      check(
        (await reopened.readLocalState()).stores['preferences'],
      ).isNotNull().deepEquals(before ?? {});
      check(await exportedPlan(reopened)).deepEquals(state);
    },
  );
  test('first generation establishes a stable cycle across reopen', () async {
    final timed = SnapshotBackupService(
      coordinator: service.coordinator,
      clock: () => DateTime.utc(2026, 10, 14),
    );
    await timed.resolveTrainingPlan(
      inputs: 'initial',
      configuration: TrainingPlanConfig.defaultConfig,
      generate: (_) async => TrainingPlan.empty(),
    );
    final state = await exportedPlan(timed);
    check(
      (state['cycle_start_date'] as Map)['value'],
    ).equals('2026-10-14T00:00:00.000Z');
    check((state['week_in_cycle'] as Map)['value']).equals(0);
    check(
      (state['cycle_start_date'] as Map)['modified_at'],
    ).equals(state['modified_at']);
    await Hive.close();
    Hive.init(directory.path);
    final reopened = SnapshotBackupService(
      coordinator: LocalDataCoordinator(),
      clock: () => DateTime.utc(2026, 10, 28),
    );
    await reopened.initialize();
    check(await exportedPlan(reopened)).deepEquals(state);
    check(
      (await reopened.readLocalState())
          .stores['preferences']?['cycle_start_date'],
    ).equals('2026-10-14T00:00:00.000Z');
  });
  test(
    'ordinary generation preserves explicitly cleared cycle fields',
    () async {
      final snapshot = await service.readLocalState();
      snapshot.stores['preferences'] = {
        'cycle_start_date_modified_at': '2026-10-01T00:00:00.000Z',
        'week_in_cycle_modified_at': '2026-10-01T00:00:00.000Z',
      };
      await service.applyLocalState(
        snapshot,
        expectedRevision: snapshot.revision,
      );
      await service.resolveTrainingPlan(
        inputs: 'cleared state',
        configuration: TrainingPlanConfig.defaultConfig,
        generate: (_) async => TrainingPlan.empty(),
      );
      final state = await exportedPlan(service);
      check((state['cycle_start_date'] as Map)['value']).isNull();
      check(
        (state['cycle_start_date'] as Map)['modified_at'],
      ).equals('2026-10-01T00:00:00.000Z');
      check((state['week_in_cycle'] as Map)['value']).isNull();
    },
  );
  test('saved empty plan is present, unlike absent plan state', () async {
    final before = await service.readLocalState();
    before.stores['training_plans'] = {'active_state': emptyPlanState()};
    await service.applyLocalState(before, expectedRevision: before.revision);
    final archive =
        jsonDecode(utf8.decode((await service.prepareExport()).bytes)) as Map;
    check((archive['counts'] as Map)['training_plan_state']).equals(1);
    final state = (archive['data'] as Map)['training_plan_state'] as Map;
    check(state['active_plan_id']).equals('active');
    check(state['modified_at']).isNull();
    check(
      ((state['plans'] as List).single as Map)['plan'] as Map,
    ).containsKey('days');
  });
  test(
    'full plan survives export, durable apply, and reopen without generation',
    () async {
      await service.resolveTrainingPlan(
        inputs: 'initial',
        configuration: const TrainingPlanConfig(longRunFraction: 0.4),
        generate: (_) async => detailedPlan(),
      );
      final exported = await exportedPlan(service);
      check(exported['modified_at']).isNotNull();
      final plan = ((exported['plans'] as List).single as Map)['plan'] as Map;
      check(plan['start_date']).equals('2026-10-14');
      final day = (plan['days'] as List).first as Map;
      check(day['estimated_duration']).equals(1800.123456);
      check((day['pace_target'] as Map)['fastest_pace']).equals(300.000001);
      check(
        ((day['intervals'] as List).single as Map)['duration'],
      ).equals(90.000002);
      check((day['run_walk_phase'] as Map)['run_seconds']).equals(77);
      check(
        ((exported['configuration'] as Map)['long_run_fraction']),
      ).equals(0.4);
      final snapshot = await service.readLocalState();
      snapshot.stores['training_plans'] = {
        'active_state': Map<String, Object?>.from(exported),
      };
      await service.applyLocalState(
        snapshot,
        expectedRevision: snapshot.revision,
      );
      await Hive.close();
      Hive.init(directory.path);
      final reopened = SnapshotBackupService(
        coordinator: LocalDataCoordinator(),
      );
      await reopened.initialize();
      final restored = await reopened.resolveTrainingPlan(
        inputs: 'different device',
        configuration: TrainingPlanConfig.defaultConfig,
        generate: (_) async => throw StateError('Saved plan must be loaded'),
      );
      check(restored.goal).equals('My saved plan');
      check(
        restored.days.first.estimatedDuration?.inMicroseconds,
      ).equals(1800123456);
      check(restored.days[1].intervals).isNull();
      check(restored.days[2].intervals).isNotNull().which((it) => it.isEmpty());
      check(await exportedPlan(reopened)).deepEquals(exported);
    },
  );
  test('invalid nested plan cannot replace any local state', () async {
    for (final mutation in <void Function(Map)>[
      (plan) => plan['cycle_phase'] = 'future_phase',
      (plan) => plan['start_date'] = '2026-02-31',
      (plan) => plan['week_in_cycle'] = 2.5,
      (plan) => plan['days'] = [
        {
          'date': '2026-10-14',
          'type': 'easy',
          'description': 'Invalid duration',
          'estimated_duration': -2,
        },
      ],
    ]) {
      final before = await service.readLocalState();
      final state = emptyPlanState();
      mutation(((state['plans'] as List).single as Map)['plan'] as Map);
      final next = LocalSnapshot(
        revision: before.revision,
        stores: {
          ...before.stores,
          'training_plans': {'active_state': state},
        },
      );
      await check(
        service.applyLocalState(next, expectedRevision: before.revision),
      ).throws<StateError>();
      check((await service.readLocalState()).stores).deepEquals(before.stores);
    }
  });
  test(
    'reset preserves configuration and changes one coherent cycle unit',
    () async {
      final timed = SnapshotBackupService(
        coordinator: service.coordinator,
        clock: () => DateTime.utc(2026, 10, 15),
      );
      await timed.resolveTrainingPlan(
        inputs: 'initial',
        configuration: const TrainingPlanConfig(longRunFraction: 0.4),
        generate: (_) async => detailedPlan(),
      );
      final before = await timed.readLocalState();
      await timed.resetTrainingCycle(DateTime.utc(2026, 10, 15));
      final state = await exportedPlan(timed);
      check(state['plans'] as List).isEmpty();
      check(state['modified_at']).equals('2026-10-15T00:00:00.000Z');
      check((state['configuration'] as Map)['long_run_fraction']).equals(0.4);
      check((state['week_in_cycle'] as Map)['value']).equals(0);
      final next = await timed.readLocalState();
      check(
        next.stores['preferences']?['athlete_name_modified_at'],
      ).equals(before.stores['preferences']?['athlete_name_modified_at']);
      final regenerated = await timed.resolveTrainingPlan(
        inputs: 'reset',
        configuration: TrainingPlanConfig.defaultConfig,
        generate: (config) async {
          check(config.longRunFraction).equals(0.4);
          return TrainingPlan.empty();
        },
      );
      check(regenerated.days).isEmpty();
    },
  );
  test(
    'delayed generator cannot overwrite a concurrently restored plan',
    () async {
      final pending = Completer<TrainingPlan>();
      final started = Completer<void>();
      final future = service.resolveTrainingPlan(
        inputs: 'old inputs',
        configuration: TrainingPlanConfig.defaultConfig,
        generate: (_) {
          started.complete();
          return pending.future;
        },
      );
      await started.future;
      final snapshot = await service.readLocalState();
      snapshot.stores['training_plans'] = {'active_state': emptyPlanState()};
      await service.applyLocalState(
        snapshot,
        expectedRevision: snapshot.revision,
      );
      pending.complete(detailedPlan());
      check((await future).goal).equals('Saved goal');
      check((await exportedPlan(service))['modified_at']).isNull();
    },
  );
}

Map<String, Object?> emptyPlanState() => {
  'plans': [
    {
      'id': 'active',
      'plan': {
        'start_date': '2026-10-14',
        'days': [],
        'goal': 'Saved goal',
        'description': 'Saved description',
        'week_in_cycle': -1,
        'cycle_phase': 'beginner',
      },
    },
  ],
  'active_plan_id': 'active',
  'configuration': TrainingPlanConfigArchive.fromDomain(
    const TrainingPlanConfig(longRunFraction: 0.4),
  ).toJson(),
  'week_in_cycle': {'value': null, 'modified_at': null},
  'cycle_start_date': {'value': null, 'modified_at': null},
  'modified_at': null,
};

Future<Map> exportedPlan(SnapshotBackupService service) async {
  final archive =
      jsonDecode(utf8.decode((await service.prepareExport()).bytes)) as Map;
  return (archive['data'] as Map)['training_plan_state'] as Map;
}

TrainingPlan detailedPlan() => TrainingPlan(
  startDate: DateTime(2026, 10, 14, 23, 59),
  goal: 'My saved plan',
  description: 'Full details',
  weekInCycle: 3,
  cyclePhase: CyclePhase.returning,
  days: [
    TrainingDay(
      date: DateTime(2026, 10, 14),
      type: WorkoutType.intervals,
      description: 'Exact workout',
      targetMinutes: 30,
      warmUpMinutes: 5,
      coolDownMinutes: 5,
      estimatedDuration: const Duration(microseconds: 1800123456),
      paceTarget: const PaceZone(
        slowestPace: Duration(seconds: 360),
        fastestPace: Duration(microseconds: 300000001),
        label: 'Target pace',
      ),
      heartRateTarget: const HrZone(
        minBpm: 120,
        maxBpm: 150,
        zoneNumber: 2,
        label: 'Aerobic',
      ),
      intervals: [
        const IntervalPhase(
          type: IntervalPhaseType.work,
          duration: Duration(microseconds: 90000002),
        ),
      ],
      runWalkPhase: const RunWalkPhase(
        type: RunWalkPhaseType.phase2,
        runSeconds: 77,
        walkSeconds: 44,
        totalDurationMinutes: 30,
        label: 'Custom ratio',
      ),
    ),
    TrainingDay(
      date: DateTime(2026, 10, 15),
      type: WorkoutType.rest,
      description: 'Rest',
    ),
    TrainingDay(
      date: DateTime(2026, 10, 16),
      type: WorkoutType.walk,
      description: 'Walk',
      intervals: [],
    ),
  ],
);
