import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/models/skulmate_intake_models.dart';
import 'package:prepskul/features/skulmate/services/skulmate_lecture_transcription_service.dart';

void main() {
  test('LectureTranscriptionResult holds transcript id and text', () {
    const result = LectureTranscriptionResult(
      transcriptId: 'abc-123',
      text: 'This is a sample lecture transcript with enough characters.',
    );
    expect(result.transcriptId, 'abc-123');
    expect(result.text.length, greaterThan(10));
  });

  test('SkulMateIntakeSource includes lecture', () {
    expect(
      SkulMateIntakeSource.values,
      contains(SkulMateIntakeSource.lecture),
    );
  });
}
