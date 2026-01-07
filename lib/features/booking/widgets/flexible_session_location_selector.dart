import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/features/booking/widgets/map_location_picker.dart';

/// Flexible Session Location Selector
///
/// Allows users to select online or onsite for each scheduled session
/// when "flexible" booking option is selected.
/// Shows map picker for any sessions marked as onsite.
class FlexibleSessionLocationSelector extends StatefulWidget {
  final List<String> selectedDays;
  final Map<String, String> selectedTimes; // {"Monday": "3:00 PM"}
  final Map<String, String>? initialSessionLocations; // {"Monday-3:00 PM": "onsite"}
  final Map<String, Map<String, String?>>? initialLocationDetails; // {"Monday-3:00 PM": {"address": "...", "coordinates": "..."}}
  final Function(Map<String, String> sessionLocations, Map<String, Map<String, String?>> locationDetails) onLocationsSelected;

  const FlexibleSessionLocationSelector({
    super.key,
    required this.selectedDays,
    required this.selectedTimes,
    this.initialSessionLocations,
    this.initialLocationDetails,
    required this.onLocationsSelected,
  });

  @override
  State<FlexibleSessionLocationSelector> createState() => _FlexibleSessionLocationSelectorState();
}

class _FlexibleSessionLocationSelectorState extends State<FlexibleSessionLocationSelector> {
  // Map of session key (e.g., "Monday-3:00 PM") to location type ("online" or "onsite")
  Map<String, String> _sessionLocations = {};
  
  // Map of session key to location details (address, coordinates, description)
  // Only stored for onsite sessions
  Map<String, Map<String, String?>> _locationDetails = {};
  
  // Track which session's map picker is currently open
  String? _openMapPickerFor;

  @override
  void initState() {
    super.initState();
    // Initialize from widget data if provided
    if (widget.initialSessionLocations != null) {
      _sessionLocations = Map<String, String>.from(widget.initialSessionLocations!);
    }
    if (widget.initialLocationDetails != null) {
      _locationDetails = Map<String, Map<String, String?>>.from(widget.initialLocationDetails!);
    }
    
    // Initialize all sessions to "online" by default if not set
    for (final day in widget.selectedDays) {
      final time = widget.selectedTimes[day] ?? '';
      if (time.isNotEmpty) {
        final sessionKey = '$day-$time';
        if (!_sessionLocations.containsKey(sessionKey)) {
          _sessionLocations[sessionKey] = 'online';
        }
      }
    }
    
    // Defer notification until after build phase completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyParent();
    });
  }

  void _setSessionLocation(String sessionKey, String location) {
    safeSetState(() {
      _sessionLocations[sessionKey] = location;
      
      // If changed to online, remove location details
      if (location == 'online') {
        _locationDetails.remove(sessionKey);
        _openMapPickerFor = null;
      } else {
        // If changed to onsite, ensure location details entry exists
        if (!_locationDetails.containsKey(sessionKey)) {
          _locationDetails[sessionKey] = {
            'address': null,
            'coordinates': null,
            'locationDescription': null,
          };
        }
      }
    });
    _notifyParent();
  }

  void _updateLocationDetails(String sessionKey, String address, String coordinates, String? locationDescription) {
    safeSetState(() {
      _locationDetails[sessionKey] = {
        'address': address,
        'coordinates': coordinates,
        'locationDescription': locationDescription,
      };
      _openMapPickerFor = null; // Close map picker after selection
    });
    _notifyParent();
  }

  void _notifyParent() {
    widget.onLocationsSelected(_sessionLocations, _locationDetails);
  }

  String _getDayAbbreviation(String day) {
    return day.substring(0, 3); // Mon, Tue, Wed, etc.
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Choose Location for Each Session',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select online or onsite for each scheduled session',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Session list
          ...widget.selectedDays.map((day) {
            final time = widget.selectedTimes[day] ?? '';
            if (time.isEmpty) return const SizedBox.shrink();
            
            final sessionKey = '$day-$time';
            final location = _sessionLocations[sessionKey] ?? 'online';
            final hasLocationDetails = _locationDetails.containsKey(sessionKey) &&
                _locationDetails[sessionKey]!['address'] != null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Session card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Session header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getDayAbbreviation(day),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    day,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    time,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Location toggle
                        Row(
                          children: [
                            Expanded(
                              child: _buildLocationOption(
                                sessionKey: sessionKey,
                                location: 'online',
                                title: 'Online',
                                icon: Icons.videocam,
                                color: Colors.blue,
                                isSelected: location == 'online',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildLocationOption(
                                sessionKey: sessionKey,
                                location: 'onsite',
                                title: 'Onsite',
                                icon: Icons.home,
                                color: Colors.green,
                                isSelected: location == 'onsite',
                              ),
                            ),
                          ],
                        ),
                        
                        // Location details for onsite sessions
                        if (location == 'onsite') ...[
                          const SizedBox(height: 16),
                          if (hasLocationDetails) ...[
                            // Show selected address
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, size: 18, color: Colors.green[700]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _locationDetails[sessionKey]!['address'] ?? '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.green[900],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      safeSetState(() {
                                        _openMapPickerFor = _openMapPickerFor == sessionKey ? null : sessionKey;
                                      });
                                    },
                                    child: Text(
                                      _openMapPickerFor == sessionKey ? 'Hide Map' : 'Change',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // Show map picker button
                            OutlinedButton.icon(
                              onPressed: () {
                                safeSetState(() {
                                  _openMapPickerFor = _openMapPickerFor == sessionKey ? null : sessionKey;
                                });
                              },
                              icon: Icon(Icons.map, color: AppTheme.primaryColor),
                              label: Text(
                                'Select Location',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppTheme.primaryColor),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Map picker (shown when this session is selected)
                if (location == 'onsite' && _openMapPickerFor == sessionKey) ...[
                  MapLocationPicker(
                    initialAddress: _locationDetails[sessionKey]?['address'],
                    initialCoordinates: _locationDetails[sessionKey]?['coordinates'],
                    initialLocationDescription: _locationDetails[sessionKey]?['locationDescription'],
                    onLocationSelected: (address, coordinates, locationDescription) {
                      _updateLocationDetails(sessionKey, address, coordinates, locationDescription);
                    },
                    height: 350,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLocationOption({
    required String sessionKey,
    required String location,
    required String title,
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _setSessionLocation(sessionKey, location),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

