import 'package:json_annotation/json_annotation.dart';
import '../snapshot_store.dart';

part 'rehab_feedback_section.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class RehabFeedbackArchive {
  final List<RehabFeedbackArchiveRecord> records;
  const RehabFeedbackArchive({required this.records});
  int get recordCount => records.length;
  factory RehabFeedbackArchive.fromJson(Map<String, dynamic> json) =>
      _$RehabFeedbackArchiveFromJson(json);
  Map<String, dynamic> toJson() => _$RehabFeedbackArchiveToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class RehabFeedbackArchiveRecord {
  final String id;
  const RehabFeedbackArchiveRecord({required this.id});
  factory RehabFeedbackArchiveRecord.fromJson(Map<String, dynamic> json) =>
      _$RehabFeedbackArchiveRecordFromJson(json);
  Map<String, dynamic> toJson() => _$RehabFeedbackArchiveRecordToJson(this);
}

class RehabFeedbackSectionCodec {
  const RehabFeedbackSectionCodec();
  RehabFeedbackArchive encode(LocalSnapshot snapshot) {
    final records = snapshot.stores['rehab_feedback'];
    if (records == null || records.isNotEmpty) {
      throw StateError('Stored Rehab Feedback cannot yet be exported safely.');
    }
    return const RehabFeedbackArchive(records: []);
  }
}
