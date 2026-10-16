import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/rehab_feedback.dart';
import '../backup/local_data_coordinator.dart';
import '../backup/snapshot_backup_service.dart';

/// Stored check-ins have no clinical interpretation or readiness side effects.
class LocalRehabFeedbackDataSource {
  final SnapshotBackupService service;
  final DateTime Function() clock;
  LocalRehabFeedbackDataSource({
    SnapshotBackupService? service,
    LocalDataCoordinator? coordinator,
    DateTime Function()? clock,
  }) : service = service ?? SnapshotBackupService(coordinator: coordinator),
       clock = clock ?? DateTime.now;

  Future<List<RehabFeedback>> readAll() => service.coordinator.read(() async {
    final box = Hive.isBoxOpen('rehab_feedback')
        ? Hive.box('rehab_feedback')
        : await Hive.openBox('rehab_feedback');
    return box.values
        .map(
          (value) =>
              RehabFeedback.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList();
  });

  /// A local edit stamps its actual time; imported application bypasses this.
  Future<void> save(RehabFeedback feedback) =>
      service.transformLocalState((state) {
        feedback.validate();
        final rows = state.stores['rehab_feedback'] ?? {};
        final old = rows[feedback.id];
        if (old != null) {
          final existing = RehabFeedback.fromJson(
            Map<String, dynamic>.from(old as Map),
          );
          if (!existing.hasSameIdentity(feedback)) {
            throw FormatException(
              'Feedback ID belongs to another Activity or Injury Site.',
            );
          }
        }
        return LocalSnapshot(
          revision: state.revision,
          stores: {
            ...state.stores,
            'rehab_feedback': {
              ...rows,
              feedback.id: feedback.editedAt(clock()).toJson(),
            },
          },
        );
      });
}
