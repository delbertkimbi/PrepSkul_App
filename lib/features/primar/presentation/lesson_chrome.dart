import 'package:flutter/material.dart';

import 'mascot.dart';
import 'primar_theme.dart';

/// The state the pinned top bar reads, owned by the screen and written by the
/// session.
///
/// Notifiers rather than `setState`, on purpose: the bar has to repaint on
/// every answer while the question below it must not. Lifting the session's
/// state up to the screen so the bar could see it would rebuild the whole
/// question tree — figures, painters and all — fourteen times a session, on
/// the cheapest phone we support.
class LessonChrome {
  final ValueNotifier<double> progress = ValueNotifier(0);
  final ValueNotifier<Mood> mood = ValueNotifier(Mood.idle);

  /// How many the child has got right this session. Duolingo puts a number up
  /// here because a bar alone answers "how much is left" and never "how am I
  /// doing", and the second one is the question a child actually has.
  final ValueNotifier<int> correct = ValueNotifier(0);

  /// Hidden outside a session. The onboarding has its own step dots, and two
  /// progress bars on one screen measure nothing.
  final ValueNotifier<bool> visible = ValueNotifier(false);

  void reset() {
    progress.value = 0;
    correct.value = 0;
    mood.value = Mood.idle;
  }

  void dispose() {
    progress.dispose();
    mood.dispose();
    correct.dispose();
    visible.dispose();
  }
}

/// The bar that stays put.
///
/// ## Why it is pinned and at the top
///
/// It used to sit inside the scrolling column, vertically centred with
/// everything else, so the one element that is supposed to be constant moved
/// every time the question under it changed height — and on a short phone it
/// scrolled off entirely. A progress bar you have to go looking for is not
/// telling anybody anything.
///
/// Duolingo's arrangement is the right one and the reason is not fashion: the
/// bar and the mascot are the *frame*, and the question is the only thing that
/// changes. Fixing the frame is what makes the changes legible.
class LessonTopBar extends StatelessWidget {
  const LessonTopBar({
    super.key,
    required this.chrome,
    required this.onQuit,
  });

  final LessonChrome chrome;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          // Mate rides in the bar rather than above the question. He is the
          // one thing on screen that reacts, so he belongs with the other
          // constant, not in the part that gets replaced every few seconds.
          ValueListenableBuilder<Mood>(
            valueListenable: chrome.mood,
            builder: (context, mood, _) => Mate(mood: mood, size: 46),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ValueListenableBuilder<double>(
              valueListenable: chrome.progress,
              builder: (context, value, _) => _Bar(value: value),
            ),
          ),
          const SizedBox(width: 12),
          ValueListenableBuilder<int>(
            valueListenable: chrome.correct,
            builder: (context, n, _) => _Tally(count: n),
          ),
          const SizedBox(width: 4),
          // A way out that is not the system back button. A child handed a
          // phone will find this; a parent needs it to exist.
          IconButton(
            onPressed: onQuit,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 22),
            color: PrimarTheme.ghostInk,
            tooltip: 'Stop',
          ),
        ],
      ),
    );
  }
}

/// One continuous bar rather than fourteen dots.
///
/// The dots were unreadable at the width a phone actually has — the fix for
/// them overflowing was to shrink them to two and a half logical pixels, which
/// is not a progress indicator, it is a texture. A filling bar reads at a
/// glance from across a room, which is roughly where the parent is.
class _Bar extends StatelessWidget {
  const _Bar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 16,
        color: const Color(0xFFE2E8F0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: PrimarTheme.teal,
                borderRadius: BorderRadius.circular(999),
                // A lighter band along the top edge, so the fill reads as a
                // rounded solid rather than a flat rectangle.
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2DD4BF), PrimarTheme.teal],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Right answers so far, as a count a child can watch go up.
class _Tally extends StatelessWidget {
  const _Tally({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      scale: count == 0 ? 0.9 : 1.0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 20, color: PrimarTheme.yellow),
          const SizedBox(width: 3),
          Text('$count',
              style: PrimarTheme.display(17, color: PrimarTheme.navy)),
        ],
      ),
    );
  }
}
