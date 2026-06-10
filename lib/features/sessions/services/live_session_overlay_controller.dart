import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/booking/utils/session_live_utils.dart';

/// Tracks an active in-progress session for the global floating live PiP.
class LiveSessionOverlayController extends ChangeNotifier {
  LiveSessionOverlayController._();
  static final LiveSessionOverlayController instance =
      LiveSessionOverlayController._();

  Map<String, dynamic>? _session;
  String? _userRole;
  String? _counterpartyName;
  String? _subject;
  String? _localAvatarUrl;
  String? _counterpartyAvatarUrl;
  bool _isOnline = true;
  DateTime? _startedAt;
  bool _routeSuppressed = false;
  bool _notifyScheduled = false;

  bool get isActive => _session != null && !_routeSuppressed;
  Map<String, dynamic>? get session => _session;
  String? get sessionId => _session?['id']?.toString();
  String? get userRole => _userRole;
  String? get counterpartyName => _counterpartyName;
  String? get subject => _subject;
  String? get localAvatarUrl => _localAvatarUrl;
  String? get counterpartyAvatarUrl => _counterpartyAvatarUrl;
  bool get isOnline => _isOnline;
  DateTime? get startedAt => _startedAt;

  String get sessionType {
    final type = _session?['_sessionType'] as String?;
    if (type != null && type.isNotEmpty) return type;
    if (_session?.containsKey('scheduled_date') == true) return 'individual';
    return 'trial';
  }

  void register({
    required Map<String, dynamic> session,
    required String userRole,
    required String counterpartyName,
    String? subject,
    String? localAvatarUrl,
    String? counterpartyAvatarUrl,
    bool isOnline = true,
    DateTime? startedAt,
  }) {
    _session = Map<String, dynamic>.from(session);
    _userRole = userRole;
    _counterpartyName = counterpartyName;
    _subject = subject;
    _localAvatarUrl = localAvatarUrl;
    _counterpartyAvatarUrl = counterpartyAvatarUrl;
    _isOnline = isOnline;
    _startedAt = startedAt ?? _parseStartedAt(session);
    _notify();
  }

  void registerFromSessionMap({
    required Map<String, dynamic> session,
    required String userRole,
    required String counterpartyName,
    String? subject,
    String? localAvatarUrl,
    String? counterpartyAvatarUrl,
    bool isOnline = true,
    bool allowStale = false,
  }) {
    if (!allowStale && !_isSessionGenuinelyLive(session)) {
      final id = session['id']?.toString();
      if (id != null && sessionId == id) clear();
      LogService.info(
        '[LIVE_OVERLAY] Skipping PiP — session $id is not genuinely live',
      );
      return;
    }
    final avatars = _resolveAvatars(session, userRole);
    register(
      session: session,
      userRole: userRole,
      counterpartyName: counterpartyName,
      subject: subject,
      localAvatarUrl: localAvatarUrl ?? avatars.$1,
      counterpartyAvatarUrl: counterpartyAvatarUrl ?? avatars.$2,
      isOnline: isOnline,
      startedAt: _parseStartedAt(session),
    );
  }

  (String?, String?) _resolveAvatars(
    Map<String, dynamic> session,
    String userRole,
  ) {
    final recurring = session['recurring_sessions'] as Map<String, dynamic>?;
    if (userRole == 'tutor') {
      final tutor = session['tutor_avatar_url']?.toString() ??
          recurring?['tutor_avatar_url']?.toString();
      final student = session['student_avatar_url']?.toString() ??
          session['learner_avatar_url']?.toString() ??
          recurring?['learner_avatar_url']?.toString() ??
          recurring?['student_avatar_url']?.toString();
      return (tutor, student);
    }
    final learner = session['learner_avatar_url']?.toString() ??
        session['student_avatar_url']?.toString() ??
        recurring?['learner_avatar_url']?.toString();
    final tutor = session['tutor_avatar_url']?.toString() ??
        recurring?['tutor_avatar_url']?.toString();
    return (learner, tutor);
  }

  DateTime? _parseStartedAt(Map<String, dynamic> session) {
    final raw = session['session_started_at'];
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  /// True only when the tutor actually started and the session window has not expired.
  bool isSessionGenuinelyLive(Map<String, dynamic> session) =>
      SessionLiveUtils.isSessionGenuinelyLive(session);

  bool _isSessionGenuinelyLive(Map<String, dynamic> session) =>
      SessionLiveUtils.isSessionGenuinelyLive(session);

  void clear() {
    if (_session == null) return;
    _session = null;
    _userRole = null;
    _counterpartyName = null;
    _subject = null;
    _localAvatarUrl = null;
    _counterpartyAvatarUrl = null;
    _startedAt = null;
    _routeSuppressed = false;
    _notify();
  }

  /// Hide overlay while the live session detail route is visible.
  void setRouteSuppressed(bool suppressed) {
    if (_routeSuppressed == suppressed) return;
    _routeSuppressed = suppressed;
    _notify();
  }

  void _notify() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  /// Restore overlay after hot restart if user still has an in-progress session.
  Future<void> refreshFromServer({String? userRole}) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      clear();
      return;
    }

    try {
      final role = userRole ??
          (await SupabaseService.client
                  .from('profiles')
                  .select('user_type')
                  .eq('id', userId)
                  .maybeSingle())
              ?['user_type']
              ?.toString();

      if (role == 'tutor') {
        final row = await SupabaseService.client
            .from('individual_sessions')
            .select('''
              *,
              recurring_sessions(
                id, subject, tutor_name, tutor_avatar_url,
                learner_name, learner_avatar_url,
                learner_id, learner_type
              )
            ''')
            .eq('tutor_id', userId)
            .eq('status', 'in_progress')
            .order('session_started_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (row != null) {
          final map = Map<String, dynamic>.from(row);
          map['_sessionType'] = 'individual';
          if (!_isSessionGenuinelyLive(map)) {
            clear();
            return;
          }
          registerFromSessionMap(
            session: map,
            userRole: 'tutor',
            counterpartyName: _resolveCounterpartyForTutor(map),
            subject: _resolveSubject(map),
            isOnline: (map['location'] as String? ?? 'online') == 'online',
          );
          return;
        }
      } else {
        final row = await SupabaseService.client
            .from('individual_sessions')
            .select('''
              *,
              recurring_sessions(
                id, subject, tutor_name, tutor_avatar_url, learner_name,
                learner_avatar_url
              )
            ''')
            .eq('learner_id', userId)
            .eq('status', 'in_progress')
            .order('session_started_at', ascending: false)
            .limit(1)
            .maybeSingle();

        var learnerRow = row;
        if (learnerRow == null) {
          learnerRow = await SupabaseService.client
              .from('individual_sessions')
              .select('''
                *,
                recurring_sessions(
                  id, subject, tutor_name, tutor_avatar_url, learner_name,
                  learner_avatar_url
                )
              ''')
              .eq('parent_id', userId)
              .eq('status', 'in_progress')
              .order('session_started_at', ascending: false)
              .limit(1)
              .maybeSingle();
        }

        if (learnerRow != null) {
          final map = Map<String, dynamic>.from(learnerRow);
          map['_sessionType'] = 'individual';
          if (!_isSessionGenuinelyLive(map)) {
            clear();
            return;
          }
          registerFromSessionMap(
            session: map,
            userRole: role ?? 'student',
            counterpartyName: _resolveCounterpartyForLearner(map),
            subject: _resolveSubject(map),
            isOnline: (map['location'] as String? ?? 'online') == 'online',
          );
          return;
        }
      }

      clear();
    } catch (e) {
      LogService.warning('[LIVE_OVERLAY] refreshFromServer failed: $e');
    }
  }

  String _resolveSubject(Map<String, dynamic> session) {
    final recurring = session['recurring_sessions'] as Map<String, dynamic>?;
    return recurring?['subject']?.toString() ??
        session['subject']?.toString() ??
        'Session';
  }

  String _resolveCounterpartyForTutor(Map<String, dynamic> session) {
    final recurring = session['recurring_sessions'] as Map<String, dynamic>?;
    final name = session['student_name'] as String? ??
        recurring?['learner_name']?.toString();
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return 'Student';
  }

  String _resolveCounterpartyForLearner(Map<String, dynamic> session) {
    final recurring = session['recurring_sessions'] as Map<String, dynamic>?;
    final name = recurring?['tutor_name']?.toString() ??
        session['tutor_name']?.toString();
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return 'Tutor';
  }
}
