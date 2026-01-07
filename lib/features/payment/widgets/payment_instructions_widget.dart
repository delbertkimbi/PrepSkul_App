import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/payment/utils/payment_provider_helper.dart';

/// Payment Instructions Widget
/// 
/// Displays provider-specific payment instructions with step-by-step guide
class PaymentInstructionsWidget extends StatelessWidget {
  final String? provider; // 'mtn' or 'orange'
  final String phoneNumber;

  const PaymentInstructionsWidget({
    Key? key,
    required this.provider,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (provider == null) {
      return _buildGenericInstructions();
    }

    final providerName = PaymentProviderHelper.getProviderName(provider);
    final providerColor = PaymentProviderHelper.getProviderColor(provider);
    final providerIcon = PaymentProviderHelper.getProviderIcon(provider);
    final ussdCode = PaymentProviderHelper.getUSSDCode(provider);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: providerColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: providerColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Provider Header
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
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay with $providerName',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: providerColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phoneNumber,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Instructions Title
          Text(
            'Payment Instructions',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          
          // Step-by-step instructions
          _buildInstructionStep(
            step: 1,
            text: 'You will receive a payment request notification on your phone',
            icon: Icons.notifications_outlined,
            color: providerColor,
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            step: 2,
            text: 'Open your $providerName Mobile Money app',
            icon: Icons.phone_android,
            color: providerColor,
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            step: 3,
            text: 'Approve the payment request when prompted',
            icon: Icons.check_circle_outline,
            color: providerColor,
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            step: 4,
            text: 'Enter your $providerName Mobile Money PIN to confirm',
            icon: Icons.lock_outline,
            color: providerColor,
          ),
          const SizedBox(height: 20),
          
          // USSD Code Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: providerColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: providerColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: providerColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Quick access: Dial $ussdCode to check your $providerName Mobile Money balance',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
