import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/booking/services/recurring_session_service.dart';
import '../../../features/booking/services/individual_session_service.dart';
import '../../../features/booking/services/session_lifecycle_service.dart';

class TutorSessionsScreen extends StatefulWidget {
  const TutorSessionsScreen({Key? key}) : super(key: key);

  @override
  State<TutorSessionsScreen> createState() => _TutorSessionsScreenState();
}

class _TutorSessionsScreenState extends State<TutorSessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  final Map<String, bool> _sessionLoadingStates = {};
  String _selectedFilter = 'all'; // all, upcoming, past

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      // Try to load individual sessions first (more specific)
      List<Map<String, dynamic>> individualSessions = [];
      try {
        if (_selectedFilter == 'upcoming' || _selectedFilter == 'all') {
          individualSessions =
              await IndividualSessionService.getTutorUpcomingSessions(
                limit: 50,
              );
        }
        if (_selectedFilter == 'past' || _selectedFilter == 'all') {
          final pastSessions =
              await IndividualSessionService.getTutorPastSessions(limit: 50);
          if (_selectedFilter == 'all') {
            individualSessions.addAll(pastSessions);
          } else {
            individualSessions = pastSessions;
          }
        }
      } catch (e) {
        print(
          '⚠️ Could not load individual sessions, falling back to recurring: $e',
        );
      }

      // If we have individual sessions, use them; otherwise fall back to recurring
      if (individualSessions.isNotEmpty) {
        final now = DateTime.now();
        List<Map<String, dynamic>> filtered = individualSessions;

        if (_selectedFilter == 'upcoming') {
          filtered = individualSessions.where((s) {
            final scheduledDate = DateTime.parse(s['scheduled_date'] as String);
            final status = s['status'] as String;
            return scheduledDate.isAfter(now) &&
                (status == 'scheduled' || status == 'in_progress');
          }).toList();
        } else if (_selectedFilter == 'past') {
          filtered = individualSessions.where((s) {
            final scheduledDate = DateTime.parse(s['scheduled_date'] as String);
            final status = s['status'] as String;
            return scheduledDate.isBefore(now) ||
                status == 'completed' ||
                status == 'cancelled';
          }).toList();
        }

        // Sort by scheduled date
        filtered.sort((a, b) {
          final aDate = DateTime.parse(a['scheduled_date'] as String);
          final bDate = DateTime.parse(b['scheduled_date'] as String);
          if (_selectedFilter == 'upcoming' || _selectedFilter == 'all') {
            return aDate.compareTo(bDate); // Upcoming: earliest first
          } else {
            return bDate.compareTo(aDate); // Past: latest first
          }
        });

        setState(() {
          _sessions = filtered;
          _isLoading = false;
        });
        return;
      }

      // Fallback to recurring sessions
      final sessions = await RecurringSessionService.getTutorRecurringSessions(
        status: _selectedFilter == 'all' ? null : _selectedFilter,
      );

      // Filter for upcoming/past if needed
      final now = DateTime.now();
      List<Map<String, dynamic>> filtered = sessions;

      if (_selectedFilter == 'upcoming') {
        filtered = sessions.where((s) {
          final startDate = DateTime.parse(s['start_date'] as String);
          return startDate.isAfter(now) && s['status'] == 'active';
        }).toList();
      } else if (_selectedFilter == 'past') {
        filtered = sessions.where((s) {
          final startDate = DateTime.parse(s['start_date'] as String);
          return startDate.isBefore(now) || s['status'] == 'completed';
        }).toList();
      } else if (_selectedFilter == 'all') {
        // Sort by priority: upcoming first, then active, then past
        filtered.sort((a, b) {
          final aDate = DateTime.parse(a['start_date'] as String);
          final bDate = DateTime.parse(b['start_date'] as String);
          final aStatus = a['status'] as String;
          final bStatus = b['status'] as String;

          // Upcoming (active and future date) first
          final aIsUpcoming = aDate.isAfter(now) && aStatus == 'active';
          final bIsUpcoming = bDate.isAfter(now) && bStatus == 'active';
          if (aIsUpcoming && !bIsUpcoming) return -1;
          if (!aIsUpcoming && bIsUpcoming) return 1;

          // Then active (current or past start but still active)
          if (aStatus == 'active' && bStatus != 'active') return -1;
          if (aStatus != 'active' && bStatus == 'active') return 1;

          // Then by date (earliest first for upcoming, latest first for past)
          if (aIsUpcoming || bIsUpcoming) {
            return aDate.compareTo(bDate); // Upcoming: earliest first
          } else {
            return bDate.compareTo(aDate); // Past: latest first
          }
        });
      }

      setState(() {
        _sessions = filtered;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading sessions: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sessions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // No back button in bottom nav
        title: Text(
          'Sessions',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips (like notification screen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildFilterChip('all', 'All (${_getCountForFilter('all')})'),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'upcoming',
                    'Upcoming (${_getCountForFilter('upcoming')})',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'past',
                    'Past (${_getCountForFilter('past')})',
                  ),
                ],
              ),
            ),
          ),
          // Sessions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sessions.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadSessions,
                    color: AppTheme.primaryColor,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        return _buildSessionCard(_sessions[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
        });
        _loadSessions();
      },
      selectedColor: AppTheme.primaryColor, // Deep blue background
      checkmarkColor: Colors.white,
      labelStyle: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        color: isSelected
            ? Colors.white
            : AppTheme.textDark, // White text on selected
      ),
    );
  }

  int _getCountForFilter(String filter) {
    if (filter == 'all') {
      return _sessions.length;
    } else if (filter == 'upcoming') {
      final now = DateTime.now();
      return _sessions.where((s) {
        final isIndividual = s.containsKey('scheduled_date');
        if (isIndividual) {
          final scheduledDate = DateTime.parse(s['scheduled_date'] as String);
          final status = s['status'] as String;
          return scheduledDate.isAfter(now) &&
              (status == 'scheduled' || status == 'in_progress');
        } else {
          final startDate = DateTime.parse(s['start_date'] as String);
          return startDate.isAfter(now) && s['status'] == 'active';
        }
      }).length;
    } else if (filter == 'past') {
      final now = DateTime.now();
      return _sessions.where((s) {
        final isIndividual = s.containsKey('scheduled_date');
        if (isIndividual) {
          final scheduledDate = DateTime.parse(s['scheduled_date'] as String);
          final status = s['status'] as String;
          return scheduledDate.isBefore(now) ||
              status == 'completed' ||
              status == 'cancelled';
        } else {
          final startDate = DateTime.parse(s['start_date'] as String);
          return startDate.isBefore(now) || s['status'] == 'completed';
        }
      }).length;
    }
    return 0;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_outlined, size: 64, color: AppTheme.textLight),
            const SizedBox(height: 16),
            Text(
              'No sessions yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your sessions will appear here',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textMedium,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    // Detect if this is an individual session or recurring session
    final isIndividualSession =
        session.containsKey('scheduled_date') &&
        session.containsKey('scheduled_time');

    final status = session['status'] as String;
    String studentName = 'Student';
    String? studentAvatar;
    String location = 'online';
    String? address;
    DateTime? sessionDate;
    String? sessionTime;
    String? subject;
    int? frequency;
    int totalSessions = 0;
    List<String> days = [];
    Map<String, String> times = {};
    DateTime? startDate;

    if (isIndividualSession) {
      // Individual session data
      final recurringData =
          session['recurring_sessions'] as Map<String, dynamic>?;
      studentName = recurringData?['student_name']?.toString() ?? 'Student';
      studentAvatar = recurringData?['student_avatar_url']?.toString();
      location = session['location'] as String? ?? 'online';
      address = session['onsite_address'] as String?;
      subject = session['subject'] as String?;
      sessionDate = DateTime.parse(session['scheduled_date'] as String);
      sessionTime = session['scheduled_time'] as String?;

      // Get recurring session info if available
      if (recurringData != null) {
        frequency = recurringData['frequency'] as int?;
        totalSessions = recurringData['total_sessions_completed'] as int? ?? 0;
        days = List<String>.from(recurringData['days'] as List? ?? []);
        times = Map<String, String>.from(recurringData['times'] as Map? ?? {});
        if (recurringData['start_date'] != null) {
          startDate = DateTime.parse(recurringData['start_date'] as String);
        }
      }
    } else {
      // Recurring session data
      studentName = session['student_name'] as String? ?? 'Student';
      studentAvatar = session['student_avatar_url'] as String?;
      location = session['location'] as String? ?? 'online';
      address = session['address'] as String?;
      frequency = session['frequency'] as int?;
      totalSessions = session['total_sessions_completed'] as int? ?? 0;
      days = List<String>.from(session['days'] as List? ?? []);
      times = Map<String, String>.from(session['times'] as Map? ?? {});
      if (session['start_date'] != null) {
        startDate = DateTime.parse(session['start_date'] as String);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(status).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showSessionDetails(session),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Student info + Status
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    backgroundImage: studentAvatar != null
                        ? CachedNetworkImageProvider(studentAvatar)
                        : null,
                    child: studentAvatar == null
                        ? Text(
                            studentName[0].toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          isIndividualSession
                              ? (subject ?? 'Session') +
                                    (sessionDate != null
                                        ? ' • ${_formatDate(sessionDate)}'
                                        : '')
                              : '${frequency ?? 0}x per week • $totalSessions sessions completed',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Schedule Info - Different for individual vs recurring
              if (isIndividualSession) ...[
                // Individual session info
                if (sessionDate != null)
                  _buildInfoRow(Icons.calendar_today, _formatDate(sessionDate)),
                if (sessionTime != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.access_time, sessionTime),
                ],
                if (subject != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.book_outlined, subject),
                ],
              ] else ...[
                // Recurring session info
                if (days.isNotEmpty)
                  _buildInfoRow(Icons.calendar_today, days.join(', ')),
                if (times.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.access_time, times.values.join(', ')),
                ],
                if (startDate != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.trending_up,
                    'Started ${_formatDate(startDate)}',
                  ),
                ],
              ],
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.location_on,
                _formatLocation(location, address),
              ),
              // Action buttons for individual sessions
              if (isIndividualSession &&
                  (status == 'scheduled' || status == 'in_progress')) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (status == 'scheduled') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_sessionLoadingStates[session['id'] as String] ?? false)
                              ? null
                              : () => _handleStartSession(session['id'] as String),
                          icon: (_sessionLoadingStates[session['id'] as String] ?? false)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.play_arrow, size: 18),
                          label: Text(
                            (_sessionLoadingStates[session['id'] as String] ?? false)
                                ? 'Starting...'
                                : 'Start Session',
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ] else if (status == 'in_progress') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_sessionLoadingStates[session['id'] as String] ?? false)
                              ? null
                              : () => _handleEndSession(session['id'] as String),
                          icon: (_sessionLoadingStates[session['id'] as String] ?? false)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.stop, size: 18),
                          label: Text(
                            (_sessionLoadingStates[session['id'] as String] ?? false)
                                ? 'Ending...'
                                : 'End Session',
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (session['meeting_link'] != null &&
                        location == 'online') ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _openMeetLink(session['meeting_link'] as String),
                        icon: const Icon(Icons.video_call, size: 18),
                        label: Text(
                          'Join',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(color: AppTheme.primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              // Next Session (if active recurring session)
              if (!isIndividualSession &&
                  status == 'active' &&
                  days.isNotEmpty &&
                  times.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Next session: ${_getNextSessionDate(days, times)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textMedium),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textDark),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
      case 'in_progress':
        return AppTheme.accentGreen;
      case 'scheduled':
        return Colors.blue;
      case 'paused':
        return Colors.orange;
      case 'completed':
        return AppTheme.textMedium;
      case 'cancelled':
        return Colors.red;
      default:
        return AppTheme.textMedium;
    }
  }

  Future<void> _handleStartSession(String sessionId) async {
    setState(() {
      _sessionLoadingStates[sessionId] = true;
    });
    
    try {
      // Use SessionLifecycleService for comprehensive start flow
      await SessionLifecycleService.startSession(sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Session started', style: GoogleFonts.poppins()),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
      _loadSessions(); // Refresh
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sessionLoadingStates[sessionId] = false;
        });
      }
    }
  }

  Future<void> _handleEndSession(String sessionId) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EndSessionDialog(),
    );

    if (result != null) {
      setState(() {
        _sessionLoadingStates[sessionId] = true;
      });
      
      try {
        // Use SessionLifecycleService for comprehensive end flow
        await SessionLifecycleService.endSession(
          sessionId,
          tutorNotes: result['notes'] as String?,
          progressNotes: result['progressNotes'] as String?,
          homeworkAssigned: result['homework'] as String?,
          nextFocusAreas: result['nextFocus'] as String?,
          studentEngagement: result['engagement'] as int?,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Session ended', style: GoogleFonts.poppins()),
                ],
              ),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
        _loadSessions(); // Refresh
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to end session: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _sessionLoadingStates[sessionId] = false;
          });
        }
      }
    }
  }

  Future<void> _openMeetLink(String meetLink) async {
    try {
      final uri = Uri.parse(meetLink);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open Meet link'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error opening Meet link: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening Meet link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatLocation(String location, String? address) {
    switch (location) {
      case 'online':
        return 'Online';
      case 'onsite':
        return address ?? 'Onsite';
      case 'hybrid':
        return 'Hybrid ${address != null ? '($address)' : ''}';
      default:
        return location;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  String _getNextSessionDate(List<String> days, Map<String, String> times) {
    // Calculate next session date based on days and times
    final now = DateTime.now();
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    for (int i = 0; i < 7; i++) {
      final checkDate = now.add(Duration(days: i));
      final dayName = dayNames[checkDate.weekday - 1];

      if (days.contains(dayName) && times.containsKey(dayName)) {
        return '${DateFormat('EEE, MMM d').format(checkDate)} at ${times[dayName]}';
      }
    }

    return 'Check schedule';
  }

  void _showSessionDetails(Map<String, dynamic> session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SessionDetailsSheet(session: session),
    );
  }
}

// End Session Dialog
class _EndSessionDialog extends StatefulWidget {
  @override
  State<_EndSessionDialog> createState() => _EndSessionDialogState();
}

class _EndSessionDialogState extends State<_EndSessionDialog> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('End Session', style: GoogleFonts.poppins()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add optional notes about this session:',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'E.g., "Great progress on algebra today!"',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'notes': _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            });
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text('End Session', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}

// Session Details Sheet
class _SessionDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> session;

  const _SessionDetailsSheet({required this.session});

  @override
  Widget build(BuildContext context) {
    final isIndividualSession =
        session.containsKey('scheduled_date') &&
        session.containsKey('scheduled_time');

    String studentName = 'Student';
    String location = 'online';
    String? address;
    DateTime? sessionDate;
    String? sessionTime;
    String? subject;
    int? frequency;
    int totalSessions = 0;
    List<String> days = [];
    Map<String, String> times = {};
    DateTime? startDate;
    double? monthlyTotal;
    String? paymentPlan;

    if (isIndividualSession) {
      final recurringData =
          session['recurring_sessions'] as Map<String, dynamic>?;
      studentName = recurringData?['student_name']?.toString() ?? 'Student';
      location = session['location'] as String? ?? 'online';
      address = session['onsite_address'] as String?;
      subject = session['subject'] as String?;
      sessionDate = DateTime.parse(session['scheduled_date'] as String);
      sessionTime = session['scheduled_time'] as String?;

      if (recurringData != null) {
        frequency = recurringData['frequency'] as int?;
        totalSessions = recurringData['total_sessions_completed'] as int? ?? 0;
        days = List<String>.from(recurringData['days'] as List? ?? []);
        times = Map<String, String>.from(recurringData['times'] as Map? ?? {});
        monthlyTotal = (recurringData['monthly_total'] as num?)?.toDouble();
        paymentPlan = recurringData['payment_plan'] as String?;
        if (recurringData['start_date'] != null) {
          startDate = DateTime.parse(recurringData['start_date'] as String);
        }
      }
    } else {
      studentName = session['student_name'] as String? ?? 'Student';
      location = session['location'] as String? ?? 'online';
      address = session['address'] as String?;
      frequency = session['frequency'] as int?;
      totalSessions = session['total_sessions_completed'] as int? ?? 0;
      days = List<String>.from(session['days'] as List? ?? []);
      times = Map<String, String>.from(session['times'] as Map? ?? {});
      monthlyTotal = (session['monthly_total'] as num?)?.toDouble();
      paymentPlan = session['payment_plan'] as String?;
      if (session['start_date'] != null) {
        startDate = DateTime.parse(session['start_date'] as String);
      }
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                'Session Details',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              // Details
              _buildDetailSection('Student', studentName),
              if (isIndividualSession) ...[
                if (subject != null) _buildDetailSection('Subject', subject),
                if (sessionDate != null)
                  _buildDetailSection(
                    'Date',
                    DateFormat('MMM d, y').format(sessionDate),
                  ),
                if (sessionTime != null)
                  _buildDetailSection('Time', sessionTime),
              ] else ...[
                if (frequency != null)
                  _buildDetailSection(
                    'Frequency',
                    '$frequency sessions per week',
                  ),
                if (days.isNotEmpty)
                  _buildDetailSection('Days', days.join(', ')),
                if (times.isNotEmpty)
                  _buildDetailSection('Times', times.values.join(', ')),
                if (startDate != null)
                  _buildDetailSection(
                    'Started',
                    DateFormat('MMM d, y').format(startDate),
                  ),
              ],
              _buildDetailSection('Location', location),
              if (address != null) _buildDetailSection('Address', address),
              if (paymentPlan != null && monthlyTotal != null) ...[
                _buildDetailSection(
                  'Payment Plan',
                  _formatPaymentPlan(paymentPlan),
                ),
                _buildDetailSection(
                  'Monthly Total',
                  _formatCurrency(monthlyTotal),
                ),
              ],
              if (!isIndividualSession)
                _buildDetailSection(
                  'Total Sessions',
                  '$totalSessions completed',
                ),
              _buildDetailSection(
                'Status',
                (session['status'] as String).toUpperCase(),
              ),
              if (isIndividualSession &&
                  session['meeting_link'] != null &&
                  location == 'online')
                _buildDetailSection(
                  'Meeting Link',
                  session['meeting_link'] as String,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 16, color: AppTheme.textDark),
          ),
        ],
      ),
    );
  }

  String _formatPaymentPlan(String plan) {
    switch (plan) {
      case 'monthly':
        return 'Monthly';
      case 'biweekly':
        return 'Bi-weekly';
      case 'weekly':
        return 'Weekly';
      default:
        return plan;
    }
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0)} XAF';
  }
}
