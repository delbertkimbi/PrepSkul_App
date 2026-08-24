import 'package:flutter/material.dart';

import '../domain/figure.dart';
import '../services/primar_voice.dart';
import 'figure_view.dart';
import 'primar_theme.dart';

/// Drag these into the right order, smallest first.
///
/// ## Why there is no "Done" button
///
/// A row of tiles is always in *some* order, so unlike every other interaction
/// here there is no moment where the child declares an answer. The obvious fix
/// is a confirm button, and it is the wrong one: a non-reader cannot be given a
/// button that means "I have finished", and adding one would make the hardest
/// part of the question the button rather than the ordering.
///
/// So the board watches itself. The instant the row is correct, it locks and
/// celebrates. A child who reaches the answer by shuffling still reaches it —
/// which is why the *number of moves* is what gets scored, not whether they got
/// there.
///
/// ## What counts as knowing
///
/// The fewest moves that can sort a row is its length minus the longest run
/// already in the right relative order. A child who can see the sequence makes
/// exactly that many moves. One extra is a slip. More than that is shuffling,
/// and the staircase has to hear about it or it will climb on nothing — the
/// same defect the match board had, where solving was the only exit and every
/// board therefore scored as a success.
/// The fewest reorder moves that can sort [from] into [target].
///
/// Each move lifts one tile out and drops it anywhere, so every tile *not* in
/// the longest already-correctly-ordered subsequence has to be moved exactly
/// once. That makes the answer `n - LIS`, computed against each tile's position
/// in the target rather than its value.
///
/// Top-level and pure because it is the scoring rule, not a rendering detail:
/// get it wrong and every child scores as knowing, which is exactly the defect
/// the match board shipped with.
int minimumOrderMoves(List<int> from, List<int> target) {
  final rank = <int, int>{for (var i = 0; i < target.length; i++) target[i]: i};
  final seq = [for (final i in from) rank[i] ?? 0];
  if (seq.isEmpty) return 0;

  var best = 0;
  // n is at most four here, so the quadratic form is the readable one.
  final len = List<int>.filled(seq.length, 1);
  for (var i = 0; i < seq.length; i++) {
    for (var j = 0; j < i; j++) {
      if (seq[j] < seq[i] && len[j] + 1 > len[i]) len[i] = len[j] + 1;
    }
    if (len[i] > best) best = len[i];
  }
  return seq.length - best;
}

class OrderRow extends StatefulWidget {
  const OrderRow({
    super.key,
    required this.item,
    required this.onSolved,
    required this.onMiss,
  });

  final PrimarItem item;

  /// Sorted. Reports how many moves past the minimum it took.
  final void Function(int movesOverPar) onSolved;

  /// A move that took the row further from sorted. Reported so the tracker
  /// sees the pattern; the board itself does nothing about it.
  final VoidCallback onMiss;

  @override
  State<OrderRow> createState() => _OrderRowState();
}

class _OrderRowState extends State<OrderRow> {
  /// Indices into `item.orderItems`, in the order currently on screen.
  late final List<int> _row = List<int>.generate(widget.item.orderItems.length, (i) => i);

  late final int _par = minimumOrderMoves(_row, widget.item.orderSolution);

  int _moves = 0;
  bool _done = false;

  bool get _sorted {
    for (var i = 0; i < _row.length; i++) {
      if (_row[i] != widget.item.orderSolution[i]) return false;
    }
    return true;
  }

  void _reorder(int oldIndex, int newIndex) {
    if (_done) return;

    final before = minimumOrderMoves(_row, widget.item.orderSolution);
    setState(() {
      // onReorderItem already accounts for the removal, so newIndex needs no
      // adjustment here — the older onReorder callback did not, and mixing the
      // two conventions puts every tile one place out.
      final moved = _row.removeAt(oldIndex);
      _row.insert(newIndex, moved);
      _moves++;
    });

    final after = minimumOrderMoves(_row, widget.item.orderSolution);
    if (after > before) widget.onMiss();

    if (_sorted) {
      setState(() => _done = true);
      PrimarVoice.instance.chime(Sfx.levelUp);
      PrimarVoice.instance.say(VoiceLines.wellOrdered);
      // A beat to see the finished row before the screen moves on.
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) widget.onSolved(_moves - _par);
      });
    } else {
      PrimarVoice.instance.chime(Sfx.tap);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiles = widget.item.orderItems;

    return Column(
      children: [
        // The direction, said without words. A child who has not been told
        // "smallest first" cannot start, and telling them in writing is not an
        // option — so the row is bracketed by a small mark and a large one.
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Bracket(size: 12),
              Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        PrimarTheme.teal.withValues(alpha: 0.25),
                        PrimarTheme.teal.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
              ),
              _Bracket(size: 26),
            ],
          ),
        ),
        // The row does not scroll, so the tiles have to be cut from the width
        // that exists. A fixed 84 fitted the phone it was written on and
        // clipped the last tile on a 320pt one — and a clipped tile in a
        // sorting task is a tile the child cannot compare.
        LayoutBuilder(
          builder: (context, box) {
            const gap = 10.0;
            final width =
                ((box.maxWidth - gap * (_row.length - 1)) / _row.length).clamp(52.0, 96.0);
            // Ten-frames are five wide and two tall, so a square tile leaves
            // most of its height empty and the dots too small to count —
            // which is the whole task at this level.
            final height = width * 1.05;

            return SizedBox(
              height: height,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _row.length,
                onReorderItem: _reorder,
                proxyDecorator: (child, index, animation) => Material(
                  color: Colors.transparent,
                  child: Transform.scale(scale: 1.06, child: child),
                ),
                itemBuilder: (context, i) {
                  final figure = tiles[_row[i]];
                  return Padding(
                    key: ValueKey(_row[i]),
                    padding: EdgeInsets.only(right: i == _row.length - 1 ? 0 : gap),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: width,
                      decoration: PrimarTheme.tile(
                        border: _done ? PrimarTheme.teal : null,
                        fill: _done ? PrimarTheme.tintTeal : null,
                        lift: _done ? 3 : 6,
                      ),
                      child: Center(
                        child: FigureView(
                          figure: figure,
                          color: _done ? PrimarTheme.teal : PrimarTheme.answerInk,
                          size: width * 0.82,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A dot at each end of the rail: a small one where the smallest goes, a large
/// one where the largest does. The instruction, with nothing to read.
class _Bracket extends StatelessWidget {
  const _Bracket({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PrimarTheme.teal.withValues(alpha: 0.85),
        shape: BoxShape.circle,
      ),
    );
  }
}
