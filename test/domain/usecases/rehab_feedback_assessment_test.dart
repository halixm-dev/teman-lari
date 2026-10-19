import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/domain/entities/rehab_feedback.dart';
import 'package:teman_lari/domain/usecases/rehab_feedback_assessment.dart';

void main() {
  test('a pass needs both windows, baseline clearance, and no sharp pain', () {
    final assessment = RehabFeedbackAssessment();
    final now = DateTime.utc(2026, 10, 19);
    final feedback = RehabFeedback(
      id: 'run:knee',
      activityId: -1,
      injurySite: InjurySite.knee,
      postRunPain: 3,
      postRunRecordedAt: now,
      acuteSharpPain: false,
      morningAfterPain: 3,
      morningAfterRecordedAt: now.add(const Duration(hours: 24)),
      morningStiffness: false,
      morningBaselineCleared: true,
    );

    check(assessment.assess(feedback)).equals(RehabStatus.pass);
    check(assessment.assess(null)).equals(RehabStatus.pending);
    final base = feedback.toJson();
    for (final entry in <Map<String, dynamic>, RehabStatus>{
      {'post_run_pain': 3.1}: RehabStatus.warning,
      {'post_run_pain': 5.0}: RehabStatus.warning,
      {'post_run_pain': 5.1}: RehabStatus.flareUp,
      {'post_run_pain': 0.0, 'acute_sharp_pain': true}: RehabStatus.flareUp,
      {'morning_stiffness': true}: RehabStatus.warning,
      {'morning_baseline_cleared': false}: RehabStatus.warning,
      {'morning_baseline_cleared': null}: RehabStatus.pending,
      {'acute_sharp_pain': null}: RehabStatus.pending,
    }.entries) {
      check(
        assessment.assess(RehabFeedback.fromJson({...base, ...entry.key})),
      ).equals(entry.value);
    }
  });
}
