import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Hybrid Mode Selection Dialog
class HybridModeSelectionDialog extends StatelessWidget {
  final String sessionAddress;
  final String? meetingLink;

  const HybridModeSelectionDialog({
    Key? key,
    required this.sessionAddress,
    this.meetingLink,
  }) : super(key: key);

  static Future<bool?> show(BuildContext context, {required String sessionAddress, String? meetingLink}) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => HybridModeSelectionDialog(sessionAddress: sessionAddress, meetingLink: meetingLink),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shuffle, color: AppTheme.primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Text('Choose Session Mode', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 8),
            Text('This is a hybrid session. Choose how you want to conduct this session.', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 24),
            InkWell(
              onTap: () => Navigator.pop(context, true),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2)),
                child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.videocam, color: Colors.blue, size: 24)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text('Online', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)), if (meetingLink != null && meetingLink!.isNotEmpty) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)), child: Text('Ready', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)))]]), const SizedBox(height: 4), Text('Video call via Google Meet', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]))])), const Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 18)]),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => Navigator.pop(context, false),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3), width: 2)),
                child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.location_on, color: Colors.green, size: 24)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Onsite', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(sessionAddress, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis)])), const Icon(Icons.arrow_forward_ios, color: Colors.green, size: 18)]),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.pop(context, null), child: Text('Cancel', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])))),
          ],
        ),
      ),
    );
  }
}
