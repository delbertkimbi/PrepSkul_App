import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/utils/hourly_rate_parser.dart';

void main() {
  group('HourlyRateParser', () {
    group('parseHourlyRate', () {
      test('should return null for null input', () {
        expect(HourlyRateParser.parseHourlyRate(null), isNull);
      });

      test('should return null for empty string', () {
        expect(HourlyRateParser.parseHourlyRate(''), isNull);
      });

      test('should parse range "2,000 – 3,000 XAF" to 2000.0', () {
        expect(
          HourlyRateParser.parseHourlyRate('2,000 – 3,000 XAF'),
          equals(2000.0),
        );
      });

      test('should parse range "3,000 – 4,000 XAF" to 3000.0', () {
        expect(
          HourlyRateParser.parseHourlyRate('3,000 – 4,000 XAF'),
          equals(3000.0),
        );
      });

      test('should parse range "4,000 – 5,000 XAF" to 4000.0', () {
        expect(
          HourlyRateParser.parseHourlyRate('4,000 – 5,000 XAF'),
          equals(4000.0),
        );
      });

      test('should parse "Above 5,000 XAF" to 5000.0', () {
        expect(
          HourlyRateParser.parseHourlyRate('Above 5,000 XAF'),
          equals(5000.0),
        );
      });

      test('should parse "Above 5,000" to 5000.0', () {
        expect(
          HourlyRateParser.parseHourlyRate('Above 5,000'),
          equals(5000.0),
        );
      });

      test('should handle single value "4,000 XAF" to 4000.0', () {
        expect(
          HourlyRateParser.parseHourlyRate('4,000 XAF'),
          equals(4000.0),
        );
      });

      test('should handle value without currency "4,000" to 4000.0', () {
        expect(
          HourlyRateParser.parseHourlyRate('4,000'),
          equals(4000.0),
        );
      });

      test('should handle value without commas "4000" to 4000.0', () {
        expect(
          HourlyRateParser.parseHourlyRate('4000'),
          equals(4000.0),
        );
      });

      test('should clamp values below 1000 to 1000.0', () {
        expect(
          HourlyRateParser.parseHourlyRate('500'),
          equals(1000.0),
        );
      });

      test('should clamp values above 50000 to 50000.0', () {
        expect(
          HourlyRateParser.parseHourlyRate('60000'),
          equals(50000.0),
        );
      });

      test('should handle range with regular hyphen "4,000-5,000" to 4000.0', () {
        expect(
          HourlyRateParser.parseHourlyRate('4,000-5,000'),
          equals(4000.0),
        );
      });

      test('should handle range with en-dash "4,000–5,000" to 4000.0', () {
        expect(
          HourlyRateParser.parseHourlyRate('4,000–5,000'),
          equals(4000.0),
        );
      });

      test('should handle decimal values "2,500.50 XAF" to 2500.50', () {
        expect(
          HourlyRateParser.parseHourlyRate('2,500.50 XAF'),
          equals(2500.50),
        );
      });

      test('should return null for invalid input "invalid"', () {
        expect(
          HourlyRateParser.parseHourlyRate('invalid'),
          isNull,
        );
      });

      test('should handle "Above 10,000 XAF" to 10000.0 (within valid range)', () {
        expect(
          HourlyRateParser.parseHourlyRate('Above 10,000 XAF'),
          equals(10000.0),
        );
      });

      test('should handle edge case "1,000 – 2,000 XAF" to 1000.0', () {
        expect(
          HourlyRateParser.parseHourlyRate('1,000 – 2,000 XAF'),
          equals(1000.0),
        );
      });

      test('should handle edge case "50,000 XAF" to 50000.0', () {
        expect(
          HourlyRateParser.parseHourlyRate('50,000 XAF'),
          equals(50000.0),
        );
      });

      test('should handle whitespace in input "  4,000 – 5,000 XAF  " to 4000.0', () {
        expect(
          HourlyRateParser.parseHourlyRate('  4,000 – 5,000 XAF  '),
          equals(4000.0),
        );
      });
    });

    group('Real-world scenarios from production', () {
      test('should prevent the bug: "4,000 – 5,000 XAF" should NOT become 40005000', () {
        final result = HourlyRateParser.parseHourlyRate('4,000 – 5,000 XAF');
        expect(result, equals(4000.0));
        expect(result, lessThan(50000.0));
        expect(result, greaterThanOrEqualTo(1000.0));
      });

      test('should ensure all dropdown values parse correctly', () {
        final testCases = [
          ('2,000 – 3,000 XAF', 2000.0),
          ('3,000 – 4,000 XAF', 3000.0),
          ('4,000 – 5,000 XAF', 4000.0),
          ('Above 5,000 XAF', 5000.0),
        ];

        for (final (input, expected) in testCases) {
          final result = HourlyRateParser.parseHourlyRate(input);
          expect(
            result,
            equals(expected),
            reason: 'Failed for input: "$input"',
          );
          // Ensure it's within database constraints
          expect(
            result,
            greaterThanOrEqualTo(1000.0),
            reason: 'Value too low for "$input"',
          );
          expect(
            result,
            lessThanOrEqualTo(50000.0),
            reason: 'Value too high for "$input"',
          );
        }
      });
    });
  });
}

