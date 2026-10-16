import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_model.dart';
import '../../domain/entities/shoe_equipment.dart';
import 'snapshot_store.dart';
import 'durable_preference_checkpoint.dart';

class HiveSnapshotStore extends SnapshotStore {
  @override
  final String name;

  HiveSnapshotStore(this.name);

  Future<Box> get _box async =>
      Hive.isBoxOpen(name) ? Hive.box(name) : await Hive.openBox(name);

  @override
  Future<Map<String, Object?>> read() async {
    final box = await _box;
    final result = <String, Object?>{};
    for (final key in box.keys) {
      if (result.containsKey('$key')) {
        throw StateError('Duplicate persisted key in $name: $key');
      }
      result['$key'] = box.get(key);
    }
    final records = Map<String, Object?>.from(
      jsonDecode(jsonEncode(result)) as Map,
    );
    validate(records);
    return records;
  }

  @override
  void validate(Map<String, Object?> records) {
    super.validate(records);
    if (name == 'equipment') _validateEquipment(records);
    if (name != 'activities' && name != 'hr_streams') return;
    for (final entry in records.values) {
      final row = entry as Map;
      final data = jsonDecode(row['data'] as String);
      if (name == 'activities') {
        ActivityModel.fromJson(Map<String, dynamic>.from(data as Map));
      } else {
        (data as List).map((sample) => (sample as num).toDouble()).toList();
      }
    }
  }

  void _validateEquipment(Map<String, Object?> records) {
    try {
      for (final entry in records.entries) {
        final shoe = ShoeEquipment.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
        if (shoe.id != entry.key) throw StateError('Invalid shoe identity.');
      }
    } catch (error) {
      throw StateError('Stored shoe equipment cannot be read safely: $error');
    }
  }

  @override
  Future<void> replace(Map<String, Object?> records) async {
    final box = await _box;
    await box.clear();
    await box.putAll(
      records.map((key, value) {
        final id = int.tryParse(key);
        final activityStore = name == 'activities' || name == 'hr_streams';
        final Object normalized =
            activityStore && id != null && id >= 0 && id <= 0xFFFFFFFF
            ? id
            : key;
        return MapEntry(normalized, value);
      }),
    );
  }

  @override
  Future<void> flush() async => (await _box).flush();
}

class PreferenceSnapshotStore extends SnapshotStore {
  final Set<String> keys;

  PreferenceSnapshotStore(this.keys);

  @override
  String get name => 'preferences';

  @override
  Future<Map<String, Object?>> read() => DurablePreferenceCheckpoint.read(keys);

  Future<void> restoreMirror() async {
    await _writePreferences(await read());
  }

  @override
  void validate(Map<String, Object?> records) {
    super.validate(records);
    if (records.keys.any((key) => !keys.contains(key))) {
      throw ArgumentError('Unrecognized backup preference.');
    }
    for (final value in records.values) {
      if (value != null &&
          value is! int &&
          value is! double &&
          value is! bool &&
          value is! String &&
          value is! List<String>) {
        throw ArgumentError('Unsupported preference value.');
      }
    }
  }

  @override
  Future<void> replace(Map<String, Object?> records) async {
    validate(records);
    await DurablePreferenceCheckpoint.replace(keys, records);
    await _writePreferences(records);
  }

  Future<void> _writePreferences(Map<String, Object?> records) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in keys) {
      final value = records[key];
      final success = switch (value) {
        null => await prefs.remove(key),
        int() => await prefs.setInt(key, value),
        double() => await prefs.setDouble(key, value),
        bool() => await prefs.setBool(key, value),
        String() => await prefs.setString(key, value),
        List<String>() => await prefs.setStringList(key, value),
        _ => throw ArgumentError('Unsupported preference value: $key'),
      };
      if (!success) throw StateError('Could not persist preference: $key');
    }
  }

  @override
  Future<void> flush() async {}
}
