import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:prepskul/core/config/app_config.dart';

/// A tutor, as much of one as a child's screen needs.
@immutable
class TutorCard {
  const TutorCard({
    required this.id,
    required this.name,
    required this.subjects,
    required this.live,
    this.city,
    this.rating,
    this.photoUrl,
    this.sessions,
  });

  final String id;
  final String name;
  final List<String> subjects;

  /// Reachable this minute.
  ///
  /// Always false today. The server has no presence signal to report — see the
  /// note in `app/api/primar/tutors/route.ts` — and the field exists so that
  /// the day it does, nothing here has to change. Until then the button says
  /// "ask for a call", never "call now".
  final bool live;

  final String? city;
  final double? rating;
  final String? photoUrl;
  final int? sessions;

  static TutorCard? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    return TutorCard(
      id: id,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Tutor',
      subjects: [
        for (final s in (json['subjects'] as List? ?? const []))
          if (s is String) s,
      ],
      live: json['live'] == true,
      city: json['city'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      photoUrl: json['photoUrl'] as String?,
      sessions: (json['sessions'] as num?)?.toInt(),
    );
  }
}

/// Reads the tutor list.
///
/// Failure is a short list, never an exception. A child on the help tab with
/// no network should see "nobody yet, try again in a bit" — not a red error,
/// and not a spinner that never stops.
class TutorDirectory {
  TutorDirectory._();

  static final TutorDirectory instance = TutorDirectory._();

  List<TutorCard>? _cache;
  DateTime? _fetchedAt;

  /// Long enough that switching tabs does not re-fetch, short enough that a
  /// tutor who joins today shows up today.
  static const _freshFor = Duration(minutes: 10);

  Future<List<TutorCard>> load({
    String subject = 'reading',
    bool force = false,
  }) async {
    final cached = _cache;
    final at = _fetchedAt;
    if (!force &&
        cached != null &&
        at != null &&
        DateTime.now().difference(at) < _freshFor) {
      return cached;
    }

    try {
      final base = AppConfig.effectiveApiBaseUrl;
      final uri = Uri.parse('$base/primar/tutors?subject=$subject');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint('[TutorDirectory] ${response.statusCode} from $uri');
        return cached ?? const [];
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return cached ?? const [];

      final tutors = [
        for (final row in (body['tutors'] as List? ?? const []))
          if (row is Map<String, dynamic>)
            if (TutorCard.fromJson(row) case final t?) t,
      ];

      _cache = tutors;
      _fetchedAt = DateTime.now();
      return tutors;
    } catch (e) {
      debugPrint('[TutorDirectory] load failed: $e');
      return cached ?? const [];
    }
  }

  @visibleForTesting
  void seed(List<TutorCard> tutors) {
    _cache = tutors;
    _fetchedAt = DateTime.now();
  }

  /// Forget what was fetched, so the next [load] goes to the network.
  ///
  /// Not a test seam — the "look again" button on an empty list needs it, and
  /// that button is the entire recovery path when the first fetch happened
  /// while the phone had no signal.
  void resetCache() {
    _cache = null;
    _fetchedAt = null;
  }
}
