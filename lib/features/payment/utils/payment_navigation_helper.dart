import 'package:flutter/material.dart';
import 'package:prepskul/features/payment/screens/booking_payment_screen.dart';
import 'package:prepskul/features/payment/screens/identity_verification_flow_screen.dart';
import 'package:prepskul/features/payment/services/payment_gate_service.dart';

/// Routes Pay Now to checkout or the onsite KYC wizard based on verification state.
class PaymentNavigationHelper {
  PaymentNavigationHelper._();

  /// Returns navigator result (e.g. `true` when payment succeeded).
  static Future<dynamic> openPayFlow(
    BuildContext context, {
    required String paymentRequestId,
    String? bookingRequestId,
    String? locationOverride,
  }) async {
    final destination = await PaymentGateService.resolve(
      paymentRequestId: paymentRequestId,
      bookingRequestId: bookingRequestId,
      locationOverride: locationOverride,
    );

    switch (destination) {
      case PaymentGateDestination.payment:
        return Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingPaymentScreen(
              paymentRequestId: paymentRequestId,
              bookingRequestId: bookingRequestId,
            ),
          ),
        );
      case PaymentGateDestination.kycIntro:
        return Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IdentityVerificationFlowScreen(
              paymentRequestId: paymentRequestId,
              bookingRequestId: bookingRequestId,
              mode: IdentityVerificationMode.wizard,
            ),
          ),
        );
      case PaymentGateDestination.kycPending:
        return Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IdentityVerificationFlowScreen(
              paymentRequestId: paymentRequestId,
              bookingRequestId: bookingRequestId,
              mode: IdentityVerificationMode.pending,
            ),
          ),
        );
    }
  }
}
