import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'archive/snapshot_archive.dart';
import 'activity_identity_aliases.dart';
import '../models/activity_model.dart';
import 'import_summary.dart';
import 'import_preview.dart';
import 'snapshot_store.dart';
import 'snapshot_record_merge.dart';
import 'snapshot_activity_signatures.dart';
import 'snapshot_state_merge.dart';

class SnapshotMergePlan {
  final LocalSnapshot state;
  final BackupImportSummary summary;
  const SnapshotMergePlan(this.state, this.summary);
}

SnapshotMergePlan planSmartMerge(
  Map<String, dynamic> archive,
  LocalSnapshot local,
) => _MergePlanner(local).plan(archive['data'] as Map);

class _MergePlanner {
  final LocalSnapshot next;
  late MergeActivityIdentities identities;
  final Map<String, String> remapped = {};
  int added = 0;
  int matched = 0;
  int conflicts = 0;
  _MergePlanner(LocalSnapshot local)
    : next = LocalSnapshot.decode(local.encode(), revision: local.revision);

  SnapshotMergePlan plan(Map data) {
    final inputs = _orderedActivities(data['activities'] as List);
    final signatures = reconcileActivitySignatures(next, inputs);
    remapped.addAll(signatures.targets);
    identities = MergeActivityIdentities(
      next.stores['activities'] ?? {},
      inputs.map((row) => row['id'] as String),
    );
    for (final item in inputs) {
      _activity(Map<String, dynamic>.from(item as Map));
    }
    _validateAliasOwners();
    _streams(data['heart_rate_streams'] as List);
    final records = mergeLinkedRecordState(next, data, remapped);
    conflicts += records.retainedConflicts;
    final profile = mergeProfileState(next, data['profile'] as Map);
    conflicts += profile.$2;
    final training = mergeTrainingPlanState(
      next,
      data['training_plan_state'] as Map,
    );
    conflicts += training.$2;
    return SnapshotMergePlan(
      next,
      BackupImportSummary(
        addedActivities: added,
        matchedActivities: matched,
        signatureMatches: signatures.matches,
        canonicalIdentityChanges: signatures.canonicalChanges,
        ambiguousSignatures: signatures.ambiguities,
        retainedConflicts: conflicts,
        addedShoes: records.addedShoes,
        updatedShoes: records.updatedShoes,
        addedFeedback: records.addedFeedback,
        updatedFeedback: records.updatedFeedback,
        changedAssignments: records.changedAssignments,
        changedPreferences: profile.$1,
        changedTrainingPlan: training.$1,
        warnings: [
          if (signatures.ambiguities > 0)
            'Some workout details are ambiguous. Those activities were kept separate.',
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _orderedActivities(List activities) =>
      List<Map<String, dynamic>>.from(
        activities.map((row) => Map<String, dynamic>.from(row as Map)),
      )..sort(
        (a, b) => BigInt.parse(
          a['id'] as String,
        ).compareTo(BigInt.parse(b['id'] as String)),
      );

  void _validateAliasOwners() {
    final rows = next.stores['activities'] ?? {};
    try {
      validateArchiveAliasOwnership([
        for (final entry in rows.entries)
          {
            ...jsonDecode((entry.value as Map)['data'] as String) as Map,
            'id': entry.key,
            'identity_aliases': (entry.value as Map)['identity_aliases'],
          },
      ]);
    } on FormatException catch (error) {
      throw BackupMergeConflict(error.message);
    }
  }

  void _activity(Map<String, dynamic> input) {
    final activities = next.stores['activities'] ?? <String, Object?>{};
    final original = input['id'] as String;
    final id = remapped[original] ?? identities.resolve(input);
    remapped[original] = id;
    final row = activities[id];
    if (row is Map) {
      final current = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      _fill(current, input);
      activities[id] = {...row, 'data': jsonEncode(current)};
      matched++;
    } else {
      final model = ActivityModel.fromJson({
        ...ArchiveActivity.fromJson(input).toJson(),
        'id': int.parse(id),
      });
      activities[id] = {
        'id': model.id,
        'data': jsonEncode(model.toJson()),
        'synced_at': 0,
      };
      added++;
    }
    final result = Map<String, dynamic>.from(activities[id] as Map);
    final aliases = <String, Map<String, dynamic>>{};
    for (final alias in [
      ...validatedActivityAliases(result['identity_aliases']),
      ...validatedActivityAliases(input['identity_aliases']),
      if (original.startsWith('-')) activityIdentityContext(input),
    ]) {
      aliases[activityAliasKey(alias)] = alias;
    }
    if (aliases.isNotEmpty) {
      final keys = aliases.keys.toList()..sort();
      result['identity_aliases'] = [for (final key in keys) aliases[key]];
    }
    activities[id] = result;
    identities.index(id, result);
    next.stores['activities'] = activities;
  }

  void _fill(Map<String, dynamic> current, Map<String, dynamic> input) {
    for (final key in const [
      'name',
      'distance',
      'moving_time',
      'elapsed_time',
      'total_elevation_gain',
      'average_speed',
      'max_speed',
    ]) {
      if (current[key] != input[key]) conflicts++;
    }
    for (final key in const [
      'average_heartrate',
      'max_heartrate',
      'average_cadence',
      'suffer_score',
      'workout_type',
      'perceived_exertion',
    ]) {
      final incoming = input[key];
      if (current[key] == null) {
        current[key] = incoming;
      } else if (incoming != null && current[key] != incoming) {
        conflicts++;
      }
    }
    if (current['average_heartrate'] != null ||
        current['max_heartrate'] != null) {
      current['has_heartrate'] = true;
    }
  }

  void _streams(List incoming) {
    final streams = next.stores['hr_streams'] ?? <String, Object?>{};
    final ordered = List<Map>.from(incoming)
      ..sort(
        (a, b) => BigInt.parse(
          a['activity_id'] as String,
        ).compareTo(BigInt.parse(b['activity_id'] as String)),
      );
    for (final item in ordered) {
      final input = item;
      final id =
          remapped[input['activity_id']] ?? input['activity_id'] as String;
      final existing = streams[id];
      if (existing is Map &&
          (jsonDecode(existing['data'] as String) as List).isNotEmpty) {
        final current = jsonDecode(existing['data'] as String) as List;
        if ((input['samples'] as List).isNotEmpty &&
            !listEquals(current, input['samples'] as List)) {
          conflicts++;
        }
        continue;
      }
      if ((input['samples'] as List).isNotEmpty) _markHeartRate(id);
      streams[id] = {
        'activity_id': int.parse(id),
        'data': jsonEncode(input['samples']),
        'synced_at': 0,
      };
    }
    next.stores['hr_streams'] = streams;
  }

  void _markHeartRate(String id) {
    final activities = next.stores['activities'];
    final row = activities?[id];
    if (row is! Map) return;
    final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
    data['has_heartrate'] = true;
    activities?[id] = {...row, 'data': jsonEncode(data)};
  }
}
