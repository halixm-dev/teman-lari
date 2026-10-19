import 'dart:convert';
import 'dart:typed_data';
import 'snapshot_archive_codec.dart';
import 'snapshot_archive.dart';
import 'snapshot_validation_sections.dart';
import 'snapshot_validation_references.dart';
import 'snapshot_validation_values.dart';

const archiveSections = {
  'profile',
  'activities',
  'heart_rate_streams',
  'training_plan_state',
  'equipment',
  'rehab_feedback',
};

Map<String, dynamic> validateSnapshotArchive(Uint8List bytes) {
  if (bytes.length > SnapshotArchiveLimits.maxBytes) {
    throw FormatException('Backup exceeds 50 MiB.');
  }
  final text = utf8.decode(bytes);
  _boundedNesting(text);
  final archive = archiveShape(jsonDecode(text), {
    'product': archiveString,
    'schema_version': archiveInteger,
    'snapshot_id': archiveNonempty,
    'created_at': archiveInstant,
    'app_version': archiveNonempty,
    'counts': archiveObject,
    'data': archiveObject,
  });
  final version = archive['schema_version'];
  if (archive['product'] != 'teman_lari' ||
      (version != SnapshotArchive.originalSchema &&
          version != SnapshotArchive.nullableElevationSchema)) {
    throw FormatException('Unsupported backup product or schema.');
  }
  final data = archiveObject(archive['data']);
  if (data.keys.toSet().difference(archiveSections).isNotEmpty ||
      archiveSections.difference(data.keys.toSet()).isNotEmpty) {
    throw FormatException('Missing or unsupported backup section.');
  }
  validateArchiveSections(
    data,
    nullableElevation: version == SnapshotArchive.nullableElevationSchema,
  );
  validateArchiveReferences(data);
  _counts(archiveObject(archive['counts']), data);
  SnapshotArchive.fromJson(archive);
  return archive;
}

void _counts(Map<String, dynamic> counts, Map<String, dynamic> data) {
  final expected = {
    'profile': 5,
    'activities': (data['activities'] as List).length,
    'heart_rate_streams': (data['heart_rate_streams'] as List).length,
    'training_plan_state':
        (archiveObject(data['training_plan_state'])['plans'] as List).length,
    'equipment':
        (archiveObject(data['equipment'])['shoes'] as List).length +
        (archiveObject(data['equipment'])['activity_assignments'] as List)
            .length,
    'rehab_feedback':
        (archiveObject(data['rehab_feedback'])['records'] as List).length,
  };
  for (final entry in expected.entries) {
    archiveNonnegativeInteger(counts[entry.key]);
    if (counts[entry.key] != entry.value) {
      throw FormatException('Section count mismatch: ${entry.key}.');
    }
  }
}

void _boundedNesting(String text) {
  var depth = 0;
  var quoted = false;
  var escaped = false;
  for (final unit in text.codeUnits) {
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (unit == 92) {
        escaped = true;
      } else if (unit == 34) {
        quoted = false;
      }
    } else if (unit == 34) {
      quoted = true;
    } else if (unit == 123 || unit == 91) {
      depth++;
      if (depth > SnapshotArchiveLimits.maxNesting) {
        throw FormatException('Backup exceeds 64 nesting levels.');
      }
    } else if (unit == 125 || unit == 93) {
      depth--;
    }
  }
}
