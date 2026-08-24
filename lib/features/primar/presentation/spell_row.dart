import 'package:flutter/material.dart';

import '../domain/figure.dart';
import '../services/primar_voice.dart';
import 'figure_view.dart';
import 'primar_theme.dart';

/// Build the word out of its sounds, one letter at a time.
///
/// ## What was missing
///
/// `decode.build` is the skill the whole decoding strand rests on —
/// `decode.read` names it as a prerequisite, so a child who cannot clear it
/// cannot go anywhere else in reading. Its generator is the only one in the
/// product that returns [Interaction.spell], and the session had no branch for
/// that interaction at all: the item arrived with an empty `options` list and
/// fell through to the grid, which rendered nothing.
///
/// So a child who got good at letters was shown a picture, a listen button, and
/// no way to answer, until the fourteen-second ring emptied and the app decided
/// they needed help. Every time. On the one rung everything above it is built
/// on.
///
/// The parts were all there — `spellTarget` and `spellPool` have been on the
/// item since the generator was written. Nothing ever drew them.
///
/// ## Why tapping and not dragging
///
/// Dragging is the obvious gesture for arranging letters and the wrong one on
/// a cheap phone in a child's hand: it needs a sustained, accurate touch, and
/// on the low-end Androids this is built for the first thing that goes is
/// touch tracking. Tapping a letter into the next slot works with one finger,
/// survives a bad digitiser, and — unlike a drag — is undoable by tapping the
/// slot again.
///
/// ## Why it grades itself only when full
///
/// A word half-built is not a wrong answer, it is an answer in progress.
/// Checking early would mark a child wrong for thinking, and marking on every
/// tap would teach them to guess letter by letter rather than hear the word.
class SpellRow extends StatefulWidget {
  const SpellRow({
    super.key,
    required this.item,
    required this.onSolved,
    required this.onMiss,
  });

  final PrimarItem item;

  /// Built. True when the word is right.
  ///
  /// Unlike the order row there is no partial credit to report: a word is the
  /// word or it is not, and "close" is not a thing a reader can act on.
  final void Function(bool correct) onSolved;

  /// A letter placed that the word does not have in that position. Reported so
  /// the tracker sees the pattern; the row itself does nothing about it, so a
  /// child can put it back without being punished for trying.
  final VoidCallback onMiss;

  @override
  State<SpellRow> createState() => _SpellRowState();
}

class _SpellRowState extends State<SpellRow> {
  /// Indices into `item.spellPool`, one per filled slot, in build order.
  final List<int> _placed = [];

  /// Locked once the word is complete, so the last tap cannot be undone while
  /// the answer is being read out.
  bool _done = false;

  List<String> get _target => widget.item.spellTarget;
  List<String> get _pool => widget.item.spellPool;

  void _place(int poolIndex) {
    if (_done || _placed.length >= _target.length) return;
    if (_placed.contains(poolIndex)) return;

    final slot = _placed.length;
    final correctHere = _pool[poolIndex] == _target[slot];

    setState(() => _placed.add(poolIndex));
    // The same sound either way. A chime that changed with correctness would
    // let a child spell the word by listening to the feedback instead of to
    // the word, which is the one thing this rung is measuring.
    PrimarVoice.instance.chime(Sfx.tap);
    // Named as it lands, because hearing the sound you just chose is the whole
    // point of building a word out of sounds rather than picking one whole.
    PrimarVoice.instance.say(VoiceLines.byId('letter:${_pool[poolIndex]}'));
    if (!correctHere) widget.onMiss();

    if (_placed.length == _target.length) _finish();
  }

  /// Take the last letter back.
  ///
  /// Only the last, deliberately: pulling a letter out of the middle would
  /// leave a gap that has no meaning in a word, and explaining that gap to a
  /// non-reader is harder than just letting them undo.
  void _takeBack() {
    if (_done || _placed.isEmpty) return;
    setState(_placed.removeLast);
  }

  void _finish() {
    final built = [for (final i in _placed) _pool[i]];
    var correct = true;
    for (var i = 0; i < _target.length; i++) {
      if (built[i] != _target[i]) correct = false;
    }

    setState(() => _done = true);
    if (correct) {
      PrimarVoice.instance.chime(Sfx.levelUp);
      PrimarVoice.instance.say(VoiceLines.byId('word:${_target.join()}'));
    }
    // A short hold so the finished word is actually seen before the session
    // moves on and replaces it.
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) widget.onSolved(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ---- The word being built. ----
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var slot = 0; slot < _target.length; slot++)
              GestureDetector(
                // Only the last filled slot takes a tap, matching what undo
                // actually does.
                onTap: slot == _placed.length - 1 ? _takeBack : null,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: 54,
                  height: 64,
                  decoration: PrimarTheme.tile(
                    border: slot < _placed.length ? PrimarTheme.blue : null,
                    fill: slot < _placed.length ? null : const Color(0xFFF1EFE8),
                    lift: slot < _placed.length ? 5 : 2,
                  ),
                  child: Center(
                    child: slot < _placed.length
                        ? FigureView(
                            figure: LetterFigure(_pool[_placed[slot]]),
                            color: PrimarTheme.answerInk,
                            size: 40,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),

        // ---- The letters to build it from. ----
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < _pool.length; i++)
              Opacity(
                // A used letter stays in place rather than vanishing: a pool
                // that reflows under a child's finger loses them the letter
                // they were about to reach for.
                opacity: _placed.contains(i) ? 0.28 : 1,
                child: GestureDetector(
                  onTap: () => _place(i),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: PrimarTheme.tile(lift: _placed.contains(i) ? 1 : 5),
                    child: Center(
                      child: FigureView(
                        figure: LetterFigure(_pool[i]),
                        color: _placed.contains(i)
                            ? PrimarTheme.ghostInk
                            : PrimarTheme.answerInk,
                        size: 34,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
