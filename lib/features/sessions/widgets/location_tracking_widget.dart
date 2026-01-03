import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/features/sessions/services/location_sharing_service.dart';
import 'package:prepskul/features/sessions/widgets/embedded_map_widget.dart';
import 'package:intl/intl.dart';

/// Location Tracking Widget
///
/// Displays real-time location tracking for parents during active onsite sessions
/// Shows current location on map, location history, and last update time
/// Only visible for parents viewing their child's active sessions
class LocationTrackingWidget extends StatefulWidget {
  final String sessionId;
  final String? sessionAddress; // Expected session location
  final String? sessionCoordinates; // Expected coordinates "lat,lon"

  const LocationTrackingWidget({
    Key? key,
    required this.sessionId,
    this.sessionAddress,
    this.sessionCoordinates,
  }) : super(key: key);

  @override
  State<LocationTrackingWidget> createState() => _LocationTrackingWidgetState();
}

class _LocationTrackingWidgetState extends State<LocationTrackingWidget> {
  Map<String, dynamic>? _currentLocation;
  List<Map<String, dynamic>> _allLocations = []; // Tutor and learner locations
  List<Map<String, dynamic>> _locationHistory = [];
  bool _isLoading = true;
  bool _isTrackingActive = false;
  String? _errorMessage;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadLocationData();
    // Poll for location updates every 10 seconds
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadLocationData();
      }
    });
  }

  Future<void> _loadLocationData() async {
    try {
      // Get current location (most recent)
      final location = await LocationSharingService.getSessionLocation(widget.sessionId);
      
      // Get all active locations (tutor and learner if both tracking)
      final allLocations = await LocationSharingService.getAllSessionLocations(widget.sessionId);
      
      // Check if tracking is active
      final isActive = LocationSharingService.isLocationSharingActive(widget.sessionId);
      
      // Get location history (last 10 updates)
      final history = await LocationSharingService.getLocationHistory(
        widget.sessionId,
        limit: 10,
      );

      if (mounted) {
        safeSetState(() {
          _currentLocation = location;
          _allLocations = allLocations;
          _locationHistory = history;
          _isTrackingActive = isActive;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      LogService.error('Error loading location data: $e');
      if (mounted) {
        safeSetState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load location data';
        });
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: Colors.blue[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Tracking',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildStatusIndicator(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else if (_currentLocation == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Location tracking will start when the session begins',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Map with current location(s)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: EmbeddedMapWidget(
                    address: widget.sessionAddress ?? '',
                    coordinates: widget.sessionCoordinates,
                    height: 250,
                    showMarker: true,
                    // Show most recent location (tutor or learner)
                    currentLocation: '${_currentLocation!['latitude']},${_currentLocation!['longitude']}',
                  ),
                ),
                // Show if both tutor and learner are tracking
                if (_allLocations.length > 1) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people, size: 16, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Both tutor and student location tracking active',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.green[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Location info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildLocationInfo(),
                ),
                const SizedBox(height: 16),

                // Location history (if available)
                if (_locationHistory.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildLocationHistory(),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (!_isTrackingActive) {
      return Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Not tracking',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Tracking active',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.green[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_currentLocation != null) ...[
          const SizedBox(width: 8),
          Text(
            '• Last update: ${_formatLastUpdate(_currentLocation!['last_updated_at'])}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationInfo() {
    final lat = _currentLocation!['latitude'] as double;
    final lon = _currentLocation!['longitude'] as double;
    final accuracy = _currentLocation!['accuracy'] as double?;
    final userType = _currentLocation!['user_type'] as String;
    final lastUpdate = _currentLocation!['last_updated_at'] as String;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.my_location, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Current Location',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${userType == 'tutor' ? 'Tutor' : 'Student'}: ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.blue[800],
            ),
          ),
          if (accuracy != null) ...[
            const SizedBox(height: 4),
            Text(
              'Accuracy: ${accuracy.toStringAsFixed(0)} meters',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.blue[700],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Updated: ${_formatLastUpdate(lastUpdate)}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Updates',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        ..._locationHistory.take(5).map((location) {
          final lat = location['latitude'] as double;
          final lon = location['longitude'] as double;
          final timestamp = location['last_updated_at'] as String?;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (timestamp != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _formatLastUpdate(timestamp),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
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
          );
        }),
      ],
    );
  }

  String _formatLastUpdate(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else {
        return DateFormat('MMM d, h:mm a').format(dateTime);
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}