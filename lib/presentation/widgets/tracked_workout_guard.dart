import 'package:flutter/material.dart';

import '../../data/backup/local_data_coordinator.dart';

/// Keeps paused and unsaved tracked sessions protected from snapshot operations.
class TrackedWorkoutGuard extends StatefulWidget {
  final Widget child;
  const TrackedWorkoutGuard({super.key, required this.child});

  @override
  State<TrackedWorkoutGuard> createState() => _TrackedWorkoutGuardState();
}

class _TrackedWorkoutGuardState extends State<TrackedWorkoutGuard> {
  bool _acquired = false;

  @override
  void initState() {
    super.initState();
    try {
      LocalDataCoordinator.shared.beginWorkout();
      _acquired = true;
    } on StateError {
      _acquired = false;
    }
  }

  @override
  void dispose() {
    if (_acquired) LocalDataCoordinator.shared.endWorkout();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _acquired
      ? widget.child
      : const Scaffold(
          body: Center(
            child: Text('Wait for the backup to finish, then retry.'),
          ),
        );
}
