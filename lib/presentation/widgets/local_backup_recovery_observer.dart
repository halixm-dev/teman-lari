import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/backup_provider.dart';
import '../providers/local_backup_refresh.dart';

/// Refreshes local providers inside the authentication scope retained by recovery.
class LocalBackupRecoveryObserver extends ConsumerStatefulWidget {
  final Widget child;
  const LocalBackupRecoveryObserver({super.key, required this.child});

  @override
  ConsumerState<LocalBackupRecoveryObserver> createState() =>
      _LocalBackupRecoveryObserverState();
}

class _LocalBackupRecoveryObserverState
    extends ConsumerState<LocalBackupRecoveryObserver> {
  late ValueListenable<bool> _recovery;
  bool _wasRequired = false;

  @override
  void initState() {
    super.initState();
    _recovery = ref
        .read(snapshotBackupServiceProvider)
        .coordinator
        .recoveryState;
    _wasRequired = _recovery.value;
    _recovery.addListener(_changed);
  }

  void _changed() {
    final required = _recovery.value;
    if (_wasRequired && !required) refreshLocalBackupProviders(ref);
    _wasRequired = required;
  }

  @override
  void dispose() {
    _recovery.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
