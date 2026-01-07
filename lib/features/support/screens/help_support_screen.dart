import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

/// Help & Support Screen
///
/// Professional support interface with:
/// - FAQ section
/// - Contact form with WhatsApp integration
/// - Direct contact options
/// - Support resources
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _complaintController = TextEditingController();
  final FocusNode _complaintFocusNode = FocusNode();
  bool _isSubmitting = false;

  // WhatsApp number for PrepSkul support
  static const String _whatsappNumber = '+237674208573'; // Based on footer contact info
  static const String _supportEmail = 'info@prepskul.com';
  static const String _supportPhone = '+237 6 53 30 19 97';

  @override
  void dispose() {
    _complaintController.dispose();
    _complaintFocusNode.dispose();
    super.dispose();
  }

  /// Open WhatsApp with pre-filled message
  Future<void> _openWhatsApp(String message) async {
    try {
      final encodedMessage = Uri.encodeComponent(message);
      final whatsappUrl = 'https://wa.me/$_whatsappNumber?text=$encodedMessage';
      
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        LogService.success('WhatsApp opened successfully');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'WhatsApp is not installed. Please install WhatsApp to contact support.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      LogService.error('Error opening WhatsApp: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to open WhatsApp. Please try again or contact us via email.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Submit complaint via WhatsApp
  Future<void> _submitViaWhatsApp() async {
    final complaint = _complaintController.text.trim();
    
    if (complaint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please describe your issue or question',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      _complaintFocusNode.requestFocus();
      return;
    }

    safeSetState(() => _isSubmitting = true);

    try {
      // Get user info for context
      final userProfile = await AuthService.getUserProfile();
      final userName = userProfile?['full_name'] as String? ?? 'User';
      final userEmail = userProfile?['email'] as String? ?? 'N/A';
      final userId = userProfile?['id'] as String? ?? 'N/A';

      // Format message with user context
      final message = '''Hello PrepSkul Support,

I need assistance with the following:

$complaint

---
User Details:
Name: $userName
Email: $userEmail
User ID: $userId

Thank you!''';

      await _openWhatsApp(message);
      
      // Clear the text field after successful submission
      _complaintController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Opening WhatsApp...',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      LogService.error('Error submitting via WhatsApp: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      safeSetState(() => _isSubmitting = false);
    }
  }

  /// Open email client
  Future<void> _openEmail() async {
    try {
      final emailUri = Uri(
        scheme: 'mailto',
        path: _supportEmail,
        queryParameters: {
          'subject': 'PrepSkul Support Request',
        },
      );
      
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No email app found. Please email us at $_supportEmail',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      LogService.error('Error opening email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to open email app. Please email us at $_supportEmail',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Open phone dialer
  Future<void> _openPhone() async {
    try {
      final phoneUri = Uri.parse('tel:$_supportPhone');
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    } catch (e) {
      LogService.error('Error opening phone: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help & Support',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section - More compact
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.help_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need help?',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tell us what you need',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textMedium,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Complaint/Issue Input Section
            Text(
              'What can we help you with?',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _complaintController,
              focusNode: _complaintFocusNode,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Describe your issue or question...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textLight,
                ),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),

            // WhatsApp Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitViaWhatsApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // WhatsApp green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSubmitting)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      _buildWhatsAppIcon(),
                    const SizedBox(width: 10),
                    Text(
                      _isSubmitting ? 'Opening...' : 'Send via WhatsApp',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quick Contact Options
            Text(
              'Other ways to reach us',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            _buildContactOption(
              icon: Icons.email_outlined,
              title: 'Email Support',
              subtitle: _supportEmail,
              color: AppTheme.primaryColor,
              onTap: _openEmail,
            ),
            const SizedBox(height: 8),
            _buildContactOption(
              icon: Icons.phone_outlined,
              title: 'Call Us',
              subtitle: _supportPhone,
              color: AppTheme.primaryColor,
              onTap: _openPhone,
            ),
            const SizedBox(height: 20),

            // FAQ Section
            Text(
              'Frequently Asked Questions',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            _buildFAQItem(
              question: 'How do I book a tutor?',
              answer: 'You can browse available tutors in the "Find Tutors" section, or submit a custom request if you need a specific tutor not on the platform.',
            ),
            _buildFAQItem(
              question: 'How do I pay for sessions?',
              answer: 'Payment is processed securely through the app. You can pay using mobile money or other supported payment methods when booking a tutor.',
            ),
            _buildFAQItem(
              question: 'Can I cancel a booking?',
              answer: 'Yes, you can cancel bookings from the "My Requests" section. Cancellation policies may apply depending on the timing.',
            ),
            _buildFAQItem(
              question: 'How do I update my profile?',
              answer: 'Go to your Profile tab and tap on any field you want to update. Changes are saved automatically.',
            ),
            _buildFAQItem(
              question: 'What if I can\'t find a tutor?',
              answer: 'Submit a custom tutor request with your requirements. Our team will find a suitable tutor for you and notify you when matched.',
            ),
            const SizedBox(height: 24),

            // Support Hours
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 20, color: AppTheme.textMedium),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Support Hours',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Monday - Friday: 8:00 AM - 6:00 PM\nSaturday: 9:00 AM - 2:00 PM',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textMedium,
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

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem({
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          question,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        children: [
          Text(
            answer,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textMedium,
              height: 1.5,
            ),
          ),
        ],
        iconColor: AppTheme.primaryColor,
        collapsedIconColor: AppTheme.textMedium,
      ),
    );
  }

  Widget _buildWhatsAppIcon() {
    // Use a built-in icon to avoid missing asset issues
    return const Icon(
      Icons.chat,
      size: 20,
      color: Colors.white,
    );
  }
}

