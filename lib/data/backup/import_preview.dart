import 'dart:convert';

import 'archive/snapshot_archive.dart';

enum BackupImportMode { smartMerge, replaceAll }

enum BackupImportPhase { idle, picking, validating }

/// Retains the exact validated content independently of callers' mutable DTOs.
class BackupImportPreview {
  final String _archiveJson;
  final int localRevision;
  final Map<String, int> localCounts;

  BackupImportPreview({
    required Map<String, dynamic> archiveJson,
    required this.localRevision,
    required Map<String, int> localCounts,
  }) : _archiveJson = jsonEncode(archiveJson),
       localCounts = Map.unmodifiable(localCounts);

  /// Content binding includes optional metadata and cannot be changed in place.
  String get archiveBinding => _archiveJson;
  SnapshotArchive get archive => SnapshotArchive.fromJson(
    jsonDecode(_archiveJson) as Map<String, dynamic>,
  );
  Map<String, int> get archiveCounts => Map.unmodifiable(archive.counts);
  Map<String, dynamic> get archiveJson =>
      _freeze(jsonDecode(_archiveJson)) as Map<String, dynamic>;
}

Object? _freeze(Object? value) => switch (value) {
  Map<String, dynamic>() => Map<String, dynamic>.unmodifiable(
    value.map((key, item) => MapEntry(key, _freeze(item))),
  ),
  List() => List<Object?>.unmodifiable(value.map(_freeze)),
  _ => value,
};
