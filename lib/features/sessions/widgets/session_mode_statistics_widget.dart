import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/features/sessions/services/session_mode_statistics_service.dart';

/// Session Mode Statistics Widget
///
/// Displays statistics about online vs onsite usage for flexible sessions
/// Shows counts and percentages for each mode
class SessionModeStatisticsWidget extends StatefulWidget {
  final String recurringSessionId;
  final String currentSessionLocation; // 'online' or 'onsite'

  const SessionModeStatisticsWidget({
    Key? key,
    required this.recurringSessionId,
    required this.currentSessionLocation,
  }) : super(key: key);

  @override
  State<SessionModeStatisticsWidget> createState() => _SessionModeStatisticsWidgetState();
}

class _SessionModeStatisticsWidgetState extends State<SessionModeStatisticsWidget> {
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await SessionModeStatisticsService.getModeStatistics(
        widget.recurringSessionId,
      );
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('Error loading mode statistics: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_statistics == null) {
      return const SizedBox.shrink();
    }

    final onlineCount = _statistics!['online_count'] as int? ?? 0;
    final onsiteCount = _statistics!['onsite_count'] as int? ?? 0;
    final totalCount = onlineCount + onsiteCount;

    if (totalCount == 0) {
      return const SizedBox.shrink();
    }

    final onlinePercent = (onlineCount / totalCount * 100).round();
    final onsitePercent = (onsiteCount / totalCount * 100).round();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mode Usage Statistics',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildModeCard(
                  'Online',
                  onlineCount,
                  onlinePercent,
                  Icons.video_call,
                  Colors.blue,
                  widget.currentSessionLocation == 'online',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModeCard(
                  'Onsite',
                  onsiteCount,
                  onsitePercent,
                  Icons.location_on,
                  Colors.green,
                  widget.currentSessionLocation == 'onsite',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard(
    String label,
    int count,
    int percent,
    IconData icon,
    Color color,
    bool isCurrent,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? color.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent ? color : Colors.grey.shade300,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Current',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$count sessions',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            '$percent%',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}

