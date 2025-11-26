import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/survey_repository.dart';

/// Step 4: Location Selector
///
/// Lets user choose session format:
/// - Online (Google Meet, Zoom, etc.)
/// - Onsite (at student's location - requires address)
/// - Hybrid (mix of both)
///
/// Features:
/// - Auto-populates address from onboarding survey when hybrid/onsite is selected
/// - User can edit the auto-filled address
/// - Validates that address is not empty before proceeding
/// - Location description field for additional details
class LocationSelector extends StatefulWidget {
  final Map<String, dynamic> tutor;
  final String? initialLocation;
  final String? initialAddress;
  final String? initialLocationDescription;
  final Function(String location, String? address, String? locationDescription)
  onLocationSelected;

  const LocationSelector({
    Key? key,
    required this.tutor,
    this.initialLocation,
    this.initialAddress,
    this.initialLocationDescription,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  State<LocationSelector> createState() => _LocationSelectorState();
}

class _LocationSelectorState extends State<LocationSelector> {
  String? _selectedLocation;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _locationDescriptionController =
      TextEditingController();
  bool _showAddressError = false;

  // Parse tutor's teaching mode from demo data
  Set<String> _tutorTeachingModes = {};

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _addressController.text = widget.initialAddress ?? '';
    _locationDescriptionController.text =
        widget.initialLocationDescription ?? '';
    _loadTutorTeachingModes();
  }

  void _loadTutorTeachingModes() {
    final teachingMode = widget.tutor['teaching_mode'];
    if (teachingMode != null) {
      final mode = teachingMode.toString().toLowerCase();
      if (mode.contains('online')) _tutorTeachingModes.add('online');
      if (mode.contains('onsite') || mode.contains('in-person')) {
        _tutorTeachingModes.add('onsite');
      }
      if (mode.contains('both') || mode.contains('hybrid')) {
        _tutorTeachingModes.addAll(['online', 'onsite', 'hybrid']);
      }
    }

    // Fallback: if no teaching mode, assume all available
    if (_tutorTeachingModes.isEmpty) {
      _tutorTeachingModes = {'online', 'onsite', 'hybrid'};
    }
  }

  bool _isLocationAvailable(String location) {
    if (location == 'hybrid') {
      // Hybrid only available if tutor offers both
      return _tutorTeachingModes.contains('online') &&
          _tutorTeachingModes.contains('onsite');
    }
    return _tutorTeachingModes.contains(location);
  }

  void _selectLocation(String location) async {
    setState(() => _selectedLocation = location);
    
    // Auto-populate address from survey if hybrid/onsite selected and address is empty
    if ((location == 'onsite' || location == 'hybrid') && 
        _addressController.text.trim().isEmpty) {
      await _autoFillAddressFromSurvey();
    }
    
    _notifyParent();
  }

  /// Auto-fill address from user's onboarding survey data
  Future<void> _autoFillAddressFromSurvey() async {
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
          
          setState(() {
            _addressController.text = address;
          });
          
          // Also pre-fill location description if available
          final locationDesc = surveyData['location_description'];
          if (locationDesc != null && locationDesc.toString().isNotEmpty) {
            _locationDescriptionController.text = locationDesc.toString();
          } else {
            final additionalInfo = surveyData['additional_address_info'];
            if (additionalInfo != null && additionalInfo.toString().isNotEmpty) {
              _locationDescriptionController.text = additionalInfo.toString();
            }
          }
          
          _notifyParent();
        }
      }
    } catch (e) {
      print('⚠️ Could not auto-fill address from survey: $e');
      // Silent fail - user can still type manually
    }
  }

  void _notifyParent() {
    if (_selectedLocation == null) return;

    final needsAddress =
        _selectedLocation == 'onsite' || _selectedLocation == 'hybrid';
    
    // Validate address if needed
    if (needsAddress) {
      final addressText = _addressController.text.trim();
      setState(() {
        _showAddressError = addressText.isEmpty;
      });
    } else {
      setState(() {
        _showAddressError = false;
      });
    }
    
    final address = needsAddress ? _addressController.text.trim() : null;
    final locationDescription = needsAddress
        ? _locationDescriptionController.text.trim()
        : null;

    widget.onLocationSelected(_selectedLocation!, address, locationDescription);
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
            'Where will sessions happen?',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your preferred learning format',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Online option
          _buildLocationOption(
            location: 'online',
            title: 'Online',
            subtitle: 'Video call sessions via Google Meet or Zoom',
            icon: Icons.videocam,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),

          // Onsite option
          _buildLocationOption(
            location: 'onsite',
            title: 'Onsite',
            subtitle: 'Tutor comes to your location',
            icon: Icons.home_outlined,
            color: Colors.green,
          ),
          const SizedBox(height: 16),

          // Hybrid option
          _buildLocationOption(
            location: 'hybrid',
            title: 'Hybrid',
            subtitle: 'Mix of online and onsite sessions',
            icon: Icons.shuffle,
            color: Colors.purple,
          ),

          // Address input (for onsite/hybrid)
          if (_selectedLocation == 'onsite' ||
              _selectedLocation == 'hybrid') ...[
            const SizedBox(height: 32),
            Text(
              'Session Address',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              onChanged: (_) {
                // Clear error when user starts typing
                if (_showAddressError && _addressController.text.trim().isNotEmpty) {
                  setState(() {
                    _showAddressError = false;
                  });
                }
                _notifyParent();
              },
              maxLines: 1,
              decoration: InputDecoration(
                labelText: 'Address *',
                hintText: 'Enter your full address (City, Quarter, Street...)',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
                filled: true,
                fillColor: Colors.grey[50],
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
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.red[300]!,
                    width: 1,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.red[400]!,
                    width: 2,
                  ),
                ),
                prefixIcon: Icon(Icons.location_on, color: Colors.grey[600]),
                errorText: _showAddressError
                    ? 'Address is required for ${_selectedLocation == 'onsite' ? 'onsite' : 'hybrid'} sessions'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationDescriptionController,
              onChanged: (_) => _notifyParent(),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Location Description',
                hintText:
                    'Add landmarks, nearby buildings, or clear directions to help the tutor find your location easily',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[400],
                ),
                filled: true,
                fillColor: Colors.grey[50],
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
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                prefixIcon: Icon(
                  Icons.description_outlined,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Include landmarks or clear directions to help the tutor find your location easily.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Tutor availability note
          if (_tutorTeachingModes.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: Colors.green[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tutor offers: ${_getTutorModesText()}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.green[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationOption({
    required String location,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isAvailable = _isLocationAvailable(location);
    final isSelected = _selectedLocation == location;

    return GestureDetector(
      onTap: isAvailable ? () => _selectLocation(location) : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.05)
              : (isAvailable ? Colors.white : Colors.grey[100]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isAvailable ? Colors.grey[300]! : Colors.grey[200]!),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : (isAvailable ? color.withOpacity(0.1) : Colors.grey[200]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color: isSelected
                    ? Colors.white
                    : (isAvailable ? color : Colors.grey[400]),
              ),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isAvailable ? Colors.black : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isAvailable ? Colors.grey[600] : Colors.grey[400],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Selection indicator
            if (isAvailable)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.transparent,
                  ),
                ),
              )
            else
              Icon(Icons.block, size: 24, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  String _getTutorModesText() {
    if (_tutorTeachingModes.contains('hybrid') ||
        (_tutorTeachingModes.contains('online') &&
            _tutorTeachingModes.contains('onsite'))) {
      return 'Online & Onsite';
    } else if (_tutorTeachingModes.contains('online')) {
      return 'Online only';
    } else if (_tutorTeachingModes.contains('onsite')) {
      return 'Onsite only';
    }
    return 'All formats';
  }

  @override
  void dispose() {
    _addressController.dispose();
    _locationDescriptionController.dispose();
    super.dispose();
  }
}

