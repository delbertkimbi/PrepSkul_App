import 'dart:async';

import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/core/services/storage_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/payment/models/kyc_verification_state.dart';

/// KYC verification for parent/learner accounts (onsite/hybrid bookings).
class KycVerificationService {
  static final _supabase = SupabaseService.client;

  static bool isOnsiteLikeLocation(String? location) {
    final loc = (location ?? '').trim().toLowerCase();
    return loc == 'onsite' || loc == 'hybrid';
  }

  /// Full verification state for gating payments.
  static Future<KycVerificationState> getVerificationStateForCurrentUser() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select('identity_verified_at')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null && profile['identity_verified_at'] != null) {
        return KycVerificationState.verified;
      }

      final latest = await _supabase
          .from('identity_verifications')
          .select('status, rejection_reason')
          .eq('account_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (latest == null) {
        return const KycVerificationState(isVerified: false, status: null);
      }

      final status = latest['status'] as String? ?? 'pending';
      if (status == 'verified') {
        return KycVerificationState.verified;
      }

      return KycVerificationState(
        isVerified: false,
        status: status,
        rejectionReason: latest['rejection_reason'] as String?,
      );
    } catch (e) {
      LogService.error('Error fetching KYC state: $e');
      rethrow;
    }
  }

  /// Legacy helper — returns map with status for backward compatibility.
  static Future<Map<String, dynamic>?> getLatestVerificationForCurrentUser() async {
    final state = await getVerificationStateForCurrentUser();
    if (state.isVerified) {
      return {'status': 'verified'};
    }
    if (state.status == null) return null;
    return {
      'status': state.status,
      if (state.rejectionReason != null) 'rejection_reason': state.rejectionReason,
    };
  }

  /// Resolve booking location from payment request metadata or booking_requests.
  static Future<String> resolveLocationForPayment({
    required String paymentRequestId,
    String? bookingRequestId,
  }) async {
    try {
      final pr = await _supabase
          .from('payment_requests')
          .select('metadata, booking_request_id')
          .eq('id', paymentRequestId)
          .maybeSingle();

      if (pr != null) {
        final metadata = pr['metadata'];
        if (metadata is Map) {
          final loc = (metadata['location'] as String?)?.trim().toLowerCase();
          if (loc != null && loc.isNotEmpty) return loc;
        }
        bookingRequestId ??= pr['booking_request_id'] as String?;
      }
    } catch (e) {
      LogService.warning('Could not read payment_request metadata: $e');
    }

    if (bookingRequestId != null && bookingRequestId.isNotEmpty) {
      try {
        final booking = await _supabase
            .from('booking_requests')
            .select('location')
            .eq('id', bookingRequestId)
            .maybeSingle();
        return (booking?['location'] as String?)?.trim().toLowerCase() ?? '';
      } catch (e) {
        LogService.warning('Could not read booking_requests.location: $e');
      }
    }
    return '';
  }

  /// Submit verification with all four required assets.
  static Future<Map<String, dynamic>> submitVerification({
    required String documentType,
    required String whoseId,
    String? relationship,
    required dynamic frontFile,
    required dynamic backFile,
    required dynamic holdingFile,
    required dynamic locationFile,
    String? bookingRequestId,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final userId = user.id;

    try {
      final frontUrl = await StorageService.uploadDocument(
        userId: userId,
        documentFile: frontFile,
        documentType: 'kyc_front',
      );
      final backUrl = await StorageService.uploadDocument(
        userId: userId,
        documentFile: backFile,
        documentType: 'kyc_back',
      );
      final holdingUrl = await StorageService.uploadDocument(
        userId: userId,
        documentFile: holdingFile,
        documentType: 'kyc_holding',
      );
      final locationUrl = await StorageService.uploadDocument(
        userId: userId,
        documentFile: locationFile,
        documentType: 'kyc_location',
      );

      final payload = <String, dynamic>{
        'account_id': userId,
        'document_type': documentType,
        'whose_id': whoseId,
        'front_url': frontUrl,
        'back_url': backUrl,
        'holding_id_url': holdingUrl,
        'location_photo_url': locationUrl,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        if (relationship != null && relationship.trim().isNotEmpty)
          'relationship': relationship.trim(),
        if (bookingRequestId != null && bookingRequestId.isNotEmpty)
          'booking_request_id': bookingRequestId,
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

      final verificationId = inserted['id'] as String?;
      if (verificationId != null) {
        String? accountName;
        try {
          final profile = await _supabase
              .from('profiles')
              .select('full_name, email')
              .eq('id', userId)
              .maybeSingle();
          accountName = profile?['full_name'] as String? ??
              profile?['email'] as String?;
        } catch (_) {}

        unawaited(
          NotificationHelperService.notifyAdminsAboutIdentityVerificationSubmitted(
            verificationId: verificationId,
            accountId: userId,
            accountName: accountName,
            documentType: documentType,
            bookingRequestId: bookingRequestId,
          ),
        );
      }

      return Map<String, dynamic>.from(inserted as Map);
    } catch (e) {
      LogService.error('Error submitting KYC verification: $e');
      rethrow;
    }
  }
}
