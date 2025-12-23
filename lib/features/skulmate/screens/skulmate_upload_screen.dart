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

/// Screen for uploading notes/documents to create games
class SkulMateUploadScreen extends StatefulWidget {
  final String? childId; // For parents creating games for children

  const SkulMateUploadScreen({Key? key, this.childId}) : super(key: key);

  @override
  State<SkulMateUploadScreen> createState() => _SkulMateUploadScreenState();
}

class _SkulMateUploadScreenState extends State<SkulMateUploadScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _textController = TextEditingController();
  String? _selectedFileUrl;
  String? _selectedFileName;
  String _uploadMethod = 'none'; // 'pdf', 'image', 'text'
  bool _isUploading = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _uploadPDF() async {
    try {
      safeSetState(() => _isUploading = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt'],
      );

      if (result == null || result.files.isEmpty) {
        safeSetState(() => _isUploading = false);
        return;
      }

      final file = result.files.first;
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Upload to Supabase Storage
      final fileUrl = await StorageService.uploadDocument(
        userId: userId,
        documentFile: file,
        documentType: 'skulmate_document',
      );

      safeSetState(() {
        _selectedFileUrl = fileUrl;
        _selectedFileName = file.name;
        _uploadMethod = 'pdf';
        _isUploading = false;
      });

      LogService.success('📄 [skulMate] PDF uploaded: $fileUrl');
    } catch (e) {
      LogService.error('📄 [skulMate] Error uploading PDF: $e');
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

  Future<void> _uploadImage() async {
    try {
      safeSetState(() => _isUploading = true);

      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        safeSetState(() => _isUploading = false);
        return;
      }

      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Upload to Supabase Storage
      final fileUrl = await StorageService.uploadDocument(
        userId: userId,
        documentFile: image,
        documentType: 'skulmate_image',
      );

      safeSetState(() {
        _selectedFileUrl = fileUrl;
        _selectedFileName = image.name;
        _uploadMethod = 'image';
        _isUploading = false;
      });

      LogService.success('📷 [skulMate] Image uploaded: $fileUrl');
    } catch (e) {
      LogService.error('📷 [skulMate] Error uploading image: $e');
      safeSetState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      safeSetState(() => _isUploading = true);

      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image == null) {
        safeSetState(() => _isUploading = false);
        return;
      }

      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Upload to Supabase Storage
      final fileUrl = await StorageService.uploadDocument(
        userId: userId,
        documentFile: image,
        documentType: 'skulmate_image',
      );

      safeSetState(() {
        _selectedFileUrl = fileUrl;
        _selectedFileName = image.name;
        _uploadMethod = 'image';
        _isUploading = false;
      });

      LogService.success('📷 [skulMate] Photo uploaded: $fileUrl');
    } catch (e) {
      LogService.error('📷 [skulMate] Error taking photo: $e');
      safeSetState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _selectTextInput() {
    safeSetState(() {
      _uploadMethod = 'text';
      _selectedFileUrl = null;
      _selectedFileName = null;
    });
  }

  Future<void> _generateGame() async {
    if (_uploadMethod == 'none') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an upload method'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_uploadMethod == 'text' && _textController.text.trim().length < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text must be at least 50 characters long'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to generation screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameGenerationScreen(
            fileUrl: _selectedFileUrl,
            text: _uploadMethod == 'text' ? _textController.text : null,
            childId: widget.childId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'skulMate',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Turn Your Notes Into Games!',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload your notes, documents, or photos and skulMate will create interactive games to help you learn',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Upload Options
            Text(
              'Choose Upload Method',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 16),

            // PDF/Document Upload
            _buildUploadOption(
              icon: Icons.picture_as_pdf,
              title: 'Upload PDF/Document',
              subtitle: 'PDF, DOCX, or TXT files',
              isSelected: _uploadMethod == 'pdf',
              onTap: _uploadPDF,
              isLoading: _isUploading && _uploadMethod == 'pdf',
            ),
            const SizedBox(height: 12),

            // Image Upload
            _buildUploadOption(
              icon: Icons.image,
              title: 'Upload Photo/Image',
              subtitle: 'Take a photo or select from gallery',
              isSelected: _uploadMethod == 'image',
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: const Text('Take Photo'),
                          onTap: () {
                            Navigator.pop(context);
                            _takePhoto();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Choose from Gallery'),
                          onTap: () {
                            Navigator.pop(context);
                            _uploadImage();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              isLoading: _isUploading && _uploadMethod == 'image',
            ),
            const SizedBox(height: 12),

            // Text Input
            _buildUploadOption(
              icon: Icons.text_fields,
              title: 'Enter Text Manually',
              subtitle: 'Type or paste your notes',
              isSelected: _uploadMethod == 'text',
              onTap: _selectTextInput,
              isLoading: false,
            ),

            // Text Input Field (shown when text method selected)
            if (_uploadMethod == 'text') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _textController,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: 'Paste or type your notes here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ],

            // Selected File Info
            if (_selectedFileName != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.accentGreen.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.accentGreen),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedFileName!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Generate Button
            ElevatedButton(
              onPressed: _isUploading ? null : _generateGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
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

  Widget _buildUploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isLoading,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.textDark,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
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
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
              ),
          ],
        ),
      ),
    );
  }
}

