import 'dart:convert';
import '../../domain/entities/shoe_equipment.dart';
import '../../domain/entities/rehab_feedback.dart';
import '../models/activity_model.dart';
import 'snapshot_store.dart';
import 'import_preview.dart';

class LinkedRecordMergeSummary {
  int addedShoes = 0;
  int updatedShoes = 0;
  int addedFeedback = 0;
  int updatedFeedback = 0;
  int changedAssignments = 0;
  int retainedConflicts = 0;
}

LinkedRecordMergeSummary mergeLinkedRecordState(
  LocalSnapshot next,
  Map archiveData,
  Map<String, String> remapped,
) {
  final summary = LinkedRecordMergeSummary();
  mergeEquipmentState(next, archiveData['equipment'] as Map, remapped, summary);
  _feedback(next, archiveData['rehab_feedback'] as Map, remapped, summary);
  return summary;
}

void mergeEquipmentState(
  LocalSnapshot next,
  Map incoming,
  Map<String, String> remapped,
  LinkedRecordMergeSummary summary,
) {
  final equipment = next.stores['equipment'] ?? <String, Object?>{};
  final shoes = List<Map>.from(incoming['shoes'] as List)
    ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
  for (final shoe in shoes) {
    _shoe(equipment, Map<String, dynamic>.from(shoe), summary);
  }
  next.stores['equipment'] = equipment;
  final assignments = List<Map>.from(incoming['activity_assignments'] as List)
    ..sort(
      (a, b) => BigInt.parse(
        a['activity_id'] as String,
      ).compareTo(BigInt.parse(b['activity_id'] as String)),
    );
  for (final assignment in assignments) {
    _assignment(next, assignment, remapped, summary);
  }
}

void _shoe(
  Map<String, Object?> equipment,
  Map<String, dynamic> row,
  LinkedRecordMergeSummary summary,
) {
  final imported = ShoeEquipment.fromJson(row);
  final stored = equipment[imported.id];
  if (stored == null) {
    equipment[imported.id] = imported.toJson();
    summary.addedShoes++;
    return;
  }
  final current = ShoeEquipment.fromJson(
    Map<String, dynamic>.from(stored as Map),
  );
  if (current.createdAt != null &&
      imported.createdAt != null &&
      current.createdAt != imported.createdAt) {
    throw const BackupMergeConflict(
      'A shoe ID has a different creation identity.',
    );
  }
  if (_newer(current.modifiedAt, imported.modifiedAt)) {
    equipment[imported.id] = {
      ...imported.toJson(),
      'created_at': (current.createdAt ?? imported.createdAt)
          ?.toUtc()
          .toIso8601String(),
    };
    summary.updatedShoes++;
  } else if (_differentValues(
    current.toJson()..remove('created_at'),
    imported.toJson()..remove('created_at'),
  )) {
    summary.retainedConflicts++;
  }
}

void _assignment(
  LocalSnapshot next,
  Map incoming,
  Map<String, String> remapped,
  LinkedRecordMergeSummary summary,
) {
  final owner =
      remapped[incoming['activity_id']] ?? incoming['activity_id'] as String;
  final activities = next.stores['activities'] ?? <String, Object?>{};
  final row = activities[owner] as Map;
  final model = ActivityModel.fromJson(
    jsonDecode(row['data'] as String) as Map<String, dynamic>,
  );
  if (model.shoeId != null || model.shoeAssignmentModifiedAt != null) {
    if (model.shoeId != incoming['shoe_id']) summary.retainedConflicts++;
    return;
  }
  final modified = incoming['modified_at'];
  final updated = model.copyWith(
    shoeId: incoming['shoe_id'] as String?,
    shoeAssignmentModifiedAt: modified == null
        ? null
        : DateTime.parse(modified as String).toUtc(),
  );
  activities[owner] = {...row, 'data': jsonEncode(updated.toJson())};
  summary.changedAssignments++;
  next.stores['activities'] = activities;
}

void _feedback(
  LocalSnapshot next,
  Map incoming,
  Map<String, String> remapped,
  LinkedRecordMergeSummary summary,
) {
  final records = next.stores['rehab_feedback'] ?? <String, Object?>{};
  final offered = List<Map>.from(incoming['records'] as List)
    ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
  for (final row in offered) {
    final id = row['id'] as String;
    final owner = row['activity_id'] as String;
    final imported = RehabFeedback.fromJson({
      ...Map<String, dynamic>.from(row),
      'activity_id': remapped[owner] ?? owner,
    });
    final stored = records[id];
    if (stored == null) {
      records[id] = imported.toJson();
      summary.addedFeedback++;
    } else {
      final current = RehabFeedback.fromJson(
        Map<String, dynamic>.from(stored as Map),
      );
      if (!current.hasSameIdentity(imported)) {
        throw const BackupMergeConflict(
          'A Rehab Feedback ID belongs to a different Activity or injury site.',
        );
      }
      if (_newer(current.modifiedAt, imported.modifiedAt)) {
        records[id] = imported.toJson();
        summary.updatedFeedback++;
      } else if (_differentValues(current.toJson(), imported.toJson())) {
        summary.retainedConflicts++;
      }
    }
  }
  next.stores['rehab_feedback'] = records;
}

bool _newer(DateTime? local, DateTime? incoming) =>
    local != null && incoming != null && incoming.isAfter(local);

bool _differentValues(
  Map<String, dynamic> local,
  Map<String, dynamic> incoming,
) {
  final previous = {...local}..remove('modified_at');
  final offered = {...incoming}..remove('modified_at');
  return jsonEncode(previous) != jsonEncode(offered);
}
