import 'dart:convert';
import '../activity_identity_aliases.dart';
import 'package:flutter/foundation.dart';
import '../../models/activity_model.dart';
import '../snapshot_store.dart';
import 'snapshot_archive.dart';
import 'snapshot_validation_values.dart';

class ActivitySectionCodec {
  const ActivitySectionCodec();
  List<ArchiveActivity> encode(LocalSnapshot snapshot) {
    final records = snapshot.stores['activities'];
    if (records == null) throw StateError('Missing Activity store.');
    return records.entries.map(_activity).toList();
  }

  ArchiveActivity _activity(MapEntry<String, Object?> entry) {
    final row = entry.value as Map;
    final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
    final id = data['id'];
    if (id is! int || '$id' != entry.key || row['id'] != id) {
      throw StateError('Stored Activity identity is inconsistent.');
    }
    ensureExactIdentity(id);
    archiveInstant(data['start_date']);
    final model = ActivityModel.fromJson(data);
    _validateMeasurements(model);
    return ArchiveActivity(
      id: '$id',
      name: model.name,
      type: model.type,
      distance: model.distance,
      movingTime: model.movingTime,
      elapsedTime: model.elapsedTime,
      totalElevationGain: model.totalElevationGain,
      startDate: DateTime.parse(model.startDate).toUtc().toIso8601String(),
      averageSpeed: model.averageSpeed,
      maxSpeed: model.maxSpeed,
      averageHeartrate: model.averageHeartrate,
      maxHeartrate: model.maxHeartrate,
      averageCadence: model.averageCadence,
      sufferScore: model.sufferScore,
      hasHeartrate: model.hasHeartrate,
      workoutType: model.workoutType,
      perceivedExertion: model.perceivedExertion,
      isLocal: id < 0,
      identityAliases: validatedActivityAliases(
        row['identity_aliases'],
        owner: data,
      ),
    );
  }

  void _validateMeasurements(ActivityModel model) {
    final values = [
      model.distance,
      model.totalElevationGain,
      model.averageSpeed,
      model.maxSpeed,
      model.averageHeartrate,
      model.maxHeartrate,
      model.averageCadence,
      model.perceivedExertion,
    ];
    if (values.any((value) => value != null && !value.isFinite) ||
        model.distance < 0 ||
        model.movingTime < 0 ||
        model.elapsedTime < 0) {
      throw StateError('Stored Activity has invalid measurements.');
    }
  }
}

void ensureExactIdentity(int id) {
  if (kIsWeb && (id > 9007199254740991 || id < -9007199254740991)) {
    throw StateError(
      'An Activity ID cannot be represented exactly on the web.',
    );
  }
}

class HeartRateSectionCodec {
  const HeartRateSectionCodec();
  List<ArchiveHeartRateStream> encode(
    LocalSnapshot snapshot,
    Set<String> owners,
  ) {
    final records = snapshot.stores['hr_streams'];
    if (records == null) throw StateError('Missing heart rate stream store.');
    return records.entries.map((entry) => _stream(entry, owners)).toList();
  }

  ArchiveHeartRateStream _stream(
    MapEntry<String, Object?> entry,
    Set<String> owners,
  ) {
    final row = entry.value as Map;
    final id = row['activity_id'];
    if (id is! int || '$id' != entry.key || !owners.contains('$id')) {
      throw StateError(
        'Stored heart rate stream has an invalid Activity reference.',
      );
    }
    ensureExactIdentity(id);
    final samples = (jsonDecode(row['data'] as String) as List)
        .map((value) => (value as num).toDouble())
        .toList();
    if (samples.any((value) => !value.isFinite)) {
      throw StateError('Stored heart rate stream has invalid samples.');
    }
    return ArchiveHeartRateStream(activityId: '$id', samples: samples);
  }
}
