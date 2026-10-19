import '../entities/rehab_feedback.dart';

export '../entities/rehab_feedback.dart' show RehabStatus;

/// ADR 0002 classifications; incomplete observations never imply clearance.
class RehabFeedbackAssessment {
  RehabStatus assess(RehabFeedback? feedback) {
    if (feedback == null) return RehabStatus.pending;
    feedback.validate();
    final pain = [
      feedback.postRunPain,
      feedback.morningAfterPain,
    ].whereType<double>();
    if (feedback.acuteSharpPain == true || pain.any((value) => value > 5)) {
      return RehabStatus.flareUp;
    }
    if (pain.any((value) => value > 3) ||
        feedback.morningStiffness == true ||
        feedback.morningBaselineCleared == false) {
      return RehabStatus.warning;
    }
    if (!isComplete(feedback)) {
      return RehabStatus.pending;
    }
    return RehabStatus.pass;
  }

  bool isComplete(RehabFeedback? feedback) =>
      feedback != null &&
      feedback.postRunPain != null &&
      feedback.morningAfterPain != null &&
      feedback.acuteSharpPain != null &&
      feedback.morningStiffness != null &&
      feedback.morningBaselineCleared != null;
}
