import 'activity.dart';
import 'rehab_feedback.dart';
import 'rehab_program.dart';

class RehabJournal {
  final RehabProgram? program;
  final List<Activity> activities;
  final List<RehabFeedback> feedback;

  const RehabJournal({
    this.program,
    this.activities = const [],
    this.feedback = const [],
  });
}
