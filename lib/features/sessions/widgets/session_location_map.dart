import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/sessions/services/location_checkin_service.dart';
import 'package:prepskul/features/sessions/services/session_safety_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/features/sessions/widgets/embedded_map_widget.dart';

/// Session Location Map Widget
///
/// Displays session location on a map (using native maps app)
/// Shows address, distance, and provides directions
class SessionLocationMap extends StatefulWidget {
  final String address;
  final String? coordinates; // Optional: "lat,lon" format
  final String? locationDescription; // Location notes, landmarks, directions
  final String sessionId;
  final String? currentUserId;
  final String? userType; // 'tutor' or 'student'
  final bool showCheckIn; // Whether to show check-in button
  final DateTime? scheduledDateTime; // For punctuality calculation
  final String? locationType; // 'online' or 'onsite' (hybrid is a preference only)

  const SessionLocationMap({
    Key? key,
    required this.address,
    this.coordinates,
    this.locationDescription,
    required this.sessionId,
    this.currentUserId,
    this.userType,
    this.showCheckIn = false,
    this.scheduledDateTime,
    this.locationType,
  }) : super(key: key);

  @override
  State<SessionLocationMap> createState() => _SessionLocationMapState();
}

class _SessionLocationMapState extends State<SessionLocationMap> {
  bool _isLoading = false;
  double? _distance;
  Position? _currentPosition;
  Map<String, dynamic>? _checkInStatus;
  Map<String, dynamic>? _attendanceRecord;
  bool _isCheckingOut = false;
  bool _isSharingWithEmergencyContact = false;
  bool _isPanicButtonTriggered = false;

  @override
  void initState() {
    super.initState();
    // Schedule async operations to avoid blocking widget initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.showCheckIn) {
        _loadCheckInStatus();
      }
      _calculateDistance();
    });
  }

  Future<void> _loadCheckInStatus() async {
    if (widget.currentUserId == null) return;

    try {
      final status = await LocationCheckInService.getCheckInStatus(
        sessionId: widget.sessionId,
        userId: widget.currentUserId!,
      );
      
      // Also load full attendance record for check-out and punctuality
      final attendance = await LocationCheckInService.getAttendanceRecord(
        sessionId: widget.sessionId,
        userId: widget.currentUserId!,
      );
      
      if (mounted) {
        safeSetState(() {
          _checkInStatus = status;
          _attendanceRecord = attendance;
        });
      }
    } catch (e) {
      LogService.warning('Error loading check-in status: $e');
    }
  }

  Future<void> _calculateDistance() async {
    if (widget.coordinates == null) return;

    try {
      // Parse coordinates
      final parts = widget.coordinates!.split(',');
      if (parts.length != 2) return;

      final lat = double.tryParse(parts[0].trim());
      final lon = double.tryParse(parts[1].trim());
      if (lat == null || lon == null) return;

      // Get current location
      try {
        final position = await LocationCheckInService.getCurrentLocation();
        if (mounted) {
          safeSetState(() {
            _currentPosition = position;
            _distance = LocationCheckInService.calculateDistance(
              position.latitude,
              position.longitude,
              lat,
              lon,
            );
          });
        }
      } catch (e) {
        // Location permission denied or unavailable
        LogService.warning('Could not get current location: $e');
      }
    } catch (e) {
      LogService.warning('Error calculating distance: $e');
    }
  }

  Future<void> _openInMaps() async {
    try {
      String url;
      
      if (widget.coordinates != null) {
        // Use coordinates if available
        final parts = widget.coordinates!.split(',');
        if (parts.length == 2) {
          final lat = parts[0].trim();
          final lon = parts[1].trim();
          // Try Google Maps first, fallback to Apple Maps
          url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
        } else {
          url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.address)}';
        }
      } else {
        // Use address
        url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.address)}';
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch maps');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getDirections() async {
    try {
      String url;
      
      if (widget.coordinates != null) {
        // Use coordinates for directions
        final parts = widget.coordinates!.split(',');
        if (parts.length == 2) {
          final lat = parts[0].trim();
          final lon = parts[1].trim();
          url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon';
        } else {
          url = 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(widget.address)}';
        }
      } else {
        url = 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(widget.address)}';
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch directions');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open directions. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleCheckIn() async {
    if (widget.currentUserId == null || widget.userType == null) return;

    safeSetState(() => _isLoading = true);

    try {
      final result = await LocationCheckInService.checkInToSession(
        sessionId: widget.sessionId,
        userId: widget.currentUserId!,
        userType: widget.userType!,
        sessionAddress: widget.coordinates ?? widget.address,
        verifyProximity: true,
        scheduledDateTime: widget.scheduledDateTime,
      );

      if (mounted) {
        safeSetState(() => _isLoading = false);
        
        if (result['success'] == true) {
          await _loadCheckInStatus();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] as String),
              backgroundColor: result['verified'] == true 
                  ? Colors.green 
                  : Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] as String ?? 'Check-in failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        safeSetState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking in: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleCheckOut() async {
    if (widget.currentUserId == null || widget.userType == null) return;

    safeSetState(() => _isCheckingOut = true);

    try {
      final result = await LocationCheckInService.checkOutFromSession(
        sessionId: widget.sessionId,
        userId: widget.currentUserId!,
        userType: widget.userType!,
      );

      if (mounted) {
        safeSetState(() => _isCheckingOut = false);
        
        if (result['success'] == true) {
          await _loadCheckInStatus(); // Reload to get updated record
          
          final duration = result['duration_minutes'] as int?;
          final durationText = duration != null 
              ? 'Session duration: ${duration} minutes'
              : 'Check-out successful!';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(durationText),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] as String ?? 'Check-out failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        safeSetState(() => _isCheckingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Location',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      if (_distance != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${(_distance! / 1000).toStringAsFixed(1)} km away',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Embedded Map Preview (Leaflet iframe on web, keeps users in-app)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: EmbeddedMapWidget(
              address: widget.address,
              coordinates: widget.coordinates,
              height: 200,
              showMarker: true,
              currentLocation: _currentPosition != null 
                  ? '${_currentPosition!.latitude},${_currentPosition!.longitude}'
                  : null, // Enable routing if current location available
            ),
          ),

          const SizedBox(height: 16),

          // Address
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
              widget.address,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Location Description (landmarks, directions, etc.)
                if (widget.locationDescription != null && 
                    widget.locationDescription!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location Details',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.locationDescription!,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.blue.shade800,
                                  height: 1.4,
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

          const SizedBox(height: 16),

          // Check-in status (if checked in)
          if (_checkInStatus != null && _checkInStatus!['has_checked_in'] == true) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_checkInStatus!['verified'] == true 
                      ? Colors.green 
                      : Colors.orange).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (_checkInStatus!['verified'] == true 
                        ? Colors.green 
                        : Colors.orange).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                  children: [
                    Icon(
                      _checkInStatus!['verified'] == true 
                          ? Icons.check_circle 
                          : Icons.warning,
                      color: _checkInStatus!['verified'] == true 
                          ? Colors.green 
                          : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _checkInStatus!['verified'] == true
                            ? 'Checked in and verified'
                            : 'Checked in (location not verified)',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _checkInStatus!['verified'] == true 
                              ? Colors.green.shade700 
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                      ],
                    ),
                    // Punctuality status
                    if (_attendanceRecord != null) ...[
                      const SizedBox(height: 8),
                      _buildPunctualityInfo(_attendanceRecord!),
                    ],
                    // Check-in time
                    if (_attendanceRecord?['check_in_time'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Checked in: ${_formatTime(_attendanceRecord!['check_in_time'])}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    // Check-out time (if checked out)
                    if (_attendanceRecord?['check_out_time'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.logout, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Checked out: ${_formatTime(_attendanceRecord!['check_out_time'])}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      if (_attendanceRecord?['duration_minutes'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Duration: ${_attendanceRecord!['duration_minutes']} minutes',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Check-in button (if enabled)
                if (widget.showCheckIn && 
                    widget.currentUserId != null && 
                    widget.userType != null &&
                    (_checkInStatus == null || _checkInStatus!['has_checked_in'] != true)) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleCheckIn,
                      icon: _isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(Icons.location_on, size: 18),
                      label: Text(
                        _isLoading ? 'Checking in...' : 'Check In',
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
                  const SizedBox(width: 12),
                ],
                
                // Check-out button (if checked in but not checked out)
                if (widget.showCheckIn && 
                    widget.currentUserId != null && 
                    widget.userType != null &&
                    _checkInStatus != null && 
                    _checkInStatus!['has_checked_in'] == true &&
                    _attendanceRecord != null &&
                    _attendanceRecord!['check_out_time'] == null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isCheckingOut ? null : _handleCheckOut,
                      icon: _isCheckingOut
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                              ),
                            )
                          : Icon(Icons.logout, size: 18),
                      label: Text(
                        _isCheckingOut ? 'Checking out...' : 'Check Out',
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
                  ),
                  const SizedBox(width: 12),
                ],
                
                // View on Map button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openInMaps,
                    icon: Icon(Icons.map, size: 18),
                    label: Text(
                      'View Map',
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
                ),
                
                const SizedBox(width: 12),
                
                // Get Directions button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _getDirections,
                    icon: Icon(Icons.directions, size: 18),
                    label: Text(
                      'Directions',
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
                ),
              ],
            ),
          ),

          // Safety Features (for onsite sessions)
          if (widget.showCheckIn && 
              widget.currentUserId != null &&
              widget.userType != null &&
              widget.locationType == 'onsite') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Safety Features',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Share with Emergency Contact
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSharingWithEmergencyContact
                              ? null
                              : _handleShareWithEmergencyContact,
                          icon: _isSharingWithEmergencyContact
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.blue,
                                    ),
                                  ),
                                )
                              : Icon(Icons.share_location, size: 16),
                          label: Text(
                            'Share Location',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                            side: BorderSide(color: Colors.blue.shade300!),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Panic Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isPanicButtonTriggered
                              ? null
                              : _handlePanicButton,
                          icon: Icon(
                            Icons.warning,
                            size: 16,
                            color: _isPanicButtonTriggered
                                ? Colors.grey
                                : Colors.white,
                          ),
                          label: Text(
                            'Panic Button',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isPanicButtonTriggered
                                ? Colors.grey.shade400
                                : Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _handleShareWithEmergencyContact() async {
    if (widget.currentUserId == null || widget.userType == null) return;

    safeSetState(() {
      _isSharingWithEmergencyContact = true;
    });

    try {
      final success = await SessionSafetyService.shareWithEmergencyContact(
        sessionId: widget.sessionId,
        userId: widget.currentUserId!,
        userType: widget.userType!,
      );

      if (mounted) {
        safeSetState(() {
          _isSharingWithEmergencyContact = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Location shared with emergency contact'
                  : 'Failed to share location. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        safeSetState(() {
          _isSharingWithEmergencyContact = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error sharing location: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePanicButton() async {
    if (widget.currentUserId == null || widget.userType == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Trigger Panic Button?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will notify your emergency contact and record a safety incident. Only use in genuine emergencies.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Yes, Trigger', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    safeSetState(() {
      _isPanicButtonTriggered = true;
    });

    try {
      final success = await SessionSafetyService.triggerPanicButton(
        sessionId: widget.sessionId,
        userId: widget.currentUserId!,
        userType: widget.userType!,
        reason: 'Panic button triggered by user',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Panic button triggered. Emergency contact has been notified.'
                  : 'Failed to trigger panic button. Please contact emergency services directly.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: success ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        safeSetState(() {
          _isPanicButtonTriggered = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error triggering panic button: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPunctualityInfo(Map<String, dynamic> attendance) {
    final status = attendance['punctuality_status'] as String?;
    final minutes = attendance['arrival_time_minutes'] as int?;
    
    if (status == null) return const SizedBox.shrink();
    
    Color color;
    IconData icon;
    String text;
    
    switch (status) {
      case 'on_time':
        color = Colors.green;
        icon = Icons.schedule;
        text = 'On time';
        break;
      case 'early':
        color = Colors.blue;
        icon = Icons.trending_up;
        text = minutes != null ? '${minutes.abs()} min early' : 'Early';
        break;
      case 'late':
        color = Colors.orange;
        icon = Icons.trending_down;
        text = minutes != null ? '$minutes min late' : 'Late';
        break;
      default:
        return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? timeString) {
    if (timeString == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(timeString);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid';
    }
  }
}
