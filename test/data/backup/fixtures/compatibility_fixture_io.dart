import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> loadCompatibilityFixture() =>
    File('test/fixtures/offline-backup-v1-populated.tlbackup').readAsBytes();
Future<String> createCompatibilityStorage() async =>
    (await Directory.systemTemp.createTemp('backup_platform_roundtrip_')).path;
Future<void> deleteCompatibilityStorage(String path) =>
    Directory(path).delete(recursive: true);
