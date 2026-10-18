import 'import_preview.dart';
import 'dart:convert';
import 'archive/snapshot_validation_values.dart';

Map<String, dynamic> activityIdentityContext(
  Map activity, {
  String? sourceId,
}) => {
  'source_id': sourceId ?? '${activity['id']}',
  'type': activity['type'],
  'start_date': DateTime.parse(
    activity['start_date'] as String,
  ).toUtc().toIso8601String(),
  'distance_meters': BigInt.from(
    (activity['distance'] as num).toDouble().roundToDouble(),
  ).toString(),
};

String activityAliasKey(Map value) => jsonEncode([
  value['source_id'],
  value['type'],
  DateTime.parse(value['start_date'] as String).toUtc().toIso8601String(),
  value['distance_meters'],
]);

List<Map<String, dynamic>> validatedActivityAliases(
  Object? value, {
  Map? owner,
}) {
  if (value == null) return [];
  if (value is! List) throw FormatException('Invalid Activity aliases.');
  final keys = <String>{};
  return value.map((item) {
    final alias = archiveShape(item, {
      'source_id': archiveIdentity,
      'type': archiveNonempty,
      'start_date': archiveInstant,
      'distance_meters': archiveString,
    });
    final meters = alias['distance_meters'] as String;
    if (BigInt.parse(alias['source_id'] as String) >= BigInt.zero ||
        meters.length > 309 ||
        !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(meters)) {
      throw FormatException('Invalid Activity alias identity or distance.');
    }
    final number = double.tryParse(meters);
    if (number == null ||
        !number.isFinite ||
        BigInt.from(number).toString() != meters) {
      throw const FormatException('Invalid Activity alias rounded distance.');
    }
    if (owner != null &&
        (alias['type'] != owner['type'] ||
            DateTime.parse(alias['start_date'] as String).toUtc() !=
                DateTime.parse(owner['start_date'] as String).toUtc())) {
      throw FormatException('Activity alias belongs to another workout.');
    }
    if (!keys.add(activityAliasKey(alias))) {
      throw FormatException('Repeated Activity alias.');
    }
    return {
      for (final key in ['source_id', 'type', 'start_date', 'distance_meters'])
        key: alias[key],
    };
  }).toList();
}

void validateArchiveAliasOwnership(List activities) {
  final owners = <String, String>{};
  for (final item in activities) {
    final row = item as Map;
    for (final alias in validatedActivityAliases(
      row['identity_aliases'],
      owner: row,
    )) {
      final key = activityAliasKey(alias);
      final previous = owners[key];
      if (previous != null && previous != row['id']) {
        throw const FormatException('An Activity alias has multiple owners.');
      }
      owners[key] = row['id'] as String;
    }
  }
}

class MergeActivityIdentities {
  final Map<String, Object?> activities;
  final Set<String> reserved;
  final Map<String, Set<String>> _contexts = {};
  int _available = -1;
  MergeActivityIdentities(this.activities, Iterable<String> incoming)
    : reserved = {...activities.keys, ...incoming} {
    for (final entry in activities.entries) {
      index(entry.key, Map<String, dynamic>.from(entry.value as Map));
    }
  }

  void index(String id, Map<String, dynamic> row) {
    final model = jsonDecode(row['data'] as String) as Map<String, dynamic>;
    final contexts = [
      if (id.startsWith('-')) activityIdentityContext(model, sourceId: id),
      ...validatedActivityAliases(row['identity_aliases'], owner: model),
    ];
    for (final context in contexts) {
      (_contexts[activityAliasKey(context)] ??= {}).add(id);
    }
  }

  String resolve(Map<String, dynamic> incoming) {
    final id = incoming['id'] as String;
    final existing = activities[id];
    if (!id.startsWith('-')) {
      if (existing is Map) _compatible(existing, incoming, id == '0');
      return id;
    }
    final contexts = [
      activityIdentityContext(incoming),
      ...validatedActivityAliases(
        incoming['identity_aliases'],
        owner: incoming,
      ),
    ];
    final candidates = <String>{};
    for (final context in contexts) {
      candidates.addAll(_contexts[activityAliasKey(context)] ?? {});
    }
    if (candidates.length == 1) {
      final destination = activities[candidates.single];
      if (destination is Map) _compatible(destination, incoming, false);
      return candidates.single;
    }
    return existing == null ? id : _fresh();
  }

  void _compatible(Map row, Map incoming, bool checkDistance) {
    final current = jsonDecode(row['data'] as String) as Map;
    if (current['type'] != incoming['type'] ||
        DateTime.parse(current['start_date'] as String).toUtc() !=
            DateTime.parse(incoming['start_date'] as String).toUtc() ||
        checkDistance &&
            activityIdentityContext(current)['distance_meters'] !=
                activityIdentityContext(incoming)['distance_meters']) {
      throw const BackupMergeConflict(
        'Activity ID has incompatible type or start.',
      );
    }
  }

  String _fresh() {
    while (reserved.contains('$_available')) {
      _available--;
    }
    archiveIdentity('$_available');
    final id = '$_available';
    reserved.add(id);
    _available--;
    return id;
  }
}
