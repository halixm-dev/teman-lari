import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup/snapshot_backup_service.dart';
import '../../data/backup/transport/backup_file_transport.dart';

final snapshotBackupServiceProvider = Provider<SnapshotBackupService>(
  (ref) => SnapshotBackupService.shared,
);

final backupFileTransportProvider = Provider<BackupFileTransport>(
  (ref) => PlatformBackupFileTransport(),
);

final backupCountsProvider = FutureProvider.autoDispose<Map<String, int>>(
  (ref) => ref.watch(snapshotBackupServiceProvider).readBackupCounts(),
);
