import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/shimmer_loading.dart';

import '../l10n/skulmate_copy.dart';
import '../models/skulmate_intake_models.dart';
import '../services/skulmate_intake_coordinator.dart';
import '../services/skulmate_session_intake_service.dart';
import 'skulmate_surface_styles.dart';

/// Full-width bottom sheet to pick a tutor class session for revision.
class SkulMateFromClassSheet extends StatefulWidget {
  final String? childId;

  const SkulMateFromClassSheet({super.key, this.childId});

  static Future<void> show(BuildContext context, {String? childId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.softBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SkulMateFromClassSheet(childId: childId),
    );
  }

  @override
  State<SkulMateFromClassSheet> createState() => _SkulMateFromClassSheetState();
}

class _SkulMateFromClassSheetState extends State<SkulMateFromClassSheet> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sessions = await SkulMateSessionIntakeService.loadRecordedSessions(
        childId: widget.childId,
      );
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onSessionTap(Map<String, dynamic> session) async {
    final summary = session['session_summary'] as String? ?? '';
    if (summary.trim().isEmpty) return;

    final recurring = session['recurring_sessions'] as Map<String, dynamic>?;
    final subject = recurring?['subject'] as String? ?? 'Class session';
    final tutor = recurring?['tutor_name'] as String?;

    Navigator.pop(context);
    if (!context.mounted) return;

    await SkulMateIntakeCoordinator.start(
      context,
      SkulMateIntakePayload(
        source: SkulMateIntakeSource.fromClass,
        text: summary,
        title: tutor != null ? '$subject · $tutor' : subject,
        childId: widget.childId,
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.neutral200,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    copy.sessions,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: AppTheme.textMedium,
                ),
              ],
            ),
          ),
          Flexible(
            child: _loading
                ? ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: 4,
                    itemBuilder: (_, __) => ShimmerLoading.listTile(),
                  )
                : _sessions.isEmpty
                    ? _EmptyState(copy: copy)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final session = _sessions[index];
                          final recurring =
                              session['recurring_sessions']
                                  as Map<String, dynamic>?;
                          final subject =
                              recurring?['subject'] as String? ?? 'Session';
                          final tutor =
                              recurring?['tutor_name'] as String? ?? '';
                          final date = _formatDate(
                            session['scheduled_date'] as String?,
                          );

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _onSessionTap(session),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: SkulMateSurfaceStyles.homeCard(
                                  radius: 14,
                                  compact: true,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.video_library_rounded,
                                        color: AppTheme.primaryColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            subject,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (tutor.isNotEmpty)
                                            Text(
                                              tutor,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: AppTheme.textMedium,
                                              ),
                                            ),
                                          if (date.isNotEmpty)
                                            Text(
                                              date,
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: AppTheme.textMedium,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppTheme.textMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final SkulMateCopy copy;

  const _EmptyState({required this.copy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.video_library_rounded,
              size: 34,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            copy.noRecordedSessions,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            copy.isFrench
                ? 'Les sessions enregistrées avec ton tuteur apparaîtront ici.'
                : 'Recorded tutor sessions will show up here after your classes.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
