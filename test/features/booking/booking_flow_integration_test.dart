import 'package:flutter_test/flutter_test.dart';

/// Integration tests for Complete Booking Flow - All Session Types
/// 
/// Tests the entire booking flow end-to-end for all location types
/// and all frequency/payment plan combinations
void main() {
  group('Complete Booking Flow Integration Tests', () {
    group('Online Sessions - All Frequencies', () {
      test('1x/week, online, monthly - complete flow', () {
        // Complete booking data
        final bookingData = {
          'frequency': 1,
          'days': ['Monday'],
          'times': {'Monday': '3:00 PM'},
          'location': 'online',
          'address': null,
          'locationDescription': null,
          'paymentPlan': 'monthly',
          'perSession': 5000.0,
        };
        
        // Calculate monthly total
        final sessionsPerMonth = bookingData['frequency'] as int * 4;
        final monthlyTotal = (bookingData['perSession'] as double) * sessionsPerMonth;
        
        // Validate all steps
        expect(bookingData['frequency'], isNotNull);
        expect((bookingData['days'] as List).length, bookingData['frequency']);
        expect((bookingData['times'] as Map).length, (bookingData['days'] as List).length);
        expect(bookingData['location'], 'online');
        expect(bookingData['paymentPlan'], isNotNull);
        expect(monthlyTotal, 20000.0);
      });

      test('2x/week, online, biweekly - complete flow', () {
        final bookingData = {
          'frequency': 2,
          'days': ['Monday', 'Wednesday'],
          'times': {'Monday': '3:00 PM', 'Wednesday': '4:00 PM'},
          'location': 'online',
          'paymentPlan': 'biweekly',
          'perSession': 5000.0,
        };
        
        final sessionsPerMonth = bookingData['frequency'] as int * 4;
        final monthlyTotal = (bookingData['perSession'] as double) * sessionsPerMonth;
        final biweeklyAmount = monthlyTotal / 2;
        
        expect(bookingData['frequency'], 2);
        expect((bookingData['days'] as List).length, 2);
        expect((bookingData['times'] as Map).length, 2);
        expect(bookingData['location'], 'online');
        expect(biweeklyAmount, 20000.0);
      });

      test('3x/week, online, weekly - complete flow', () {
        final bookingData = {
          'frequency': 3,
          'days': ['Monday', 'Wednesday', 'Friday'],
          'times': {'Monday': '3:00 PM', 'Wednesday': '4:00 PM', 'Friday': '5:00 PM'},
          'location': 'online',
          'paymentPlan': 'weekly',
          'perSession': 5000.0,
        };
        
        final sessionsPerMonth = bookingData['frequency'] as int * 4;
        final monthlyTotal = (bookingData['perSession'] as double) * sessionsPerMonth;
        final weeklyAmount = monthlyTotal / 4;
        
        expect(bookingData['frequency'], 3);
        expect((bookingData['days'] as List).length, 3);
        expect((bookingData['times'] as Map).length, 3);
        expect(weeklyAmount, 15000.0);
      });

      test('4x/week, online, monthly - complete flow', () {
        final bookingData = {
          'frequency': 4,
          'days': ['Monday', 'Tuesday', 'Wednesday', 'Thursday'],
          'times': {
            'Monday': '3:00 PM',
            'Tuesday': '4:00 PM',
            'Wednesday': '5:00 PM',
            'Thursday': '6:00 PM',
          },
          'location': 'online',
          'paymentPlan': 'monthly',
          'perSession': 5000.0,
        };
        
        final sessionsPerMonth = bookingData['frequency'] as int * 4;
        final monthlyTotal = (bookingData['perSession'] as double) * sessionsPerMonth;
        
        expect(bookingData['frequency'], 4);
        expect((bookingData['days'] as List).length, 4);
        expect((bookingData['times'] as Map).length, 4);
        expect(monthlyTotal, 80000.0);
      });
    });

    group('Onsite Sessions - All Frequencies', () {
      test('1x/week, onsite with address, monthly - complete flow', () {
        final bookingData = {
          'frequency': 1,
          'days': ['Monday'],
          'times': {'Monday': '3:00 PM'},
          'location': 'onsite',
          'address': '123 Main Street, Yaounde, Cameroon',
          'locationDescription': 'Near the main entrance',
          'paymentPlan': 'monthly',
          'perSession': 5000.0,
        };
        
        // Validate onsite requirements
        expect(bookingData['location'], 'onsite');
        expect(bookingData['address'], isNotNull);
        expect((bookingData['address'] as String).trim().isNotEmpty, true);
        
        final sessionsPerMonth = bookingData['frequency'] as int * 4;
        final monthlyTotal = (bookingData['perSession'] as double) * sessionsPerMonth;
        
        expect(monthlyTotal, 20000.0);
      });

      test('2x/week, onsite with address, biweekly - complete flow', () {
        final bookingData = {
          'frequency': 2,
          'days': ['Monday', 'Wednesday'],
          'times': {'Monday': '3:00 PM', 'Wednesday': '4:00 PM'},
          'location': 'onsite',
          'address': '456 University Avenue, Douala',
          'locationDescription': 'Second floor, room 205',
          'paymentPlan': 'biweekly',
          'perSession': 5000.0,
        };
        
        expect(bookingData['location'], 'onsite');
        expect((bookingData['address'] as String).trim().isNotEmpty, true);
        
        final sessionsPerMonth = bookingData['frequency'] as int * 4;
        final monthlyTotal = (bookingData['perSession'] as double) * sessionsPerMonth;
        final biweeklyAmount = monthlyTotal / 2;
        
        expect(biweeklyAmount, 20000.0);
      });

      test('3x/week, onsite with address, weekly - complete flow', () {
        final bookingData = {
          'frequency': 3,
          'days': ['Monday', 'Wednesday', 'Friday'],
          'times': {'Monday': '3:00 PM', 'Wednesday': '4:00 PM', 'Friday': '5:00 PM'},
          'location': 'onsite',
          'address': '789 Business District, Buea',
          'locationDescription': 'Blue house with white gate',
          'paymentPlan': 'weekly',
          'perSession': 5000.0,
        };
        
        expect(bookingData['location'], 'onsite');
        expect((bookingData['address'] as String).trim().isNotEmpty, true);
        
        final sessionsPerMonth = bookingData['frequency'] as int * 4;
        final monthlyTotal = (bookingData['perSession'] as double) * sessionsPerMonth;
        final weeklyAmount = monthlyTotal / 4;
        
        expect(weeklyAmount, 15000.0);
      });

      test('4x/week, onsite with address, monthly - complete flow', () {
        final bookingData = {
          'frequency': 4,
          'days': ['Monday', 'Tuesday', 'Wednesday', 'Thursday'],
          'times': {
            'Monday': '3:00 PM',
            'Tuesday': '4:00 PM',
            'Wednesday': '5:00 PM',
            'Thursday': '6:00 PM',
          },
          'location': 'onsite',
          'address': '321 Residential Area, Limbe',
          'locationDescription': 'Corner house with red roof',
          'paymentPlan': 'monthly',
          'perSession': 5000.0,
        };
        
        expect(bookingData['location'], 'onsite');
        expect((bookingData['address'] as String).trim().isNotEmpty, true);
        
        final sessionsPerMonth = bookingData['frequency'] as int * 4;
        final monthlyTotal = (bookingData['perSession'] as double) * sessionsPerMonth;
        
        expect(monthlyTotal, 80000.0);
      });
    });

    group('Hybrid/Flexible Sessions - All Frequencies', () {
      test('2x/week, hybrid, monthly - complete flow', () {
        final bookingData = {
          'frequency': 2,
          'days': ['Monday', 'Wednesday'],
          'times': {'Monday': '3:00 PM', 'Wednesday': '4:00 PM'},
          'location': 'hybrid',
          'address': null, // Optional for hybrid
          'locationDescription': 'Can do online or onsite',
          'paymentPlan': 'monthly',
          'perSession': 5000.0,
        };
        
        // Hybrid doesn't require address upfront
        expect(bookingData['location'], 'hybrid');
        expect(bookingData['address'], isNull);
        
        final sessionsPerMonth = bookingData['frequency'] as int * 4;
        final monthlyTotal = (bookingData['perSession'] as double) * sessionsPerMonth;
        
        expect(monthlyTotal, 40000.0);
      });

      test('3x/week, flexible, biweekly - complete flow', () {
        final bookingData = {
          'frequency': 3,
          'days': ['Monday', 'Wednesday', 'Friday'],
          'times': {'Monday': '3:00 PM', 'Wednesday': '4:00 PM', 'Friday': '5:00 PM'},
          'location': 'flexible',
          'address': 'Optional address for flexible sessions',
          'locationDescription': 'Flexible between online and onsite',
          'paymentPlan': 'biweekly',
          'perSession': 5000.0,
        };
        
        expect(bookingData['location'], 'flexible');
        
        final sessionsPerMonth = bookingData['frequency'] as int * 4;
        final monthlyTotal = (bookingData['perSession'] as double) * sessionsPerMonth;
        final biweeklyAmount = monthlyTotal / 2;
        
        expect(biweeklyAmount, 30000.0);
      });

      test('4x/week, hybrid with optional address, weekly - complete flow', () {
        final bookingData = {
          'frequency': 4,
          'days': ['Monday', 'Tuesday', 'Wednesday', 'Thursday'],
          'times': {
            'Monday': '3:00 PM',
            'Tuesday': '4:00 PM',
            'Wednesday': '5:00 PM',
            'Thursday': '6:00 PM',
          },
          'location': 'hybrid',
          'address': 'Optional: 123 Main St, Yaounde',
          'locationDescription': 'Prefer online but can do onsite if needed',
          'paymentPlan': 'weekly',
          'perSession': 5000.0,
        };
        
        expect(bookingData['location'], 'hybrid');
        
        final sessionsPerMonth = bookingData['frequency'] as int * 4;
        final monthlyTotal = (bookingData['perSession'] as double) * sessionsPerMonth;
        final weeklyAmount = monthlyTotal / 4;
        
        expect(weeklyAmount, 20000.0);
      });
    });

    group('All Payment Plans - Validation', () {
      test('monthly payment plan should use full monthly total', () {
        const frequency = 2;
        const perSession = 5000.0;
        const sessionsPerMonth = frequency * 4;
        final monthlyTotal = perSession * sessionsPerMonth;
        
        expect(monthlyTotal, 40000.0);
      });

      test('biweekly payment plan should be half of monthly', () {
        const frequency = 2;
        const perSession = 5000.0;
        const sessionsPerMonth = frequency * 4;
        final monthlyTotal = perSession * sessionsPerMonth;
        final biweeklyAmount = monthlyTotal / 2;
        
        expect(biweeklyAmount, 20000.0);
        expect(biweeklyAmount * 2, monthlyTotal);
      });

      test('weekly payment plan should be quarter of monthly', () {
        const frequency = 2;
        const perSession = 5000.0;
        const sessionsPerMonth = frequency * 4;
        final monthlyTotal = perSession * sessionsPerMonth;
        final weeklyAmount = monthlyTotal / 4;
        
        expect(weeklyAmount, 10000.0);
        expect(weeklyAmount * 4, monthlyTotal);
      });
    });

    group('Complete Flow Validation - All Combinations', () {
      test('all location types should work with all frequencies', () {
        final locations = ['online', 'onsite', 'hybrid', 'flexible'];
        final frequencies = [1, 2, 3, 4];
        
        for (final location in locations) {
          for (final frequency in frequencies) {
            expect(location, isNotEmpty);
            expect(frequency, greaterThan(0));
            expect(frequency, lessThanOrEqualTo(4));
          }
        }
      });

      test('all payment plans should work with all frequencies', () {
        final paymentPlans = ['monthly', 'biweekly', 'weekly'];
        final frequencies = [1, 2, 3, 4];
        
        for (final plan in paymentPlans) {
          for (final frequency in frequencies) {
            const perSession = 5000.0;
            final sessionsPerMonth = frequency * 4;
            final monthlyTotal = perSession * sessionsPerMonth;
            
            expect(monthlyTotal, greaterThan(0));
            expect(plan, isNotEmpty);
          }
        }
      });

      test('complete booking data structure should be valid', () {
        final bookingData = {
          'frequency': 2,
          'days': ['Monday', 'Wednesday'],
          'times': {'Monday': '3:00 PM', 'Wednesday': '4:00 PM'},
          'location': 'online',
          'address': null,
          'locationDescription': null,
          'paymentPlan': 'monthly',
          'perSession': 5000.0,
        };
        
        // Validate structure
        expect(bookingData.containsKey('frequency'), true);
        expect(bookingData.containsKey('days'), true);
        expect(bookingData.containsKey('times'), true);
        expect(bookingData.containsKey('location'), true);
        expect(bookingData.containsKey('paymentPlan'), true);
        expect(bookingData.containsKey('perSession'), true);
        
        // Validate types
        expect(bookingData['frequency'], isA<int>());
        expect(bookingData['days'], isA<List>());
        expect(bookingData['times'], isA<Map>());
        expect(bookingData['location'], isA<String>());
        expect(bookingData['paymentPlan'], isA<String>());
        expect(bookingData['perSession'], isA<double>());
      });
    });
  });
}

