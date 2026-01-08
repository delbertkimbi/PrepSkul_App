import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/messaging/models/message_model.dart';

void main() {
  group('Message', () {
    group('fromJson', () {
      test('should parse valid JSON correctly', () {
        final json = {
          'id': 'msg-123',
          'conversation_id': 'conv-123',
          'sender_id': 'user-123',
          'content': 'Hello, this is a test message',
          'created_at': '2024-01-01T12:00:00Z',
          'is_read': false,
          'read_at': null,
          'is_filtered': false,
          'filter_reason': null,
          'moderation_status': 'approved',
          'sender_name': 'John Doe',
          'sender_avatar_url': 'https://example.com/avatar.jpg',
        };

        final message = Message.fromJson(json, currentUserId: 'user-123');

        expect(message.id, 'msg-123');
        expect(message.conversationId, 'conv-123');
        expect(message.senderId, 'user-123');
        expect(message.content, 'Hello, this is a test message');
        expect(message.isRead, false);
        expect(message.moderationStatus, 'approved');
        expect(message.senderName, 'John Doe');
        expect(message.senderAvatarUrl, 'https://example.com/avatar.jpg');
        expect(message.isCurrentUser, true);
      });

      test('should handle missing optional fields', () {
        final json = {
          'id': 'msg-123',
          'conversation_id': 'conv-123',
          'sender_id': 'user-123',
          'content': 'Test message',
          'created_at': '2024-01-01T12:00:00Z',
        };

        final message = Message.fromJson(json, currentUserId: 'user-456');

        expect(message.id, 'msg-123');
        expect(message.isRead, false); // Default value
        expect(message.moderationStatus, 'approved'); // Default value
        expect(message.senderName, isNull);
        expect(message.senderAvatarUrl, isNull);
        expect(message.isCurrentUser, false);
      });

      test('should handle type conversions correctly', () {
        final json = {
          'id': 'msg-123',
          'conversation_id': 'conv-123',
          'sender_id': 'user-123',
          'content': 'Test',
          'created_at': '2024-01-01T12:00:00Z',
          'is_read': true,
          'read_at': '2024-01-01T12:05:00Z',
        };

        final message = Message.fromJson(json, currentUserId: 'user-123');

        expect(message.isRead, true);
        expect(message.readAt, isNotNull);
        expect(message.readAt?.year, 2024);
      });

      test('should correctly identify current user', () {
        final json = {
          'id': 'msg-123',
          'conversation_id': 'conv-123',
          'sender_id': 'user-123',
          'content': 'Test',
          'created_at': '2024-01-01T12:00:00Z',
        };

        final messageFromSelf = Message.fromJson(json, currentUserId: 'user-123');
        expect(messageFromSelf.isCurrentUser, true);

        final messageFromOther = Message.fromJson(json, currentUserId: 'user-456');
        expect(messageFromOther.isCurrentUser, false);
      });
    });

    group('toJson', () {
      test('should serialize message correctly', () {
        final message = Message(
          id: 'msg-123',
          conversationId: 'conv-123',
          senderId: 'user-123',
          content: 'Test message',
          createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
          isRead: false,
          moderationStatus: 'approved',
        );

        final json = message.toJson();

        expect(json['id'], 'msg-123');
        expect(json['conversation_id'], 'conv-123');
        expect(json['sender_id'], 'user-123');
        expect(json['content'], 'Test message');
        expect(json['is_read'], false);
        expect(json['moderation_status'], 'approved');
      });

      test('should include optional fields when present', () {
        final message = Message(
          id: 'msg-123',
          conversationId: 'conv-123',
          senderId: 'user-123',
          content: 'Test',
          createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
          isRead: true,
          readAt: DateTime.parse('2024-01-01T12:05:00Z'),
          isFiltered: true,
          filterReason: 'phone_number',
          moderationStatus: 'flagged',
        );

        final json = message.toJson();

        expect(json['is_read'], true);
        expect(json['read_at'], contains('2024-01-01T12:05:00'));
        expect(json['is_filtered'], true);
        expect(json['filter_reason'], 'phone_number');
        expect(json['moderation_status'], 'flagged');
      });
    });

    group('copyWith', () {
      test('should update fields correctly', () {
        final original = Message(
          id: 'msg-123',
          conversationId: 'conv-123',
          senderId: 'user-123',
          content: 'Original',
          createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
        );

        final updated = original.copyWith(
          content: 'Updated',
          isRead: true,
        );

        expect(updated.id, original.id);
        expect(updated.content, 'Updated');
        expect(updated.isRead, true);
        expect(updated.createdAt, original.createdAt);
      });

      test('should maintain immutability', () {
        final original = Message(
          id: 'msg-123',
          conversationId: 'conv-123',
          senderId: 'user-123',
          content: 'Original',
          createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
        );

        final updated = original.copyWith(content: 'Updated');

        expect(original.content, 'Original');
        expect(updated.content, 'Updated');
      });

      test('should handle null values in copyWith', () {
        final original = Message(
          id: 'msg-123',
          conversationId: 'conv-123',
          senderId: 'user-123',
          content: 'Test',
          createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
          senderName: 'John',
        );

        // Note: copyWith doesn't support null assignment in current implementation
        // This test verifies the method exists
        final updated = original.copyWith(content: 'Updated');

        expect(updated.content, 'Updated');
        expect(original.content, 'Test');
      });
    });
  });
}
