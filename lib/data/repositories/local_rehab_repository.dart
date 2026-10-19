import '../../domain/entities/rehab_feedback.dart';
import '../../domain/entities/rehab_journal.dart';
import '../../domain/entities/rehab_program.dart';
import '../../domain/usecases/rehab_progression.dart';
import '../backup/snapshot_backup_service.dart';
import '../backup/archive/training_plan_section.dart';
import '../backup/snapshot_store_adapters.dart';
import '../../domain/entities/activity.dart';
import 'rehab_journal_mapper.dart';

class LocalRehabRepository {
  final SnapshotBackupService service;
  LocalRehabRepository({required this.service});

  bool get initialized => service.coordinator.initialized;

  Future<RehabJournal> read() => service.coordinator.read(() async {
    final stores = <String, Map<String, Object?>>{};
    for (final name in ['activities', 'training_plans', 'rehab_feedback']) {
      stores[name] = await HiveSnapshotStore(name).read();
    }
    return rehabJournalFromSnapshot(
      LocalSnapshot(revision: service.coordinator.revision, stores: stores),
    );
  });

  Future<void> start(RehabProgram program) => _edit((old, _) {
    program.validate();
    if (old != null && old.graduatedAt == null) {
      throw StateError('A return-to-run episode is already active.');
    }
    if (program.graduatedAt != null ||
        program.startedAt.isAfter(service.clock())) {
      throw StateError('A new episode must start before now and be active.');
    }
    return program;
  });

  Future<void> changeMode(ReturnModality mode) => _edit((old, _) {
    if (old == null) throw StateError('Start a return-to-run episode first.');
    return old.copyWith(mode: mode);
  });

  Future<void> graduate({DateTime? expectedStart}) => _edit((old, journal) {
    if (old == null ||
        expectedStart != null && old.startedAt != expectedStart) {
      throw StateError('The return-to-run episode changed. Refresh and retry.');
    }
    if (old.graduatedAt != null) return old;
    final progress = RehabProgression().assess(
      program: old,
      activities: journal.activities,
      feedback: journal.feedback,
      now: service.clock(),
    );
    if (!progress.readyToGraduate) {
      throw StateError('Complete the return stages and check-ins first.');
    }
    return old.copyWith(graduatedAt: service.clock());
  });

  Future<void> saveFeedback(RehabFeedback feedback) =>
      service.transformLocalState((snapshot) {
        feedback.validate();
        final journal = rehabJournalFromSnapshot(snapshot);
        final activity = journal.activities
            .where((a) => a.id == feedback.activityId)
            .firstOrNull;
        if (activity == null) throw StateError('This run is no longer stored.');
        _validateTimes(feedback, activity);
        final rows = snapshot.stores['rehab_feedback'] ?? {};
        final old = rows[feedback.id];
        if (old != null) {
          final existing = RehabFeedback.fromJson(
            Map<String, dynamic>.from(old as Map),
          );
          if (!existing.hasSameIdentity(feedback)) {
            throw FormatException(
              'Feedback ID belongs to another run or injury site.',
            );
          }
        }
        snapshot.stores['rehab_feedback'] = {
          ...rows,
          feedback.id: feedback.editedAt(service.clock()).toJson(),
        };
        return snapshot;
      });

  void _validateTimes(RehabFeedback feedback, Activity activity) {
    for (final instant in [
      feedback.postRunRecordedAt,
      feedback.morningAfterRecordedAt,
    ]) {
      if (instant != null &&
          (instant.isBefore(activity.date) ||
              instant.isAfter(service.clock()))) {
        throw StateError('Check-in recording time must match an observed run.');
      }
    }
    final morning = feedback.morningAfterRecordedAt;
    final run = activity.date.toLocal();
    if (morning != null &&
        morning.toLocal().isBefore(
          DateTime(run.year, run.month, run.day + 1),
        )) {
      throw StateError('The morning check-in opens the day after your run.');
    }
  }

  Future<void> _edit(
    RehabProgram Function(RehabProgram?, RehabJournal) update,
  ) => service.transformLocalState((snapshot) {
    const codec = TrainingPlanSectionCodec();
    final state = codec.encode(snapshot);
    final journal = rehabJournalFromSnapshot(snapshot);
    final next = update(state.rehabilitation, journal);
    snapshot.stores['training_plans'] = codec.decode(
      state.withRehabilitation(next, service.clock()),
    );
    return snapshot;
  });
}
