import 'dart:async';
import 'package:flutter/foundation.dart';

/// One queue for all local data access, including provider reads and restores.
class LocalDataCoordinator {
  // Standalone legacy adapters keep their original lifecycle until app startup
  // activates coordination by recovering before it creates normal providers.
  static final shared = LocalDataCoordinator(deferUntilRecovery: true);
  bool _enabled;
  LocalDataCoordinator({bool deferUntilRecovery = false})
    : _enabled = !deferUntilRecovery;

  final Object _zoneKey = Object();
  Future<void>? _tail;
  int revision = 0;
  bool snapshotBusy = false;
  bool workoutActive = false;
  final _recoveryState = ValueNotifier<bool>(false);
  ValueListenable<bool> get recoveryState => _recoveryState;
  bool get recoveryRequired => _recoveryState.value;
  set recoveryRequired(bool value) => _recoveryState.value = value;

  bool get _ownsLease {
    final lease = Zone.current[_zoneKey];
    return lease is _OperationLease && lease.active;
  }

  bool get initialized => _enabled;

  Future<T> read<T>(Future<T> Function() operation) =>
      _enabled ? _enqueue(operation) : operation();

  Future<T> write<T>(Future<T> Function() operation) {
    if (!_enabled || _ownsLease) return operation();
    return _enqueue(() async {
      try {
        return await operation();
      } finally {
        revision++;
      }
    });
  }

  Future<T> snapshot<T>(Future<T> Function() operation) async {
    if (!_enabled) throw StateError('Initialize local recovery before backup.');
    if (snapshotBusy) {
      throw StateError('A backup operation is already running.');
    }
    if (workoutActive) throw StateError('Finish the tracked workout first.');
    snapshotBusy = true;
    try {
      return await _enqueue(() async {
        if (workoutActive) {
          throw StateError('Finish the tracked workout first.');
        }
        return operation();
      });
    } finally {
      snapshotBusy = false;
    }
  }

  Future<T> recover<T>(Future<T> Function() operation) async {
    _enabled = true;
    if (snapshotBusy) {
      throw StateError('A backup operation is already running.');
    }
    snapshotBusy = true;
    recoveryRequired = true;
    try {
      return await _enqueue(() async {
        final result = await operation();
        recoveryRequired = false;
        return result;
      }, allowRecovery: true);
    } finally {
      snapshotBusy = false;
    }
  }

  void beginWorkout() {
    if (snapshotBusy || recoveryRequired) {
      throw StateError('Wait for the backup operation to finish.');
    }
    workoutActive = true;
  }

  void endWorkout() => workoutActive = false;

  Future<T> _enqueue<T>(
    Future<T> Function() operation, {
    bool allowRecovery = false,
  }) async {
    if (_ownsLease) return operation();
    final previous = _tail;
    final finished = Completer<void>();
    _tail = finished.future;
    if (previous != null) await previous;
    final lease = _OperationLease();
    try {
      if (recoveryRequired && !allowRecovery) {
        throw StateError('Local data recovery needs retry.');
      }
      return await runZoned(operation, zoneValues: {_zoneKey: lease});
    } finally {
      lease.active = false;
      if (identical(_tail, finished.future)) _tail = null;
      finished.complete();
    }
  }
}

class _OperationLease {
  bool active = true;
}
