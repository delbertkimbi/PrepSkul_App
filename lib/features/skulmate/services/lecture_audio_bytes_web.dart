import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List> readRecordingBytes(String localPath) async {
  if (localPath.startsWith('blob:') || localPath.startsWith('http')) {
    final request = await html.HttpRequest.request(
      localPath,
      responseType: 'arraybuffer',
    );
    final buffer = request.response;
    if (buffer is ByteBuffer) {
      return Uint8List.view(buffer);
    }
    throw Exception('Could not read recording from browser');
  }
  throw Exception('Recording file not found');
}
