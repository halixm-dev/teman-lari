import 'rehab_feedback.dart';
import 'activity.dart';
import 'rehab_program.dart';

class RehabProgress {
  final RehabProgram program;
  final int stage;
  final double weeklyMinutes;
  final RehabStatus status;
  final DateTime? recoveryUntil;
  final RehabStatus? recoveryStatus;
  final List<Activity> pendingActivities;
  final bool readyToGraduate;

  const RehabProgress({
    required this.program,
    required this.stage,
    required this.weeklyMinutes,
    required this.status,
    this.recoveryUntil,
    this.recoveryStatus,
    this.pendingActivities = const [],
    this.readyToGraduate = false,
  });
}
