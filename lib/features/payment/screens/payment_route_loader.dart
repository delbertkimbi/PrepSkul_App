import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/payment/screens/booking_payment_screen.dart';
import 'package:prepskul/features/payment/screens/identity_verification_flow_screen.dart';
import 'package:prepskul/features/payment/services/payment_gate_service.dart';

/// Resolves KYC gate then shows checkout or verification wizard (for deep links).
class PaymentRouteLoader extends StatefulWidget {
  final String paymentRequestId;
  final String? bookingRequestId;

  const PaymentRouteLoader({
    super.key,
    required this.paymentRequestId,
    this.bookingRequestId,
  });

  @override
  State<PaymentRouteLoader> createState() => _PaymentRouteLoaderState();
}

class _PaymentRouteLoaderState extends State<PaymentRouteLoader> {
  late Future<PaymentGateDestination> _destinationFuture;

  @override
  void initState() {
    super.initState();
    _destinationFuture = PaymentGateService.resolve(
      paymentRequestId: widget.paymentRequestId,
      bookingRequestId: widget.bookingRequestId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PaymentGateDestination>(
      future: _destinationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: AppTheme.softBackground,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading payment…',
                    style: GoogleFonts.poppins(color: AppTheme.textMedium),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Payment')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load payment: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(),
                ),
              ),
            ),
          );
        }

        switch (snapshot.data!) {
          case PaymentGateDestination.payment:
            return BookingPaymentScreen(
              paymentRequestId: widget.paymentRequestId,
              bookingRequestId: widget.bookingRequestId,
            );
          case PaymentGateDestination.kycIntro:
            return IdentityVerificationFlowScreen(
              paymentRequestId: widget.paymentRequestId,
              bookingRequestId: widget.bookingRequestId,
              mode: IdentityVerificationMode.wizard,
            );
          case PaymentGateDestination.kycPending:
            return IdentityVerificationFlowScreen(
              paymentRequestId: widget.paymentRequestId,
              bookingRequestId: widget.bookingRequestId,
              mode: IdentityVerificationMode.pending,
            );
        }
      },
    );
  }
}
