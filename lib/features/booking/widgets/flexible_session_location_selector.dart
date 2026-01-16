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
  
  // Two-step flow: selection mode and review mode
  bool _isReviewMode = false;
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

  /// Fetch addresses from survey for all onsite sessions
  Future<void> _fetchAddressesForOnsiteSessions() async {
    safeSetState(() {
      _isLoadingAddresses = true;
    });

    try {
      final userProfile = await AuthService.getUserProfile();
      if (userProfile == null) {
        safeSetState(() {
          _isLoadingAddresses = false;
          _isReviewMode = true;
        });
        return;
      }

      final userType = userProfile['user_type'] as String?;
      if (userType == null) {
        safeSetState(() {
          _isLoadingAddresses = false;
          _isReviewMode = true;
        });
        return;
      }

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
          
          // Pre-fill location description if available
          final locationDesc = surveyData['location_description'];
          final description = locationDesc != null && locationDesc.toString().isNotEmpty
              ? locationDesc.toString()
              : (surveyData['additional_address_info'] != null && 
                 surveyData['additional_address_info'].toString().isNotEmpty
                  ? surveyData['additional_address_info'].toString()
                  : null);

          // Apply address to all onsite sessions that don't have one
          final onsiteKeys = _getOnsiteSessionKeys();
          safeSetState(() {
            for (final sessionKey in onsiteKeys) {
              if (!_locationDetails.containsKey(sessionKey) || 
                  _locationDetails[sessionKey]?['address'] == null) {
                _locationDetails[sessionKey] = {
                  'address': address,
                  'coordinates': null,
                  'locationDescription': description,
                };
              }
            }
            _isLoadingAddresses = false;
            _isReviewMode = true;
          });
          _notifyParent();
          return;
        }
      }
    } catch (e) {
      LogService.warning('Could not fetch addresses from survey: $e');
    }

    safeSetState(() {
      _isLoadingAddresses = false;
      _isReviewMode = true;
    });
  }

  void _updateLocationDetails(String sessionKey, String? address, String? coordinates, String? locationDescription) {
    safeSetState(() {
      _locationDetails[sessionKey] = {
        'address': address,
        'coordinates': coordinates,
        'locationDescription': locationDescription,
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
    if (_isReviewMode) {
      return _buildReviewMode();
    }
    
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
                                color: Colors.green,
                                isSelected: location == 'onsite',
                              ),
                            ),
                          ],
                        ),
                        
                        // No address fields in selection mode - will show in review mode
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          }).toList(),
          
          // Continue button to proceed to review
          if (!_isReviewMode && _allSessionsHaveLocation()) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoadingAddresses ? null : () => _fetchAddressesForOnsiteSessions(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoadingAddresses
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Continue to Review Locations',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build review mode UI - shows all onsite sessions with addresses for editing
  Widget _buildReviewMode() {
    final onsiteSessions = _getOnsiteSessionKeys();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Review Onsite Locations',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            onsiteSessions.isEmpty
                ? 'All sessions are online. No addresses needed.'
                : 'Review and edit addresses for onsite sessions, or confirm to proceed.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Show only onsite sessions for review
          if (onsiteSessions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                    const SizedBox(height: 16),
                    Text(
                      'All sessions are online',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...onsiteSessions.map((sessionKey) {
              final parts = sessionKey.split('-');
              final day = parts[0];
              final time = parts.length > 1 ? parts.sublist(1).join('-') : '';
              
              return _buildOnsiteSessionReviewCard(sessionKey, day, time);
            }).toList(),

          // Action buttons
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    safeSetState(() {
                      _isReviewMode = false;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    // Confirm and proceed
                    _notifyParent();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Confirm & Continue',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build review card for an onsite session
  Widget _buildOnsiteSessionReviewCard(String sessionKey, String day, String time) {
    final address = _locationDetails[sessionKey]?['address'] ?? '';
    final description = _locationDetails[sessionKey]?['locationDescription'] ?? '';
    final addressController = TextEditingController(text: address);
    final descriptionController = TextEditingController(text: description);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 16),
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
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getDayAbbreviation(day),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
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
                Icon(Icons.home, color: Colors.green[700], size: 20),
              ],
            ),
            const SizedBox(height: 16),
            
            // Address field
            TextFormField(
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
                  borderSide: BorderSide(color: Colors.green, width: 2),
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
                  descriptionController.text.trim().isNotEmpty 
                      ? descriptionController.text.trim() 
                      : null,
                );
              },
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            
            // Description field
            TextFormField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'e.g., Apartment 3B, Near the main gate',
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
                  borderSide: BorderSide(color: Colors.green, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                _updateLocationDetails(
                  sessionKey,
                  addressController.text.trim().isNotEmpty 
                      ? addressController.text.trim() 
                      : null,
                  null,
                  value.trim().isNotEmpty ? value.trim() : null,
                );
              },
              maxLines: 2,
            ),
          ],
        ),
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

