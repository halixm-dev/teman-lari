import 'dart:convert';
import 'import_summary.dart';

import 'archive/snapshot_archive.dart';

class BackupMergeConflict extends FormatException {
  const BackupMergeConflict(super.message);
}

enum BackupImportMode { smartMerge, replaceAll }

enum BackupImportPhase { idle, picking, validating, applying }

/// Retains the exact validated content independently of callers' mutable DTOs.
class BackupImportPreview {
  final String _archiveJson;
  final int localRevision;
  final BackupImportSummary summary;
  final BackupImportSummary replacementSummary;
  final String? mergeError;
  final String snapshotId;
  final DateTime createdAt;
  final int schemaVersion;
  final String appVersion;
  final Map<String, int> archiveCounts;
  final Map<String, int> localCounts;

  BackupImportPreview({
    required Map<String, dynamic> archiveJson,
    required this.localRevision,
    this.summary = const BackupImportSummary(),
    this.replacementSummary = const BackupImportSummary(),
    this.mergeError,
    required Map<String, int> localCounts,
  }) : _archiveJson = jsonEncode(archiveJson),
       localCounts = Map.unmodifiable(localCounts),
       snapshotId = archiveJson['snapshot_id'] as String,
       createdAt = DateTime.parse(archiveJson['created_at'] as String).toUtc(),
       schemaVersion = archiveJson['schema_version'] as int,
       appVersion = archiveJson['app_version'] as String,
       archiveCounts = Map.unmodifiable(
         Map<String, int>.from(archiveJson['counts'] as Map),
       );

  /// Content binding includes optional metadata and cannot be changed in place.
  String get archiveBinding => _archiveJson;
  SnapshotArchive get archive => SnapshotArchive.fromJson(
    jsonDecode(_archiveJson) as Map<String, dynamic>,
  );
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
