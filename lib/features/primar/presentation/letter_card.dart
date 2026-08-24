import 'package:flutter/material.dart';

import '../domain/word_bank.dart';
import '../services/primar_voice.dart';
import 'primar_theme.dart';
import 'word_picture.dart';

/// One letter, and two things that start with it.
///
/// ## Where this comes from
///
/// Every printed phonics worksheet in the world is some version of this card:
/// the letter big at the top in both cases, and beneath it two pictures whose
/// names begin with its sound. **Z z — zebra, zip.** It has survived decades of
/// classroom use because it does one job with nothing else on the page.
///
/// The app had no equivalent. Its letter teaching was a spoken line — "this
/// letter says /b/" — with nothing to look at, which for a child who cannot
/// read is a sound arriving out of nowhere and leaving no trace.
///
/// ## Why two pictures and not one
///
/// One picture teaches a pair: this letter goes with that thing. Two pictures
/// that share nothing except their first sound teach the *sound*, because the
/// only thing a ball and a bed have in common is the noise at the front. That
/// is the whole difference between memorising an association and hearing a
/// phoneme.
///
/// ## Why it is not a worksheet
///
/// The paper version asks a child to trace the letter, which is genuinely
/// valuable and needs a finger on glass to do properly. That is worth building
/// and is not built. This card is the half that works today: see it, hear it,
/// hear the words.
class LetterCard extends StatefulWidget {
  const LetterCard({
    super.key,
    required this.letter,
    required this.sound,
    this.locale = 'en',
  });

  /// Lower case. Both cases are shown.
  final String letter;

  /// Voice-catalogue id for the sound this letter makes, e.g. `buh`.
  final String sound;

  final String locale;

  /// Whether a card can be built — it needs at least two drawable words that
  /// begin with the letter.
  static bool canShow(String letter, {String locale = 'en'}) =>
      wordsStartingWith(letter, locale: locale).length >= 2;

  /// Drawable words beginning with [letter], local ones first.
  static List<String> wordsStartingWith(String letter, {String locale = 'en'}) =>
      picturableWords(locale)
          .where((w) => w.startsWith(letter.toLowerCase()) && WordPicture.canDraw(w))
          .toList();

  @override
  State<LetterCard> createState() => _LetterCardState();
}

class _LetterCardState extends State<LetterCard> {
  late final List<String> _words =
      LetterCard.wordsStartingWith(widget.letter, locale: widget.locale).take(2).toList();

  @override
  void initState() {
    super.initState();
    _say();
  }

  /// The sound, then each word. In that order, because the sound is the thing
  /// being taught and the words are the evidence for it.
  void _say() {
    PrimarVoice.instance.sayAll([
      VoiceLines.thisLetterSays,
      VoiceLine.sound(widget.sound),
      for (final w in _words) VoiceLine.word(w),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tap anywhere to hear it again. A child who missed it should not have to
      // find a small speaker.
      onTap: _say,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        decoration: PrimarTheme.paperSheet(),
        child: Column(
          children: [
            // Both cases, together. A child meets capitals on signs and lower
            // case in books, and being taught only one leaves half the world
            // unreadable.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(widget.letter.toUpperCase(),
                    style: PrimarTheme.display(88, weight: FontWeight.w700)),
                const SizedBox(width: 14),
                Text(widget.letter.toLowerCase(),
                    style: PrimarTheme.display(88,
                        color: PrimarTheme.blue, weight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final w in _words)
                  Column(
                    children: [
                      WordPicture(word: w, size: 92),
                      const SizedBox(height: 6),
                      // The word written under its picture. A child who cannot
                      // read it yet still sees that the mark and the thing go
                      // together, which is where reading starts.
                      Text(w, style: PrimarTheme.display(19)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
