import 'dart:async';
import 'package:teman_lari/domain/entities/training_plan.dart';
import 'package:teman_lari/domain/usecases/training_plan_config.dart';
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
  late TestTransport transport;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('backup_card_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({});
    service = SnapshotBackupService(coordinator: LocalDataCoordinator());
    await service.initialize();
    transport = TestTransport();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> showCard(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1,
    bool showBackup = true,
  }) async {
    await tester.runAsync(service.readBackupCounts);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          snapshotBackupServiceProvider.overrideWithValue(service),
          backupFileTransportProvider.overrideWithValue(transport),
        ],
        child: MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: showBackup
                    ? const BackupCard()
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> exportAndSettle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Export Backup'));
      while (service.coordinator.snapshotBusy) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'guest sees a readable-data notice and accessible export without sign-in',
    (tester) async {
      await showCard(tester, dark: true, scale: 2);
      expect(find.textContaining('readable personal data'), findsOneWidget);
      expect(
        find.textContaining('No account or internet needed'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Export Backup'),
        findsOneWidget,
      );
      check(tester.takeException()).isNull();
    },
  );
  testWidgets('Settings shows saved Training Plan count after reopening', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await service.resolveTrainingPlan(
        inputs: 'saved',
        configuration: TrainingPlanConfig.defaultConfig,
        generate: (_) async => TrainingPlan.empty(),
      );
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
    });
    await showCard(tester);
    await tester.pumpAndSettle();
    check(find.text('Saved training plans: 1').evaluate().length).equals(1);
  });
  testWidgets('returning to Settings refreshes saved plan counts', (
    tester,
  ) async {
    await showCard(tester);
    await tester.pumpAndSettle();
    check(find.text('Saved training plans: 0').evaluate().length).equals(1);
    await showCard(tester, showBackup: false);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => service.resolveTrainingPlan(
        inputs: 'changed on Plan tab',
        configuration: TrainingPlanConfig.defaultConfig,
        generate: (_) async => TrainingPlan.empty(),
      ),
    );
    await showCard(tester);
    await tester.pumpAndSettle();
    check(find.text('Saved training plans: 1').evaluate().length).equals(1);
  });
  for (final entry in {
    BackupDelivery.saved: 'Backup saved.',
    BackupDelivery.cancelled: 'Export cancelled. No backup was saved.',
    BackupDelivery.downloadStarted:
        'Download started. Check your browser downloads.',
    BackupDelivery.shared:
        'Backup shared with another app. Check that it was saved there.',
  }.entries) {
    testWidgets('delivery outcome is honest: ${entry.key.name}', (
      tester,
    ) async {
      transport.result = entry.key;
      await showCard(tester);
      await exportAndSettle(tester);
      expect(find.text(entry.value), findsOneWidget);
    });
  }
  testWidgets('waiting save announces progress and blocks duplicate exports', (
    tester,
  ) async {
    transport.waiting = Completer<BackupDelivery>();
    await showCard(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Export Backup'));
      await transport.started.future;
    });
    await tester.pump();
    expect(find.text('Choose where to save your backup…'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Export Backup'),
    );
    check(button.onPressed).isNull();
    await check(service.prepareExport()).throws<StateError>();
    check(() => service.coordinator.beginWorkout()).throws<StateError>();
    await tester.runAsync(() async {
      transport.waiting?.complete(BackupDelivery.saved);
      while (service.coordinator.snapshotBusy) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Backup saved.'), findsOneWidget);
  });
  testWidgets('tracked workout refusal and storage failures allow retry', (
    tester,
  ) async {
    service.coordinator.beginWorkout();
    await showCard(tester);
    await exportAndSettle(tester);
    expect(
      find.textContaining('Finish the tracked workout first'),
      findsOneWidget,
    );
    service.coordinator.endWorkout();
    transport.error = StateError('Destination could not be written');
    await exportAndSettle(tester);
    expect(
      find.textContaining('Destination could not be written'),
      findsOneWidget,
    );
    transport.error = null;
    await exportAndSettle(tester);
    expect(find.text('Backup saved.'), findsOneWidget);
  });
}

class TestTransport implements BackupFileTransport {
  BackupDelivery result = BackupDelivery.saved;
  Object? error;
  Completer<BackupDelivery>? waiting;
  final started = Completer<void>();
  @override
  Future<BackupDelivery> save({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (!started.isCompleted) started.complete();
    final failure = error;
    if (failure != null) throw failure;
    return waiting?.future ?? result;
  }

  @override
  Future<Uint8List?> pick() async => null;
}
