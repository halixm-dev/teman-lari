import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
import '../../../domain/entities/shoe_equipment.dart';
import '../../models/activity_model.dart';
import '../snapshot_store.dart';

part 'equipment_section.g.dart';

typedef ShoeArchiveRecord = ShoeEquipment;

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
class ShoeAssignmentArchiveRecord {
  final String activityId;
  final String? shoeId;
  final DateTime? modifiedAt;
  const ShoeAssignmentArchiveRecord({
    required this.activityId,
    required this.shoeId,
    this.modifiedAt,
  });
  factory ShoeAssignmentArchiveRecord.fromJson(Map<String, dynamic> json) =>
      _$ShoeAssignmentArchiveRecordFromJson(json);
  Map<String, dynamic> toJson() => _$ShoeAssignmentArchiveRecordToJson(this);
}

class EquipmentSectionCodec {
  const EquipmentSectionCodec();
  EquipmentArchive encode(LocalSnapshot snapshot) {
    final records = snapshot.stores['equipment'];
    if (records == null) throw StateError('Missing shoe equipment store.');
    final shoes = records.entries.map((entry) {
      final shoe = ShoeEquipment.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
      if (shoe.id != entry.key) {
        throw StateError('Stored shoe identity is inconsistent.');
      }
      return shoe;
    }).toList();
    final ids = shoes.map((shoe) => shoe.id).toSet();
    final assignments = <ShoeAssignmentArchiveRecord>[];
    for (final entry in (snapshot.stores['activities'] ?? {}).entries) {
      final row = entry.value as Map;
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      validateShoeInstant(data['shoe_assignment_modified_at']);
      final model = ActivityModel.fromJson(data);
      final shoeId = model.shoeId;
      if (shoeId == null && model.shoeAssignmentModifiedAt == null) continue;
      if (shoeId != null && !ids.contains(shoeId)) {
        throw StateError('Activity references a missing shoe.');
      }
      assignments.add(
        ShoeAssignmentArchiveRecord(
          activityId: entry.key,
          shoeId: shoeId,
          modifiedAt: model.shoeAssignmentModifiedAt?.toUtc(),
        ),
      );
    }
    return EquipmentArchive(shoes: shoes, activityAssignments: assignments);
  }
}
