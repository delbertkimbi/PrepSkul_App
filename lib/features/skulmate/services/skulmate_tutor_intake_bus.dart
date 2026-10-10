import 'package:flutter/foundation.dart';
import 'package:prepskul/features/skulmate/models/skulmate_intake_models.dart';

/// Drops attachments into the open tutor thread instead of a mode picker.
class SkulMateTutorIntakeBus {
  SkulMateTutorIntakeBus._();

  static final ValueNotifier<SkulMateIntakePayload?> pending =
      ValueNotifier<SkulMateIntakePayload?>(null);

  static void offer(SkulMateIntakePayload payload) {
    pending.value = payload;
  }

  static SkulMateIntakePayload? take() {
    final value = pending.value;
    pending.value = null;
    return value;
  }
}
