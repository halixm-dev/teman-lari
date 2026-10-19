import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/domain/entities/rehab_journal.dart';
import 'package:teman_lari/domain/entities/rehab_program.dart';
import 'package:teman_lari/domain/entities/rehab_feedback.dart';
import 'package:teman_lari/domain/entities/running_stats.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/presentation/providers/activities_provider.dart';
import 'package:teman_lari/presentation/providers/rehab_provider.dart';
import 'package:teman_lari/presentation/widgets/rehab/rehab_card.dart';
import '../../domain/usecases/rehab_progression_test.dart'
    show rehabProgram, rehabRun, clearedFeedback;
import '../screens/run_session_screen_test.dart' show FakeActivityRepository;
import 'rehab_check_in_sheet_test.dart' show FakeRehabRepository;

class ReadinessRepository extends FakeRehabRepository {
  int confirmations = 0;
  @override
  Future<void> start(RehabProgram program) async {
    journal = RehabJournal(program: program, activities: journal.activities);
  }

  @override
  Future<void> changeMode(ReturnModality mode) async {
    journal = RehabJournal(
      program: journal.program?.copyWith(mode: mode),
      activities: journal.activities,
      feedback: journal.feedback,
    );
  }

  @override
  Future<void> graduate({DateTime? expectedStart}) async {
    confirmations++;
    journal = RehabJournal(
      program: journal.program?.copyWith(
        graduatedAt: DateTime.utc(2026, 10, 30),
      ),
      activities: journal.activities,
      feedback: journal.feedback,
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('runner chooses an injury site and preferred return modality', (
    tester,
  ) async {
    final repository = ReadinessRepository()..journal = const RehabJournal();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localRehabRepositoryProvider.overrideWithValue(repository),
          activityRepositoryProvider.overrideWithValue(
            FakeActivityRepository(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RehabCard(allowStart: true, stats: RunningStats.empty()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start return-to-run'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rehab-injury-site')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Knee').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rehab-setup-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuous easy runs').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start return plan'));
    await tester.pumpAndSettle();

    check(repository.journal.program?.injurySite).equals(InjurySite.knee);
    check(repository.journal.program?.mode).equals(ReturnModality.continuous);
    check(repository.journal.program?.graduatedAt).isNull();
  });

  testWidgets('readiness requires confirmation and can be declined', (
    tester,
  ) async {
    final repository = ReadinessRepository()
      ..journal = RehabJournal(
        program: rehabProgram(),
        activities: [rehabRun(-1, 7), rehabRun(-2, 14), rehabRun(-3, 21)],
        feedback: [
          clearedFeedback(-1, 7),
          clearedFeedback(-2, 14),
          clearedFeedback(-3, 21),
        ],
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localRehabRepositoryProvider.overrideWithValue(repository),
          activityRepositoryProvider.overrideWithValue(
            FakeActivityRepository()
              ..activities.addAll(repository.journal.activities),
          ),
          rehabTimeProvider.overrideWith(
            (ref) => Stream.value(DateTime.utc(2026, 10, 30)),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: RehabCard())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final readiness = find.text('Review readiness');
    await tester.ensureVisible(readiness);
    await tester.tap(readiness);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep return plan'));
    await tester.pumpAndSettle();
    check(repository.confirmations).equals(0);
    await tester.tap(readiness);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm readiness'));
    await tester.pumpAndSettle();
    check(repository.confirmations).equals(1);
    check(find.text('Return-to-run complete').evaluate()).isNotEmpty();
  });
}
