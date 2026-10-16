import 'snapshot_validation_values.dart';

void validateArchiveReferences(Map<String, dynamic> data) {
  final activities = data['activities'] as List;
  final streams = data['heart_rate_streams'] as List;
  final equipment = archiveObject(data['equipment']);
  final shoes = equipment['shoes'] as List;
  final assignments = equipment['activity_assignments'] as List;
  final feedback = archiveObject(data['rehab_feedback'])['records'] as List;
  for (final rows in [activities, shoes, feedback]) {
    archiveUnique(rows, 'id');
  }
  for (final rows in [streams, assignments]) {
    archiveUnique(rows, 'activity_id');
  }
  final owners = activities.map((row) => archiveObject(row)['id']).toSet();
  final shoeIds = shoes.map((row) => archiveObject(row)['id']).toSet();
  for (final row in [...streams, ...assignments, ...feedback]) {
    if (!owners.contains(archiveObject(row)['activity_id'])) {
      throw FormatException('Backup references a missing Activity.');
    }
  }
  for (final value in assignments) {
    final id = archiveObject(value)['shoe_id'];
    if (id != null && !shoeIds.contains(id)) {
      throw FormatException('Backup assignment references a missing shoe.');
    }
  }
}
