import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'package:teman_lari/data/repositories/local_rehab_repository.dart';
import 'package:teman_lari/domain/entities/rehab_journal.dart';
import 'package:teman_lari/domain/entities/rehab_feedback.dart';
import 'package:teman_lari/presentation/providers/activities_provider.dart';
import 'package:teman_lari/presentation/providers/rehab_provider.dart';
import 'package:teman_lari/presentation/widgets/rehab/rehab_check_in_sheet.dart';
import 'package:teman_lari/domain/usecases/rehab_feedback_assessment.dart';
import '../../domain/usecases/rehab_progression_test.dart'
    show rehabProgram, rehabRun, clearedFeedback;
import '../screens/run_session_screen_test.dart' show FakeActivityRepository;

class FakeRehabRepository extends LocalRehabRepository {
  RehabJournal journal = RehabJournal(
    program: rehabProgram(),
    activities: [rehabRun(-1, 2)],
  );
  bool failSave = true;
  FakeRehabRepository() : super(service: SnapshotBackupService());
  @override
  bool get initialized => true;
  @override
  Future<RehabJournal> read() async => journal;
  @override
  Future<void> saveFeedback(RehabFeedback feedback) async {
    if (failSave) throw StateError('Disk full');
    journal = RehabJournal(
      program: journal.program,
      activities: journal.activities,
      feedback: [feedback],
    );
  }
}

void main() {
  testWidgets(
    'historical morning-only record requires an explicit post-run observation time',
    (tester) async {
      final existing = RehabFeedback.fromJson({
        ...clearedFeedback(-1, 2).toJson(),
        'post_run_pain': null,
        'post_run_recorded_at': null,
        'acute_sharp_pain': null,
      });
      final repository = FakeRehabRepository()..failSave = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localRehabRepositoryProvider.overrideWithValue(repository),
            activityRepositoryProvider.overrideWithValue(
              FakeActivityRepository(),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showRehabCheckIn(
                    context,
                    activity: rehabRun(-1, 2),
                    program: rehabProgram(),
                    existing: existing,
                  ),
                  child: const Text('Open old check-in'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open old check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No pain (0)'));
      await tester.tap(find.byKey(const Key('sharp-pain-no')));
      await tester.pump();
      final save = find.widgetWithText(FilledButton, 'Save check-in');
      check(tester.widget<FilledButton>(save).onPressed).isNull();
      await tester.ensureVisible(find.text('Choose observation time'));
      await tester.tap(find.text('Choose observation time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      final saved = repository.journal.feedback.single;
      saved.validate();
      check(
        saved.morningAfterRecordedAt,
      ).equals(existing.morningAfterRecordedAt);
      check(
        saved.postRunRecordedAt?.isAfter(
          existing.morningAfterRecordedAt ?? DateTime(1900),
        ),
      ).equals(false);
    },
  );

  testWidgets(
    'large-text morning check-in preserves post-run answers and baseline warning',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final existing = RehabFeedback.fromJson({
        ...clearedFeedback(-1, 2).toJson(),
        'morning_after_pain': null,
        'morning_after_recorded_at': null,
        'morning_stiffness': null,
        'morning_baseline_cleared': null,
      });
      final repository = FakeRehabRepository()..failSave = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localRehabRepositoryProvider.overrideWithValue(repository),
            activityRepositoryProvider.overrideWithValue(
              FakeActivityRepository(),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child ?? const SizedBox.shrink(),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showRehabCheckIn(
                    context,
                    activity: rehabRun(-1, 2),
                    program: rehabProgram(),
                    existing: existing,
                    window: CheckInWindow.morningAfter,
                  ),
                  child: const Text('Open morning'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open morning'));
      await tester.pumpAndSettle();
      for (final finder in [
        find.text('No pain (0)'),
        find.byKey(const Key('stiffness-no')),
        find.byKey(const Key('baseline-no')),
      ]) {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pump();
      }
      final save = find.text('Save check-in');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      check(tester.takeException()).isNull();
      final saved = repository.journal.feedback.single;
      check(saved.postRunPain).equals(2);
      check(saved.postRunRecordedAt).equals(existing.postRunRecordedAt);
      check(saved.morningAfterPain).equals(0);
      check(
        RehabFeedbackAssessment().assess(saved),
      ).equals(RehabStatus.warning);
    },
  );

  testWidgets('failed check-in save retains explicit answers for retry', (
    tester,
  ) async {
    final repository = FakeRehabRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localRehabRepositoryProvider.overrideWithValue(repository),
          activityRepositoryProvider.overrideWithValue(
            FakeActivityRepository()
              ..activities.addAll(repository.journal.activities),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showRehabCheckIn(
                  context,
                  activity: rehabRun(-1, 2),
                  program: rehabProgram(),
                ),
                child: const Text('Open check-in'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open check-in'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save check-in');
    check(tester.widget<FilledButton>(save).onPressed).isNull();
    await tester.tap(find.text('No pain (0)'));
    await tester.tap(find.byKey(const Key('sharp-pain-no')));
    await tester.pump();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    check(
      find
          .text('Could not save check-in. Your answers are kept. Try again.')
          .evaluate(),
    ).isNotEmpty();
    repository.failSave = false;
    await tester.tap(save);
    await tester.pumpAndSettle();

    check(repository.journal.feedback.single.postRunPain).equals(0);
    check(repository.journal.feedback.single.acuteSharpPain).equals(false);
    check(repository.journal.feedback.single.morningAfterPain).isNull();
  });
}
