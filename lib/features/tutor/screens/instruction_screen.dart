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
      backgroundColor: AppTheme.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and title section with gradient background
            if (icon != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 3,
                        ),
                      ),
                      child: Icon(icon, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              // Title without icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.1),
                      AppTheme.primaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

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
        final trimmedSection = section.trim();
        if (trimmedSection.isEmpty) return const SizedBox.shrink();

        // Check for special sections
        final isImportantSection =
            trimmedSection.startsWith('📹') ||
            trimmedSection.contains('Important');
        final isWhatToDoSection = trimmedSection.contains('What to do:');
        final isHeadingSection =
            trimmedSection.contains('Guiding Questions') ||
            trimmedSection.contains('Need help');

        // Check if section is a numbered or bulleted list
        final lines = section.split('\n');
        final isNumberedList =
            lines.isNotEmpty &&
            RegExp(r'^\d+[\)\.]').hasMatch(lines.first.trim());
        final isBulletList =
            lines.isNotEmpty &&
            (lines.first.trim().startsWith('•') ||
                lines.first.trim().startsWith('-') ||
                lines.first.trim().startsWith('*'));

        // Special styling for important sections
        if (isImportantSection) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines.map((line) {
                final trimmedLine = line.trim();
                if (trimmedLine.isEmpty) return const SizedBox.shrink();

                final isBullet = trimmedLine.startsWith('•');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isBullet) ...[
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          isBullet
                              ? trimmedLine.substring(1).trim()
                              : trimmedLine,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: isBullet
                                ? FontWeight.w500
                                : FontWeight.w600,
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
        }

        // Heading sections
        if (isHeadingSection || isWhatToDoSection) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: Text(
              trimmedSection,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
                height: 1.6,
              ),
            ),
          );
        }

        if (isNumberedList || isBulletList) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.softBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines.asMap().entries.map((entry) {
                final index = entry.key;
                final line = entry.value;
                final trimmedLine = line.trim();
                if (trimmedLine.isEmpty) return const SizedBox(height: 8);

                // Extract number from line if it's a numbered list
                final numberMatch = isNumberedList
                    ? RegExp(r'^\d+[\)\.]\s*').firstMatch(trimmedLine)
                    : null;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            isNumberedList ? '${index + 1}' : '•',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isNumberedList && numberMatch != null
                              ? trimmedLine.substring(numberMatch.end).trim()
                              : trimmedLine
                                    .replaceFirst(RegExp(r'^[•\-*]\s*'), '')
                                    .trim(),
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
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.softBorder, width: 1),
            ),
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
