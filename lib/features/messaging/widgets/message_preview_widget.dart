import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Message Preview Widget
/// 
/// Shows filter warnings before sending a message
/// Allows user to edit before sending
/// Visual indicators for violations
class MessagePreviewWidget extends StatelessWidget {
  final List<Map<String, dynamic>> flags;
  final List<String> warnings;
  final bool willBlock;
  final VoidCallback? onEdit;
  final VoidCallback? onSendAnyway; // Only if allowed but has warnings
  final VoidCallback? onCancel;

  const MessagePreviewWidget({
    Key? key,
    required this.flags,
    required this.warnings,
    required this.willBlock,
    this.onEdit,
    this.onSendAnyway,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (flags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: willBlock 
            ? Colors.red[50] 
            : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: willBlock 
              ? Colors.red[300]! 
              : Colors.orange[300]!,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                willBlock ? Icons.block : Icons.warning_amber_rounded,
                color: willBlock ? Colors.red[700] : Colors.orange[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  willBlock 
                      ? 'Message Blocked' 
                      : 'Message Warning',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: willBlock ? Colors.red[900] : Colors.orange[900],
                  ),
                ),
              ),
              if (onCancel != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onCancel,
                  color: Colors.grey[600],
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Warnings
          ...warnings.map((warning) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: willBlock ? Colors.red[700] : Colors.orange[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    warning,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: willBlock ? Colors.red[800] : Colors.orange[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
          
          const SizedBox(height: 16),
          
          // Actions
          if (willBlock) ...[
            // Blocked - only edit option
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 18),
                label: Text(
                  'Edit Message',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red[700]!),
                  foregroundColor: Colors.red[700],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else ...[
            // Warnings but allowed - edit or send anyway
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: Text(
                      'Edit',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.orange[700]!),
                      foregroundColor: Colors.orange[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSendAnyway,
                    icon: const Icon(Icons.send, size: 18),
                    label: Text(
                      'Send Anyway',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

