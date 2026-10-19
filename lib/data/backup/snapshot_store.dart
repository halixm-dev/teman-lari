import 'dart:convert';

/// Complete local state. Keys are store names, then persisted record keys.
/// Domain archive encoding belongs above this storage contract.
class LocalSnapshot {
  final int revision;
  final Map<String, Map<String, Object?>> stores;

  LocalSnapshot({required this.revision, required this.stores});

  String encode() => jsonEncode(stores);

  factory LocalSnapshot.decode(String value, {int revision = 0}) {
    final decoded = jsonDecode(value) as Map<String, dynamic>;
    return LocalSnapshot(
      revision: revision,
      stores: decoded.map(
        (key, value) => MapEntry(key, Map<String, Object?>.from(value as Map)),
      ),
    );
  }
}

abstract class SnapshotStore {
  String get name;
  Future<Map<String, Object?>> read();
  Future<void> replace(Map<String, Object?> records);
  Future<void> flush();
  void validate(Map<String, Object?> records) => jsonEncode(records);
}
