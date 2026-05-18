import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat screen wires vocabulary candidate metadata actions', () async {
    final file = File('lib/features/messaging/screens/chat_screen.dart');
    final content = await file.readAsString();

    expect(content.contains('_extractVocabularyCandidate'), isTrue);
    expect(content.contains('_addWordFromMessage'), isTrue);
    expect(content.contains('_showMessageActions'), isTrue);
    expect(content.contains('Vocabulary candidate'), isTrue);
    expect(content.contains('addWordToVocabularyDeck'), isTrue);
  });
}
