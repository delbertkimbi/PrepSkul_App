import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/payment/utils/payment_provider_helper.dart';

/// Payment Instructions Widget
/// 
/// Displays provider-specific instructions for confirming payment
/// Shows USSD code and step-by-step guide
class PaymentInstructionsWidget extends StatelessWidget {
  final String? provider;
  final String phoneNumber;

  const PaymentInstructionsWidget({
    Key? key,
    required this.provider,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final providerName = PaymentProviderHelper.getProviderName(provider);
    final ussdCode = PaymentProviderHelper.getUssdCode(provider);
    final providerColor = PaymentProviderHelper.getProviderColor(provider);
    final providerIcon = PaymentProviderHelper.getProviderIcon(provider);
    final instructions = PaymentProviderHelper.getPaymentInstructions(provider);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: providerColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: providerColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with provider info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: providerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  providerIcon,
                  color: providerColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirm Payment',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      providerName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // USSD Code Highlight
          if (ussdCode.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: providerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: providerColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone,
                    color: providerColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Dial $ussdCode',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: providerColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Step-by-step instructions
          Text(
            'Follow these steps:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          ...instructions.asMap().entries.map((entry) {
            final index = entry.key;
            final instruction = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: providerColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      instruction,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          
          const SizedBox(height: 16),
          
          // Helpful tips
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blue.shade200,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tip:',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Check your phone ($phoneNumber) for the payment notification. You have 2 minutes to confirm.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

