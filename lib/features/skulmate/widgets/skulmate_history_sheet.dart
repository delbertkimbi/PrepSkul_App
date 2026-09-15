import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/tutor_session_models.dart';
import '../services/skulmate_tutor_session_service.dart';
import 'skulmate_sheet_scaffold.dart';

/// Tutor-thread history. Learners and parents both open their own sessions.
class SkulMateHistorySheet extends StatefulWidget {
  final String? childId;
  final String? activeSessionId;
  final ValueChanged<String>? onSelectSession;
  final VoidCallback? onNewSession;

  const SkulMateHistorySheet({
    super.key,
    this.childId,
    this.activeSessionId,
    this.onSelectSession,
    this.onNewSession,
  });

  static Future<void> show(
    BuildContext context, {
    String? childId,
    String? activeSessionId,
    ValueChanged<String>? onSelectSession,
    VoidCallback? onNewSession,
  }) {
    return SkulMateSheetScaffold.show<void>(
      context,
      child: SkulMateHistorySheet(
        childId: childId,
        activeSessionId: activeSessionId,
        onSelectSession: onSelectSession,
        onNewSession: onNewSession,
      ),
    );
  }

  @override
  State<SkulMateHistorySheet> createState() => _SkulMateHistorySheetState();
}

class _SkulMateHistorySheetState extends State<SkulMateHistorySheet> {
  final _searchController = TextEditingController();
  List<TutorSessionSummary> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final sessions = await SkulMateTutorSessionService.listSessions(
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

  List<TutorSessionSummary> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _sessions;
    return _sessions.where((s) {
      final title = (s.title ?? '').toLowerCase();
      final preview = (s.preview ?? '').toLowerCase();
      return title.contains(q) || preview.contains(q);
    }).toList();
  }

  String _subtitle(TutorSessionSummary session) {
    final preview = session.preview?.trim();
    if (preview != null && preview.isNotEmpty) return preview;
    return session.lastTurnAt.toLocal().toString().split('.').first;
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final items = _filtered;
    final listHeight = MediaQuery.sizeOf(context).height * 0.48;

    return SkulMateSheetScaffold(
      title: copy.history,
      showWandIcon: false,
      maxHeightFactor: 0.82,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: copy.searchHint,
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppTheme.textMedium.withValues(alpha: 0.7),
              ),
              filled: true,
              fillColor: AppTheme.softBackground,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: AppTheme.softBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onNewSession?.call();
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(copy.newThread),
            ),
          ),
          SizedBox(
            height: listHeight,
            child: _loading && items.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : items.isEmpty
                    ? Center(
                        child: Text(
                          copy.historyEmpty,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: AppTheme.textMedium,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final session = items[index];
                          final active = session.id == widget.activeSessionId;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                widget.onSelectSession?.call(session.id);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppTheme.skyBlueLight
                                            .withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        active
                                            ? Icons.chat_bubble_rounded
                                            : Icons.chat_bubble_outline_rounded,
                                        color: AppTheme.primaryColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            session.title?.trim().isNotEmpty ==
                                                    true
                                                ? session.title!
                                                : copy.heroQuestion,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: AppTheme.textDark,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            _subtitle(session),
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: AppTheme.textMedium,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
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
