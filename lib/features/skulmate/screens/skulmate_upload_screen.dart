import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/storage_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import '../services/skulmate_service.dart';
import 'game_generation_screen.dart';
import 'game_library_screen.dart';

/// Screen for uploading notes/documents to create games
class SkulMateUploadScreen extends StatefulWidget {
  final String? childId; // For parents creating games for children

  const SkulMateUploadScreen({Key? key, this.childId}) : super(key: key);

  @override
  State<SkulMateUploadScreen> createState() => _SkulMateUploadScreenState();
}

class _SkulMateUploadScreenState extends State<SkulMateUploadScreen> {
  final _textController = TextEditingController();
  String? _fileUrl;
  bool _isUploading = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'docx', 'jpg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        safeSetState(() => _isUploading = true);
        
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        
        final userId = SupabaseService.client.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final uploadedUrl = await StorageService.uploadDocument(
          userId: userId,
          documentFile: result.files.single,
          documentType: 'skulmate_game',
        );

        safeSetState(() {
          _fileUrl = uploadedUrl;
          _isUploading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File uploaded: $fileName'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      }
    } catch (e) {
      LogService.error('Error picking file: $e');
      safeSetState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _generateGame() {
    if (_fileUrl == null && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a file or enter text'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameGenerationScreen(
          fileUrl: _fileUrl,
          text: _textController.text.trim().isNotEmpty ? _textController.text.trim() : null,
          childId: widget.childId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Create Game',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Upload a document or enter text to create a game',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppTheme.textMedium,
              ),
            ),
            const SizedBox(height: 24),
            // File upload button
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickFile,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_isUploading ? 'Uploading...' : 'Upload File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_fileUrl != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentGreen),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.accentGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'File uploaded successfully',
                        style: GoogleFonts.poppins(
                          color: AppTheme.accentGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Or enter text:',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: 'Enter your notes or text here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _generateGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Generate Game',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
