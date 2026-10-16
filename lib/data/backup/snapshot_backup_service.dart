import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'archive/snapshot_archive_codec.dart';
import 'archive/equipment_section.dart';

import 'archive/rehab_feedback_section.dart';
import 'transport/backup_file_transport.dart';
import 'package:flutter/foundation.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'local_data_coordinator.dart';
import 'snapshot_store.dart';
import 'snapshot_store_adapters.dart';

export 'snapshot_store.dart';

enum BackupExportPhase { idle, preparing, saving }

enum SnapshotPhase { staged, storeWritten, committed, rolledBack }

typedef SnapshotPhaseObserver =
    Future<void> Function(SnapshotPhase phase, String? store);

class SnapshotRecoveryException implements Exception {
  final Object cause;
  SnapshotRecoveryException(this.cause);
  @override
  String toString() => 'Local data recovery needs retry: $cause';
}

/// Strict, local-only boundary used by portable and future cloud snapshots.
/// Initialize recovery before creating providers. The shared coordinator refuses
/// snapshots until initialized; initialize also retries any failed recovery.
class SnapshotBackupService {
  static const profileKeys = {
    'resting_hr',
    'max_hr',
    'threshold_pace_sec',
    'date_of_birth',
    'athlete_name',
    'week_in_cycle',
    'cycle_start_date',
  };
  static final shared = SnapshotBackupService(versionReader: _packagedVersion);
  final LocalDataCoordinator coordinator;
  final DateTime Function() clock;
  final String Function() snapshotId;
  final String appVersion;
  final Future<String> Function()? versionReader;
  final exportPhase = ValueNotifier<BackupExportPhase>(BackupExportPhase.idle);
  final SnapshotPhaseObserver? onPhase;
  final Future<bool> Function(int bytes)? checkAvailableSpace;
  final Map<String, SnapshotStore> _stores = {};

  SnapshotBackupService({
    LocalDataCoordinator? coordinator,
    Iterable<SnapshotStore>? stores,
    this.onPhase,
    this.checkAvailableSpace,
    DateTime Function()? clock,
    String Function()? snapshotId,
    this.appVersion = '1.0.0+1',
    this.versionReader,
  }) : coordinator = coordinator ?? LocalDataCoordinator.shared,
       clock = clock ?? DateTime.now,
       snapshotId = snapshotId ?? _newSnapshotId {
    for (final store in stores ?? defaultStores()) {
      registerStore(store);
    }
  }

  static List<SnapshotStore> defaultStores() => [
    HiveSnapshotStore('activities'),
    HiveSnapshotStore('hr_streams'),
    HiveSnapshotStore('training_plans'),
    HiveSnapshotStore('equipment'),
    HiveSnapshotStore('rehab_feedback'),
    PreferenceSnapshotStore({
      ...profileKeys,
      for (final key in profileKeys) '${key}_modified_at',
    }),
  ];

  void registerStore(SnapshotStore store) {
    if (coordinator.snapshotBusy) throw StateError('Backup is running.');
    if (_stores.containsKey(store.name)) {
      throw ArgumentError('Duplicate store.');
    }
    _stores[store.name] = store;
  }

  Future<Box> get _journal async => Hive.isBoxOpen('snapshot_recovery')
      ? Hive.box('snapshot_recovery')
      : await Hive.openBox('snapshot_recovery');

  Future<void> initialize() => coordinator.recover(() async {
    try {
      final journal = await _journal;
      if (journal.isNotEmpty) await _recoverJournal(journal);
      for (final store in _stores.values.whereType<PreferenceSnapshotStore>()) {
        await store.restoreMirror();
      }
    } catch (error) {
      throw SnapshotRecoveryException(error);
    }
  });

  Future<void> _recoverJournal(Box journal) async {
    if (journal.get('committed') == true || journal.get('settled') == true) {
      await _cleanup();
    } else {
      final before = journal.get('before');
      if (before is! String) throw StateError('Incomplete recovery journal.');
      final state = LocalSnapshot.decode(before);
      _validateStores(state);
      await _rollback(state);
    }
  }

  Future<PreparedBackup> prepareExport() =>
      coordinator.snapshot(_prepareExport);

  Future<PreparedBackup> _prepareExport() async => compute(_encodeExport, (
    await _read(),
    clock().toUtc(),
    snapshotId(),
    await _version(),
  ));

  Future<String> _version() async {
    final reader = versionReader;
    return reader == null ? appVersion : await reader();
  }

  /// Busy coordination covers both capture and the user's save destination.
  Future<BackupDelivery> exportBackup(BackupFileTransport transport) =>
      coordinator.snapshot(() async {
        exportPhase.value = BackupExportPhase.preparing;
        try {
          final file = await _prepareExport();
          exportPhase.value = BackupExportPhase.saving;
          return await transport.save(
            bytes: file.bytes,
            filename: file.filename,
          );
        } finally {
          exportPhase.value = BackupExportPhase.idle;
        }
      });

  static String _newSnapshotId() {
    final random = Random.secure();
    return base64Url
        .encode(List.generate(12, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  Future<LocalSnapshot> readLocalState() => coordinator.snapshot(_read);

  Future<LocalSnapshot> _read() async {
    final stores = <String, Map<String, Object?>>{};
    for (final store in _stores.values) {
      stores[store.name] = await store.read();
    }
    return LocalSnapshot(revision: coordinator.revision, stores: stores);
  }

  Future<void> applyLocalState(
    LocalSnapshot next, {
    required int expectedRevision,
  }) => coordinator.snapshot(() => _applyState(next, expectedRevision));

  /// Recoverable normal edit; tracked workouts may continue recording.
  Future<void> transformLocalState(
    FutureOr<LocalSnapshot> Function(LocalSnapshot) transform, {
    int? expectedRevision,
  }) => coordinator.write(() async {
    final current = await _read();
    if (expectedRevision != null && expectedRevision != current.revision) {
      throw StateError('Local data changed before the edit.');
    }
    await _applyState(
      await transform(current),
      current.revision,
      advanceRevision: false,
    );
  });

  Future<void> _applyState(
    LocalSnapshot next,
    int expectedRevision, {
    bool advanceRevision = true,
  }) async {
    if (expectedRevision != coordinator.revision) {
      throw StateError('Local data changed. Refresh the import preview.');
    }
    final stagedNext = LocalSnapshot.decode(
      next.encode(),
      revision: next.revision,
    );
    _validateStores(stagedNext);
    final before = await _read();
    await _stage(before, stagedNext);
    try {
      await _replace(stagedNext);
      final journal = await _journal;
      await journal.put('committed', true);
      await journal.flush();
    } catch (error) {
      await _rollback(before);
      rethrow;
    }
    if (advanceRevision) coordinator.revision++;
    await onPhase?.call(SnapshotPhase.committed, null);
    await _cleanup();
  }

  void _validateStores(LocalSnapshot state) {
    if (state.stores.length != _stores.length ||
        _stores.keys.any((key) => !state.stores.containsKey(key))) {
      throw ArgumentError('Snapshot must contain every registered store.');
    }
    for (final store in _stores.values) {
      store.validate(state.stores[store.name] ?? {});
    }
    if (state.stores.containsKey('equipment')) {
      const EquipmentSectionCodec().encode(state);
    }
    if (state.stores.containsKey('rehab_feedback')) {
      const RehabFeedbackSectionCodec().encode(state);
    }
    state.encode();
  }

  Future<void> _stage(LocalSnapshot before, LocalSnapshot next) async {
    final previous = before.encode();
    final staged = next.encode();
    final reserveBytes =
        utf8.encode(previous).length + utf8.encode(staged).length;
    final checkSpace = checkAvailableSpace;
    if (checkSpace != null && !await checkSpace(reserveBytes * 3)) {
      throw StateError('Not enough storage space to restore safely.');
    }
    final journal = await _journal;
    if (journal.isNotEmpty) throw StateError('Recovery must finish first.');
    try {
      await journal.putAll({
        'before': previous,
        'next': staged,
        'committed': false,
        'reservation': Uint8List(reserveBytes * 2),
      });
      await journal.flush();
      await journal.delete('reservation');
      await journal.compact();
      await journal.flush();
      await onPhase?.call(SnapshotPhase.staged, null);
    } catch (_) {
      await _cleanup();
      rethrow;
    }
  }

  Future<void> _replace(LocalSnapshot state) async {
    for (final store in _stores.values) {
      final records = state.stores[store.name];
      if (records == null) throw StateError('Missing recovery store.');
      await store.replace(records);
      await store.flush();
      await onPhase?.call(SnapshotPhase.storeWritten, store.name);
    }
  }

  Future<void> _rollback(LocalSnapshot before) async {
    try {
      final journal = await _journal;
      await journal.put('committed', false);
      await journal.flush();
      await _replace(before);
      // A durable rollback marker prevents stale journal bytes from undoing
      // later edits if cleanup fails after the restored stores are flushed.
      await journal.put('settled', true);
      await journal.flush();
      await onPhase?.call(SnapshotPhase.rolledBack, null);
      await _cleanup();
    } catch (error) {
      coordinator.recoveryRequired = true;
      throw SnapshotRecoveryException(error);
    }
  }

  Future<void> _cleanup() async {
    final journal = await _journal;
    await journal.clear();
    await journal.flush();
  }
}

PreparedBackup _encodeExport(
  (LocalSnapshot, DateTime, String, String) values,
) => const SnapshotArchiveCodec().encode(
  values.$1,
  values.$2,
  values.$3,
  values.$4,
);

Future<String> _packagedVersion() async {
  if (kIsWeb) {
    // build.sh injects pubspec's version; never fetch web version.json offline.
    return const String.fromEnvironment(
      'APP_VERSION',
      defaultValue: 'development',
    );
  }
  final package = await PackageInfo.fromPlatform();
  return '${package.version}+${package.buildNumber}';
}
