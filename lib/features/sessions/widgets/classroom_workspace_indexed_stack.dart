import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:prepskul/core/services/storage_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/sessions/domain/workspace_sync_state.dart';
import 'package:prepskul/features/sessions/widgets/collaborative_whiteboard.dart';
import 'package:prepskul/features/sessions/widgets/session_materials_pdf_panel.dart';

/// Central workspace band: keeps **board / materials / notes** widgets mounted so switching
/// tools does not reset scroll-local state (`IndexedStack` + one [ScrollController] per surface).
class ClassroomWorkspaceIndexedStack extends StatelessWidget {
  const ClassroomWorkspaceIndexedStack({
    super.key,
    required this.workspace,
    required this.userRole,
    this.publishPacket,
    this.sessionIdForMaterialsUpload,
  });

  final WorkspaceViewState workspace;

  /// Tutor + realtime: publish workspace packets (learners pass null).
  final Future<void> Function(WorkspacePacket packet)? publishPacket;

  /// `'tutor'` or `'learner'`
  final String userRole;

  /// Session id segment for Supabase Storage paths (`session_materials_<id>`).
  final String? sessionIdForMaterialsUpload;

  @override
  Widget build(BuildContext context) {
    final index = WorkspaceSurface.values
        .indexOf(workspace.surface)
        .clamp(0, WorkspaceSurface.values.length - 1);
    return IndexedStack(
      index: index,
      sizing: StackFit.expand,
      children: [
        for (final surface in WorkspaceSurface.values)
          _SurfaceScrollWorkspace(
            surface: surface,
            workspace: workspace,
            publishPacket: publishPacket,
            userRole: userRole,
            sessionIdForMaterialsUpload: sessionIdForMaterialsUpload,
          ),
      ],
    );
  }
}

IconData _iconFor(WorkspaceSurface surface) {
  switch (surface) {
    case WorkspaceSurface.launcher:
      return Icons.dashboard_rounded;
    case WorkspaceSurface.whiteboard:
      return Icons.gesture_rounded;
    case WorkspaceSurface.pdfDocument:
      return Icons.picture_as_pdf_rounded;
    case WorkspaceSurface.lessonNotes:
      return Icons.note_alt_rounded;
  }
}

String _labelFor(WorkspaceSurface surface) {
  switch (surface) {
    case WorkspaceSurface.launcher:
      return 'Teaching tools';
    case WorkspaceSurface.whiteboard:
      return 'Board';
    case WorkspaceSurface.pdfDocument:
      return 'Materials';
    case WorkspaceSurface.lessonNotes:
      return 'Notes';
  }
}

class _SurfaceScrollWorkspace extends StatefulWidget {
  const _SurfaceScrollWorkspace({
    required this.surface,
    required this.workspace,
    required this.userRole,
    this.publishPacket,
    this.sessionIdForMaterialsUpload,
  });

  final WorkspaceSurface surface;
  final WorkspaceViewState workspace;
  final Future<void> Function(WorkspacePacket packet)? publishPacket;
  final String userRole;
  final String? sessionIdForMaterialsUpload;

  @override
  State<_SurfaceScrollWorkspace> createState() =>
      _SurfaceScrollWorkspaceState();
}

class _SurfaceScrollWorkspaceState extends State<_SurfaceScrollWorkspace> {
  final ScrollController _scroll = ScrollController();
  Timer? _scrollPublishDebounce;
  Timer? _slidePublishDebounce;
  bool _applyingRemoteScroll = false;
  double? _lastPublishedOffsetNorm;
  bool _pdfMaterialsActivated = false;

  bool get _canPublishScroll =>
      widget.userRole == 'tutor' && widget.publishPacket != null;

  /// Remote `SCROLL_TO` packets should only drive the learner UI — tutors keep local scroll.
  bool get _followRemoteScroll => widget.userRole == 'learner';

  @override
  void initState() {
    super.initState();
    _pdfMaterialsActivated =
        widget.surface == WorkspaceSurface.pdfDocument &&
        widget.workspace.surface == WorkspaceSurface.pdfDocument;
    _scroll.addListener(_onLocalScrollChanged);
    if (_followRemoteScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyRemoteScrollFromState();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _SurfaceScrollWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pdfActive =
        widget.surface == WorkspaceSurface.pdfDocument &&
        widget.workspace.surface == WorkspaceSurface.pdfDocument;
    if (pdfActive && !_pdfMaterialsActivated) {
      setState(() => _pdfMaterialsActivated = true);
    }
    if (!_followRemoteScroll) return;
    final scrollStateChanged =
        oldWidget.workspace.scrollOffsetNormalized !=
            widget.workspace.scrollOffsetNormalized ||
        oldWidget.workspace.pdfPageIndex != widget.workspace.pdfPageIndex ||
        oldWidget.workspace.revision != widget.workspace.revision;
    if (!scrollStateChanged) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyRemoteScrollFromState();
    });
  }

  @override
  void dispose() {
    _scrollPublishDebounce?.cancel();
    _slidePublishDebounce?.cancel();
    _scroll.removeListener(_onLocalScrollChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _debouncedPublishSlideIndex(int index) {
    _slidePublishDebounce?.cancel();
    _slidePublishDebounce = Timer(const Duration(milliseconds: 160), () async {
      if (!mounted || widget.publishPacket == null) return;
      await widget.publishPacket!(SlideIndexPacket(index: index));
    });
  }

  Future<void> _pickAndUploadPdf(BuildContext context) async {
    final uid = SupabaseService.client.auth.currentUser?.id;
    final sid = widget.sessionIdForMaterialsUpload;
    if (widget.publishPacket == null) return;
    if (uid == null || sid == null || sid.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload requires an active session and sign-in.'),
          ),
        );
      }
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (kIsWeb) {
        if (file.bytes == null) {
          throw Exception('Could not read PDF bytes on this platform.');
        }
      } else {
        if (file.path == null || file.path!.isEmpty) {
          throw Exception('Could not read PDF file path.');
        }
      }

      final url = await StorageService.uploadDocument(
        userId: uid,
        documentFile: file,
        documentType: 'session_materials_$sid',
      );
      await widget.publishPacket!(SetMaterialsPdfUrlPacket(url: url));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lesson PDF attached.')));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not upload PDF: $e')));
      }
    }
  }

  Future<void> _clearMaterialsPdf() async {
    if (widget.publishPacket == null) return;
    await widget.publishPacket!(SetMaterialsPdfUrlPacket(url: ''));
  }

  void _onLocalScrollChanged() {
    if (!_canPublishScroll || _applyingRemoteScroll) return;
    _scrollPublishDebounce?.cancel();
    _scrollPublishDebounce = Timer(const Duration(milliseconds: 180), () async {
      if (!mounted || !_canPublishScroll || !_scroll.hasClients) return;
      final maxExtent = _scroll.position.maxScrollExtent;
      final norm = maxExtent <= 0
          ? 0.0
          : (_scroll.offset / maxExtent).clamp(0.0, 1.0);
      final prev = _lastPublishedOffsetNorm;
      if (prev != null && (norm - prev).abs() < 0.015) return;
      _lastPublishedOffsetNorm = norm;
      await widget.publishPacket!(
        ScrollToPacket(
          page: widget.workspace.pdfPageIndex,
          offsetNormalized: norm,
        ),
      );
    });
  }

  void _applyRemoteScrollFromState() {
    if (!mounted || !_scroll.hasClients || !_followRemoteScroll) return;
    final maxExtent = _scroll.position.maxScrollExtent;
    final target =
        (widget.workspace.scrollOffsetNormalized.clamp(0.0, 1.0) * maxExtent)
            .clamp(0.0, maxExtent);
    if ((_scroll.offset - target).abs() < 6.0) return;
    _applyingRemoteScroll = true;
    _scroll
        .animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        )
        .whenComplete(() {
          _applyingRemoteScroll = false;
        });
  }

  Future<void> _pickSurface(WorkspaceSurface surface) async {
    if (widget.publishPacket == null) return;
    await widget.publishPacket!(ToolChangePacket(surface: surface));
  }

  Widget _launcherToolTile(WorkspaceSurface surface) {
    final active = widget.workspace.surface == surface;
    final interactive = widget.publishPacket != null;
    return Material(
      color: Colors.white.withOpacity(
        interactive ? (active ? 0.11 : 0.06) : 0.04,
      ),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: interactive ? () => _pickSurface(surface) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                _iconFor(surface),
                color: Colors.white.withOpacity(
                  interactive ? (active ? 0.96 : 0.88) : 0.52,
                ),
                size: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _labelFor(surface),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(
                          interactive ? (active ? 0.98 : 0.94) : 0.65,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      surface == WorkspaceSurface.whiteboard
                          ? 'Draw and explain live'
                          : surface == WorkspaceSurface.pdfDocument
                          ? 'Lesson PDF with shared page sync'
                          : 'Lesson scratchpad',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(
                          interactive ? (active ? 0.64 : 0.52) : 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                active
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: interactive
                    ? (active
                          ? Colors.white.withOpacity(0.90)
                          : Colors.white.withOpacity(0.45))
                    : Colors.white.withOpacity(0.28),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLauncher(BuildContext context) {
    final mq = MediaQuery.of(context);
    final short = mq.size.height < 760;
    final spacing = short ? 8.0 : 10.0;
    final tutorHint =
        'Choose what to share — your learner sees it when you select a tool.';
    final learnerHint = 'Your tutor will choose board, materials, or notes.';
    final tiles = <WorkspaceSurface>[
      WorkspaceSurface.whiteboard,
      WorkspaceSurface.pdfDocument,
      WorkspaceSurface.lessonNotes,
    ];
    return Scrollbar(
      controller: _scroll,
      thumbVisibility: false,
      radius: const Radius.circular(10),
      child: SingleChildScrollView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(16, short ? 8 : 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.userRole == 'tutor' ? tutorHint : learnerHint,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.35,
                color: Colors.white.withOpacity(0.72),
              ),
            ),
            if (widget.publishPacket == null) ...[
              const SizedBox(height: 8),
              Text(
                'Only your tutor can switch tools in this view.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
            SizedBox(height: short ? 12 : 18),
            for (final s in tiles) ...[
              _launcherToolTile(s),
              SizedBox(height: spacing),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsEmpty(BuildContext context) {
    final canPick =
        widget.userRole == 'tutor' &&
        widget.publishPacket != null &&
        widget.sessionIdForMaterialsUpload != null &&
        widget.sessionIdForMaterialsUpload!.isNotEmpty;

    return SingleChildScrollView(
      key: const ValueKey<String>('ws_materials_empty'),
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.picture_as_pdf_rounded,
            size: 44,
            color: Colors.white.withOpacity(0.42),
          ),
          const SizedBox(height: 14),
          Text(
            'Materials',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.userRole == 'tutor'
                ? 'Share one lesson PDF for both of you. Page changes sync while you are on Materials.'
                : 'Your tutor hasn’t shared a document yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.4,
              color: Colors.white.withOpacity(0.58),
            ),
          ),
          if (widget.userRole == 'tutor' && widget.publishPacket != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: canPick ? () => _pickAndUploadPdf(context) : null,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Choose PDF'),
            ),
            if (!canPick)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Upload needs a live session link — try again after joining.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    height: 1.35,
                    color: Colors.white.withOpacity(0.45),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 10),
          Text(
            'Slide ${widget.workspace.pdfPageIndex + 1}',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withOpacity(0.42),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsDeferredPlaceholder() {
    return Center(
      key: const ValueKey<String>('ws_materials_pdf_deferred'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_rounded,
              size: 48,
              color: Colors.white.withOpacity(0.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Lesson PDF is ready',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.88),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.userRole == 'tutor'
                  ? 'Stay on Materials to load and drive the shared PDF.'
                  : 'Your tutor will open Materials when it is time to review the document.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.4,
                color: Colors.white.withOpacity(0.58),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsPdfShell(BuildContext context, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.white.withOpacity(0.75),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Page ${widget.workspace.pdfPageIndex + 1}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
              if (_canPublishScroll) ...[
                TextButton(
                  onPressed: () => _pickAndUploadPdf(context),
                  child: const Text('Replace'),
                ),
                TextButton(
                  onPressed: _clearMaterialsPdf,
                  child: Text(
                    'Remove',
                    style: TextStyle(color: Colors.red.withOpacity(0.88)),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: SessionMaterialsPdfPanel(
            pdfUrl: url,
            pdfPageIndexZeroBased: widget.workspace.pdfPageIndex,
            onTutorPageChanged: _canPublishScroll
                ? _debouncedPublishSlideIndex
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesEmpty(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey<String>('ws_notes_empty'),
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.note_alt_rounded,
            size: 44,
            color: Colors.white.withOpacity(0.42),
          ),
          const SizedBox(height: 14),
          Text(
            'Notes',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.userRole == 'tutor'
                ? 'Shared lesson notes will appear here. Typed collaboration is planned; use board or chat for now.'
                : 'Notes from your tutor will show here during the lesson.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.45,
              color: Colors.white.withOpacity(0.58),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.surface == WorkspaceSurface.launcher) {
      return _buildLauncher(context);
    }
    if (widget.surface == WorkspaceSurface.whiteboard) {
      return CollaborativeWhiteboard(
        key: const ValueKey<String>('ws_whiteboard'),
        strokes: widget.workspace.whiteboardStrokes,
        readOnly: widget.publishPacket == null,
        onPublish: widget.publishPacket,
      );
    }
    if (widget.surface == WorkspaceSurface.pdfDocument) {
      final raw = widget.workspace.materialsPdfUrl;
      final url = raw != null && raw.trim().isNotEmpty ? raw.trim() : null;

      if (url != null && _pdfMaterialsActivated) {
        return _buildMaterialsPdfShell(context, url);
      }
      if (url != null && !_pdfMaterialsActivated) {
        return _buildMaterialsDeferredPlaceholder();
      }

      return Scrollbar(
        controller: _scroll,
        thumbVisibility: false,
        radius: const Radius.circular(10),
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (ScrollMetricsNotification n) {
            if (!_followRemoteScroll) return false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _applyRemoteScrollFromState();
            });
            return false;
          },
          child: _buildMaterialsEmpty(context),
        ),
      );
    }
    return Scrollbar(
      controller: _scroll,
      thumbVisibility: false,
      radius: const Radius.circular(10),
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (ScrollMetricsNotification n) {
          if (!_followRemoteScroll) return false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _applyRemoteScrollFromState();
          });
          return false;
        },
        child: _buildNotesEmpty(context),
      ),
    );
  }
}
