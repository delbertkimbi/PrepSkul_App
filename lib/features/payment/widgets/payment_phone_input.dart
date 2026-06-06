import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/payment/utils/payment_provider_helper.dart';

/// Phone number field with MTN/Orange provider badge — shared checkout widget.
class PaymentPhoneInput extends StatelessWidget {
  final TextEditingController controller;
  final String? detectedProvider;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const PaymentPhoneInput({
    super.key,
    required this.controller,
    this.detectedProvider,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Phone Number',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              if (detectedProvider != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: PaymentProviderHelper.getProviderColor(detectedProvider)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: PaymentProviderHelper.getProviderColor(detectedProvider)
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PaymentProviderHelper.getProviderIcon(detectedProvider),
                        size: 14,
                        color: PaymentProviderHelper.getProviderColor(detectedProvider),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        PaymentProviderHelper.getProviderName(detectedProvider),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: PaymentProviderHelper.getProviderColor(detectedProvider),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: '67XXXXXXX (MTN) or 69XXXXXXX (Orange)',
              prefixIcon: Icon(Icons.phone, color: AppTheme.primaryColor, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.softBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              errorText: errorText,
            ),
          ),
          if (detectedProvider == null && controller.text.trim().isNotEmpty && errorText == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Please enter a valid MTN or Orange number',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.accentOrange),
              ),
            ),
        ],
      ),
    );
  }
}
