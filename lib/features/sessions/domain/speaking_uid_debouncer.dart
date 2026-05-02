import 'dart:async';

/// Speaking-indicator smoothing: show a UID as soon as volume says "speaking",
/// but keep it lit for [releaseDelay] after the last positive sample so borders do not
/// flicker between adjacent talkers.
class SpeakingUidDebouncer {
  SpeakingUidDebouncer({
    this.releaseDelay = const Duration(milliseconds: 280),
  });

  final Duration releaseDelay;

  final Set<int> _displayed = {};
  final Map<int, Timer> _releaseTimers = {};

  /// Currently debounced speaking UIDs (copy).
  Set<int> get displayed => Set<int>.from(_displayed);

  void applyRaw(Set<int> raw, void Function(Set<int> debounced) onChanged) {
    var added = false;
    for (final uid in raw) {
      _releaseTimers.remove(uid)?.cancel();
      if (_displayed.add(uid)) {
        added = true;
      }
    }
    if (added) {
      onChanged(Set<int>.from(_displayed));
    }

    for (final uid in _displayed.difference(raw)) {
      _releaseTimers[uid]?.cancel();
      _releaseTimers[uid] = Timer(releaseDelay, () {
        _releaseTimers.remove(uid);
        if (_displayed.remove(uid)) {
          onChanged(Set<int>.from(_displayed));
        }
      });
    }
  }

  void reset() {
    for (final t in _releaseTimers.values) {
      t.cancel();
    }
    _releaseTimers.clear();
    _displayed.clear();
  }
}
