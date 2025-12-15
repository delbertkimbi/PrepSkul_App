import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/sessions/services/location_checkin_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

/// Session Location Map Widget
///
/// Displays session location on a map (using native maps app)
/// Shows address, distance, and provides directions
class SessionLocationMap extends StatefulWidget {
  final String address;
  final String? coordinates; // Optional: "lat,lon" format
  final String sessionId;
  final String? currentUserId;
  final String? userType; // 'tutor' or 'student'
  final bool showCheckIn; // Whether to show check-in button

  const SessionLocationMap({
    Key? key,
    required this.address,
    this.coordinates,
    required this.sessionId,
    this.currentUserId,
    this.userType,
    this.showCheckIn = false,
  }) : super(key: key);

  @override
  State<SessionLocationMap> createState() => _SessionLocationMapState();
}

class _SessionLocationMapState extends State<SessionLocationMap> {
  bool _isLoading = false;
  double? _distance;
  Position? _currentPosition;
  Map<String, dynamic>? _checkInStatus;

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
      if (mounted) {
        safeSetState(() {
          _checkInStatus = status;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
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
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Address
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.address,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.5,
              ),
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
                child: Row(
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
                              ? Colors.green[700] 
                              : Colors.orange[700],
                        ),
                      ),
                    ),
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

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

