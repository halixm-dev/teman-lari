import 'package:json_annotation/json_annotation.dart';
import '../snapshot_store.dart';

part 'equipment_section.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class EquipmentArchive {
  final List<ShoeArchiveRecord> shoes;
  final List<ShoeAssignmentArchiveRecord> activityAssignments;
  const EquipmentArchive({
    required this.shoes,
    required this.activityAssignments,
  });
  int get recordCount => shoes.length + activityAssignments.length;
  factory EquipmentArchive.fromJson(Map<String, dynamic> json) =>
      _$EquipmentArchiveFromJson(json);
  Map<String, dynamic> toJson() => _$EquipmentArchiveToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ShoeArchiveRecord {
  final String id;
  const ShoeArchiveRecord({required this.id});
  factory ShoeArchiveRecord.fromJson(Map<String, dynamic> json) =>
      _$ShoeArchiveRecordFromJson(json);
  Map<String, dynamic> toJson() => _$ShoeArchiveRecordToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ShoeAssignmentArchiveRecord {
  final String activityId;
  final String shoeId;
  const ShoeAssignmentArchiveRecord({
    required this.activityId,
    required this.shoeId,
  });
  factory ShoeAssignmentArchiveRecord.fromJson(Map<String, dynamic> json) =>
      _$ShoeAssignmentArchiveRecordFromJson(json);
  Map<String, dynamic> toJson() => _$ShoeAssignmentArchiveRecordToJson(this);
}

class EquipmentSectionCodec {
  const EquipmentSectionCodec();
  EquipmentArchive encode(LocalSnapshot snapshot) {
    final records = snapshot.stores['equipment'];
    if (records == null || records.isNotEmpty) {
      throw StateError('Stored shoe equipment cannot yet be exported safely.');
    }
    return const EquipmentArchive(shoes: [], activityAssignments: []);
  }
}
