import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/localization/language_service.dart';
import 'package:prepskul/core/services/parent_learners_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/features/discovery/screens/find_tutors_screen.dart';

import '../services/active_tutor_service.dart';
import '../services/parent_progress_service.dart';

/// Parent view: streak, minutes, weak topics, rough exam readiness (C4).
class ParentSkulMateProgressScreen extends StatefulWidget {
  final String? initialChildId;

  const ParentSkulMateProgressScreen({
    super.key,
    this.initialChildId,
  });

  @override
  State<ParentSkulMateProgressScreen> createState() =>
      _ParentSkulMateProgressScreenState();
}

class _ParentSkulMateProgressScreenState
    extends State<ParentSkulMateProgressScreen> {
  List<Map<String, dynamic>> _children = [];
  String? _selectedChildId;
  ParentProgressSnapshot? _snapshot;
  ActiveTutorStatus? _tutorStatus;
  bool _loading = true;

  bool get _isFrench => LanguageService.languageCode == 'fr';

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.initialChildId;
    _load();
  }

  Future<void> _load() async {
    safeSetState(() => _loading = true);
    try {
      final user = await AuthService.getCurrentUser();
      final parentId = user['userId'] as String?;
      if (parentId != null) {
        _children = await ParentLearnersService.getLearners(parentId);
      }

      if (_selectedChildId == null && _children.length == 1) {
        _selectedChildId = _children.first['id']?.toString();
      }

      final snapshot = await ParentSkulMateProgressService.fetch(
        childId: _selectedChildId,
        french: _isFrench,
      );
      final tutorStatus = await ActiveTutorService.check();

      safeSetState(() {
        _snapshot = snapshot;
        _tutorStatus = tutorStatus;
        _loading = false;
      });
    } catch (_) {
      safeSetState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot ?? ParentProgressSnapshot.empty(french: _isFrench);

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isFrench ? 'Progression SkulMate' : 'SkulMate progress',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (_children.length > 1) ...[
                    _childPicker(),
                    const SizedBox(height: 12),
                  ],
                  if (snapshot.learnerContextLine != null) ...[
                    Text(
                      snapshot.learnerContextLine!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_children.isEmpty) _noChildHint(),
                  _statsGrid(snapshot),
                  const SizedBox(height: 14),
                  _readinessCard(snapshot),
                  if (snapshot.weakTopics.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle(
                      _isFrench
                          ? 'Sujets à renforcer'
                          : 'Topics needing attention',
                    ),
                    const SizedBox(height: 8),
                    ...snapshot.weakTopics.map(_weakTopicTile),
                  ],
                  if (snapshot.recentGames.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle(
                      _isFrench ? 'Révisions récentes' : 'Recent revision',
                    ),
                    const SizedBox(height: 8),
                    ...snapshot.recentGames.map(_recentGameTile),
                  ],
                  if (snapshot.sessionHighlights.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle(
                      _isFrench
                          ? 'Dernières séances de tutorat'
                          : 'Recent tutoring sessions',
                    ),
                    const SizedBox(height: 8),
                    ...snapshot.sessionHighlights.map(_sessionHighlightTile),
                  ],
                  if (snapshot.upcomingSessions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle(
                      _isFrench ? 'Séances à venir' : 'Upcoming sessions',
                    ),
                    const SizedBox(height: 8),
                    ...snapshot.upcomingSessions.map(_upcomingSessionTile),
                  ],
                  if (!snapshot.hasActivity) ...[
                    const SizedBox(height: 24),
                    _emptyState(),
                  ],
                  const SizedBox(height: 20),
                  _tutorAction(snapshot),
                ],
              ),
            ),
    );
  }

  Widget _childPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedChildId,
          hint: Text(
            _isFrench ? 'Choisir un enfant' : 'Select child',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          items: _children
              .map(
                (c) => DropdownMenuItem<String>(
                  value: c['id']?.toString(),
                  child: Text(
                    c['name']?.toString() ?? 'Child',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                ),
              )
              .toList(),
          onChanged: (id) {
            safeSetState(() => _selectedChildId = id);
            _load();
          },
        ),
      ),
    );
  }

  Widget _noChildHint() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        _isFrench
            ? 'Ajoutez un enfant dans Mon profil pour suivre chaque parcours séparément.'
            : 'Add a child in My profile to track each learner separately.',
        style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textMedium, height: 1.4),
      ),
    );
  }

  Widget _statsGrid(ParentProgressSnapshot snapshot) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: [
        _statCard(
          icon: PhosphorIcons.fire(),
          label: _isFrench ? 'Série' : 'Streak',
          value: '${snapshot.streakDays}',
          subtitle: _isFrench ? 'jours' : 'days',
        ),
        _statCard(
          icon: PhosphorIcons.clock(),
          label: _isFrench ? '7 derniers jours' : 'Last 7 days',
          value: '${snapshot.revisionMinutesLast7Days}',
          subtitle: _isFrench ? 'minutes' : 'minutes',
        ),
        _statCard(
          icon: PhosphorIcons.gameController(),
          label: _isFrench ? 'Sessions' : 'Sessions',
          value: '${snapshot.sessionsLast7Days}',
          subtitle: _isFrench ? 'cette semaine' : 'this week',
        ),
        _statCard(
          icon: PhosphorIcons.target(),
          label: _isFrench ? 'Précision' : 'Accuracy',
          value: snapshot.accuracyLast7Days != null
              ? '${snapshot.accuracyLast7Days}%'
              : '—',
          subtitle: _isFrench ? '7 jours' : '7 days',
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 22),
          const Spacer(),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textMedium),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textMedium),
          ),
        ],
      ),
    );
  }

  Widget _readinessCard(ParentProgressSnapshot snapshot) {
    final color = _readinessColor(snapshot.readinessBand);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.chartLineUp(), color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  snapshot.readinessTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              Text(
                '${snapshot.examReadiness}%',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: snapshot.examReadiness / 100,
              minHeight: 8,
              backgroundColor: AppTheme.neutral200,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.readinessLabel,
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textMedium),
          ),
          const SizedBox(height: 4),
          Text(
            snapshot.readinessDisclaimer,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppTheme.textMedium,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Color _readinessColor(String band) {
    switch (band) {
      case 'needs_support':
        return AppTheme.error;
      case 'building':
        return Colors.orange;
      case 'on_track':
        return AppTheme.primaryColor;
      default:
        return AppTheme.accentGreen;
    }
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme.textDark,
      ),
    );
  }

  Widget _weakTopicTile(ParentWeakTopic topic) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                if (topic.frameworkLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    topic.frameworkLabel!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
                Text(
                  _isFrench
                      ? '${topic.masteryPercent}% maîtrise · ${topic.attempts} essais'
                      : '${topic.masteryPercent}% mastery · ${topic.attempts} attempts',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium),
                ),
              ],
            ),
          ),
          Text(
            '${topic.masteryPercent}%',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentGameTile(ParentRecentGame game) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              game.title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textDark,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${game.accuracy}%',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionHighlightTile(ParentSessionHighlight session) {
    final title = session.subjectHint ??
        (_isFrench ? 'Séance de tutorat' : 'Tutoring session');
    final tutorSuffix = session.tutorName != null && session.tutorName!.isNotEmpty
        ? ' · ${session.tutorName}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.chalkboardTeacher(), size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$title$tutorSuffix',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            session.summaryPreview,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textMedium,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _upcomingSessionTile(ParentUpcomingSession session) {
    final tutorSuffix = session.tutorName != null && session.tutorName!.isNotEmpty
        ? ' · ${session.tutorName}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.calendar(), size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${session.scheduledAt}$tutorSuffix',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tutorAction(ParentProgressSnapshot snapshot) {
    final hasTutor = _tutorStatus?.hasActiveTutor == true;
    final tutorName = _tutorStatus?.primaryTutorName() ?? '';

    if (hasTutor) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.accentLightGreen.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.35)),
            ),
            child: Text(
              _isFrench
                  ? (tutorName.isNotEmpty
                      ? '$tutorName accompagne déjà votre enfant — partagez ces points faibles lors de la prochaine séance.'
                      : 'Votre enfant a déjà un tuteur — partagez ces points faibles lors de la prochaine séance.')
                  : (tutorName.isNotEmpty
                      ? '$tutorName is already supporting your child — share these focus areas in the next session.'
                      : 'Your child already has a tutor — share these focus areas in the next session.'),
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textDark,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/my-sessions'),
              icon: Icon(PhosphorIcons.calendarCheck()),
              label: Text(
                _isFrench ? 'Voir les séances' : 'View sessions',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (snapshot.weakTopics.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FindTutorsScreen()),
          );
        },
        icon: Icon(PhosphorIcons.chalkboardTeacher()),
        label: Text(
          _isFrench ? 'Trouver un tuteur' : 'Find a tutor',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryColor,
          side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(PhosphorIcons.gameController(), size: 40, color: AppTheme.primaryColor),
          const SizedBox(height: 10),
          Text(
            _isFrench
                ? 'Pas encore de données SkulMate'
                : 'No SkulMate data yet',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _isFrench
                ? 'Quand votre enfant joue des jeux de révision, la progression apparaîtra ici.'
                : 'When your child plays revision games, progress will show up here.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textMedium,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
