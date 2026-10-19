import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../archive/snapshot_archive_codec.dart';

import 'backup_native_save_stub.dart'
    if (dart.library.io) 'backup_native_save_io.dart'
    as native;

/// Maximum input retained by the platform picker, before archive validation.
const backupFileMaxBytes = SnapshotArchiveLimits.maxBytes;

enum BackupDelivery { saved, cancelled, downloadStarted, shared }

abstract interface class BackupFileTransport {
  Future<BackupDelivery> save({
    required Uint8List bytes,
    required String filename,
  });

  Future<Uint8List?> pick();
}

class BackupFileException implements Exception {
  const BackupFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Owns document selection/delivery only; the backup service owns its contents.
class PlatformBackupFileTransport implements BackupFileTransport {
  PlatformBackupFileTransport();

  static const _channel = MethodChannel('dev.halixm.temanlari/backup');

  @override
  Future<BackupDelivery> save({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (bytes.length > backupFileMaxBytes) throw _tooLarge();
    _validateFilename(filename);
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        return await _saveAndroid(bytes, filename);
      }
      final location = kIsWeb
          ? await FilePicker.platform.saveFile(
              fileName: filename,
              bytes: bytes,
              type: FileType.any,
            )
          : await native.save(bytes, filename);
      if (kIsWeb) return BackupDelivery.downloadStarted;
      return location == null ? BackupDelivery.cancelled : BackupDelivery.saved;
    } on BackupFileException {
      rethrow;
    } on PlatformException catch (error) {
      throw BackupFileException(
        error.code.startsWith('backup_')
            ? error.message ?? 'Could not save backup. Try another folder.'
            : 'Could not save backup. Try another folder.',
      );
    } catch (_) {
      throw const BackupFileException(
        'Could not save backup. Check available space and try another folder.',
      );
    }
  }

  Future<BackupDelivery> _saveAndroid(Uint8List bytes, String filename) async {
    final result = await _channel.invokeMethod<String>('saveBackup', {
      'filename': filename,
      'bytes': bytes,
    });
    return switch (result) {
      'saved' => BackupDelivery.saved,
      'cancelled' => BackupDelivery.cancelled,
      _ => throw const BackupFileException(
        'Backup was not saved. Please try again.',
      ),
    };
  }

  @override
  Future<Uint8List?> pick() async {
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
        withReadStream: true,
      );
      if (selection == null) return null;
      if (selection.files.length != 1) {
        throw const BackupFileException(
          'Choose one backup file and try again.',
        );
      }
      return await _read(selection.files.single);
    } on BackupFileException {
      rethrow;
    } catch (_) {
      throw const BackupFileException(
        'Could not read the backup. Choose a local file and try again.',
      );
    }
  }

  Future<Uint8List> _read(PlatformFile file) async {
    if (file.size > backupFileMaxBytes) throw _tooLarge();
    final stream = file.readStream;
    if (stream == null) {
      throw const BackupFileException(
        'Could not open the backup. Choose a local file and try again.',
      );
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (chunk.length > backupFileMaxBytes - bytes.length) throw _tooLarge();
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  void _validateFilename(String filename) {
    if (filename.isEmpty ||
        filename.contains('/') ||
        filename.contains(r'\') ||
        filename == '.' ||
        filename == '..') {
      throw const BackupFileException('Choose a valid backup filename.');
    }
  }

  BackupFileException _tooLarge() => const BackupFileException(
    'This backup exceeds the 50 MiB limit. Choose a smaller backup.',
  );
}
