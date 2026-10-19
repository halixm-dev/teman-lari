import 'package:json_annotation/json_annotation.dart';
import '../../../domain/entities/rehab_feedback.dart';
import '../snapshot_store.dart';

export '../../../domain/entities/rehab_feedback.dart' show RehabFeedback;
part 'rehab_feedback_section.g.dart';

typedef RehabFeedbackArchiveRecord = RehabFeedback;

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class RehabFeedbackArchive {
  final List<RehabFeedback> records;
  const RehabFeedbackArchive({required this.records});
  int get recordCount => records.length;
  factory RehabFeedbackArchive.fromJson(Map<String, dynamic> json) =>
      _$RehabFeedbackArchiveFromJson(json);
  Map<String, dynamic> toJson() => _$RehabFeedbackArchiveToJson(this);
}

class RehabFeedbackSectionCodec {
  const RehabFeedbackSectionCodec();
  RehabFeedbackArchive encode(LocalSnapshot snapshot) {
    final records = snapshot.stores['rehab_feedback'];
    if (records == null) throw StateError('Missing Rehab Feedback store.');
    final owners = snapshot.stores['activities']?.keys.toSet() ?? <String>{};
    final result = <RehabFeedback>[];
    for (final entry in records.entries) {
      final feedback = RehabFeedback.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
      if (entry.key != feedback.id ||
          !owners.contains('${feedback.activityId}')) {
        throw FormatException(
          'Feedback identity or Activity reference is invalid.',
        );
      }
      result.add(feedback);
    }
    result.sort((a, b) => a.id.compareTo(b.id));
    return RehabFeedbackArchive(records: result);
  }
}
