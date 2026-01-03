import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/sessions/services/location_checkin_service.dart';

/// Attendance History Screen
///
/// Displays attendance history for the current user
class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<Map<String, dynamic>> _attendanceHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
  }

  Future<void> _loadAttendanceHistory() async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final history = await LocationCheckInService.getAttendanceHistory(userId: userId);
      setState(() {
        _attendanceHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('Error loading attendance history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Attendance History',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _attendanceHistory.isEmpty
              ? Center(
                  child: Text(
                    'No attendance records found',
                    style: GoogleFonts.poppins(
                      color: AppTheme.textMedium,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _attendanceHistory.length,
                  itemBuilder: (context, index) {
                    final record = _attendanceHistory[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          record['session_id'] as String? ?? 'Unknown Session',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Checked in: ${record['check_in_time'] ?? 'N/A'}\n'
                          'Checked out: ${record['check_out_time'] ?? 'N/A'}',
                        ),
                        trailing: Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

