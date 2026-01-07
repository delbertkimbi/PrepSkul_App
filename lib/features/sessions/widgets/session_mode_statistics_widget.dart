import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';

/// Session Mode Statistics Widget
/// 
/// Displays statistics for flexible recurring sessions showing
/// breakdown of online vs onsite sessions
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
  int _onlineCount = 0;
  int _onsiteCount = 0;
  int _totalCount = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch all individual sessions for this recurring session
      final response = await SupabaseService.client
          .from('individual_sessions')
          .select('id, location')
          .eq('recurring_session_id', widget.recurringSessionId);

      if (response.isEmpty) {
        setState(() {
          _onlineCount = 0;
          _onsiteCount = 0;
          _totalCount = 0;
          _isLoading = false;
        });
        return;
      }

      int onlineCount = 0;
      int onsiteCount = 0;

      for (final session in response) {
        final location = session['location'] as String?;
        if (location == 'online') {
          onlineCount++;
        } else if (location == 'onsite') {
          onsiteCount++;
        }
        // Note: 'hybrid' is treated as a preference, not a location type
        // Individual sessions are either 'online' or 'onsite'
      }

      setState(() {
        _onlineCount = onlineCount;
        _onsiteCount = onsiteCount;
        _totalCount = onlineCount + onsiteCount;
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('[SESSION_STATS] Error loading statistics: $e');
      setState(() {
        _error = 'Failed to load statistics';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: AppTheme.softBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.softBorder),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_totalCount == 0) {
      return const SizedBox.shrink();
    }

    final onlinePercentage = _totalCount > 0 ? (_onlineCount / _totalCount) * 100 : 0.0;
    final onsitePercentage = _totalCount > 0 ? (_onsiteCount / _totalCount) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: AppTheme.softBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(
                Icons.bar_chart,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Session Mode Statistics',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Statistics Row
          Row(
            children: [
              // Online Stats
              Expanded(
                child: _buildStatCard(
                  label: 'Online',
                  count: _onlineCount,
                  percentage: onlinePercentage,
                  color: Colors.blue,
                  isCurrent: widget.currentSessionLocation == 'online',
                ),
              ),
              const SizedBox(width: 12),
              // Onsite Stats
              Expanded(
                child: _buildStatCard(
                  label: 'Onsite',
                  count: _onsiteCount,
                  percentage: onsitePercentage,
                  color: Colors.green,
                  isCurrent: widget.currentSessionLocation == 'onsite',
                ),
              ),
            ],
          ),
          
          // Progress Bar
          const SizedBox(height: 12),
          _buildProgressBar(
            onlinePercentage: onlinePercentage,
            onsitePercentage: onsitePercentage,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required int count,
    required double percentage,
    required Color color,
    required bool isCurrent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? color.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent ? color : AppTheme.softBorder,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMedium,
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
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar({
    required double onlinePercentage,
    required double onsitePercentage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total Sessions: $_totalCount',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppTheme.textMedium,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (onlinePercentage > 0)
                  Expanded(
                    flex: onlinePercentage.round(),
                    child: Container(
                      color: Colors.blue,
                    ),
                  ),
                if (onsitePercentage > 0)
                  Expanded(
                    flex: onsitePercentage.round(),
                    child: Container(
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
