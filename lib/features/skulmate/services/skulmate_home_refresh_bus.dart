import 'package:flutter/foundation.dart';

/// Notifies SkulMate home to reload games/decks after library changes.
class SkulMateHomeRefreshBus {
  SkulMateHomeRefreshBus._();

  static final ValueNotifier<int> tick = ValueNotifier(0);

  static void notify() {
    tick.value++;
  }
}
