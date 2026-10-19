import 'dart:convert';
import 'dart:typed_data';
import '../snapshot_store.dart';
import 'archive_profile.dart';
import 'activity_section.dart';
import 'equipment_section.dart';
import 'rehab_feedback_section.dart';
import 'snapshot_archive.dart';
import 'training_plan_section.dart';

abstract final class SnapshotArchiveLimits {
  static const maxBytes = 50 * 1024 * 1024;
  static const maxNesting = 64;
}

class PreparedBackup {
  final Uint8List bytes;
  final String filename;
  const PreparedBackup({required this.bytes, required this.filename});
}

class SnapshotArchiveCodec {
  const SnapshotArchiveCodec();
  PreparedBackup encode(
    LocalSnapshot snapshot,
    DateTime now,
    String id,
    String appVersion,
  ) {
    final data = _data(snapshot);
    final archive = SnapshotArchive(
      schemaVersion: data.activities.any((a) => a.totalElevationGain == null)
          ? SnapshotArchive.nullableElevationSchema
          : SnapshotArchive.originalSchema,
      snapshotId: id,
      createdAt: now.toUtc(),
      appVersion: appVersion,
      data: data,
      counts: {
        'profile': 5,
        'activities': data.activities.length,
        'heart_rate_streams': data.heartRateStreams.length,
        'training_plan_state': data.trainingPlanState.recordCount,
        'equipment': data.equipment.recordCount,
        'rehab_feedback': data.rehabFeedback.recordCount,
      },
    );
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(archive.toJson())));
    if (bytes.length > SnapshotArchiveLimits.maxBytes) {
      throw StateError('Backup exceeds 50 MiB. No history was omitted.');
    }
    final date = now.toUtc().toIso8601String().substring(0, 10);
    return PreparedBackup(
      bytes: bytes,
      filename: 'teman-lari-$date-$id.tlbackup',
    );
  }

  Map<String, int> counts(LocalSnapshot snapshot) {
    final data = _data(snapshot);
    return {
      'profile': 5,
      'activities': data.activities.length,
      'heart_rate_streams': data.heartRateStreams.length,
      'training_plan_state': data.trainingPlanState.recordCount,
      'equipment': data.equipment.recordCount,
      'rehab_feedback': data.rehabFeedback.recordCount,
    };
  }

  SnapshotArchiveData _data(LocalSnapshot snapshot) {
    final prefs = snapshot.stores['preferences'] ?? {};
    final activities = const ActivitySectionCodec().encode(snapshot);
    final streams = const HeartRateSectionCodec().encode(
      snapshot,
      activities.map((activity) => activity.id).toSet(),
    );
    return SnapshotArchiveData(
      profile: ArchiveProfile(
        athleteName: archivePreference(prefs, 'athlete_name'),
        dateOfBirth: archivePreference(prefs, 'date_of_birth'),
        restingHr: archivePreference(prefs, 'resting_hr'),
        maxHr: archivePreference(prefs, 'max_hr'),
        thresholdPaceSec: archivePreference(prefs, 'threshold_pace_sec'),
      ),
      activities: activities,
      heartRateStreams: streams,
      trainingPlanState: const TrainingPlanSectionCodec().encode(snapshot),
      equipment: const EquipmentSectionCodec().encode(snapshot),
      rehabFeedback: const RehabFeedbackSectionCodec().encode(snapshot),
    );
  }
}
