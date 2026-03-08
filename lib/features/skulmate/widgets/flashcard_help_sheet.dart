import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/discovery/widgets/youtube_video_player.dart';
import '../services/skulmate_service.dart';

/// Bottom sheet showing AI explanation and optional YouTube recommendations for a flashcard
class FlashcardHelpSheet extends StatefulWidget {
  final String term;
  final String definition;

  const FlashcardHelpSheet({
    Key? key,
    required this.term,
    required this.definition,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required String term,
    required String definition,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FlashcardHelpSheet(
          term: term,
          definition: definition,
        ),
      ),
    );
  }

  @override
  State<FlashcardHelpSheet> createState() => _FlashcardHelpSheetState();
}

class _FlashcardHelpSheetState extends State<FlashcardHelpSheet> {
  ExplainResult? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await SkulMateService.explainFlashcard(
        term: widget.term,
        definition: widget.definition,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _error = msg.contains('Failed to get explanation') || msg.contains('Empty response')
              ? 'Explanation unavailable. The service may be busy—please try again in a moment.'
              : msg;
          _loading = false;
        });
      }
    }
  }

  void _openVideo(String videoId) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: YoutubeVideoPlayer(videoId: videoId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'Learn more about ${widget.term}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Flexible(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryColor),
              SizedBox(height: 16),
              Text('Getting explanation...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.poppins(color: AppTheme.textMedium),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final result = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result.explanation,
            style: GoogleFonts.poppins(
              fontSize: 15,
              height: 1.6,
              color: AppTheme.textDark,
            ),
          ),
          if (result.videos.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Watch to understand',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            ...result.videos.map((v) => _VideoCard(
                  video: v,
                  onTap: () => _openVideo(v.videoId),
                )),
          ],
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final ExplainVideo video;
  final VoidCallback onTap;

  const _VideoCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: CachedNetworkImage(
                imageUrl: video.thumbnailUrl,
                width: 120,
                height: 68,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 120,
                  height: 68,
                  color: Colors.grey[300],
                  child: const Icon(Icons.video_library),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 120,
                  height: 68,
                  color: Colors.grey[300],
                  child: const Icon(Icons.video_library),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.play_circle_filled,
                            size: 18, color: AppTheme.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          'Watch',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
