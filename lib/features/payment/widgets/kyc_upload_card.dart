import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/neumorphic_surface.dart';

/// Large tap target for a single KYC photo upload.
class KycUploadCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isComplete;
  final String? fileName;
  final dynamic previewFile;
  final VoidCallback onTap;

  const KycUploadCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isComplete,
    required this.onTap,
    this.fileName,
    this.previewFile,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isComplete
                ? AppTheme.accentLightGreen.withValues(alpha: 0.35)
                : AppTheme.neutral50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isComplete
                  ? AppTheme.success.withValues(alpha: 0.55)
                  : AppTheme.primaryColor.withValues(alpha: 0.12),
              width: isComplete ? 1.5 : 1,
            ),
            boxShadow: isComplete ? NeumorphicSurface.inset : NeumorphicSurface.raised,
          ),
          child: Row(
            children: [
              _buildLeading(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isComplete && fileName != null ? fileName! : subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                isComplete ? Icons.check_circle : Icons.chevron_right,
                color: isComplete ? AppTheme.success : AppTheme.neutral400,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading() {
    if (isComplete && previewFile != null) {
      final path = previewFile is XFile
          ? previewFile.path
          : (previewFile is File ? previewFile.path : null);
      if (path != null && path.isNotEmpty && !kIsWeb) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(path),
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _iconBox(),
          ),
        );
      }
    }
    return _iconBox();
  }

  Widget _iconBox() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: isComplete
            ? AppTheme.success.withValues(alpha: 0.12)
            : AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        boxShadow: NeumorphicSurface.inset,
      ),
      child: Icon(
        isComplete ? Icons.check_circle_outline : Icons.add_a_photo_outlined,
        color: isComplete ? AppTheme.success : AppTheme.primaryColor,
        size: 24,
      ),
    );
  }
}
