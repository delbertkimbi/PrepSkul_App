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
  final double? amount; // Payment amount in XAF

  const PaymentInstructionsWidget({
    Key? key,
    required this.provider,
    required this.phoneNumber,
    this.amount,
  }) : super(key: key);

  /// Get payment instructions for the provider
  List<String> _getPaymentInstructions(String? provider) {
    final amountText = amount != null 
        ? '${amount!.toStringAsFixed(0)} XAF'
        : 'the amount';
    
    if (provider == null) {
      return [
        'Dial the USSD code on your phone',
        'Enter your PIN code when prompted',
        'Confirm payment of $amountText',
      ];
    }
    
    switch (provider.toLowerCase()) {
      case 'mtn':
        return [
          'Dial *126# on your MTN phone',
          'Enter your PIN code when prompted',
          'Confirm payment of $amountText',
        ];
      case 'orange':
        return [
          'Dial *144# on your Orange phone',
          'Enter your PIN code when prompted',
          'Confirm payment of $amountText',
        ];
      default:
        return [
          'Dial the USSD code on your phone',
          'Enter your PIN code when prompted',
          'Confirm payment of $amountText',
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
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.15),
            width: 1,
          ),
          // Soft shadow (not elevated)
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
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
                height: 120, // Increased from 90 for better visibility
                width: 120,  // Increased from 90 for better visibility
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Confirm Payment',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              providerName,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            
            // USSD Code Highlight
            if (ussdCode.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
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
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Dial $ussdCode',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Step-by-step instructions
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Follow these steps:',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ...instructions.asMap().entries.map((entry) {
              final index = entry.key;
              final instruction = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
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
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            
            const SizedBox(height: 20),
            
            // Helpful tip
            Container(
              padding: const EdgeInsets.all(14),
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
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tip',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Check your phone ($phoneNumber) for the payment notification. You have 2 minutes to confirm.',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade700,
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
