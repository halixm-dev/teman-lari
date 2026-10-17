import 'dart:async';
import 'dart:io';
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
import 'package:teman_lari/presentation/providers/backup_provider.dart';
import 'package:teman_lari/presentation/widgets/settings/backup_card.dart';

void main() {
  late Directory directory;
  late SnapshotBackupService service;
  late ImportTransport transport;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('import_card_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({});
    service = SnapshotBackupService(coordinator: LocalDataCoordinator());
    await service.initialize();
    transport = ImportTransport();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> showCard(WidgetTester tester, {double scale = 1}) async {
    await tester.runAsync(service.readBackupCounts);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          snapshotBackupServiceProvider.overrideWithValue(service),
          backupFileTransportProvider.overrideWithValue(transport),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: SingleChildScrollView(child: BackupCard()),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> importAndSettle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Import Backup'));
      while (service.coordinator.snapshotBusy) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('picker cancellation leaves data unchanged', (tester) async {
    final before = await tester.runAsync(service.readLocalState);
    await showCard(tester);
    await importAndSettle(tester);
    check(
      find
          .text('Import cancelled. Local data was not changed.')
          .evaluate()
          .length,
    ).equals(1);
    final after = await tester.runAsync(service.readLocalState);
    check(after?.encode()).equals(before?.encode());
  });
  testWidgets('preview shows counts and defaults to Smart Merge at 200% text', (
    tester,
  ) async {
    transport.bytes = await tester.runAsync(
      () async => Uint8List.fromList(
        await File(
          'test/fixtures/offline-backup-v1-empty.tlbackup',
        ).readAsBytes(),
      ),
    );
    final before = await tester.runAsync(service.readLocalState);
    await showCard(tester, scale: 2);
    await importAndSettle(tester);
    check(find.text('Backup preview').evaluate().length).equals(1);
    check(find.text('App version: 1.0.0+1').evaluate().length).equals(1);
    check(find.text('Schema version: 1').evaluate().length).equals(1);
    final group = tester.widget<RadioGroup<BackupImportMode>>(
      find.byType(RadioGroup<BackupImportMode>),
    );
    check(group.groupValue).equals(BackupImportMode.smartMerge);
    final disabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Import unavailable'),
    );
    check(disabled.onPressed).isNull();
    check(find.text('Local').evaluate().length).equals(1);
    check(find.text('Archive').evaluate().length).equals(1);
    check(find.text('Activities').evaluate().length).equals(1);
    check(tester.takeException()).isNull();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    final after = await tester.runAsync(service.readLocalState);
    check(after?.encode()).equals(before?.encode());
  });

  testWidgets('waiting picker blocks both controls and announces progress', (
    tester,
  ) async {
    transport.pending = Completer<Uint8List?>();
    await showCard(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Import Backup'));
      await transport.started.future;
    });
    await tester.pump();
    check(find.text('Choose a backup file…').evaluate().length).equals(1);
    check(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Import Backup'),
          )
          .onPressed,
    ).isNull();
    check(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Export Backup'),
          )
          .onPressed,
    ).isNull();
    check(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .semanticsLabel,
    ).equals('Backup in progress');
    await tester.runAsync(() async {
      transport.pending?.complete(null);
      while (service.coordinator.snapshotBusy) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    check(tester.takeException()).isNull();
  });

  testWidgets('active workout prevents file selection without changing data', (
    tester,
  ) async {
    service.coordinator.beginWorkout();
    await showCard(tester);
    await importAndSettle(tester);
    check(
      find.textContaining('Finish the tracked workout first').evaluate().length,
    ).equals(1);
    check(transport.started.isCompleted).isFalse();
    service.coordinator.endWorkout();
  });

  testWidgets('invalid file error permits another selection', (tester) async {
    transport.bytes = Uint8List.fromList([123]);
    await showCard(tester);
    await importAndSettle(tester);
    check(find.textContaining('Import failed:').evaluate().length).equals(1);
    check(find.text('Backup preview').evaluate()).isEmpty();
    transport.bytes = null;
    await importAndSettle(tester);
    check(
      find
          .text('Import cancelled. Local data was not changed.')
          .evaluate()
          .length,
    ).equals(1);
  });
}

class ImportTransport implements BackupFileTransport {
  Uint8List? bytes;
  Completer<Uint8List?>? pending;
  final started = Completer<void>();
  @override
  Future<Uint8List?> pick() async {
    if (!started.isCompleted) started.complete();
    return pending?.future ?? bytes;
  }

  @override
  Future<BackupDelivery> save({
    required Uint8List bytes,
    required String filename,
  }) async => BackupDelivery.saved;
}
