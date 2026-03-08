import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/storage_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// KYC (Know Your Customer) verification service for parent/learner accounts.
///
/// - Stores identity documents in the private `documents` bucket
/// - Writes to `identity_verifications` table
/// - Reads `profiles.identity_verified_at` to know if account is already verified
class KycVerificationService {
  static final _supabase = SupabaseService.client;

  /// Get the latest identity verification record for the current user, plus
  /// a quick "isVerified" flag derived from profiles.identity_verified_at.
  ///
  /// Returns:
  /// - null if no verification exists and profile is not marked verified
  /// - a Map with at least `status` when a record exists
  static Future<Map<String, dynamic>?> getLatestVerificationForCurrentUser() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final userId = user.id;

    try {
      // First, check if profile is already marked as identity verified
      final profile = await _supabase
          .from('profiles')
          .select('id, identity_verified_at')
          .eq('id', userId)
          .maybeSingle();

      if (profile != null && profile['identity_verified_at'] != null) {
        return {
          'status': 'verified',
          'identity_verified_at': profile['identity_verified_at'],
        };
      }

      // Otherwise, fetch most recent KYC record (if any)
      final latest = await _supabase
          .from('identity_verifications')
          .select('*')
          .eq('account_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (latest == null) return null;
      return Map<String, dynamic>.from(latest as Map);
    } catch (e) {
      LogService.error('Error fetching latest KYC verification: $e');
      rethrow;
    }
  }

  /// Submit a new identity verification request for the current user.
  ///
  /// - Uploads front (and optional back) of ID using StorageService.uploadDocument
  /// - Creates a pending record in `identity_verifications`
  /// - Returns the created record
  static Future<Map<String, dynamic>> submitVerification({
    required String documentType, // 'national_id', 'passport', 'voter_card', 'drivers_licence', 'residence_permit', 'other'
    required String whoseId, // 'self', 'parent_guardian', 'other_adult'
    String? relationship, // e.g. 'mother', 'guardian'
    required dynamic frontFile,
    dynamic backFile,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final userId = user.id;

    try {
      // Upload front of ID
      final frontUrl = await StorageService.uploadDocument(
        userId: userId,
        documentFile: frontFile,
        documentType: 'kyc_front',
      );

      // Upload back of ID (optional)
      String? backUrl;
      if (backFile != null) {
        backUrl = await StorageService.uploadDocument(
          userId: userId,
          documentFile: backFile,
          documentType: 'kyc_back',
        );
      }

      final payload = <String, dynamic>{
        'account_id': userId,
        'document_type': documentType,
        'whose_id': whoseId,
        'front_url': frontUrl,
        if (backUrl != null) 'back_url': backUrl,
        if (relationship != null && relationship.trim().isNotEmpty)
          'relationship': relationship.trim(),
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final inserted = await _supabase
          .from('identity_verifications')
          .insert(payload)
          .select()
          .maybeSingle();

      if (inserted == null) {
        throw Exception('Failed to create identity verification record');
      }

      LogService.success('KYC verification submitted for user: $userId');
      return Map<String, dynamic>.from(inserted as Map);
    } catch (e) {
      LogService.error('Error submitting KYC verification: $e');
      rethrow;
    }
  }
}

