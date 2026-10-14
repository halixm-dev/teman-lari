// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'equipment_section.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EquipmentArchive _$EquipmentArchiveFromJson(Map<String, dynamic> json) =>
    EquipmentArchive(
      shoes: (json['shoes'] as List<dynamic>)
          .map((e) => ShoeArchiveRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      activityAssignments: (json['activity_assignments'] as List<dynamic>)
          .map(
            (e) =>
                ShoeAssignmentArchiveRecord.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );

Map<String, dynamic> _$EquipmentArchiveToJson(EquipmentArchive instance) =>
    <String, dynamic>{
      'shoes': instance.shoes.map((e) => e.toJson()).toList(),
      'activity_assignments': instance.activityAssignments
          .map((e) => e.toJson())
          .toList(),
    };

ShoeArchiveRecord _$ShoeArchiveRecordFromJson(Map<String, dynamic> json) =>
    ShoeArchiveRecord(id: json['id'] as String);

Map<String, dynamic> _$ShoeArchiveRecordToJson(ShoeArchiveRecord instance) =>
    <String, dynamic>{'id': instance.id};

ShoeAssignmentArchiveRecord _$ShoeAssignmentArchiveRecordFromJson(
  Map<String, dynamic> json,
) => ShoeAssignmentArchiveRecord(
  activityId: json['activity_id'] as String,
  shoeId: json['shoe_id'] as String,
);

Map<String, dynamic> _$ShoeAssignmentArchiveRecordToJson(
  ShoeAssignmentArchiveRecord instance,
) => <String, dynamic>{
  'activity_id': instance.activityId,
  'shoe_id': instance.shoeId,
};
