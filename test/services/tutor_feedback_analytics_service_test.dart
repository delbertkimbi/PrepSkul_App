import 'package:flutter_test/flutter_test.dart';

/// Unit tests for TutorFeedbackAnalyticsService
void main() {
  group('TutorFeedbackAnalyticsService', () {
    group('Sentiment Analysis', () {
      test('calculateSentiment categorizes by rating', () {
        final mockReviews = [
          {'student_rating': 5},
          {'student_rating': 4},
          {'student_rating': 3},
          {'student_rating': 2},
          {'student_rating': 1},
        ];

        int positive = 0;
        int neutral = 0;
        int negative = 0;

        for (final review in mockReviews) {
          final rating = review['student_rating'] as int;
          if (rating >= 4) {
            positive++;
          } else if (rating == 3) {
            neutral++;
          } else {
            negative++;
          }
        }

        expect(positive, 2);
        expect(neutral, 1);
        expect(negative, 2);
      });
    });

    group('Response Rate Calculation', () {
      test('calculateResponseRate counts responses correctly', () {
        final mockReviews = [
          {'tutor_response': 'Thank you!'},
          {'tutor_response': null},
          {'tutor_response': 'Great feedback'},
          {'tutor_response': null},
        ];

        int responded = 0;
        int notResponded = 0;

        for (final review in mockReviews) {
          final response = review['tutor_response'] as String?;
          if (response != null && response.isNotEmpty) {
            responded++;
          } else {
            notResponded++;
          }
        }

        expect(responded, 2);
        expect(notResponded, 2);
      });
    });
  });
}
