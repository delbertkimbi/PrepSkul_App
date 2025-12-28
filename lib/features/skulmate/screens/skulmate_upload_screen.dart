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
import '../widgets/game_customization_dialog.dart';
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
  String? _fileUrl;
  String? _imageUrl;
  bool _isUploading = false;
  bool _isUploadingImage = false;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'docx'],
      );

      // On web, PlatformFile has bytes instead of path
      // On mobile, PlatformFile has path
      final file = result?.files.single;
      final hasFile = file != null && (file.path != null || file.bytes != null);
      
      if (hasFile) {
        safeSetState(() => _isUploading = true);
        
        final fileName = file.name;
        
        final userId = SupabaseService.client.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final uploadedUrl = await StorageService.uploadDocument(
          userId: userId,
          documentFile: file,
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

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        safeSetState(() => _isUploadingImage = true);
        
        final userId = SupabaseService.client.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        // Upload image to storage (using uploadDocument for images too)
        final uploadedUrl = await StorageService.uploadDocument(
          userId: userId,
          documentFile: image,
          documentType: 'skulmate_game_image',
        );

        safeSetState(() {
          _imageUrl = uploadedUrl;
          _isUploadingImage = false;
        });

        // No SnackBar needed - status is already shown on the card
      }
    } catch (e) {
      LogService.error('Error picking image: $e');
      safeSetState(() => _isUploadingImage = false);
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

  void _navigateToTextInput() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TextInputScreen(
          onTextSubmitted: (text) {
            Navigator.pop(context);
            // Navigate to game generation with text
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GameGenerationScreen(
                  text: text,
                  childId: widget.childId,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _generateGame() async {
    if (_fileUrl == null && _imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a file or image'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show customization dialog first
    final customization = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const GameCustomizationDialog(),
    );

    if (customization != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameGenerationScreen(
            fileUrl: _fileUrl,
            imageUrl: _imageUrl,
            childId: widget.childId,
            difficulty: customization['difficulty'] as String?,
            topic: customization['topic'] as String?,
            numQuestions: customization['numQuestions'] as int?,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Game',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero section with title - extends to top of device
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 32,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.1),
                    AppTheme.accentGreen.withOpacity(0.05),
                  ],
                ),
              ),
              child: Column(
                children: [
                  SizedBox(height: statusBarHeight + 70), // Space for status bar + app bar (increased to prevent overlap)
                  // Icon/Emoji
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 32,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Turn Your Notes Into a Game!',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Upload your notes, documents, or images and watch them transform into fun, interactive learning games',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textMedium,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // Upload options section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // File upload card
                  _buildUploadCard(
                    icon: Icons.description,
                    title: 'Upload Document',
                    subtitle: 'PDF, Word, or Text files',
                    onTap: _isUploading ? null : _pickFile,
                    isLoading: _isUploading,
                    isUploaded: _fileUrl != null,
                  ),
                  const SizedBox(height: 12),
                  // Image upload card
                  _buildUploadCard(
                    icon: Icons.image,
                    title: 'Upload Image',
                    subtitle: 'Photos of your notes or diagrams',
                    onTap: _isUploadingImage ? null : _pickImage,
                    isLoading: _isUploadingImage,
                    isUploaded: _imageUrl != null,
                  ),
                  const SizedBox(height: 20),
                  // Divider with "OR" text
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppTheme.textLight)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textMedium,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppTheme.textLight)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Text input card
                  _buildUploadCard(
                    icon: Icons.text_fields,
                    title: 'Enter Text',
                    subtitle: 'Type or paste your notes directly',
                    onTap: _navigateToTextInput,
                    isLoading: false,
                    isUploaded: false,
                  ),
                  if (_fileUrl != null || _imageUrl != null) ...[
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _generateGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required bool isLoading,
    required bool isUploaded,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isUploaded
            ? BorderSide(color: AppTheme.accentGreen, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isUploaded
                ? AppTheme.accentGreen.withOpacity(0.05)
                : Colors.white,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isUploaded
                      ? AppTheme.accentGreen.withOpacity(0.1)
                      : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Icon(
                        isUploaded ? Icons.check_circle : icon,
                        color: isUploaded
                            ? AppTheme.accentGreen
                            : AppTheme.primaryColor,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 12),
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
                        fontSize: 13,
                        color: AppTheme.textMedium,
                      ),
                    ),
                    if (isUploaded) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Uploaded successfully',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.accentGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isLoading && !isUploaded)
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.textLight,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Separate screen for text input
class _TextInputScreen extends StatefulWidget {
  final Function(String) onTextSubmitted;

  const _TextInputScreen({required this.onTextSubmitted});

  @override
  State<_TextInputScreen> createState() => _TextInputScreenState();
}

class _TextInputScreenState extends State<_TextInputScreen> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submitText() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter some text'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    widget.onTextSubmitted(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Enter Text',
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
              'Enter your notes or text to create a game',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppTheme.textMedium,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _textController,
              maxLines: 15,
              autofocus: true,
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
              onPressed: _submitText,
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
