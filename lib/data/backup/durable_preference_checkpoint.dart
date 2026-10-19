import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hive is the durable source; SharedPreferences remains the app-facing mirror.
/// This internal checkpoint is never an archive section.
class DurablePreferenceCheckpoint {
  static const boxName = 'snapshot_preferences';
  static const _initialized = '__initialized';
  static bool get isInitialized => Hive.isBoxOpen(boxName);

  static Future<Box> get _box async =>
      Hive.isBoxOpen(boxName) ? Hive.box(boxName) : await Hive.openBox(boxName);

  static Future<void> initialize(Set<String> keys) async {
    final box = await _box;
    if (box.get(_initialized) == true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await box.putAll({
      for (final key in keys)
        if (prefs.containsKey(key)) key: prefs.get(key),
      _initialized: true,
    });
    await box.flush();
  }

  static Future<Map<String, Object?>> read(Set<String> keys) async {
    await initialize(keys);
    final box = await _box;
    return {
      for (final key in keys)
        if (box.containsKey(key)) key: box.get(key),
    };
  }

  static Future<void> replace(
    Set<String> keys,
    Map<String, Object?> state,
  ) async {
    final box = await _box;
    await box.deleteAll(keys.where((key) => !state.containsKey(key)));
    await box.putAll({...state, _initialized: true});
    await box.flush();
  }

  static Future<void> record(
    SharedPreferences prefs,
    String key,
    String timestamp,
  ) async {
    // Legacy isolated storage clients need no Hive initialization. Production
    // opens this checkpoint before creating any normal providers.
    if (!Hive.isBoxOpen(boxName)) return;
    final box = Hive.box(boxName);
    if (prefs.containsKey(key)) {
      await box.put(key, prefs.get(key));
    } else {
      await box.delete(key);
    }
    await box.put('${key}_modified_at', timestamp);
    await box.flush();
  }
}
