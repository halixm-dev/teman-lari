import 'dart:convert';
import 'dart:typed_data';

Map<String, dynamic> validateSnapshotArchive(Uint8List bytes) =>
    jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
