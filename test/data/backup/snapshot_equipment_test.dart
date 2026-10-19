import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'package:teman_lari/data/backup/archive/snapshot_archive.dart';
import 'package:teman_lari/data/datasources/local_activity_datasource.dart';
import 'package:teman_lari/data/datasources/local_equipment_datasource.dart';
import 'package:teman_lari/domain/entities/shoe_equipment.dart';
import 'snapshot_archive_export_test.dart' show activity;
import '../repositories/activity_repository_impl_test.dart'
    show FakeStravaActivityDataSource;
import 'package:teman_lari/data/repositories/activity_repository_impl.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
import 'package:teman_lari/domain/entities/activity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SnapshotBackupService service;
  final editedAt = DateTime.utc(2026, 10, 14, 1, 2, 3);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('backup_equipment_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({});
    service = SnapshotBackupService(coordinator: LocalDataCoordinator());
    await service.initialize();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test(
    'shoe assignments survive export, durable application and reopen',
    () async {
      final equipment = LocalEquipmentDataSource(
        coordinator: service.coordinator,
        clock: () => editedAt,
      );
      await equipment.save(
        const ShoeEquipment(
          id: 'shoe-1',
          name: 'Everyday pair',
          category: ShoeCategory.dailyTrainer,
          foamChemistry: FoamChemistry.traditionalEva,
          lifecycleTargetMeters: 700000,
          performanceTargetMeters: 400000,
        ),
      );
      final local = LocalActivityDataSource(coordinator: service.coordinator);
      final repository = ActivityRepositoryImpl(
        remoteDataSource: FakeStravaActivityDataSource(),
        localDataSource: local,
        preferencesStorage: PreferencesStorage(
          coordinator: service.coordinator,
        ),
      );
      await repository.saveActivity(
        Activity(
          id: -7,
          name: 'Run',
          date: DateTime.utc(2026, 10, 13),
          type: ActivityType.run,
          distanceKm: 5,
          movingTime: const Duration(minutes: 30),
          pace: const Duration(minutes: 6),
          elevationGainM: 0,
          trainingLoad: TrainingLoad.easy,
          shoeId: 'shoe-1',
        ),
      );
      final file = await service.prepareExport();
      final archive = SnapshotArchive.fromJson(
        jsonDecode(utf8.decode(file.bytes)) as Map<String, dynamic>,
      );
      final shoes = archive.data.equipment.shoes;
      check(shoes.single.name).equals('Everyday pair');
      check(shoes.single.modifiedAt).equals(editedAt);
      check(shoes.single.lifecycleTargetMeters).equals(700000);
      check(archive.counts['equipment']).equals(2);
      check(
        archive.data.equipment.activityAssignments.single.activityId,
      ).equals('-7');
      final state = await service.readLocalState();
      await service.applyLocalState(state, expectedRevision: state.revision);
      await Hive.close();
      Hive.init(directory.path);
      await service.initialize();
      check(
        (await LocalActivityDataSource(
          coordinator: service.coordinator,
        ).getAllActivities()).single.shoeId,
      ).equals('shoe-1');
      check(
        (await LocalEquipmentDataSource(
          coordinator: service.coordinator,
        ).getAll()).single.foamChemistry,
      ).equals(FoamChemistry.traditionalEva);
    },
  );
  test(
    'remote refresh rejects dangling shoe references before mutation',
    () async {
      final local = LocalActivityDataSource(coordinator: service.coordinator);
      await local.saveActivity(activity(-7, 'Run'));
      final before = await service.readLocalState();
      await check(
        local.smartMergeActivities([
          activity(10, 'Run').copyWith(shoeId: 'missing'),
        ]),
      ).throws<ArgumentError>();
      check((await service.readLocalState()).stores).deepEquals(before.stores);
    },
  );
  test('invalid assignment instants fail before durable mutation', () async {
    await LocalEquipmentDataSource(coordinator: service.coordinator).save(
      const ShoeEquipment(
        id: 'shoe-1',
        name: 'Pair',
        category: ShoeCategory.tempoWorkout,
      ),
    );
    await LocalActivityDataSource(
      coordinator: service.coordinator,
    ).saveActivity(activity(-7, 'Run').copyWith(shoeId: 'shoe-1'));
    final before = await service.readLocalState();
    final next = LocalSnapshot.decode(before.encode());
    final row = next.stores['activities']?['-7'] as Map;
    final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
    data['shoe_assignment_modified_at'] = '2026-02-30T00:00:00.000Z';
    row['data'] = jsonEncode(data);
    await check(
      service.applyLocalState(next, expectedRevision: before.revision),
    ).throws<FormatException>();
    check((await service.readLocalState()).stores).deepEquals(before.stores);
  });
  test(
    'legacy unknown recency survives refresh and real shoe edits get edit times',
    () async {
      final state = await service.readLocalState();
      state.stores['equipment']?['legacy'] = const ShoeEquipment(
        id: 'legacy',
        name: 'Old pair',
        category: ShoeCategory.dailyTrainer,
      ).toJson();
      final model = activity(42, 'Run').copyWith(shoeId: 'legacy');
      state.stores['activities']?['42'] = {
        'id': 42,
        'data': jsonEncode(model.toJson()),
      };
      await service.applyLocalState(state, expectedRevision: state.revision);
      await LocalActivityDataSource(
        coordinator: service.coordinator,
      ).smartMergeActivities([activity(42, 'Run')]);
      var archive = await exported(service);
      check(archive.data.equipment.shoes.single.modifiedAt).isNull();
      check(archive.data.equipment.shoes.single.foamChemistry).isNull();
      check(
        archive.data.equipment.activityAssignments.single.shoeId,
      ).equals('legacy');
      check(
        archive.data.equipment.activityAssignments.single.modifiedAt,
      ).isNull();
      await LocalEquipmentDataSource(
        coordinator: service.coordinator,
        clock: () => editedAt,
      ).save(
        const ShoeEquipment(
          id: 'legacy',
          name: 'Renamed pair',
          category: ShoeCategory.tempoWorkout,
        ),
      );
      archive = await exported(service);
      check(archive.data.equipment.shoes.single.modifiedAt).equals(editedAt);
      check(archive.data.equipment.shoes.single.createdAt).isNull();
    },
  );
  test(
    'dangling assignments and incompatible shoe identities leave stored data untouched',
    () async {
      final equipment = LocalEquipmentDataSource(
        coordinator: service.coordinator,
        clock: () => editedAt,
      );
      await equipment.save(
        const ShoeEquipment(
          id: 'pair',
          name: 'Pair',
          category: ShoeCategory.raceDayPlated,
        ),
      );
      final local = LocalActivityDataSource(coordinator: service.coordinator);
      await local.saveActivity(activity(-7, 'Run').copyWith(shoeId: 'pair'));
      final before = await service.readLocalState();
      final next = LocalSnapshot.decode(before.encode());
      next.stores['equipment']?.clear();
      await check(
        service.applyLocalState(next, expectedRevision: before.revision),
      ).throws<StateError>();
      await check(
        local.saveActivity(activity(-8, 'Run').copyWith(shoeId: 'missing')),
      ).throws<ArgumentError>();
      await check(
        equipment.save(
          ShoeEquipment(
            id: 'pair',
            name: 'Other pair',
            category: ShoeCategory.dailyTrainer,
            createdAt: DateTime.utc(2025),
          ),
        ),
      ).throws<StateError>();
      check((await service.readLocalState()).stores).deepEquals(before.stores);
    },
  );
  test(
    'invalid shoe records cannot be durably applied or silently omitted',
    () async {
      final before = await service.readLocalState();
      for (final field in [
        {'category': 'future_variant'},
        {'lifecycle_target_meters': -1},
        {'performance_target_meters': 0},
        {'modified_at': '2026-02-30T00:00:00Z'},
      ]) {
        final next = LocalSnapshot.decode(before.encode());
        next.stores['equipment']?['pair'] = {
          ...const ShoeEquipment(
            id: 'pair',
            name: 'Pair',
            category: ShoeCategory.dailyTrainer,
          ).toJson(),
          ...field,
        };
        await check(
          service.applyLocalState(next, expectedRevision: before.revision),
        ).throws<StateError>();
      }
      final box = await Hive.openBox('equipment');
      await box.put('broken', {'id': 'broken'});
      await check(service.prepareExport()).throws<StateError>();
      await box.clear();
      check((await service.readLocalState()).stores).deepEquals(before.stores);
    },
  );
  test(
    'equivalent explicit timezone timestamps export as UTC without changing recency',
    () async {
      final state = await service.readLocalState();
      state.stores['equipment']?['pair'] = {
        ...const ShoeEquipment(
          id: 'pair',
          name: 'Pair',
          category: ShoeCategory.dailyTrainer,
        ).toJson(),
        'created_at': '2026-10-14T08:02:03+07:00',
        'modified_at': '2026-10-14T01:02:03Z',
      };
      await service.applyLocalState(state, expectedRevision: state.revision);
      final shoe = (await exported(service)).data.equipment.shoes.single;
      check(shoe.createdAt).equals(editedAt);
      check(shoe.modifiedAt).equals(editedAt);
      check(shoe.toJson()['created_at']).equals('2026-10-14T01:02:03.000Z');
    },
  );
  test(
    'negative and large Activity edits preserve assignment recency',
    () async {
      final state = await service.readLocalState();
      state.stores['equipment']?['pair'] = const ShoeEquipment(
        id: 'pair',
        name: 'Pair',
        category: ShoeCategory.dailyTrainer,
      ).toJson();
      final original = DateTime.utc(2025);
      for (final id in [-7, 9007199254740991]) {
        state.stores['activities']?['$id'] = {
          'id': id,
          'data': jsonEncode(
            activity(id, 'Run')
                .copyWith(shoeId: 'pair', shoeAssignmentModifiedAt: original)
                .toJson(),
          ),
        };
      }
      await service.applyLocalState(state, expectedRevision: state.revision);
      final local = LocalActivityDataSource(
        coordinator: service.coordinator,
        clock: () => editedAt,
      );
      for (final run in await local.getAllActivities()) {
        await local.updateActivity(run.copyWith(name: 'Renamed run'));
      }
      final renamed = (await exported(
        service,
      )).data.equipment.activityAssignments;
      check(renamed.length).equals(2);
      check(renamed.every((record) => record.modifiedAt == original)).isTrue();
      for (final run in await local.getAllActivities()) {
        await local.updateActivity(run.copyWith(shoeId: null));
      }
      final cleared = (await exported(
        service,
      )).data.equipment.activityAssignments;
      check(cleared.length).equals(2);
      check(
        cleared.every(
          (record) => record.shoeId == null && record.modifiedAt == editedAt,
        ),
      ).isTrue();
    },
  );
  test(
    'cleared assignments retain their edit timestamp in the archive',
    () async {
      await LocalEquipmentDataSource(coordinator: service.coordinator).save(
        const ShoeEquipment(
          id: 'pair',
          name: 'Pair',
          category: ShoeCategory.dailyTrainer,
        ),
      );
      final local = LocalActivityDataSource(
        coordinator: service.coordinator,
        clock: () => editedAt,
      );
      final run = activity(-7, 'Run').copyWith(shoeId: 'pair');
      await local.saveActivity(run);
      await local.updateActivity(run.copyWith(shoeId: null));
      await local.smartMergeActivities([run.copyWith(shoeId: 'pair')]);
      final assignment = (await exported(
        service,
      )).data.equipment.activityAssignments.single;
      check(assignment.shoeId).isNull();
      check(assignment.modifiedAt).equals(editedAt);
    },
  );
}

Future<SnapshotArchive> exported(SnapshotBackupService service) async =>
    SnapshotArchive.fromJson(
      jsonDecode(utf8.decode((await service.prepareExport()).bytes))
          as Map<String, dynamic>,
    );
