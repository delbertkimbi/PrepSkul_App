import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Bottom sheet for picking images/documents from camera, gallery, or files
class ImagePickerBottomSheet extends StatelessWidget {
  const ImagePickerBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Text(
              'Choose File',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),

            const SizedBox(height: 24),

            // Camera option (only on mobile platforms)
            if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
              _buildOption(
                context: context,
                icon: Icons.camera_alt,
                title: 'Camera',
                subtitle: 'Take a new photo',
                onTap: () async {
                  try {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    );
                    if (image != null && context.mounted) {
                      Navigator.pop(context, File(image.path));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Camera not available: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  }
                },
              ),

            if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
              const SizedBox(height: 12),

            // Gallery option
            _buildOption(
              context: context,
              icon: Icons.photo_library,
              title: 'Gallery',
              subtitle: 'Choose from photos',
              onTap: () async {
                try {
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (image != null && context.mounted) {
                    Navigator.pop(context, File(image.path));
                  } else if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to pick image: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    Navigator.pop(context);
                  }
                }
              },
            ),

            const SizedBox(height: 12),

            // Files option
            _buildOption(
              context: context,
              icon: Icons.folder,
              title: 'Files',
              subtitle: 'Browse documents',
              onTap: () async {
                try {
                  final FilePickerResult? result = await FilePicker.platform
                      .pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                      );
                  if (result != null &&
                      result.files.isNotEmpty &&
                      context.mounted) {
                    Navigator.pop(context, File(result.files.single.path!));
                  } else if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to pick file: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    Navigator.pop(context);
                  }
                }
              },
            ),

            const SizedBox(height: 24),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textMedium, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.softBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: AppTheme.textLight),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textLight),
          ],
        ),
      ),
    );
  }
}
