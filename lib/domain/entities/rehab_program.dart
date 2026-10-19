import 'package:json_annotation/json_annotation.dart';
import 'rehab_feedback.dart';

part 'rehab_program.g.dart';

enum ReturnModality { walkRun, continuous }

@JsonSerializable(fieldRename: FieldRename.snake)
class RehabProgram {
  @JsonKey(fromJson: requiredRehabInstant, toJson: feedbackInstantJson)
  final DateTime startedAt;
  final InjurySite injurySite;
  final ReturnModality mode;
  final double initialWeeklyMinutes;
  final int rampWeeks;
  @JsonKey(fromJson: feedbackInstant, toJson: feedbackInstantJson)
  final DateTime? graduatedAt;

  const RehabProgram({
    required this.startedAt,
    required this.injurySite,
    required this.mode,
    required this.initialWeeklyMinutes,
    required this.rampWeeks,
    this.graduatedAt,
  });

  factory RehabProgram.fromJson(Map<String, dynamic> json) {
    final program = _$RehabProgramFromJson(json);
    program.validate();
    return program;
  }

  Map<String, dynamic> toJson() {
    validate();
    return _$RehabProgramToJson(this);
  }

  void validate() {
    final graduation = graduatedAt;
    if (!initialWeeklyMinutes.isFinite ||
        initialWeeklyMinutes <= 0 ||
        rampWeeks < 1 ||
        rampWeeks > 52 ||
        graduation != null && graduation.isBefore(startedAt)) {
      throw const FormatException('Invalid saved return-to-run episode.');
    }
  }

  RehabProgram copyWith({ReturnModality? mode, DateTime? graduatedAt}) =>
      RehabProgram(
        startedAt: startedAt,
        injurySite: injurySite,
        mode: mode ?? this.mode,
        initialWeeklyMinutes: initialWeeklyMinutes,
        rampWeeks: rampWeeks,
        graduatedAt: graduatedAt ?? this.graduatedAt,
      );
}

DateTime requiredRehabInstant(String value) =>
    feedbackInstant(value) ?? (throw const FormatException('Missing instant.'));
