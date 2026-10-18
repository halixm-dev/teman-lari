import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'package:teman_lari/data/backup/snapshot_store_adapters.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
import 'package:teman_lari/data/datasources/token_storage.dart';
import 'package:teman_lari/data/datasources/local_activity_datasource.dart';
import 'package:teman_lari/data/models/activity_model.dart';
import 'package:teman_lari/presentation/providers/activities_provider.dart';
import 'package:teman_lari/presentation/providers/local_backup_refresh.dart';
import 'package:teman_lari/data/models/strava_tokens.dart';
import 'package:teman_lari/presentation/providers/backup_provider.dart';
import 'package:teman_lari/presentation/providers/core_provider.dart';
import 'package:teman_lari/presentation/screens/settings_screen.dart';
import 'package:teman_lari/presentation/widgets/local_recovery_gate.dart';

void main() {
  late Directory directory;
  late SnapshotBackupService service;
  late RetryStore equipment;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('runtime_recovery_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({'athlete_name': 'Before'});
    equipment = RetryStore();
    service = SnapshotBackupService(
      coordinator: LocalDataCoordinator(),
      stores: SnapshotBackupService.defaultStores().map(
        (store) => store.name == 'equipment' ? equipment : store,
      ),
    );
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  testWidgets(
    'Settings refresh stays offline and keeps restored profile timestamps',
    (tester) async {
      await tester.runAsync(() async {
        var requests = 0;
        final client = MockClient((_) async {
          requests++;
          throw StateError('Unexpected network');
        });
        await service.initialize();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              snapshotBackupServiceProvider.overrideWithValue(service),
              preferencesStorageProvider.overrideWithValue(
                PreferencesStorage(coordinator: service.coordinator),
              ),
              localActivityDataSourceProvider.overrideWithValue(
                LocalActivityDataSource(coordinator: service.coordinator),
              ),
              tokenStorageProvider.overrideWithValue(MemoryTokens()),
              httpClientProvider.overrideWithValue(client),
            ],
            child: const MaterialApp(home: RefreshSettingsHost()),
          ),
        );
        await settleRealWork(tester);
        check(requests).equals(0);
        await (() async {
          final next = await service.readLocalState().timeout(
            const Duration(seconds: 30),
          );
          next.stores['preferences'] = {
            'athlete_name': 'Restored',
            'max_hr': 150,
            'max_hr_modified_at': '2026-10-01T00:00:00.000Z',
          };
          final activity = ActivityModel(
            id: -7,
            name: 'Restored run',
            type: 'Run',
            distance: 5000,
            movingTime: 1500,
            elapsedTime: 1500,
            totalElevationGain: 0,
            startDate: '2026-10-01T00:00:00.000Z',
            averageSpeed: 3.3,
            maxSpeed: 4,
            averageHeartrate: 145,
            maxHeartrate: 210,
            hasHeartrate: true,
          );
          next.stores['activities'] = {
            '-7': {
              'id': -7,
              'data': jsonEncode(activity.toJson()),
              'synced_at': '2026-10-01T00:00:00.000Z',
            },
          };
          await service
              .applyLocalState(next, expectedRevision: next.revision)
              .timeout(const Duration(seconds: 30));
        })();
        await tester.tap(find.byKey(const ValueKey('refresh-local-backup')));
        await settleRealWork(tester);
        check(find.text('Restored').evaluate().length).equals(1);
        check(find.text('Analysis ready').evaluate().length).equals(1);
        check(requests).equals(0);
        final snapshot = await service.readLocalState();
        check(snapshot.stores['preferences']?['max_hr']).equals(150);
        check(
          snapshot.stores['preferences']?['max_hr_modified_at'],
        ).equals('2026-10-01T00:00:00.000Z');
      });
    },
  );
  testWidgets('explicit Settings sync downloads missing heart rate samples', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final streamed = Completer<void>();
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/streams')) {
          streamed.complete();
          return http.Response(
            jsonEncode({
              'heartrate': {
                'type': 'heartrate',
                'data': [140.25, 150.5],
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode([
            {
              'id': 321,
              'name': 'Synced run',
              'type': 'Run',
              'distance': 5000,
              'moving_time': 1500,
              'elapsed_time': 1500,
              'total_elevation_gain': 0,
              'start_date': '2026-10-01T00:00:00.000Z',
              'average_speed': 3.3,
              'max_speed': 4,
              'average_heartrate': 145,
              'max_heartrate': 160,
              'has_heartrate': true,
            },
          ]),
          200,
        );
      });
      await service.initialize();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            snapshotBackupServiceProvider.overrideWithValue(service),
            preferencesStorageProvider.overrideWithValue(
              PreferencesStorage(coordinator: service.coordinator),
            ),
            localActivityDataSourceProvider.overrideWithValue(
              LocalActivityDataSource(coordinator: service.coordinator),
            ),
            tokenStorageProvider.overrideWithValue(MemoryTokens()),
            httpClientProvider.overrideWithValue(client),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Sync Now'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Sync Now'));
      await streamed.future.timeout(const Duration(seconds: 5));
      await tester.pump();
      final waiting = Stopwatch()..start();
      while (find.text('Syncing...').evaluate().isNotEmpty &&
          waiting.elapsed.inSeconds < 5) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
      check(find.text('Syncing...').evaluate()).isEmpty();
      final snapshot = await service.readLocalState();
      check(snapshot.stores['hr_streams']?.keys).isNotNull().contains('321');
      final samples =
          jsonDecode(
                (snapshot.stores['hr_streams']?['321'] as Map)['data']
                    as String,
              )
              as List;
      check(samples).deepEquals([140.25, 150.5]);
    });
  });
  testWidgets(
    'runtime rollback failure hides Settings and preserves login on retry',
    (tester) async {
      await tester.runAsync(() async {
        var requests = 0;
        final tokens = MemoryTokens();
        final client = MockClient((request) async {
          requests++;
          throw StateError('Recovery must stay offline');
        });
        await service.initialize().timeout(const Duration(seconds: 10));
        await tester.pumpWidget(
          LocalRecoveryGate(
            initialize: service.initialize,
            recoveryRequired: service.coordinator.recoveryState,
            ready: () => ProviderScope(
              overrides: [
                snapshotBackupServiceProvider.overrideWithValue(service),
                preferencesStorageProvider.overrideWithValue(
                  PreferencesStorage(coordinator: service.coordinator),
                ),
                tokenStorageProvider.overrideWithValue(tokens),
                httpClientProvider.overrideWithValue(client),
              ],
              child: const MaterialApp(home: SettingsScreen()),
            ),
          ),
        );
        await settleRecovery(tester, service);
        check(find.byType(SettingsScreen).evaluate().length).equals(1);
        tokens.value = StravaTokens(
          accessToken: 'original',
          refreshToken: 'original-refresh',
          expiresAt: 1,
        );
        final next = await service.readLocalState().timeout(
          const Duration(seconds: 10),
        );
        next.stores['preferences'] = {'athlete_name': 'After'};
        equipment.failures = 2;
        await check(
          service
              .applyLocalState(next, expectedRevision: next.revision)
              .timeout(const Duration(seconds: 10)),
        ).throws<SnapshotRecoveryException>();
        await tester.pumpAndSettle();
        check(find.byType(SettingsScreen).evaluate().length).equals(0);
        check(find.text('Retry recovery').evaluate().length).equals(1);
        await tester.tap(find.text('Retry recovery'));
        await settleRecovery(tester, service);
        check(find.text('Checking local data recovery…').evaluate()).isEmpty();
        check(find.byType(SettingsScreen).evaluate().length).equals(1);
        check(requests).equals(0);
        check(tokens.saves).equals(0);
        check(tokens.value.refreshToken).equals('original-refresh');
        check(
          (await service.readLocalState())
              .stores['preferences']?['athlete_name'],
        ).equals('Before');
      });
    },
  );
}

Future<void> settleRecovery(
  WidgetTester tester,
  SnapshotBackupService service,
) async {
  await tester.pump();
  final recovery = Stopwatch()..start();
  while (service.coordinator.snapshotBusy &&
      recovery.elapsed < const Duration(seconds: 10)) {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  check(service.coordinator.snapshotBusy).isFalse();
  await tester.pumpAndSettle();
}

class RetryStore extends HiveSnapshotStore {
  int failures = 0;
  RetryStore() : super('equipment');
  @override
  Future<void> replace(Map<String, Object?> records) async {
    if (failures > 0) {
      failures--;
      throw const FileSystemException('Disk unavailable');
    }
    await super.replace(records);
  }
}

class MemoryTokens extends TokenStorage {
  StravaTokens value = StravaTokens(
    accessToken: 'original',
    refreshToken: 'original-refresh',
    expiresAt: 4102444800,
  );
  int saves = 0;
  @override
  Future<StravaTokens?> getTokens() async => value;
  @override
  Future<void> saveTokens(StravaTokens tokens) async {
    value = tokens;
    saves++;
  }
}

Future<void> settleRealWork(WidgetTester tester) async {
  await tester.pump();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SettingsScreen)),
  );
  await container
      .read(runningStatsProvider.future)
      .timeout(const Duration(seconds: 30));
  await container
      .read(backupCountsProvider.future)
      .timeout(const Duration(seconds: 30));
  await tester.pumpAndSettle();
}

class RefreshSettingsHost extends ConsumerWidget {
  const RefreshSettingsHost({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(runningStatsProvider);
    return Scaffold(
      body: Column(
        children: [
          Text(stats.hasValue ? 'Analysis ready' : 'Analysis pending'),
          const Expanded(child: SettingsScreen()),
        ],
      ),
      floatingActionButton: IconButton(
        key: const ValueKey('refresh-local-backup'),
        icon: const Icon(Icons.restore),
        onPressed: () => refreshLocalBackupProviders(ref),
      ),
    );
  }
}
