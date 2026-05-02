class StreamPriorityDecision {
  const StreamPriorityDecision({
    required this.highPriorityUids,
    required this.lowPriorityUids,
    this.spotlightUid,
  });

  final Set<int> highPriorityUids;
  final Set<int> lowPriorityUids;
  final int? spotlightUid;
}

/// Determines which remote participants should use high vs low dual-stream video.
///
/// PrepSkul classroom: keep **high** for the pinned gallery tile (when set) and for the
/// active speaker spotlight; everyone else stays **low** to save bandwidth.
class StreamPriorityPolicy {
  const StreamPriorityPolicy();

  /// Maximum simultaneous high-stream remotes (extra safety if the room grows).
  static const int defaultMaxHighStreams = 4;

  StreamPriorityDecision decide({
    required Set<int> remoteUids,
    required Set<int> speakingUids,
    int? currentSpotlightUid,
    int? pinnedRemoteUid,
    int maxHighStreams = defaultMaxHighStreams,
  }) {
    if (remoteUids.isEmpty) {
      return const StreamPriorityDecision(
        highPriorityUids: <int>{},
        lowPriorityUids: <int>{},
      );
    }

    var spotlight = currentSpotlightUid ?? remoteUids.first;
    if (!remoteUids.contains(spotlight)) {
      spotlight = remoteUids.first;
    }

    // Prefer whoever Agora reports as speaking (first match wins — stable ordering).
    for (final uid in speakingUids) {
      if (remoteUids.contains(uid)) {
        spotlight = uid;
        break;
      }
    }

    final orderedHigh = <int>[];
    if (pinnedRemoteUid != null && remoteUids.contains(pinnedRemoteUid)) {
      orderedHigh.add(pinnedRemoteUid);
    }
    if (!orderedHigh.contains(spotlight)) {
      orderedHigh.add(spotlight);
    }

    final high = orderedHigh.take(maxHighStreams).toSet();
    final low = remoteUids.difference(high);

    return StreamPriorityDecision(
      highPriorityUids: high,
      lowPriorityUids: low,
      spotlightUid: spotlight,
    );
  }
}

