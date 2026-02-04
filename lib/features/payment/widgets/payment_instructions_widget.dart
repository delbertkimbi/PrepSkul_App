import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/payment/utils/payment_provider_helper.dart';

/// Payment Instructions Widget
/// 
/// Displays provider-specific instructions for confirming payment
/// Shows USSD code and step-by-step guide in a centered, soft card
class PaymentInstructionsWidget extends StatelessWidget {
  final String? provider; // 'mtn' or 'orange'
  final String phoneNumber;
  final double? amount; // Optional amount to display in instructions

  const PaymentInstructionsWidget({
    Key? key,
    required this.provider,
    required this.phoneNumber,
    this.amount,
  }) : super(key: key);

  /// Get payment instructions for the provider
  List<String> _getPaymentInstructions(String? provider) {
    if (provider == null) {
      return [
        'Dial the USSD code on your phone',
        'Select "Pay" or "Payment" from the menu',
        'Enter the amount when prompted',
        'Confirm the payment',
      ];
    }
    
    switch (provider.toLowerCase()) {
      case 'mtn':
        return [
          'Dial *126# on your MTN phone',
          'Select "Pay" from the menu',
          'Enter the amount when prompted',
          'Confirm the payment',
        ];
      case 'orange':
        return [
          'Dial *144# on your Orange phone',
          'Select "Pay" or "Payment" from the menu',
          'Enter the amount when prompted',
          'Confirm the payment',
        ];
      default:
        return [
          'Dial the USSD code on your phone',
          'Select "Pay" or "Payment" from the menu',
          'Enter the amount when prompted',
          'Confirm the payment',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (provider == null) {
      return _buildGenericInstructions();
    }

    final providerName = PaymentProviderHelper.getProviderName(provider);
    final ussdCode = PaymentProviderHelper.getUSSDCode(provider);
    final instructions = _getPaymentInstructions(provider);
    
    // Determine logo path based on provider
    final logoPath = provider == 'mtn'
        ? 'assets/images/mtn-logo.png'
        : provider == 'orange'
            ? 'assets/images/orange-logo.png'
            : null;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.softBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header with logo and title
            if (logoPath != null) ...[
              Image.asset(
                logoPath,
                height: 60,
                width: 60,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Confirm Payment',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              providerName,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textMedium,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            
            // USSD Code Highlight
            if (ussdCode.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.phone,
                      color: AppTheme.primaryColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dial $ussdCode',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Step-by-step instructions
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Follow these steps:',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...instructions.asMap().entries.map((entry) {
              final index = entry.key;
              final instruction = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        instruction,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textMedium,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            
            const SizedBox(height: 16),
            
            // Helpful tip
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Check your phone ($phoneNumber) for the payment notification. You have 2 minutes to confirm.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textMedium,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep({
    required int step,
    required String text,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step number badge
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Icon
        Icon(
          icon,
          size: 20,
          color: color.withOpacity(0.7),
        ),
        const SizedBox(width: 8),
        // Text
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textDark,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenericInstructions() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Instructions',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'A payment request will be sent to $phoneNumber. Please approve it in your mobile money app to complete the payment.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
