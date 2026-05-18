import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// High-contrast strip for lobby + in-call when the device has no network.
/// Pairs with [OfflineDialog] — this stays visible behind/above the call chrome.
class ClassroomOfflineBanner extends StatelessWidget {
  const ClassroomOfflineBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE65100),
      elevation: 3,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
