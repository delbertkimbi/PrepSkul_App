import 'package:flutter/material.dart';

import '../domain/figure.dart';
import '../services/primar_voice.dart';
import 'figure_view.dart';
import 'primar_theme.dart';

/// Join each thing on the left to its partner on the right.
///
/// Choosing one of four tests recognition and can be guessed a quarter of the
/// time. Matching a whole set tests the relationship itself — this many *is*
/// that number — and a child cannot bluff their way through three pairs.
///
/// It is also the first screen where a child does something other than pick:
/// they select, then connect, and a wrong join comes apart again rather than
/// being marked.
class MatchBoard extends StatefulWidget {
  const MatchBoard({
    super.key,
    required this.item,
    required this.onSolved,
    required this.onMiss,
  });

  final PrimarItem item;

  /// Every pair joined. Reports how many wrong joins it took, because solving
  /// a board is not evidence of anything on its own — a child can reach the
  /// end by trying every combination.
  final void Function(int wrongJoins) onSolved;

  /// A wrong join. Reported so the misconception tracker sees it, but the
  /// board simply lets go and the child tries again — there is no penalty and
  /// no moving on.
  final VoidCallback onMiss;

  @override
  State<MatchBoard> createState() => _MatchBoardState();
}

class _MatchBoardState extends State<MatchBoard> {
  int? _pickedLeft;
  final Set<int> _joined = {};
  int? _wrongLeft;
  int? _wrongRight;
  int _wrongJoins = 0;

  void _tapLeft(int i) {
    if (_joined.contains(i)) return;
    PrimarVoice.instance.chime(Sfx.tap);
    setState(() {
      _pickedLeft = _pickedLeft == i ? null : i;
      _wrongLeft = null;
      _wrongRight = null;
    });
  }

  void _tapRight(int j) {
    final left = _pickedLeft;
    if (left == null) return;
    if (widget.item.matchPairing.contains(j) &&
        _joined.contains(widget.item.matchPairing.indexOf(j))) {
      return;
    }

    if (widget.item.matchPairing[left] == j) {
      PrimarVoice.instance.chime(Sfx.correct);
      setState(() {
        _joined.add(left);
        _pickedLeft = null;
      });
      if (_joined.length == widget.item.matchLeft.length) {
        widget.onSolved(_wrongJoins);
      }
    } else {
      // The pair simply comes apart. No mark, no advance — a child who joined
      // the wrong two things needs another go, not a verdict.
      widget.onMiss();
      _wrongJoins++;
      setState(() {
        _wrongLeft = left;
        _wrongRight = j;
        _pickedLeft = null;
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _wrongLeft = null;
          _wrongRight = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < item.matchLeft.length; i++)
                _Cell(
                  figure: item.matchLeft[i],
                  done: _joined.contains(i),
                  picked: _pickedLeft == i,
                  wrong: _wrongLeft == i,
                  onTap: () => _tapLeft(i),
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: [
              for (var j = 0; j < item.matchRight.length; j++)
                _Cell(
                  figure: item.matchRight[j],
                  done: _joined.any((l) => item.matchPairing[l] == j),
                  picked: false,
                  wrong: _wrongRight == j,
                  onTap: () => _tapRight(j),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.figure,
    required this.done,
    required this.picked,
    required this.wrong,
    required this.onTap,
  });

  final Figure figure;
  final bool done;
  final bool picked;
  final bool wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: done ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: 76,
          // A joined pair settles rather than vanishing, so a child can see
          // what they have already done.
          transform: Matrix4.translationValues(wrong ? 4 : 0, 0, 0),
          decoration: PrimarTheme.tile(
            border: done
                ? PrimarTheme.teal
                : picked
                    ? PrimarTheme.blue
                    : null,
            fill: done
                ? PrimarTheme.tintTeal
                : picked
                    ? PrimarTheme.tintBlue
                    : null,
            lift: picked ? 8 : (done ? 2 : 5),
          ),
          child: Center(
            child: Opacity(
              opacity: done ? 0.55 : 1,
              child: FigureView(
                figure: figure,
                color: done ? PrimarTheme.teal : PrimarTheme.answerInk,
                size: 52,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
