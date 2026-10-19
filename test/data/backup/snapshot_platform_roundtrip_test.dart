import 'dart:convert';
import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'package:teman_lari/data/backup/archive/snapshot_archive.dart';
import 'fixtures/compatibility_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String storage;
  late SnapshotBackupService service;
  setUp(() async {
    storage = await createCompatibilityStorage();
    Hive.init(storage);
    SharedPreferences.setMockInitialValues({
      'access_token': 'native-secret',
      'strava_refresh_token': 'web-secret',
      'has_completed_onboarding': true,
    });
    service = SnapshotBackupService(coordinator: LocalDataCoordinator());
    await service.initialize();
  });
  tearDown(() async {
    await Hive.close();
    await deleteCompatibilityStorage(storage);
  });
  test(
    'the canonical six-section fixture replaces and round trips after reopen on this platform',
    () async {
      final bytes = await loadCompatibilityFixture();
      final expected = SnapshotArchive.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      ).data.toJson();
      await service.applyImport(
        await service.prepareImport(bytes),
        mode: BackupImportMode.replaceAll,
      );
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      final exported = await service.prepareExport();
      check(
        utf8.decode(exported.bytes),
      ).not((value) => value.contains('native-secret'));
      check(
        utf8.decode(exported.bytes),
      ).not((value) => value.contains('web-secret'));
      check(
        canonicalData(jsonDecode(utf8.decode(exported.bytes))['data'] as Map),
      ).deepEquals(canonicalData(expected));
      await service.applyImport(
        await service.prepareImport(exported.bytes),
        mode: BackupImportMode.replaceAll,
      );
      check(
        canonicalData(
          jsonDecode(utf8.decode((await service.prepareExport()).bytes))['data']
              as Map,
        ),
      ).deepEquals(canonicalData(expected));
      final prefs = await SharedPreferences.getInstance();
      check(prefs.getString('access_token')).equals('native-secret');
      check(prefs.getString('strava_refresh_token')).equals('web-secret');
      check(prefs.getBool('has_completed_onboarding')).equals(true);
    },
  );
  test(
    'cross-ID Smart Merge rewrites the same fixture and every reference on this platform',
    () async {
      final bytes = await loadCompatibilityFixture();
      await service.applyImport(
        await service.prepareImport(bytes),
        mode: BackupImportMode.replaceAll,
      );
      final remote = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      remapFixture(remote['data'] as Map);
      final input = Uint8List.fromList(utf8.encode(jsonEncode(remote)));
      final preview = await service.prepareImport(input);
      check(preview.summary.signatureMatches).equals(1);
      check(preview.summary.canonicalIdentityChanges).equals(1);
      await service.applyImport(preview);
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      final expected = SnapshotArchive.fromJson(remote).data.toJson();
      final activity = (expected['activities'] as List).cast<Map>().singleWhere(
        (row) => row['id'] == '500',
      );
      activity['identity_aliases'] = [
        {
          'source_id': '-7',
          'type': 'Run',
          'start_date': '1990-01-02T03:04:05.123456Z',
          'distance_meters': '1235',
        },
      ];
      final actual =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes))['data']
              as Map;
      check(canonicalData(actual)).deepEquals(canonicalData(expected));
      final again = await service.prepareImport(input);
      check(again.summary.addedActivities).equals(0);
      check(again.summary.canonicalIdentityChanges).equals(0);
    },
  );
  test(
    'an identity beyond JavaScript precision is exact natively and rejected before writes on web',
    () async {
      final archive =
          jsonDecode(utf8.decode(await loadCompatibilityFixture()))
              as Map<String, dynamic>;
      ((archive['data'] as Map)['activities'] as List).cast<Map>().singleWhere(
        (row) => row['id'] == '42',
      )['id'] = '9007199254740993';
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(archive)));
      final before = await service.readLocalState();
      if (kIsWeb) {
        await check(service.prepareImport(bytes)).throws<FormatException>();
        check(
          (await service.readLocalState()).encode(),
        ).equals(before.encode());
      } else {
        await service.applyImport(
          await service.prepareImport(bytes),
          mode: BackupImportMode.replaceAll,
        );
        final data =
            jsonDecode(
                  utf8.decode((await service.prepareExport()).bytes),
                )['data']
                as Map;
        check(
          (data['activities'] as List)
              .cast<Map>()
              .map((row) => row['id'])
              .toSet(),
        ).contains('9007199254740993');
      }
    },
  );
}

Map<String, dynamic> canonicalData(Map data) {
  final copy = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  for (final row in copy['activities'] as List) {
    row['start_date'] = DateTime.parse(
      row['start_date'] as String,
    ).toUtc().toIso8601String();
  }
  (copy['activities'] as List).sort(
    (a, b) => (a['id'] as String).compareTo(b['id'] as String),
  );
  return copy;
}

void remapFixture(Map data) {
  final activity = (data['activities'] as List).cast<Map>().singleWhere(
    (row) => row['id'] == '-7',
  );
  activity['id'] = '500';
  activity['is_local'] = false;
  for (final row in data['heart_rate_streams'] as List) {
    if (row['activity_id'] == '-7') row['activity_id'] = '500';
  }
  for (final row
      in (data['equipment'] as Map)['activity_assignments'] as List) {
    if (row['activity_id'] == '-7') row['activity_id'] = '500';
  }
  for (final row in (data['rehab_feedback'] as Map)['records'] as List) {
    if (row['activity_id'] == '-7') row['activity_id'] = '500';
  }
}
