import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/booking/services/recurring_session_service.dart';

class TutorStudentsScreen extends StatefulWidget {
  const TutorStudentsScreen({Key? key}) : super(key: key);

  @override
  State<TutorStudentsScreen> createState() => _TutorStudentsScreenState();
}

class _TutorStudentsScreenState extends State<TutorStudentsScreen> {
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      // Fetch active recurring sessions (each represents a student)
      final sessions = await RecurringSessionService.getTutorRecurringSessions(
        status: 'active',
      );

      // Group by student and get unique students
      final Map<String, Map<String, dynamic>> uniqueStudents = {};
      
      for (final session in sessions) {
        final studentId = session['student_id'] as String;
        if (!uniqueStudents.containsKey(studentId)) {
          uniqueStudents[studentId] = {
            'student_id': studentId,
            'student_name': session['student_name'],
            'student_avatar_url': session['student_avatar_url'],
            'student_type': session['student_type'],
            'sessions': <Map<String, dynamic>>[],
            'total_sessions_completed': 0,
            'total_revenue': 0.0,
          };
        }
        
        // Add session to student's sessions list
        uniqueStudents[studentId]!['sessions']!.add(session);
        
        // Accumulate stats
        final currentTotal = uniqueStudents[studentId]!['total_sessions_completed'] as int;
        final sessionTotal = session['total_sessions_completed'] as int? ?? 0;
        uniqueStudents[studentId]!['total_sessions_completed'] = currentTotal + sessionTotal;
        
        final currentRevenue = uniqueStudents[studentId]!['total_revenue'] as double;
        final sessionRevenue = (session['total_revenue'] as num?)?.toDouble() ?? 0.0;
        uniqueStudents[studentId]!['total_revenue'] = currentRevenue + sessionRevenue;
      }

      setState(() {
        _students = uniqueStudents.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading students: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load students: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false, // No back button in bottom nav
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Students',
          style: GoogleFonts.poppins(
            color: AppTheme.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : _students.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadStudents,
                  color: AppTheme.primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      return _buildStudentCard(_students[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 80, color: AppTheme.textLight),
          const SizedBox(height: 16),
          Text(
            'No students yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your students will appear here',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final studentName = student['student_name'] as String;
    final studentAvatar = student['student_avatar_url'] as String?;
    final studentType = student['student_type'] as String;
    final sessions = student['sessions'] as List<Map<String, dynamic>>;
    final totalSessions = student['total_sessions_completed'] as int;
    final totalRevenue = student['total_revenue'] as double;
    
    // Get next session info
    final nextSession = _getNextSession(sessions);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showStudentDetails(student),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Student info
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    backgroundImage: studentAvatar != null
                        ? CachedNetworkImageProvider(studentAvatar)
                        : null,
                    child: studentAvatar == null
                        ? Text(
                            studentName[0].toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 20,
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
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          studentType == 'learner' ? 'Student' : 'Parent',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      Icons.event,
                      '$totalSessions',
                      'Sessions',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: _buildStatItem(
                      Icons.attach_money,
                      _formatCurrency(totalRevenue),
                      'Revenue',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: _buildStatItem(
                      Icons.book,
                      '${sessions.length}',
                      'Subjects',
                    ),
                  ),
                ],
              ),
              // Next Session (if available)
              if (nextSession != null) ...[
                const SizedBox(height: 16),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Next Session',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppTheme.textMedium,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nextSession,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
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

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppTheme.textMedium,
          ),
        ),
      ],
    );
  }

  String? _getNextSession(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return null;
    
    // Get the first active session and calculate next occurrence
    final session = sessions.first;
    final days = List<String>.from(session['days'] as List);
    final times = Map<String, String>.from(session['times'] as Map);
    
    if (days.isEmpty || times.isEmpty) return null;
    
    final now = DateTime.now();
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    for (int i = 0; i < 7; i++) {
      final checkDate = now.add(Duration(days: i));
      final dayName = dayNames[checkDate.weekday - 1];
      
      if (days.contains(dayName) && times.containsKey(dayName)) {
        return '${DateFormat('EEE, MMM d').format(checkDate)} at ${times[dayName]}';
      }
    }
    
    return null;
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0)} XAF';
  }

  void _showStudentDetails(Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _StudentDetailsSheet(student: student),
    );
  }
}

// Student Details Sheet
class _StudentDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> student;

  const _StudentDetailsSheet({required this.student});

  @override
  Widget build(BuildContext context) {
    final sessions = student['sessions'] as List<Map<String, dynamic>>;
    final totalSessions = student['total_sessions_completed'] as int;
    final totalRevenue = student['total_revenue'] as double;

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
                'Student Details',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              // Student Info
              _buildDetailSection('Name', student['student_name'] as String),
              _buildDetailSection('Type', student['student_type'] == 'learner' ? 'Student' : 'Parent'),
              _buildDetailSection('Total Sessions', '$totalSessions completed'),
              _buildDetailSection('Total Revenue', _formatCurrency(totalRevenue)),
              _buildDetailSection('Active Sessions', '${sessions.length}'),
              const SizedBox(height: 16),
              // Session List
              Text(
                'Active Sessions',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...sessions.map((session) => _buildSessionItem(session)),
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
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(Map<String, dynamic> session) {
    final days = List<String>.from(session['days'] as List);
    final times = Map<String, String>.from(session['times'] as Map);
    final frequency = session['frequency'] as int;
    final location = session['location'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$frequency sessions per week',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Days: ${days.join(', ')}',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          Text(
            'Times: ${times.values.join(', ')}',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          Text(
            'Location: ${location == 'online' ? 'Online' : location}',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0)} XAF';
  }
}
