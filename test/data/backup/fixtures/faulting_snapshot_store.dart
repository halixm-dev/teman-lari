import 'dart:io';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';

class FaultingSnapshotStore extends SnapshotStore {
  final SnapshotStore delegate;
  int failWrites = 0;
  int failFlushes = 0;
  FaultingSnapshotStore(this.delegate);
  @override
  String get name => delegate.name;
  @override
  Future<Map<String, Object?>> read() => delegate.read();
  @override
  void validate(Map<String, Object?> records) => delegate.validate(records);
  @override
  Future<void> replace(Map<String, Object?> records) async {
    await delegate.replace(records);
    if (failWrites > 0) {
      failWrites--;
      throw const FileSystemException('injected store write failure');
    }
  }

  @override
  Future<void> flush() async {
    await delegate.flush();
    if (failFlushes > 0) {
      failFlushes--;
      throw const FileSystemException('injected store flush failure');
    }
  }
}
