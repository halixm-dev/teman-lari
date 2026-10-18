import 'dart:convert';
import '../backup/activity_identity_aliases.dart';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/activity_model.dart';
import 'local_equipment_datasource.dart';
import '../backup/local_data_coordinator.dart';
import '../backup/snapshot_backup_service.dart';
import 'local_activity_identity_migration.dart';

/// Transparent proxy around Hive [Box] ensuring that negative integer IDs
/// and 64-bit integer IDs do not trigger Hive's [Frame.assertKey] error,
/// while maintaining full compatibility with integer key lookups and queries.
class _SafeBox implements Box {
  final Box _box;

  _SafeBox(this._box);

  static dynamic _normalizeKey(dynamic key) {
    if (key is int) {
      if (key >= 0 && key <= 0xFFFFFFFF) {
        return key;
      }
      return key.toString();
    }
    return key;
  }

  static dynamic _denormalizeKey(dynamic key) {
    if (key is String) {
      final parsed = int.tryParse(key);
      if (parsed != null && (parsed < 0 || parsed > 0xFFFFFFFF)) {
        return parsed;
      }
    }
    return key;
  }

  @override
  Iterable get values => _box.values;

  @override
  Iterable valuesBetween({dynamic startKey, dynamic endKey}) =>
      _box.valuesBetween(
        startKey: _normalizeKey(startKey),
        endKey: _normalizeKey(endKey),
      );

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) {
    final norm = _normalizeKey(key);
    var val = _box.get(norm);
    if (val != null) return val;
    if (key is int) {
      val = _box.get(key.toString());
      if (val != null) return val;
    } else if (key is String) {
      final parsed = int.tryParse(key);
      if (parsed != null) {
        val = _box.get(parsed);
        if (val != null) return val;
      }
    }
    return defaultValue;
  }

  @override
  dynamic getAt(int index) => _box.getAt(index);

  @override
  Map<dynamic, dynamic> toMap() =>
      _box.toMap().map((k, v) => MapEntry(_denormalizeKey(k), v));

  @override
  String get name => _box.name;

  @override
  bool get isOpen => _box.isOpen;

  @override
  String? get path => _box.path;

  @override
  bool get lazy => _box.lazy;

  @override
  Iterable get keys => _box.keys.map(_denormalizeKey);

  @override
  int get length => _box.length;

  @override
  bool get isEmpty => _box.isEmpty;

  @override
  bool get isNotEmpty => _box.isNotEmpty;

  @override
  dynamic keyAt(int index) => _denormalizeKey(_box.keyAt(index));

  @override
  Stream<BoxEvent> watch({dynamic key}) => _box.watch(key: _normalizeKey(key));

  @override
  bool containsKey(dynamic key) {
    if (_box.containsKey(_normalizeKey(key))) return true;
    if (key is int && _box.containsKey(key.toString())) return true;
    if (key is String) {
      final parsed = int.tryParse(key);
      if (parsed != null && _box.containsKey(parsed)) return true;
    }
    return false;
  }

  @override
  Future<void> put(dynamic key, dynamic value) =>
      _box.put(_normalizeKey(key), value);

  @override
  Future<void> putAt(int index, dynamic value) => _box.putAt(index, value);

  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) =>
      _box.putAll(entries.map((k, v) => MapEntry(_normalizeKey(k), v)));

  @override
  Future<int> add(dynamic value) => _box.add(value);

  @override
  Future<Iterable<int>> addAll(Iterable<dynamic> values) => _box.addAll(values);

  @override
  Future<void> delete(dynamic key) async {
    await _box.delete(_normalizeKey(key));
    if (key is int) await _box.delete(key.toString());
    if (key is String) {
      final parsed = int.tryParse(key);
      if (parsed != null) await _box.delete(parsed);
    }
  }

  @override
  Future<void> deleteAt(int index) => _box.deleteAt(index);

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    for (final k in keys) {
      await delete(k);
    }
  }

  @override
  Future<void> compact() => _box.compact();

  @override
  Future<int> clear() => _box.clear();

  @override
  Future<void> close() => _box.close();

  @override
  Future<void> deleteFromDisk() => _box.deleteFromDisk();

  @override
  Future<void> flush() => _box.flush();
}

class LocalActivityDataSource {
  final LocalDataCoordinator coordinator;
  final DateTime Function() clock;
  final SnapshotBackupService? backupService;
  LocalActivityDataSource({
    LocalDataCoordinator? coordinator,
    DateTime Function()? clock,
    this.backupService,
  }) : coordinator =
           coordinator ??
           backupService?.coordinator ??
           LocalDataCoordinator.shared,
       clock = clock ?? DateTime.now;

  static const _activitiesBoxName = 'activities';
  static const _hrStreamsBoxName = 'hr_streams';

  Box? _activitiesBox;
  Box? _hrStreamsBox;

  Future<Box> get activitiesBox async {
    final box = _activitiesBox;
    if (box != null && box.isOpen) return box;
    final opened = Hive.isBoxOpen(_activitiesBoxName)
        ? Hive.box(_activitiesBoxName)
        : await Hive.openBox(_activitiesBoxName);
    final safeBox = _SafeBox(opened);
    _activitiesBox = safeBox;
    return safeBox;
  }

  Future<Box> get hrStreamsBox async {
    final box = _hrStreamsBox;
    if (box != null && box.isOpen) return box;
    final opened = Hive.isBoxOpen(_hrStreamsBoxName)
        ? Hive.box(_hrStreamsBoxName)
        : await Hive.openBox(_hrStreamsBoxName);
    final safeBox = _SafeBox(opened);
    _hrStreamsBox = safeBox;
    return safeBox;
  }

  Future<void> saveActivities(List<ActivityModel> activities) =>
      activities.isEmpty
      ? Future.value()
      : _write(() => _saveActivities(activities));
  Future<void> saveActivity(ActivityModel activity) =>
      _write(() => _saveActivity(activity));
  Future<void> updateActivity(ActivityModel activity) =>
      _write(() => _updateActivity(activity));
  Future<void> updateLocalActivityId(
    int oldLocalId,
    ActivityModel updatedModel,
  ) => _write(() => _updateLocalActivityId(oldLocalId, updatedModel));
  Future<void> smartMergeActivities(List<ActivityModel> remoteActivities) =>
      remoteActivities.isEmpty
      ? Future.value()
      : _write(() => _smartMergeActivities(remoteActivities));
  Future<List<ActivityModel>?> getCachedActivities({bool checkTtl = true}) =>
      coordinator.read(() => _getCachedActivities(checkTtl: checkTtl));
  Future<List<ActivityModel>> getAllActivities() =>
      coordinator.read(_getAllActivities);
  Future<void> saveHeartRateStream(int activityId, List<double> data) =>
      _write(() => _saveHeartRateStream(activityId, data));
  Future<Map<int, List<double>>> getCachedHeartRateStreams({
    bool checkTtl = true,
  }) => coordinator.read(() => _getCachedHeartRateStreams(checkTtl: checkTtl));
  Future<void> clearCache() => _write(_clearCache);

  Future<void> _write(Future<void> Function() operation) =>
      coordinator.write(() async {
        await operation();
        final activities = _activitiesBox;
        final streams = _hrStreamsBox;
        if (activities != null && activities.isOpen) await activities.flush();
        if (streams != null && streams.isOpen) await streams.flush();
      });

  Future<ActivityModel> _assignment(ActivityModel activity) async {
    final shoeId = activity.shoeId;
    await _ensureShoe(shoeId);
    final raw = (await activitiesBox).get(_toKey(activity.id));
    final old = raw is Map
        ? ActivityModel.fromJson(
            jsonDecode(raw['data'] as String) as Map<String, dynamic>,
          )
        : null;
    final changed = old?.shoeId != shoeId;
    return activity.copyWith(
      shoeAssignmentModifiedAt: changed
          ? clock().toUtc()
          : old?.shoeAssignmentModifiedAt,
    );
  }

  Future<void> _ensureShoe(String? shoeId) async {
    if (shoeId == null) return;
    final shoes = await LocalEquipmentDataSource(
      coordinator: coordinator,
    ).getAll();
    if (!shoes.any((shoe) => shoe.id == shoeId)) {
      throw ArgumentError('Activity references a missing shoe.');
    }
  }

  /// Converts an activity ID to a valid Hive box key.
  /// 32-bit non-negative integers (0 to 0xFFFFFFFF) can be stored directly as int keys,
  /// while negative IDs and 64-bit IDs must be stored as String keys to satisfy Hive constraints.
  dynamic _toKey(int id) {
    if (id >= 0 && id <= 0xFFFFFFFF) {
      return id;
    }
    return id.toString();
  }

  Map<String, Object?> _identityMetadata(Object? row) =>
      row is Map && row.containsKey('identity_aliases')
      ? {'identity_aliases': validatedActivityAliases(row['identity_aliases'])}
      : {};

  /// Saves a batch of activities additively into Hive.
  Future<void> _saveActivities(List<ActivityModel> activities) async {
    if (activities.isEmpty) return;
    try {
      final box = await activitiesBox;
      final Map<dynamic, Map<String, dynamic>> entries = {};
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final input in activities) {
        final activity = await _assignment(input);
        entries[_toKey(activity.id)] = {
          ..._identityMetadata(box.get(_toKey(activity.id))),
          'id': activity.id,
          'data': jsonEncode(activity.toJson()),
          'synced_at': now,
        };
      }
      if (entries.isNotEmpty) {
        await box.putAll(entries);
      }
    } catch (_) {
      rethrow;
    }
  }

  /// Saves a single activity into Hive.
  Future<void> _saveActivity(ActivityModel activity) async {
    activity = await _assignment(activity);
    try {
      final box = await activitiesBox;
      final key = _toKey(activity.id);
      await box.put(key, {
        ..._identityMetadata(box.get(key)),
        'id': activity.id,
        'data': jsonEncode(activity.toJson()),
        'synced_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {
      rethrow;
    }
  }

  /// Updates an existing activity, preserving original synced_at timestamp if present.
  Future<void> _updateActivity(ActivityModel activity) async {
    activity = await _assignment(activity);
    try {
      final box = await activitiesBox;
      final key = _toKey(activity.id);
      final existing = box.get(key) as Map?;
      final syncedAt =
          existing?['synced_at'] as int? ??
          DateTime.now().millisecondsSinceEpoch;

      await box.put(key, {
        ..._identityMetadata(box.get(key)),
        'id': activity.id,
        'data': jsonEncode(activity.toJson()),
        'synced_at': syncedAt,
      });
    } catch (_) {
      rethrow;
    }
  }

  /// Re-key the Activity, stream and check-ins in one recoverable normal edit.
  Future<void> _updateLocalActivityId(
    int oldLocalId,
    ActivityModel updatedModel,
  ) => migrateLocalActivityIdentity(
    backupService ?? SnapshotBackupService(coordinator: coordinator),
    oldLocalId,
    updatedModel,
  );

  /// Additively merges remote Strava activities into the local store,
  /// strictly preserving all local-only activities (id < 0) and
  /// retaining any local-only metadata/annotations on matching activities.
  Future<void> _smartMergeActivities(
    List<ActivityModel> remoteActivities,
  ) async {
    if (remoteActivities.isEmpty) return;
    final box = await activitiesBox;
    final Map<dynamic, Map<String, dynamic>> entries = {};
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final remote in remoteActivities) {
      final key = _toKey(remote.id);
      final existingRaw = box.get(key);
      ActivityModel merged = remote;
      int syncedAt = now;
      if (existingRaw is Map) {
        try {
          final existingModel = ActivityModel.fromJson(
            jsonDecode(existingRaw['data'] as String),
          );
          syncedAt = existingRaw['synced_at'] as int? ?? now;
          merged = merged.copyWith(
            shoeId: existingModel.shoeAssignmentModifiedAt != null
                ? existingModel.shoeId
                : existingModel.shoeId ?? remote.shoeId,
            shoeAssignmentModifiedAt: existingModel.shoeAssignmentModifiedAt,
          );
          if (remote.perceivedExertion == null &&
              existingModel.perceivedExertion != null) {
            merged = merged.copyWith(
              perceivedExertion: existingModel.perceivedExertion,
            );
          }
        } catch (_) {}
      }
      await _ensureShoe(merged.shoeId);
      entries[key] = {
        ..._identityMetadata(existingRaw),
        'id': merged.id,
        'data': jsonEncode(merged.toJson()),
        'synced_at': syncedAt,
      };
    }
    if (entries.isNotEmpty) {
      await box.putAll(entries);
    }
  }

  /// Returns cached activities. Preserved for backwards compatibility with legacy callers
  /// and existing unit tests.
  /// When [checkTtl] is true, returns null if oldest activity is older than 1 hour.
  Future<List<ActivityModel>?> _getCachedActivities({
    bool checkTtl = true,
  }) async {
    try {
      final box = await activitiesBox;
      if (box.isEmpty) return null;

      final values = box.values.cast<Map>();
      final sortedList = values.toList()
        ..sort((a, b) {
          final idA = a['id'] as int;
          final idB = b['id'] as int;
          return idB.compareTo(idA);
        });

      if (checkTtl) {
        final oldest = sortedList.last['synced_at'] as int;
        final age = DateTime.now().millisecondsSinceEpoch - oldest;
        if (age > 3600 * 1000) return null;
      }

      return sortedList
          .map((r) => ActivityModel.fromJson(jsonDecode(r['data'] as String)))
          .toList();
    } catch (_) {
      rethrow;
    }
  }

  /// Permanent Single Source of Truth (SSOT) retrieval with Zero-TTL.
  /// Returns all stored activities sorted chronologically descending (newest first).
  /// Never returns null; returns an empty list if no activities exist.
  Future<List<ActivityModel>> _getAllActivities() async {
    try {
      final box = await activitiesBox;
      if (box.isEmpty) return [];

      final values = box.values.cast<Map>();
      final activities = values
          .map((r) => ActivityModel.fromJson(jsonDecode(r['data'] as String)))
          .toList();

      activities.sort((a, b) {
        final dateCompare = DateTime.parse(
          b.startDate,
        ).compareTo(DateTime.parse(a.startDate));
        if (dateCompare != 0) return dateCompare;
        return b.id.compareTo(a.id);
      });

      return activities;
    } catch (_) {
      return [];
    }
  }

  /// Saves a heart rate stream for an activity.
  Future<void> _saveHeartRateStream(int activityId, List<double> data) async {
    try {
      final box = await hrStreamsBox;
      final key = _toKey(activityId);
      await box.put(key, {
        ..._identityMetadata(box.get(key)),
        'activity_id': activityId,
        'data': jsonEncode(data),
        'synced_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {
      rethrow;
    }
  }

  /// Retrieves cached heart rate streams.
  /// When [checkTtl] is true, filters out streams older than 1 hour.
  Future<Map<int, List<double>>> _getCachedHeartRateStreams({
    bool checkTtl = true,
  }) async {
    try {
      final box = await hrStreamsBox;
      if (box.isEmpty) return {};

      final result = <int, List<double>>{};
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final value in box.values) {
        final row = value as Map;
        if (checkTtl) {
          final age = now - (row['synced_at'] as int);
          if (age > 3600 * 1000) continue;
        }

        final id = row['activity_id'] as int;
        final raw = row['data'] as String;
        result[id] = (jsonDecode(raw) as List<dynamic>).cast<double>();
      }
      return result;
    } catch (_) {
      rethrow;
    }
  }

  /// Permanent Zero-TTL retrieval for all stored heart rate streams.
  Future<Map<int, List<double>>> getAllHeartRateStreams() =>
      getCachedHeartRateStreams(checkTtl: false);

  /// Clears all stored activities and heart rate streams.
  Future<void> _clearCache() async {
    try {
      final feedback = Hive.isBoxOpen('rehab_feedback')
          ? Hive.box('rehab_feedback')
          : await Hive.openBox('rehab_feedback');
      if (feedback.isNotEmpty) {
        throw StateError(
          'Cannot clear Activities while Rehab Feedback is linked.',
        );
      }
      final boxAct = await activitiesBox;
      final boxHr = await hrStreamsBox;
      await boxAct.clear();
      await boxHr.clear();
    } catch (_) {
      rethrow;
    }
  }
}
