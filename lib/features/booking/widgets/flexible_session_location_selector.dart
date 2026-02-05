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
  // Only stored for onsite sessions; when using single-address flow, all onsite share one address
  Map<String, Map<String, String?>> _locationDetails = {};
  
  // Single address for all onsite sessions (ask once, not per session)
  final TextEditingController _singleAddressController = TextEditingController();
  final TextEditingController _singleDescriptionController = TextEditingController();
  bool _singleAddressTouched = false;

  // Survey address fetched on init (same as normal onsite flow) for pre-fill when user selects onsite
  String? _surveyAddress;
  String? _surveyDescription;

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

    // Fetch survey address on init (same as normal onsite flow) so we can pre-fill when user selects onsite
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchSurveyAddress());
    // Pre-fill single address when any session is already onsite (e.g. from initial data or when user taps Onsite)
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillSingleAddressFromSurvey());
  }

  /// Fetch survey address on init (same as normal onsite flow) and store for pre-fill
  Future<void> _fetchSurveyAddress() async {
    try {
      final userProfile = await AuthService.getUserProfile();
      if (userProfile == null || !mounted) return;
      final userType = userProfile['user_type'] as String?;
      if (userType == null) return;
      Map<String, dynamic>? surveyData;
      if (userType == 'student') {
        surveyData = await SurveyRepository.getStudentSurvey(userProfile['id']);
      } else if (userType == 'parent') {
        surveyData = await SurveyRepository.getParentSurvey(userProfile['id']);
      }
      if (surveyData == null || !mounted) return;
      final city = surveyData['city'];
      final quarter = surveyData['quarter'];
      if (city == null || quarter == null) return;
      final street = surveyData['street'];
      final streetStr = street != null && street.toString().isNotEmpty ? ', ${street.toString()}' : '';
      final address = '${city.toString()}, ${quarter.toString()}$streetStr';
      final locationDesc = surveyData['location_description'];
      final description = locationDesc != null && locationDesc.toString().isNotEmpty
          ? locationDesc.toString()
          : (surveyData['additional_address_info'] != null &&
                 surveyData['additional_address_info'].toString().isNotEmpty
              ? surveyData['additional_address_info'].toString()
              : null);
      if (!mounted) return;
      safeSetState(() {
        _surveyAddress = address;
        _surveyDescription = description;
      });
      // If user already selected onsite, pre-fill the address field now
      _prefillSingleAddressFromSurvey();
    } catch (e) {
      LogService.warning('Could not fetch address from survey: $e');
    }
  }

  /// Pre-fill single address from initialLocationDetails or from survey (when any session is onsite)
  Future<void> _prefillSingleAddressFromSurvey() async {
    final onsiteKeys = _getOnsiteSessionKeys();
    if (onsiteKeys.isEmpty) return;
    if (_singleAddressController.text.trim().isNotEmpty) return; // Already filled
    // 1) Prefer existing address from initialLocationDetails (e.g. returning to step)
    final firstKey = onsiteKeys.first;
    final existing = _locationDetails[firstKey]?['address'];
    if (existing != null && existing.toString().trim().isNotEmpty) {
      _singleAddressController.text = existing;
      final desc = _locationDetails[firstKey]?['locationDescription']?.toString() ?? '';
      if (desc.isNotEmpty) _singleDescriptionController.text = desc;
      _applySingleAddressToAllOnsite();
      return;
    }
    // 2) Pre-fill from survey (same as normal onsite flow)
    if (_surveyAddress != null && _surveyAddress!.trim().isNotEmpty) {
      safeSetState(() {
        _singleAddressController.text = _surveyAddress!;
        if (_surveyDescription != null && _surveyDescription!.isNotEmpty) {
          _singleDescriptionController.text = _surveyDescription!;
        }
        _applySingleAddressToAllOnsite();
      });
    }
  }

  void _setSessionLocation(String sessionKey, String location) {
    safeSetState(() {
      _sessionLocations[sessionKey] = location;

      // If changed to online, remove location details
      if (location == 'online') {
        _locationDetails.remove(sessionKey);
      } else {
        // If changed to onsite, use single address if we have one (or pre-fill from survey)
        final address = _singleAddressController.text.trim();
        final description = _singleDescriptionController.text.trim();
        _locationDetails[sessionKey] = {
          'address': address.isEmpty ? null : address,
          'coordinates': null,
          'locationDescription': description.isEmpty ? null : description,
        };
      }
    });
    _notifyParent();
    // When user first selects Onsite, pre-fill address from survey if field is still empty
    if (location == 'onsite') {
      _prefillSingleAddressFromSurvey();
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

  /// Apply the single address/description to all onsite session keys in _locationDetails
  void _applySingleAddressToAllOnsite() {
    final address = _singleAddressController.text.trim();
    final description = _singleDescriptionController.text.trim();
    final onsiteKeys = _getOnsiteSessionKeys();
    for (final key in onsiteKeys) {
      _locationDetails[key] = {
        'address': address.isEmpty ? null : address,
        'coordinates': null,
        'locationDescription': description.isEmpty ? null : description,
      };
    }
    _notifyParent();
  }

  void _notifyParent() {
    widget.onLocationsSelected(_sessionLocations, _locationDetails);
  }

  String _getDayAbbreviation(String day) {
    return day.substring(0, 3); // Mon, Tue, Wed, etc.
  }

  @override
  void dispose() {
    _singleAddressController.dispose();
    _singleDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          const SizedBox(height: 4),
          Text(
            'Select online or onsite for each scheduled session',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

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
                        const SizedBox(height: 10),
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
                        
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          }).toList(),

          // Single address for all onsite sessions (shown only when at least one session is onsite)
          if (_getOnsiteSessionKeys().isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Address for all onsite sessions',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This address will be used for every session you chose as onsite.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _singleAddressController,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        hintText: 'Enter address for onsite sessions',
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      onChanged: (_) {
                        _singleAddressTouched = true;
                        safeSetState(() => _applySingleAddressToAllOnsite());
                      },
                      maxLines: 1,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _singleDescriptionController,
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
                      onChanged: (_) {
                        safeSetState(() => _applySingleAddressToAllOnsite());
                      },
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
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

