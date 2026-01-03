import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Hybrid Mode Selection Dialog
///
/// Enhanced dialog for selecting between online and onsite modes for hybrid sessions
/// Shows detailed information about each mode and what features are available
class HybridModeSelectionDialog extends StatelessWidget {
  final String sessionAddress;
  final String? meetingLink;
  final String? locationDescription;

  const HybridModeSelectionDialog({
    Key? key,
    required this.sessionAddress,
    this.meetingLink,
    this.locationDescription,
  }) : super(key: key);

  static Future<bool?> show(
    BuildContext context, {
    required String sessionAddress,
    String? meetingLink,
    String? locationDescription,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => HybridModeSelectionDialog(
        sessionAddress: sessionAddress,
        meetingLink: meetingLink,
        locationDescription: locationDescription,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.shuffle, color: AppTheme.primaryColor, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Session Mode',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This is a hybrid session',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Online Mode Option
            _buildModeOption(
              context: context,
              title: 'Online',
              subtitle: 'Video call via Google Meet',
              icon: Icons.videocam,
              color: Colors.blue,
              isReady: meetingLink != null && meetingLink!.isNotEmpty,
              features: [
                'Video call with screen sharing',
                'Automatic recording (if enabled)',
                'Connection quality monitoring',
                'Chat and whiteboard features',
              ],
              onTap: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 16),
            
            // Onsite Mode Option
            _buildModeOption(
              context: context,
              title: 'Onsite',
              subtitle: 'In-person at location',
              icon: Icons.location_on,
              color: Colors.green,
              address: sessionAddress,
              locationDescription: locationDescription,
              features: [
                'Face-to-face interaction',
                'Location check-in required',
                'Location sharing for safety',
                'Physical materials support',
              ],
              onTap: () => Navigator.pop(context, false),
            ),
            const SizedBox(height: 24),
            
            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isReady = false,
    String? address,
    String? locationDescription,
    List<String>? features,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isReady) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Ready',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      if (address != null && address.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.place,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      address,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (locationDescription != null &&
                                        locationDescription.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        locationDescription,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: 18,
                ),
              ],
            ),
            if (features != null && features.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...features.map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: color,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}