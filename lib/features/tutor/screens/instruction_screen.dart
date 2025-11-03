import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

/// Reusable instruction screen for displaying detailed information
/// Users can navigate back to where they came from in the flow
class InstructionScreen extends StatelessWidget {
  final String title;
  final String content;
  final IconData? icon;

  const InstructionScreen({
    super.key,
    required this.title,
    required this.content,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppTheme.textDark,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and title section
            if (icon != null) ...[
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Title
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),

            const SizedBox(height: 24),

            // Content - formatted text with line breaks
            _buildFormattedContent(content),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedContent(String content) {
    // Split content by double newlines to create sections
    final sections = content.split('\n\n');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) {
        // Check if section is a numbered or bulleted list
        final lines = section.split('\n');
        final isNumberedList = lines.isNotEmpty && 
            RegExp(r'^\d+[\)\.]').hasMatch(lines.first.trim());
        final isBulletList = lines.isNotEmpty && 
            (lines.first.trim().startsWith('•') || 
             lines.first.trim().startsWith('-') ||
             lines.first.trim().startsWith('*'));

        if (isNumberedList || isBulletList) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines.asMap().entries.map((entry) {
                final index = entry.key;
                final line = entry.value;
                final trimmedLine = line.trim();
                if (trimmedLine.isEmpty) return const SizedBox.shrink();
                
                // Extract number from line if it's a numbered list
                final numberMatch = isNumberedList 
                    ? RegExp(r'^\d+[\)\.]\s*').firstMatch(trimmedLine)
                    : null;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          isNumberedList 
                              ? '${index + 1}.'
                              : '•',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          isNumberedList && numberMatch != null
                              ? trimmedLine.substring(numberMatch.end).trim()
                              : trimmedLine.replaceFirst(RegExp(r'^[•\-*]\s*'), '').trim(),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textDark,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        } else {
          // Regular paragraph
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              section,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textDark,
                height: 1.6,
              ),
            ),
          );
        }
      }).toList(),
    );
  }
}

