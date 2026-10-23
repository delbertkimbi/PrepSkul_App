import 'package:prepskul/core/design/prepskul_icon.dart';
import 'package:prepskul/core/design/learner_celebration.dart';
import 'learner_bottom_bar.dart';
import 'package:prepskul/core/services/offline_cache_service.dart';
import 'package:prepskul/core/design/learner_design.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';
import 'package:prepskul/features/profile/screens/profile_screen.dart';
import 'package:prepskul/features/discovery/screens/find_tutors_screen.dart';
import 'package:prepskul/features/booking/screens/my_requests_screen.dart';
import 'package:prepskul/features/booking/screens/my_sessions_screen.dart';
import 'package:prepskul/features/skulmate/screens/skulmate_home_screen.dart';
import 'package:prepskul/features/skulmate/screens/learning_journey_screen.dart';
import 'main_navigation_scope.dart';
import 'learner_return_policy.dart';

/// Learner destinations are tasks, while marketplace tools remain contextual.
/// Legacy tab intents are translated here so booking/notification links still work.
class LearnerExperienceShell extends StatefulWidget {
  final String userRole;
  final int? legacyInitialTab;
  const LearnerExperienceShell({
    super.key,
    required this.userRole,
    this.legacyInitialTab,
  });
  @override
  State<LearnerExperienceShell> createState() => _LearnerExperienceShellState();
}

class _LearnerExperienceShellState extends State<LearnerExperienceShell>
    with WidgetsBindingObserver {
  bool _welcoming = false;
  Map<String, dynamic>? _savedProfile;
  Timer? _welcomeTimer;
  String? _returnKey;
  int _selected = 0;
  final Set<int> _visited = {0};
  bool get fr => Localizations.localeOf(context).languageCode == 'fr';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkReturn());
    unawaited(_loadProfile());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final args = ModalRoute.of(context)?.settings.arguments;
      final tab = args is Map ? args['tab'] : null;
      final legacy = switch (tab) {
        'home' => 0,
        'findTutors' => 1,
        'skulMate' => 2,
        'requests' => 3,
        'profile' => 4,
        _ =>
          args is Map
              ? args['initialTab'] as int? ?? widget.legacyInitialTab
              : widget.legacyInitialTab,
      };
      if (legacy != null) _legacyNavigate(legacy);
    });
  }

  Future<void> _loadProfile() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    try {
      final cached = await OfflineCacheService.getCachedUserProfile(userId);
      if (mounted && cached != null) setState(() => _savedProfile = cached);
      final saved = await SupabaseService.client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      if (mounted &&
          SupabaseService.currentUser?.id == userId &&
          saved != null) {
        setState(() => _savedProfile = saved);
      }
    } catch (_) {
      // The header can render from cached or sign-in details without blocking Home.
    }
  }

  String? _nonEmpty(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Future<void> _checkReturn() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    _returnKey = 'learner_last_active_$userId';
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final previous = prefs.getInt(_returnKey!);
    await prefs.setInt(_returnKey!, now);
    // A fresh shell after 30 minutes away, not every tab change or resume.
    if (!mounted ||
        !LearnerReturnPolicy.shouldWelcome(now: now, lastActive: previous)) {
      return;
    }
    setState(() => _welcoming = true);
    _welcomeTimer = Timer(const Duration(milliseconds: 2400), _finishWelcome);
  }

  void _finishWelcome() {
    _welcomeTimer?.cancel();
    if (mounted) setState(() => _welcoming = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_returnKey != null &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      unawaited(
        SharedPreferences.getInstance().then(
          (prefs) =>
              prefs.setInt(_returnKey!, DateTime.now().millisecondsSinceEpoch),
        ),
      );
    }
  }

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _open(Widget page) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          Theme(data: LearnerDesign.theme(Theme.of(context)), child: page),
    ),
  );
  void _select(int index) => setState(() {
    _selected = index;
    _visited.add(index);
  });
  void _legacyNavigate(int index) {
    switch (index) {
      case 0:
        _select(0);
      case 1:
        _select(1);
      case 2:
        _select(2);
      case 3:
        final args = ModalRoute.of(context)?.settings.arguments;
        _open(
          MyRequestsScreen(
            highlightRequestId: args is Map
                ? args['highlightRequestId'] as String?
                : null,
          ),
        );
      case 4:
        _profile();
    }
  }

  Future<void> _profile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: LearnerDesign.theme(Theme.of(context)),
          child: ProfileScreen(
            userType: widget.userRole == 'parent' ? 'parent' : 'student',
          ),
        ),
      ),
    );
    if (mounted) await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final profile = SupabaseService.client.auth.currentUser?.userMetadata;
    final name =
        _nonEmpty(_savedProfile?['full_name']) ??
        _nonEmpty(profile?['full_name']) ??
        '';
    final avatar =
        _nonEmpty(_savedProfile?['avatar_url']) ??
        _nonEmpty(profile?['avatar_url']) ??
        _nonEmpty(profile?['picture']);
    final labels = [
      fr ? 'Accueil' : 'Home',
      fr ? 'Tuteurs' : 'Tutors',
      'Mate',
      fr ? 'Séances' : 'Sessions',
    ];
    return MainNavigationScope(
      selectedIndex: _selected,
      switchTab: _legacyNavigate,
      child: Theme(
        data: LearnerDesign.theme(Theme.of(context)),
        child: Scaffold(
          backgroundColor: LearnerDesign.canvas,
          appBar: _welcoming || _selected == 1 || _selected == 2
              ? null
              : AppBar(
                  backgroundColor: LearnerDesign.canvas,
                  surfaceTintColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  centerTitle: false,
                  titleSpacing: 20,
                  toolbarHeight: 64,
                  title: _selected == 0
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fr ? 'Bonjour' : 'Welcome back',
                              style: LearnerDesign.body(12),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              name.trim().isEmpty
                                  ? 'Your learning space'
                                  : name.trim().split(' ').first,
                              style: LearnerDesign.title(22),
                            ),
                          ],
                        )
                      : Text(labels[_selected], style: LearnerDesign.title(22)),
                  actions: [
                    if (_selected == 3)
                      IconButton(
                        tooltip: fr ? 'Demandes de cours' : 'Booking requests',
                        icon: const PrepSkulIcon(PrepSkulGlyph.requests),
                        onPressed: () => _open(const MyRequestsScreen()),
                      ),
                    if (_selected == 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: IconButton.filledTonal(
                          tooltip: fr ? 'Ton profil' : 'Your profile',
                          style: IconButton.styleFrom(
                            backgroundColor: LearnerDesign.sky,
                            foregroundColor: LearnerDesign.ink,
                          ),
                          onPressed: _profile,
                          icon: avatar != null && avatar.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    avatar,
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.person_outline),
                                  ),
                                )
                              : name.isEmpty
                              ? const Icon(Icons.person_outline)
                              : Text(
                                  name.substring(0, 1).toUpperCase(),
                                  style: LearnerDesign.text(),
                                ),
                        ),
                      ),
                  ],
                ),
          body: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 840),
                    child: IndexedStack(
                      index: _selected,
                      children: [
                        LearningJourneyScreen(
                          learnerName: name,
                          onSessions: () => _select(3),
                          onMate: () => _select(2),
                          onTutors: () => _select(1),
                        ),
                        if (_visited.contains(1))
                          const FindTutorsScreen()
                        else
                          const SizedBox.shrink(),
                        if (_visited.contains(2))
                          SkulMateHomeScreen(onExit: () => _select(0))
                        else
                          const SizedBox.shrink(),
                        if (_visited.contains(3))
                          const MySessionsScreen(embedded: true)
                        else
                          const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
              ),
              if (_welcoming)
                Positioned.fill(
                  child: LearnerCelebration(onDone: _finishWelcome),
                ),
            ],
          ),
          bottomNavigationBar: _welcoming || _selected == 2
              ? null
              : LearnerBottomBar(
                  selected: _selected,
                  labels: labels,
                  onSelected: _select,
                ),
        ),
      ),
    );
  }
}
