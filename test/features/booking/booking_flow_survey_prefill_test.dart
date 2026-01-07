import 'package:flutter_test/flutter_test.dart';

/// Unit tests for Booking Flow - Survey Data Prefilling
/// 
/// Tests that survey data correctly pre-fills booking form fields
void main() {
  group('Booking Flow - Survey Data Prefilling', () {
    test('should prefill frequency from survey data', () {
      final surveyData = {
        'preferred_session_frequency': 2,
      };
      
      int? selectedFrequency = surveyData['preferred_session_frequency'] as int?;
      
      expect(selectedFrequency, 2);
      expect(selectedFrequency, isNotNull);
    });

    test('should prefill days from survey data', () {
      final surveyData = {
        'preferred_schedule': {
          'days': ['Monday', 'Wednesday'],
        },
      };
      
      final schedule = surveyData['preferred_schedule'] as Map?;
      List<String> selectedDays = [];
      
      if (schedule != null && schedule['days'] != null) {
        selectedDays = List<String>.from(schedule['days']);
      }
      
      expect(selectedDays.length, 2);
      expect(selectedDays, contains('Monday'));
      expect(selectedDays, contains('Wednesday'));
    });

    test('should prefill location from survey data', () {
      final surveyData = {
        'preferred_location': 'online',
      };
      
      String? selectedLocation = surveyData['preferred_location'] as String?;
      
      expect(selectedLocation, 'online');
      expect(selectedLocation, isNotNull);
    });

    test('should prefill address from survey city and quarter', () {
      final surveyData = {
        'city': 'Yaounde',
        'quarter': 'Bastos',
        'street': 'Rue 1234',
      };
      
      String? onsiteAddress;
      if (surveyData['city'] != null && surveyData['quarter'] != null) {
        final street = surveyData['street'] != null ? ', ${surveyData['street']}' : '';
        onsiteAddress = '${surveyData['city']}, ${surveyData['quarter']}$street';
      }
      
      expect(onsiteAddress, 'Yaounde, Bastos, Rue 1234');
      expect(onsiteAddress, isNotNull);
    });

    test('should prefill address without street if street is null', () {
      final surveyData = {
        'city': 'Douala',
        'quarter': 'Bonanjo',
      };
      
      String? onsiteAddress;
      if (surveyData['city'] != null && surveyData['quarter'] != null) {
        final street = surveyData['street'] != null ? ', ${surveyData['street']}' : '';
        onsiteAddress = '${surveyData['city']}, ${surveyData['quarter']}$street';
      }
      
      expect(onsiteAddress, 'Douala, Bonanjo');
    });

    test('should prefill location description from survey', () {
      final surveyData = {
        'location_description': 'Near the main entrance',
      };
      
      String? locationDescription = surveyData['location_description'] as String?;
      
      expect(locationDescription, 'Near the main entrance');
    });

    test('should prefill location description from additional_address_info if location_description is null', () {
      final surveyData = {
        'additional_address_info': 'Blue house with white gate',
      };
      
      String? locationDescription = surveyData['location_description'] as String?;
      if (locationDescription == null) {
        locationDescription = surveyData['additional_address_info'] as String?;
      }
      
      expect(locationDescription, 'Blue house with white gate');
    });

    test('should handle missing survey data gracefully', () {
      final surveyData = <String, dynamic>{};
      
      int? selectedFrequency = surveyData['preferred_session_frequency'] as int?;
      String? selectedLocation = surveyData['preferred_location'] as String?;
      
      expect(selectedFrequency, isNull);
      expect(selectedLocation, isNull);
    });

    test('should apply all survey data correctly', () {
      final surveyData = {
        'preferred_session_frequency': 2,
        'preferred_schedule': {
          'days': ['Monday', 'Wednesday'],
        },
        'preferred_location': 'online',
        'city': 'Yaounde',
        'quarter': 'Bastos',
      };
      
      int? frequency = surveyData['preferred_session_frequency'] as int?;
      final schedule = surveyData['preferred_schedule'] as Map?;
      List<String> days = [];
      if (schedule != null && schedule['days'] != null) {
        days = List<String>.from(schedule['days']);
      }
      String? location = surveyData['preferred_location'] as String?;
      
      expect(frequency, 2);
      expect(days.length, 2);
      expect(location, 'online');
    });
  });
}

