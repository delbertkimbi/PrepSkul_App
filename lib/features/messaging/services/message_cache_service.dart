import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/log_service.dart';
import '../models/message_model.dart';

/// Message Cache Service
/// 
/// Caches messages locally for offline access and faster initial loads
/// Uses SharedPreferences for simple key-value storage
/// 
/// Cache Strategy:
/// - Cache messages per conversation
/// - Cache with timestamps for expiration
/// - Serve from cache on initial load, then sync
/// - Update cache on real-time events
/// - Expiration: 24 hours (messages are more time-sensitive than other data)

class MessageCacheService {
  // Cache key prefix
  static const String _keyPrefix = 'cached_messages_';
  static const String _keyTimestampSuffix = '_cache_timestamp';
  
  // Cache expiration (24 hours - messages are time-sensitive)
  static const Duration _cacheExpiration = Duration(hours: 24);

  /// Cache messages for a conversation
  static Future<void> cacheMessages(String conversationId, List<Message> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert messages to JSON
      final messagesJson = messages.map((m) => m.toJson()).toList();
      final json = jsonEncode(messagesJson);
      
      // Store messages and timestamp
      final cacheKey = '$_keyPrefix$conversationId';
      await prefs.setString(cacheKey, json);
      await prefs.setInt('$cacheKey$_keyTimestampSuffix', DateTime.now().millisecondsSinceEpoch);
      
      LogService.success('Cached ${messages.length} messages for conversation: $conversationId');
    } catch (e) {
      LogService.error('Error caching messages: $e');
    }
  }

  /// Get cached messages for a conversation
  static Future<List<Message>?> getCachedMessages(String conversationId, {String? currentUserId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_keyPrefix$conversationId';
      final json = prefs.getString(cacheKey);
      final timestamp = prefs.getInt('$cacheKey$_keyTimestampSuffix') ?? 0;
      
      if (json == null) return null;
      
      // Check if cache is expired
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _cacheExpiration) {
        LogService.warning('Message cache expired for conversation: $conversationId');
        return null;
      }

      // Parse messages from JSON
      final List<dynamic> decoded = jsonDecode(json);
      final messages = decoded.map((m) {
        try {
          return Message.fromJson(Map<String, dynamic>.from(m), currentUserId: currentUserId);
        } catch (e) {
          LogService.error('Error parsing cached message: $e');
          return null;
        }
      }).whereType<Message>().toList();
      
      LogService.success('Retrieved ${messages.length} messages from cache for conversation: $conversationId');
      return messages;
    } catch (e) {
      LogService.error('Error getting cached messages: $e');
      return null;
    }
  }

  /// Update a single message in cache (for real-time updates)
  static Future<void> updateCachedMessage(String conversationId, Message message) async {
    try {
      final cachedMessages = await getCachedMessages(conversationId);
      if (cachedMessages == null) {
        // No cache exists, can't update
        return;
      }

      // Find and update the message
      final index = cachedMessages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        cachedMessages[index] = message;
      } else {
        // Message not in cache, add it
        cachedMessages.add(message);
        // Sort by creation time
        cachedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }

      // Save updated cache
      await cacheMessages(conversationId, cachedMessages);
    } catch (e) {
      LogService.error('Error updating cached message: $e');
    }
  }

  /// Add a new message to cache (for real-time inserts)
  static Future<void> addCachedMessage(String conversationId, Message message) async {
    try {
      final cachedMessages = await getCachedMessages(conversationId) ?? [];
      
      // Check if message already exists (avoid duplicates)
      if (cachedMessages.any((m) => m.id == message.id)) {
        // Update instead of adding duplicate
        await updateCachedMessage(conversationId, message);
        return;
      }

      // Add message and sort
      cachedMessages.add(message);
      cachedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Save updated cache
      await cacheMessages(conversationId, cachedMessages);
    } catch (e) {
      LogService.error('Error adding cached message: $e');
    }
  }

  /// Remove a message from cache (for real-time deletes)
  static Future<void> removeCachedMessage(String conversationId, String messageId) async {
    try {
      final cachedMessages = await getCachedMessages(conversationId);
      if (cachedMessages == null) return;

      // Remove message
      cachedMessages.removeWhere((m) => m.id == messageId);

      // Save updated cache
      await cacheMessages(conversationId, cachedMessages);
    } catch (e) {
      LogService.error('Error removing cached message: $e');
    }
  }

  /// Clear cache for a specific conversation
  static Future<void> clearConversationCache(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_keyPrefix$conversationId';
      await prefs.remove(cacheKey);
      await prefs.remove('$cacheKey$_keyTimestampSuffix');
      LogService.success('Cleared message cache for conversation: $conversationId');
    } catch (e) {
      LogService.error('Error clearing conversation cache: $e');
    }
  }

  /// Clear all message caches
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_keyPrefix) || key.contains('$_keyPrefix') && key.contains(_keyTimestampSuffix)) {
          await prefs.remove(key);
        }
      }
      LogService.success('Cleared all message caches');
    } catch (e) {
      LogService.error('Error clearing all message caches: $e');
    }
  }

  /// Get cache timestamp for a conversation
  static Future<DateTime?> getCacheTimestamp(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_keyPrefix$conversationId';
      final timestamp = prefs.getInt('$cacheKey$_keyTimestampSuffix');
      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      return null;
    }
  }
}
