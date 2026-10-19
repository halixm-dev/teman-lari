import 'dart:async';
import '../../data/backup/fixtures/linked_record_fixtures.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
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

  Future<void> showCard(
    WidgetTester tester, {
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.runAsync(service.readBackupCounts);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          snapshotBackupServiceProvider.overrideWithValue(service),
          backupFileTransportProvider.overrideWithValue(transport),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: BackupCard()),
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

  Future<void> confirmReplacementAndWait(
    WidgetTester tester,
    String outcome,
  ) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Delete local data and restore'));
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (find.text(outcome).evaluate().isEmpty) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Replacement did not reach: $outcome');
        }
        await tester.pump().timeout(const Duration(seconds: 2));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'signature outcomes appear before and after import in $brightness',
      (tester) async {
        await tester.runAsync(() async {
          await seed(service, [activity('-1', '2025-01-01T00:00:00Z')]);
          transport.bytes = await archiveBytes([
            activity('100', '2025-01-01T00:00:00Z'),
          ]);
        });
        await showCard(tester, scale: 2, brightness: brightness);
        await importAndSettle(tester);
        for (final text in [
          'Workouts matched by details: 1',
          'Workout IDs updated: 1',
          'Uncertain groups kept separate: 0',
        ]) {
          check(find.text(text).evaluate().length).equals(1);
        }
        check(
          find
              .text('Activities with different IDs are kept separately.')
              .evaluate(),
        ).isEmpty();
        await tester.runAsync(() async {
          await tester.tap(find.text('Import with Smart Merge'));
          while (service.coordinator.snapshotBusy) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
        check(find.text('Backup preview').evaluate()).isEmpty();
        check(
          find.text('Workouts matched by details: 1').evaluate().length,
        ).equals(1);
        check(find.text('Workout IDs updated: 1').evaluate().length).equals(1);
        check(tester.takeException()).isNull();
      },
    );
  }

  testWidgets(
    'replacement needs a separate deletion confirmation and can be cancelled',
    (tester) async {
      transport.bytes = await tester.runAsync(
        () => archiveBytes(
          [],
          change: (archive) {
            ((archive['data'] as Map)['profile'] as Map)['athlete_name'] = {
              'value': null,
              'modified_at': null,
            };
          },
        ),
      );
      final before = await tester.runAsync(service.readLocalState);
      await showCard(tester);
      await importAndSettle(tester);
      final replacement = find.widgetWithText(
        RadioListTile<BackupImportMode>,
        'Replace All Local Data',
      );
      check(
        tester.widget<RadioListTile<BackupImportMode>>(replacement).enabled,
      ).equals(true);
      await tester.ensureVisible(replacement);
      await tester.tap(replacement);
      await tester.pumpAndSettle();
      check(
        find
            .text(
              'This file contains no saved data. Replacement clears your local backup data.',
            )
            .evaluate()
            .length,
      ).equals(1);
      await tester.runAsync(() => tester.tap(find.text('Review replacement')));
      await tester.pumpAndSettle();
      check(
        find.text('Delete local data and restore?').evaluate().length,
      ).equals(1);
      check(
        find.text('Delete local data and restore').evaluate().length,
      ).equals(1);
      await tester.tap(find.text('Keep local data'));
      await tester.pumpAndSettle();
      check(find.text('Backup preview').evaluate().length).equals(1);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      check(
        (await tester.runAsync(service.readLocalState))?.encode(),
      ).equals(before?.encode());
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'confirmed replacement restores data in $brightness at 200% text',
      (tester) async {
        transport.bytes = await tester.runAsync(
          () => File(
            'test/fixtures/offline-backup-v1-populated.tlbackup',
          ).readAsBytes(),
        );
        await showCard(tester, scale: 2, brightness: brightness);
        await importAndSettle(tester);
        final replacement = find.widgetWithText(
          RadioListTile<BackupImportMode>,
          'Replace All Local Data',
        );
        await tester.ensureVisible(replacement);
        await tester.tap(replacement);
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => tester.tap(find.text('Review replacement')),
        );
        await tester.pumpAndSettle();
        check(
          tester
              .widget<AlertDialog>(find.byType(AlertDialog).last)
              .semanticLabel,
        ).equals('Confirm replacement of all backup-owned local data');
        check(
          MediaQuery.textScalerOf(
            tester.element(find.text('Delete local data and restore?')),
          ).scale(10),
        ).equals(20);
        await confirmReplacementAndWait(tester, 'Replacement complete.');
        check(find.text('Replacement complete.').evaluate().length).equals(1);
        check(find.text('Activities restored: 2').evaluate().length).equals(1);
        check(find.text('Backup preview').evaluate()).isEmpty();
        check(tester.takeException()).isNull();
        final state = await tester.runAsync(service.readLocalState);
        check(state?.stores['activities']?.length).equals(2);
        check(
          state?.stores['preferences']?['athlete_name'],
        ).equals('Portable Runner');
      },
    );
  }
  testWidgets(
    'stale replacement returns to preview and requires another deletion confirmation',
    (tester) async {
      transport.bytes = await tester.runAsync(() => archiveBytes([]));
      await showCard(tester);
      await importAndSettle(tester);
      final replacement = find.widgetWithText(
        RadioListTile<BackupImportMode>,
        'Replace All Local Data',
      );
      await tester.ensureVisible(replacement);
      await tester.tap(replacement);
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('Review replacement')));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => PreferencesStorage(
          coordinator: service.coordinator,
        ).saveAthleteName('Changed after preview'),
      );
      final before = await tester.runAsync(service.readLocalState);
      await confirmReplacementAndWait(
        tester,
        'Local data changed. Review the updated preview and confirm again.',
      );
      check(
        find
            .text(
              'Local data changed. Review the updated preview and confirm again.',
            )
            .evaluate()
            .length,
      ).equals(1);
      check(
        (await tester.runAsync(service.readLocalState))?.encode(),
      ).equals(before?.encode());
      await tester.runAsync(() => tester.tap(find.text('Review replacement')));
      await tester.pumpAndSettle();
      check(
        find.text('Delete local data and restore?').evaluate().length,
      ).equals(1);
      await tester.tap(find.text('Keep local data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'replacement commit announces progress and disables cancellation and repeated actions',
    (tester) async {
      final staged = Completer<void>();
      final release = Completer<void>();
      service = SnapshotBackupService(
        coordinator: LocalDataCoordinator(),
        onPhase: (phase, _) async {
          if (phase == SnapshotPhase.staged) {
            staged.complete();
            await release.future;
          }
        },
      );
      await tester.runAsync(service.initialize);
      transport.bytes = await tester.runAsync(() => archiveBytes([]));
      await showCard(tester);
      await importAndSettle(tester);
      final replacement = find.widgetWithText(
        RadioListTile<BackupImportMode>,
        'Replace All Local Data',
      );
      await tester.ensureVisible(replacement);
      await tester.tap(replacement);
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('Review replacement')));
      await tester.pumpAndSettle();
      try {
        await tester.runAsync(() async {
          await tester.tap(find.text('Delete local data and restore'));
          final deadline = DateTime.now().add(const Duration(seconds: 10));
          while (!staged.isCompleted) {
            if (DateTime.now().isAfter(deadline)) {
              fail('Replacement did not reach durable staging');
            }
            await tester.pump();
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pump();
        check(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .semanticsLabel,
        ).equals('Import in progress');
        check(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
              .onPressed,
        ).isNull();
        check(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Review replacement'),
              )
              .onPressed,
        ).isNull();
        check(
          tester.widget<RadioListTile<BackupImportMode>>(replacement).enabled,
        ).equals(false);
      } finally {
        await tester.runAsync(() async {
          if (!release.isCompleted) release.complete();
        });
      }
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (find.text('Replacement complete.').evaluate().isEmpty) {
          if (DateTime.now().isAfter(deadline)) {
            fail('Replacement did not finish');
          }
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
    },
  );

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
    check(
      MediaQuery.textScalerOf(
        tester.element(find.text('Backup preview')),
      ).scale(10),
    ).equals(20);
    check(find.text('App version: 1.0.0+1').evaluate().length).equals(1);
    check(find.text('Schema version: 1').evaluate().length).equals(1);
    final group = tester.widget<RadioGroup<BackupImportMode>>(
      find.byType(RadioGroup<BackupImportMode>),
    );
    check(group.groupValue).equals(BackupImportMode.smartMerge);
    final disabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Import with Smart Merge'),
    );
    check(disabled.onPressed).isNotNull();
    check(find.text('Local').evaluate().length).equals(1);
    check(find.text('File').evaluate().length).equals(1);
    check(find.text('Activities').evaluate().length).equals(1);
    check(
      tester.widget<AlertDialog>(find.byType(AlertDialog)).semanticLabel,
    ).equals('Backup preview');
    check(
      find.text('Times come from each device’s clock.').evaluate().length,
    ).equals(1);
    final replacement = tester.widget<RadioListTile<BackupImportMode>>(
      find.widgetWithText(
        RadioListTile<BackupImportMode>,
        'Replace All Local Data',
      ),
    );
    check(replacement.enabled).equals(true);
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
