import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/auth_service.dart' hide LogService;
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:prepskul/core/services/log_service.dart';
// Map picker removed - using simple text fields instead

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
  
  // Controllers for address input fields (one per session)
  final Map<String, TextEditingController> _addressControllers = {};
  
  bool _isLoadingAddresses = false;
  
  // Map picker removed - using simple text fields instead

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
        // Initialize controllers for all sessions
        _initializeControllersForSession(sessionKey);
      }
    }
    
    // Defer notification until after build phase completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyParent();
    });
  }
  
  /// Initialize text controllers for a session
  void _initializeControllersForSession(String sessionKey) {
    if (!_addressControllers.containsKey(sessionKey)) {
      final address = _locationDetails[sessionKey]?['address'] ?? '';
      _addressControllers[sessionKey] = TextEditingController(text: address);
    }
  }
  
  @override
  void dispose() {
    // Dispose all text controllers
    for (final controller in _addressControllers.values) {
      controller.dispose();
    }
    _addressControllers.clear();
    super.dispose();
  }

  void _setSessionLocation(String sessionKey, String location) {
    safeSetState(() {
      _sessionLocations[sessionKey] = location;
      
      // If changed to online, remove location details and dispose controllers
      if (location == 'online') {
        _locationDetails.remove(sessionKey);
        // Dispose controllers when switching to online (they'll be recreated if needed)
        _addressControllers[sessionKey]?.dispose();
        _addressControllers.remove(sessionKey);
      } else {
        // If changed to onsite, ensure location details entry exists and auto-fetch address
        if (!_locationDetails.containsKey(sessionKey)) {
          _locationDetails[sessionKey] = {
            'address': null,
            'coordinates': null,
          };
        }
        // Initialize controllers for this session if not already done
        _initializeControllersForSession(sessionKey);
        // Auto-fetch address from survey when onsite is selected
        _fetchAddressForSession(sessionKey);
      }
    });
    _notifyParent();
  }

  /// Fetch address from survey for a single session
  Future<void> _fetchAddressForSession(String sessionKey) async {
    try {
      final userProfile = await AuthService.getUserProfile();
      if (userProfile == null) return;

      final userType = userProfile['user_type'] as String?;
      if (userType == null) return;

      Map<String, dynamic>? surveyData;

      if (userType == 'student') {
        surveyData = await SurveyRepository.getStudentSurvey(userProfile['id']);
      } else if (userType == 'parent') {
        surveyData = await SurveyRepository.getParentSurvey(userProfile['id']);
      }

      if (surveyData != null && mounted) {
        final city = surveyData['city'];
        final quarter = surveyData['quarter'];
        
        if (city != null && quarter != null) {
          final street = surveyData['street'];
          final streetStr = street != null && street.toString().isNotEmpty 
              ? ', ${street.toString()}' 
              : '';
          
          final address = '${city.toString()}, ${quarter.toString()}$streetStr';
          
          safeSetState(() {
            if (_locationDetails.containsKey(sessionKey)) {
              _locationDetails[sessionKey] = {
                'address': address,
                'coordinates': _locationDetails[sessionKey]?['coordinates'],
              };
            } else {
              _locationDetails[sessionKey] = {
                'address': address,
                'coordinates': null,
              };
            }
            // Ensure controller exists and update its text
            _initializeControllersForSession(sessionKey);
            if (_addressControllers.containsKey(sessionKey)) {
              _addressControllers[sessionKey]!.text = address;
            }
          });
          _notifyParent();
        }
      }
    } catch (e) {
      LogService.error('Error fetching address for session: $e');
    }
  }

  /// Check if all sessions have location selected
  bool _allSessionsHaveLocation() {
    for (final day in widget.selectedDays) {
      final time = widget.selectedTimes[day] ?? '';
      if (time.isEmpty) continue;
      final sessionKey = '$day-$time';
      if (!_sessionLocations.containsKey(sessionKey) || 
          _sessionLocations[sessionKey] == null) {
        return false;
      }
    }
    return true;
  }

  /// Get list of onsite session keys
  List<String> _getOnsiteSessionKeys() {
    return _sessionLocations.entries
        .where((entry) => entry.value == 'onsite')
        .map((entry) => entry.key)
        .toList();
  }


  void _updateLocationDetails(String sessionKey, String? address, String? coordinates) {
    safeSetState(() {
      _locationDetails[sessionKey] = {
        'address': address,
        'coordinates': coordinates,
      };
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
                                color: AppTheme.primaryColor,
                                isSelected: location == 'onsite',
                              ),
                            ),
                          ],
                        ),
                        
                        // Show address input immediately when onsite is selected
                        if (location == 'onsite') ...[
                          const SizedBox(height: 16),
                          _buildAddressInput(sessionKey),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }


  /// Build address input field for an onsite session (inline)
  Widget _buildAddressInput(String sessionKey) {
    // Ensure controllers exist for this session
    _initializeControllersForSession(sessionKey);
    
    final addressController = _addressControllers[sessionKey]!;

    return TextFormField(
      controller: addressController,
      decoration: InputDecoration(
        labelText: 'Address',
        hintText: 'Enter address for this session',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onChanged: (value) {
        _updateLocationDetails(
          sessionKey,
          value.trim().isNotEmpty ? value.trim() : null,
          null,
        );
      },
      maxLines: 2,
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

