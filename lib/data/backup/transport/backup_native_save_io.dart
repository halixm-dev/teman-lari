import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> save(Uint8List bytes, String filename) async {
  if (!Platform.isIOS) {
    return FilePicker.platform.saveFile(
      fileName: filename,
      bytes: bytes,
      type: FileType.any,
    );
  }
  final documents = await getApplicationDocumentsDirectory();
  final taskFilename = _taskFilename(filename);
  final staging = File('${documents.path}/$taskFilename');
  // The picker stages at this exact path. Never remove an existing document.
  if (await staging.exists()) {
    throw const FileSystemException('Backup staging filename is already used.');
  }
  try {
    return await FilePicker.platform.saveFile(
      fileName: taskFilename,
      bytes: bytes,
      type: FileType.any,
    );
  } finally {
    // Remove only this export's staging copy, including after cancellation.
    if (await staging.exists()) await staging.delete();
  }
}

String _taskFilename(String filename) {
  final random = Random.secure();
  final suffix = List.generate(
    4,
    (_) => random.nextInt(1 << 32),
  ).map((part) => part.toRadixString(16).padLeft(8, '0')).join();
  final extension = filename.lastIndexOf('.');
  if (extension <= 0) return '$filename-$suffix';
  return '${filename.substring(0, extension)}-$suffix'
      '${filename.substring(extension)}';
}
