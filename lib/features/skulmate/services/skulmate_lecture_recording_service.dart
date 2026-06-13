import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Handles lecture audio capture and local storage.
class SkulMateLectureRecordingService {
  SkulMateLectureRecordingService._();

  static final AudioRecorder _recorder = AudioRecorder();

  static Future<bool> ensurePermission() async {
    return _recorder.hasPermission();
  }

  static Future<String> start() async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/skulmate_lecture_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    return path;
  }

  static Future<String?> stop() => _recorder.stop();

  static Future<void> dispose() => _recorder.dispose();
}
