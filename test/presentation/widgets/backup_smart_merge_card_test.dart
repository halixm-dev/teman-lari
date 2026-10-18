import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'package:teman_lari/data/backup/transport/backup_file_transport.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
import 'package:teman_lari/presentation/providers/backup_provider.dart';
import 'package:teman_lari/presentation/providers/local_backup_refresh.dart';
import 'package:teman_lari/presentation/widgets/settings/backup_card.dart';

void main() {
  late Directory directory;
  late SnapshotBackupService service;
  late SmartMergeTransport transport;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('smart_merge_card_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({});
    service = SnapshotBackupService(coordinator: LocalDataCoordinator());
    await service.initialize();
    transport = SmartMergeTransport(
      Uint8List.fromList(
        await File(
          'test/fixtures/offline-backup-v1-populated.tlbackup',
        ).readAsBytes(),
      ),
    );
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> showCard(WidgetTester tester) async {
    await service.readBackupCounts();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          snapshotBackupServiceProvider.overrideWithValue(service),
          backupFileTransportProvider.overrideWithValue(transport),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: SmartMergeHost())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester) async {
    await tester.tap(find.text('Import Backup'));
    while (service.coordinator.snapshotBusy) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'failed apply keeps records unchanged and permits an explicit retry',
    (tester) async {
      await tester.runAsync(() async {
        var attempts = 0;
        service = SnapshotBackupService(
          coordinator: service.coordinator,
          checkAvailableSpace: (_) async => ++attempts > 1,
        );
        await showCard(tester);
        await pick(tester);
        await tester.tap(find.text('Import with Smart Merge'));
        while (service.coordinator.snapshotBusy) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await tester.pumpAndSettle();
        check(
          find
              .text('Not enough storage space to restore safely.')
              .evaluate()
              .length,
        ).equals(1);
        check(find.textContaining('Bad state:').evaluate()).isEmpty();
        check(find.text('Choose another file').evaluate().length).equals(1);
        check(find.text('Local refresh: 0').evaluate().length).equals(1);
        check(
          (await service.readLocalState()).stores['activities'],
        ).isNotNull().isEmpty();
        await tester.tap(find.text('Import with Smart Merge'));
        while (service.coordinator.snapshotBusy) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await tester.pumpAndSettle();
        check(find.text('Smart Merge complete.').evaluate().length).equals(1);
        check(
          (await service.readLocalState()).stores['activities']?.length,
        ).equals(2);
      });
    },
  );
  testWidgets(
    'applying blocks cancel, back, duplicate import and premature refresh',
    (tester) async {
      await tester.runAsync(() async {
        final staged = Completer<void>();
        final finish = Completer<void>();
        service = SnapshotBackupService(
          coordinator: service.coordinator,
          onPhase: (phase, _) async {
            if (phase == SnapshotPhase.staged) {
              staged.complete();
              await finish.future;
            }
          },
        );
        await showCard(tester);
        await pick(tester);
        await tester.tap(find.text('Import with Smart Merge'));
        await staged.future;
        await tester.pump();
        check(find.text('Importing your backup…').evaluate().length).equals(1);
        check(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
              .onPressed,
        ).isNull();
        check(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Import with Smart Merge'),
              )
              .onPressed,
        ).isNull();
        check(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .semanticsLabel,
        ).equals('Import in progress');
        check(find.text('Local refresh: 0').evaluate().length).equals(1);
        await tester.binding.handlePopRoute();
        await tester.pump();
        check(find.text('Backup preview').evaluate().length).equals(1);
        finish.complete();
        while (service.coordinator.snapshotBusy) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await tester.pumpAndSettle();
        check(find.text('Smart Merge complete.').evaluate().length).equals(1);
        check(find.text('Local refresh: 1').evaluate().length).equals(1);
      });
    },
  );
  testWidgets(
    'local changes replace the preview and require a second confirmation',
    (tester) async {
      await tester.runAsync(() async {
        await showCard(tester);
        await pick(tester);
        await PreferencesStorage(
          coordinator: service.coordinator,
        ).saveAthleteName('Local edit');
        await tester.tap(find.text('Import with Smart Merge'));
        while (service.coordinator.snapshotBusy) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await tester.pumpAndSettle();
        check(
          find
              .text(
                'Local data changed. Review the updated preview and confirm again.',
              )
              .evaluate()
              .length,
        ).equals(1);
        check(
          (await service.readLocalState()).stores['activities'],
        ).isNotNull().isEmpty();
        check(find.text('Local refresh: 0').evaluate().length).equals(1);
        await tester.tap(find.text('Import with Smart Merge'));
        while (service.coordinator.snapshotBusy) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await tester.pumpAndSettle();
        final snapshot = await service.readLocalState();
        check(snapshot.stores['activities']?.length).equals(2);
        check(
          snapshot.stores['preferences']?['athlete_name'],
        ).equals('Local edit');
        check(find.text('Local refresh: 1').evaluate().length).equals(1);
      });
    },
  );
  testWidgets(
    'confirmed Smart Merge applies local records and refreshes after commit',
    (tester) async {
      await tester.runAsync(() async {
        await showCard(tester);
        await pick(tester);
        check(
          (await service.readLocalState()).stores['activities'],
        ).isNotNull().isEmpty();
        await tester.tap(find.text('Import with Smart Merge'));
        while (service.coordinator.snapshotBusy) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await tester.pumpAndSettle();
        check(
          (await service.readLocalState()).stores['activities']?.length,
        ).equals(2);
        check(find.text('Smart Merge complete.').evaluate().length).equals(1);
        check(find.text('Activities added: 2').evaluate().length).equals(1);
        check(find.text('Local refresh: 1').evaluate().length).equals(1);
        check(tester.takeException()).isNull();
      });
    },
  );
}

class SmartMergeHost extends ConsumerWidget {
  const SmartMergeHost({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      Text('Local refresh: ${ref.watch(localBackupRefreshEpochProvider)}'),
      const BackupCard(),
    ],
  );
}

class SmartMergeTransport implements BackupFileTransport {
  final Uint8List bytes;
  SmartMergeTransport(this.bytes);
  @override
  Future<Uint8List?> pick() async => bytes;
  @override
  Future<BackupDelivery> save({
    required Uint8List bytes,
    required String filename,
  }) async => BackupDelivery.saved;
}
