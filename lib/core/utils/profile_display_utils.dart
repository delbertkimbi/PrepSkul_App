import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/storage_service.dart';

/// Shared helpers for profile names and avatar URLs (signed URL refresh).
class ProfileDisplayUtils {
  ProfileDisplayUtils._();

  static bool isGenericName(String? value) {
    if (value == null) return true;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    final lower = trimmed.toLowerCase();
    return lower == 'user' ||
        lower == 'student' ||
        lower == 'player' ||
        lower == 'unknown';
  }

  static String? displayNameFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return null;

    final fullName = (profile['full_name'] as String?)?.trim();
    if (!isGenericName(fullName)) return fullName;

    final email = (profile['email'] as String?)?.trim();
    if (email != null && email.contains('@')) {
      final local = email.split('@').first.trim();
      if (!isGenericName(local)) return _prettifyToken(local);
    }
    return null;
  }

  static String resolveDisplayName({
    String? primary,
    Map<String, dynamic>? profile,
    String fallback = 'Player',
  }) {
    final trimmed = primary?.trim();
    if (!isGenericName(trimmed)) return trimmed!;

    final fromProfile = displayNameFromProfile(profile);
    if (fromProfile != null) return fromProfile;

    return fallback;
  }

  /// Returns a loadable URL for avatars stored as paths or expired signed URLs.
  static Future<String?> resolveAvatarUrl(
    String? raw, {
    String? userId,
  }) async {
    if (raw == null || raw.trim().isEmpty) {
      return _avatarFromUserId(userId);
    }

    final trimmed = raw.trim();
    final storage = _parseStorageLocation(trimmed, userId: userId);
    if (storage != null) {
      try {
        if (storage.bucket == StorageService.profilePhotosBucket) {
          return SupabaseService.client.storage
              .from(storage.bucket)
              .getPublicUrl(storage.path);
        }
        return await SupabaseService.client.storage
            .from(storage.bucket)
            .createSignedUrl(storage.path, 3600 * 24 * 7);
      } catch (e) {
        LogService.debug('Avatar signed URL refresh failed: $e');
      }
    }

    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('//')) {
      return trimmed;
    }

    return _avatarFromUserId(userId);
  }

  static Future<Map<String, String>> resolveAvatarUrlsForUsers(
    Map<String, String?> rawByUserId,
  ) async {
    final resolved = <String, String>{};
    for (final entry in rawByUserId.entries) {
      final url = await resolveAvatarUrl(entry.value, userId: entry.key);
      if (url != null && url.isNotEmpty) {
        resolved[entry.key] = url;
      }
    }
    return resolved;
  }

  static Future<String?> _avatarFromUserId(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    for (final candidate in <String>[
      '$userId/profile_picture.png',
      '$userId/avatar.jpg',
      '$userId/avatar.png',
    ]) {
      try {
        return await SupabaseService.client.storage
            .from(StorageService.documentsBucket)
            .createSignedUrl(candidate, 3600 * 24 * 7);
      } catch (_) {
        try {
          return SupabaseService.client.storage
              .from(StorageService.profilePhotosBucket)
              .getPublicUrl(candidate.replaceFirst('$userId/', '$userId/'));
        } catch (_) {}
      }
    }
    return null;
  }

  static _StorageRef? _parseStorageLocation(
    String value, {
    String? userId,
  }) {
    final objectPrefix = '/storage/v1/object/';
    final idx = value.indexOf(objectPrefix);
    if (idx >= 0) {
      final tail = value.substring(idx + objectPrefix.length);
      final parts = tail.split('/');
      if (parts.length >= 2) {
        final access = parts.first;
        if (access == 'public' || access == 'sign' || access == 'authenticated') {
          final bucket = parts[1];
          final path = parts.sublist(2).join('/').split('?').first;
          if (bucket.isNotEmpty && path.isNotEmpty) {
            return _StorageRef(bucket: bucket, path: path);
          }
        }
      }
    }

    if (!value.startsWith('http') && value.contains('/')) {
      return _StorageRef(
        bucket: StorageService.documentsBucket,
        path: value,
      );
    }

    if (userId != null && userId.isNotEmpty && !value.startsWith('http')) {
      return _StorageRef(
        bucket: StorageService.documentsBucket,
        path: '$userId/$value',
      );
    }
    return null;
  }

  static String _prettifyToken(String token) {
    return token
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          return part[0].toUpperCase() + part.substring(1).toLowerCase();
        })
        .join(' ');
  }
}

class _StorageRef {
  final String bucket;
  final String path;

  const _StorageRef({required this.bucket, required this.path});
}
