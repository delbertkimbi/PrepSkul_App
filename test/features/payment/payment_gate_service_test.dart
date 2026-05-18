import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/payment/models/kyc_verification_state.dart';
import 'package:prepskul/features/payment/services/payment_gate_service.dart';

void main() {
  group('PaymentGateService.destinationFor', () {
    test('online booking always routes to payment', () {
      expect(
        PaymentGateService.destinationFor(
          location: 'online',
          kycState: const KycVerificationState(isVerified: false, status: null),
        ),
        PaymentGateDestination.payment,
      );
      expect(
        PaymentGateService.destinationFor(
          location: 'online',
          kycState: const KycVerificationState(
            isVerified: false,
            status: 'pending',
          ),
        ),
        PaymentGateDestination.payment,
      );
    });

    test('onsite/hybrid verified routes to payment', () {
      for (final loc in ['onsite', 'hybrid', 'ONSITE', 'Hybrid']) {
        expect(
          PaymentGateService.destinationFor(
            location: loc,
            kycState: KycVerificationState.verified,
          ),
          PaymentGateDestination.payment,
          reason: loc,
        );
      }
    });

    test('onsite/hybrid pending routes to kycPending', () {
      for (final loc in ['onsite', 'hybrid']) {
        expect(
          PaymentGateService.destinationFor(
            location: loc,
            kycState: const KycVerificationState(
              isVerified: false,
              status: 'pending',
            ),
          ),
          PaymentGateDestination.kycPending,
          reason: loc,
        );
      }
    });

    test('onsite/hybrid not verified routes to kycIntro', () {
      for (final loc in ['onsite', 'hybrid']) {
        expect(
          PaymentGateService.destinationFor(
            location: loc,
            kycState: const KycVerificationState(isVerified: false, status: null),
          ),
          PaymentGateDestination.kycIntro,
          reason: '$loc no submission',
        );
        expect(
          PaymentGateService.destinationFor(
            location: loc,
            kycState: const KycVerificationState(
              isVerified: false,
              status: 'rejected',
              rejectionReason: 'Blurry ID',
            ),
          ),
          PaymentGateDestination.kycIntro,
          reason: '$loc rejected',
        );
      }
    });
  });
}
