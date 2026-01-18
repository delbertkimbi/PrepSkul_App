import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/messaging/models/conversation_model.dart';

void main() {
  group('Conversation', () {
    group('fromJson', () {
      test('should parse valid JSON correctly', () {
        final json = {
          'id': 'conv-123',
          'student_id': 'student-123',
          'tutor_id': 'tutor-123',
          'trial_session_id': 'trial-123',
          'status': 'active',
          'created_at': '2024-01-01T12:00:00Z',
          'updated_at': '2024-01-01T12:00:00Z',
          'last_message_at': '2024-01-01T12:30:00Z',
          'expires_at': '2024-01-02T12:00:00Z',
          'other_user_name': 'John Doe',
          'other_user_avatar_url': 'https://example.com/student.jpg',
        };

        final conversation = Conversation.fromJson(json);

        expect(conversation.id, 'conv-123');
        expect(conversation.studentId, 'student-123');
        expect(conversation.tutorId, 'tutor-123');
        expect(conversation.trialSessionId, 'trial-123');
        expect(conversation.status, 'active');
        expect(conversation.otherUserName, 'John Doe');
        expect(conversation.otherUserAvatarUrl, 'https://example.com/student.jpg');
      });

      test('should handle context linking (trial/booking/recurring)', () {
        // Test trial session linking
        final trialJson = {
          'id': 'conv-123',
          'student_id': 'student-123',
          'tutor_id': 'tutor-123',
          'trial_session_id': 'trial-123',
          'status': 'active',
          'created_at': '2024-01-01T12:00:00Z',
        };

        final trialConv = Conversation.fromJson(trialJson);
        expect(trialConv.trialSessionId, 'trial-123');
        expect(trialConv.bookingRequestId, isNull);

        // Test booking request linking
        final bookingJson = {
          'id': 'conv-456',
          'student_id': 'student-123',
          'tutor_id': 'tutor-123',
          'booking_request_id': 'booking-123',
          'status': 'active',
          'created_at': '2024-01-01T12:00:00Z',
        };

        final bookingConv = Conversation.fromJson(bookingJson);
        expect(bookingConv.bookingRequestId, 'booking-123');
        expect(bookingConv.trialSessionId, isNull);
      });

      test('should handle missing optional fields', () {
        final json = {
          'id': 'conv-123',
          'student_id': 'student-123',
          'tutor_id': 'tutor-123',
          'status': 'active',
          'created_at': '2024-01-01T12:00:00Z',
        };

        final conversation = Conversation.fromJson(json);

        expect(conversation.id, 'conv-123');
        expect(conversation.trialSessionId, isNull);
        expect(conversation.expiresAt, isNull);
        expect(conversation.otherUserName, isNull);
        expect(conversation.unreadCount, 0); // Default value
      });
    });

    group('toJson', () {
      test('should serialize conversation correctly', () {
        final conversation = Conversation(
          id: 'conv-123',
          studentId: 'student-123',
          tutorId: 'tutor-123',
          trialSessionId: 'trial-123',
          status: 'active',
          createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
        );

        final json = conversation.toJson();

        expect(json['id'], 'conv-123');
        expect(json['student_id'], 'student-123');
        expect(json['tutor_id'], 'tutor-123');
        expect(json['trial_session_id'], 'trial-123');
        expect(json['status'], 'active');
      });
    });

    group('isActive', () {
      test('should return true for active conversation without expiration', () {
        final conversation = Conversation(
          id: 'conv-123',
          studentId: 'student-123',
          tutorId: 'tutor-123',
          status: 'active',
          createdAt: DateTime.now(),
        );

        expect(conversation.isActive, true);
      });

      test('should return true for active conversation with future expiration', () {
        final conversation = Conversation(
          id: 'conv-123',
          studentId: 'student-123',
          tutorId: 'tutor-123',
          status: 'active',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 1)),
        );

        expect(conversation.isActive, true);
      });

      test('should return false for expired conversation', () {
        final conversation = Conversation(
          id: 'conv-123',
          studentId: 'student-123',
          tutorId: 'tutor-123',
          status: 'active',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        );

        expect(conversation.isActive, false);
      });

      test('should return false for non-active status', () {
        final conversation = Conversation(
          id: 'conv-123',
          studentId: 'student-123',
          tutorId: 'tutor-123',
          status: 'closed',
          createdAt: DateTime.now(),
        );

        expect(conversation.isActive, false);
      });
    });

    group('getOtherUserId', () {
      test('should return tutor ID when current user is student', () {
        final conversation = Conversation(
          id: 'conv-123',
          studentId: 'student-123',
          tutorId: 'tutor-123',
          status: 'active',
          createdAt: DateTime.now(),
        );

        expect(conversation.getOtherUserId('student-123'), 'tutor-123');
      });

      test('should return student ID when current user is tutor', () {
        final conversation = Conversation(
          id: 'conv-123',
          studentId: 'student-123',
          tutorId: 'tutor-123',
          status: 'active',
          createdAt: DateTime.now(),
        );

        expect(conversation.getOtherUserId('tutor-123'), 'student-123');
      });
    });
  });
}
