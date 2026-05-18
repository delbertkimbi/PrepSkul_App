import 'package:prepskul/features/payment/models/kyc_verification_state.dart';
import 'package:prepskul/features/payment/services/kyc_verification_service.dart';

/// Where Pay Now should route for a given booking/payment context.
enum PaymentGateDestination {
  /// Proceed to mobile money checkout.
  payment,

  /// Start or resume the identity verification wizard (intro / upload).
  kycIntro,

  /// Show read-only pending review screen.
  kycPending,
}

class PaymentGateService {
  PaymentGateService._();

  /// Pure routing from location + verification state (for tests).
  static PaymentGateDestination destinationFor({
    required String location,
    required KycVerificationState kycState,
  }) {
    if (!KycVerificationService.isOnsiteLikeLocation(location)) {
      return PaymentGateDestination.payment;
    }
    if (kycState.isVerified) {
      return PaymentGateDestination.payment;
    }
    if (kycState.isPending) {
      return PaymentGateDestination.kycPending;
    }
    return PaymentGateDestination.kycIntro;
  }

  /// Resolve destination before opening checkout or KYC wizard.
  static Future<PaymentGateDestination> resolve({
    required String paymentRequestId,
    String? bookingRequestId,
    String? locationOverride,
  }) async {
    final location = locationOverride ??
        await KycVerificationService.resolveLocationForPayment(
          paymentRequestId: paymentRequestId,
          bookingRequestId: bookingRequestId,
        );

    final kycState = await KycVerificationService.getVerificationStateForCurrentUser();
    return destinationFor(location: location, kycState: kycState);
  }
}
