import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readRecordingBytes(String localPath) async {
  final file = File(localPath);
  if (!await file.exists()) {
    throw Exception('Recording file not found');
  }
  return file.readAsBytes();
}
