import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/local_rehab_repository.dart';
import '../../domain/entities/rehab_feedback.dart';
import '../../domain/entities/rehab_journal.dart';
import '../../domain/entities/rehab_program.dart';
import '../../domain/entities/rehab_progress.dart';
import '../../domain/usecases/rehab_progression.dart';
import 'activities_provider.dart';
import 'backup_provider.dart';
import 'training_plan_provider.dart';

part 'rehab_provider.g.dart';

@Riverpod(keepAlive: true)
LocalRehabRepository localRehabRepository(Ref ref) =>
    LocalRehabRepository(service: ref.watch(snapshotBackupServiceProvider));

@riverpod
Stream<DateTime> rehabTime(Ref ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
}

@Riverpod(keepAlive: true)
class RehabJournalNotifier extends _$RehabJournalNotifier {
  @override
  Future<RehabJournal> build() async {
    final repository = ref.watch(localRehabRepositoryProvider);
    if (!repository.initialized) return const RehabJournal();
    await ref.watch(activitiesProvider.future);
    return repository.read();
  }

  Future<void> saveFeedback(RehabFeedback feedback) =>
      _mutate((repository) => repository.saveFeedback(feedback));

  Future<void> start(RehabProgram program) =>
      _mutate((repository) => repository.start(program));

  Future<void> changeMode(ReturnModality mode) =>
      _mutate((repository) => repository.changeMode(mode));

  Future<void> graduate(DateTime expectedStart) => _mutate(
    (repository) => repository.graduate(expectedStart: expectedStart),
  );

  Future<void> _mutate(
    Future<void> Function(LocalRehabRepository) change,
  ) async {
    final repository = ref.read(localRehabRepositoryProvider);
    await change(repository);
    final journal = await repository.read();
    if (ref.mounted) state = AsyncData(journal);
  }
}

@riverpod
Future<RehabProgress?> rehabProgress(Ref ref) async {
  final now = ref.watch(rehabTimeProvider).value ?? DateTime.now();
  final config = ref.watch(trainingPlanConfigProvider);
  final journal = await ref.watch(rehabJournalProvider.future);
  final program = journal.program;
  if (program == null || program.graduatedAt != null) return null;
  return RehabProgression().assess(
    program: program,
    activities: journal.activities,
    feedback: journal.feedback,
    now: now,
    config: config,
  );
}
