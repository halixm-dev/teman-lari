import 'package:json_annotation/json_annotation.dart';

part 'rehab_feedback.g.dart';

enum InjurySite { achilles, knee, shin, plantarFascia, hamstring }

/// One Activity and Injury Site identify a dual-window check-in permanently.
@JsonSerializable(fieldRename: FieldRename.snake)
class RehabFeedback {
  final String id;
  @JsonKey(fromJson: feedbackActivityId, toJson: feedbackActivityIdJson)
  final int activityId;
  final InjurySite injurySite;
  final double? postRunPain;
  @JsonKey(fromJson: feedbackInstant, toJson: feedbackInstantJson)
  final DateTime? postRunRecordedAt;
  final double? morningAfterPain;
  final bool? morningStiffness;
  @JsonKey(fromJson: feedbackInstant, toJson: feedbackInstantJson)
  final DateTime? morningAfterRecordedAt;
  @JsonKey(fromJson: feedbackInstant, toJson: feedbackInstantJson)
  final DateTime? modifiedAt;

  const RehabFeedback({
    required this.id,
    required this.activityId,
    required this.injurySite,
    this.postRunPain,
    this.postRunRecordedAt,
    this.morningAfterPain,
    this.morningStiffness,
    this.morningAfterRecordedAt,
    this.modifiedAt,
  });

  factory RehabFeedback.fromJson(Map<String, dynamic> json) {
    try {
      final feedback = _$RehabFeedbackFromJson(json);
      feedback.validate();
      return feedback;
    } catch (error) {
      throw FormatException('Invalid Rehab Feedback: $error');
    }
  }
  Map<String, dynamic> toJson() {
    validate();
    return _$RehabFeedbackToJson(this);
  }

  void validate() {
    final post = postRunPain != null;
    final morning = morningAfterPain != null;
    if (id.trim().isEmpty || activityId == 0 || (!post && !morning)) {
      throw FormatException('Feedback requires an identity and check-in.');
    }
    if (post != (postRunRecordedAt != null) ||
        morning != (morningAfterRecordedAt != null) ||
        (!morning && morningStiffness != null)) {
      throw FormatException(
        'Feedback windows require matching recording times.',
      );
    }
    for (final pain in [postRunPain, morningAfterPain]) {
      if (pain != null && (!pain.isFinite || pain < 0 || pain > 10)) {
        throw FormatException('Feedback pain must be between 0 and 10.');
      }
    }
    final postTime = postRunRecordedAt;
    final morningTime = morningAfterRecordedAt;
    if (postTime != null &&
        morningTime != null &&
        morningTime.isBefore(postTime)) {
      throw FormatException(
        'Morning feedback cannot precede post-run feedback.',
      );
    }
  }

  bool hasSameIdentity(RehabFeedback other) =>
      activityId == other.activityId && injurySite == other.injurySite;

  RehabFeedback editedAt(DateTime instant) => RehabFeedback(
    id: id,
    activityId: activityId,
    injurySite: injurySite,
    postRunPain: postRunPain,
    postRunRecordedAt: postRunRecordedAt,
    morningAfterPain: morningAfterPain,
    morningStiffness: morningStiffness,
    morningAfterRecordedAt: morningAfterRecordedAt,
    modifiedAt: instant.toUtc(),
  );
}

int feedbackActivityId(String value) {
  final id = int.tryParse(value);
  if (id == null || id == 0 || '$id' != value) {
    throw FormatException('Feedback Activity ID must be exact decimal.');
  }
  return id;
}

String feedbackActivityIdJson(int value) => '$value';

DateTime? feedbackInstant(String? value) {
  if (value == null) return null;
  final format = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$',
  );
  if (!format.hasMatch(value)) {
    throw FormatException('Invalid feedback instant.');
  }
  if (!value.endsWith('Z')) {
    final offset = value.substring(value.length - 5).split(':');
    if (int.parse(offset[0]) > 23 || int.parse(offset[1]) > 59) {
      throw FormatException('Invalid feedback UTC offset.');
    }
  }
  final date = DateTime.parse(value);
  final civil = DateTime.parse('${value.substring(0, 19)}Z');
  if (civil.toIso8601String().substring(0, 19) != value.substring(0, 19)) {
    throw FormatException('Invalid feedback calendar date.');
  }
  return date.toUtc();
}

String? feedbackInstantJson(DateTime? value) =>
    value?.toUtc().toIso8601String();
