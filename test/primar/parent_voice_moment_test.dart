import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/parent_phrases.dart';
import 'package:prepskul/features/primar/domain/tutor_feedback.dart';
import 'package:prepskul/features/primar/domain/figure.dart';

/// Proves appreciation clips cannot unlock on struggle lines, and vice versa.
void main() {
  test('you_can_do_it is patience, not try_again', () {
    // Regression: thinking-time encouragement used to map to "Try again",
    // which tells a child they failed when they have not answered yet.
    expect(parentMomentForLine('you_can_do_it'), ParentMoment.patience);
    expect(parentPhraseFor('you_can_do_it'), 'take_time');
    expect(parentPhraseFor('you_can_do_it'), isNot('try_again'));
  });

  test('success lines only unlock appreciation recordings', () {
    const success = [
      'yes',
      'nice_one',
      'that_is_it',
      'good',
      'i_heard_you',
      'well_matched',
      'well_ordered',
    ];
    for (final id in success) {
      expect(parentMomentForLine(id), ParentMoment.appreciation, reason: id);
      expect(parentPhraseFor(id), 'well_done', reason: id);
    }
  });

  test('struggle lines only unlock encouragement recordings', () {
    const struggle = ['now_you_try', 'look_again', 'good_try', 'it_is_this_one'];
    for (final id in struggle) {
      expect(parentMomentForLine(id), ParentMoment.encouragement, reason: id);
      expect(parentPhraseFor(id), 'try_again', reason: id);
      expect(parentPhraseFor(id), isNot('well_done'), reason: id);
    }
  });

  test('thinking lines only unlock patience recordings', () {
    const thinking = ['take_your_time', 'have_a_look', 'you_can_do_it'];
    for (final id in thinking) {
      expect(parentMomentForLine(id), ParentMoment.patience, reason: id);
      expect(parentPhraseFor(id), 'take_time', reason: id);
      expect(parentPhraseFor(id), isNot('try_again'), reason: id);
      expect(parentPhraseFor(id), isNot('well_done'), reason: id);
    }
  });

  test('instructional lines never unlock a parent clip', () {
    const instructional = [
      'how_many',
      'ask_name',
      'sound:mmm',
      'word:cat',
      'lets_count',
      'build_the_word',
    ];
    for (final id in instructional) {
      expect(parentMomentForLine(id), isNull, reason: id);
      expect(parentPhraseFor(id), isNull, reason: id);
    }
  });

  test('parentPhraseFor matches parentPhraseForMoment for every mapped line', () {
    const ids = [
      'yes',
      'nice_one',
      'look_again',
      'now_you_try',
      'take_your_time',
      'you_can_do_it',
      'all_done',
      'i_heard_you',
    ];
    for (final id in ids) {
      final moment = parentMomentForLine(id)!;
      expect(parentPhraseFor(id), parentPhraseForMoment(moment), reason: id);
    }
  });

  test('tutor feedback bridges agree with their parent moments', () {
    final item = PrimarItem(
      id: 'R6-0-rhyme',
      level: 6,
      topicId: 't',
      prompt: const [PictureFigure('cat')],
      options: const [PictureFigure('hat'), PictureFigure('dog')],
      answerIndex: 0,
    );

    final cases = [
      TutorFeedback.correct(item: item, locale: 'en'),
      TutorFeedback.incorrect(item: item, locale: 'en', chosenIndex: 1),
      TutorFeedback.retryCue(item: item, locale: 'en'),
      TutorFeedback.waiting(item: item, locale: 'en'),
      TutorFeedback.speakMatched(target: 'cat', locale: 'en'),
    ];

    for (final fb in cases) {
      if (fb.parentMoment == ParentMoment.none) {
        expect(fb.parentBridgeId, isNull);
        continue;
      }
      final bridge = fb.parentBridgeId!;
      expect(
        parentMomentForLine(bridge),
        fb.parentMoment,
        reason: '${fb.id} bridge $bridge must match ${fb.parentMoment}',
      );
      // Appreciation bridge must never resolve to try_again / take_time.
      if (fb.parentMoment == ParentMoment.appreciation) {
        expect(parentPhraseFor(bridge), 'well_done');
      }
      if (fb.parentMoment == ParentMoment.encouragement) {
        expect(parentPhraseFor(bridge), 'try_again');
      }
      if (fb.parentMoment == ParentMoment.patience) {
        expect(parentPhraseFor(bridge), 'take_time');
      }
    }
  });

  test('recorded phrase metadata moments match the mapping table', () {
    for (final phrase in parentPhrases) {
      if (phrase.moment == ParentMoment.none) continue;
      expect(parentPhraseForMoment(phrase.moment), phrase.id);
    }
  });
}
