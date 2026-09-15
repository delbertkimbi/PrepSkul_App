import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/models/tutor_session_models.dart';
import 'package:prepskul/features/skulmate/services/skulmate_session_cache.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_in_thread_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('PracticeSurface parses quiz JSON', () {
    final surface = PracticeSurface.fromJson({
      'gameType': 'quiz',
      'title': 'Cells',
      'conceptId': 'cells',
      'items': [
        {
          'question': 'Where is DNA?',
          'options': ['Nucleus', 'Wall'],
          'correctAnswer': 0,
        },
      ],
    });
    expect(surface.gameType, 'quiz');
    expect(surface.items.first['question'], 'Where is DNA?');
  });

  test('session cache round-trips a tutor turn', () async {
    await SkulMateSessionCache.saveTurns(
      sessionId: 's1',
      turns: const [
        TutorTurn(isUser: true, text: 'Help me with osmosis'),
        TutorTurn(isUser: false, text: 'Water moves to the higher solute.'),
      ],
    );
    final loaded = await SkulMateSessionCache.loadTurns('s1');
    expect(loaded, hasLength(2));
    expect(loaded.first.isUser, isTrue);
    expect(loaded.last.text, contains('solute'));
  });

  testWidgets('in-thread quiz reports an outcome', (tester) async {
    bool? got;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SkulMateInThreadSurface(
            surface: PracticeSurface.fromJson({
              'gameType': 'quiz',
              'title': 'Check',
              'items': [
                {
                  'question': '2+2?',
                  'options': ['3', '4'],
                  'correctAnswer': 1,
                },
              ],
            }),
            onOutcome: (correct) async => got = correct,
          ),
        ),
      ),
    );

    await tester.tap(find.text('4'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(got, isTrue);
  });
}
