import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/storage_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'dart:io' show File;
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
  final TextEditingController _textController = TextEditingController();
  String? _fileUrl;
  String? _imageUrl;
  bool _isLoading = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        LogService.info('📄 [Upload] Selected file: $filePath');

        setState(() => _isLoading = true);

        // Upload to Supabase Storage
        final file = result.files.single;
        final fileName = file.name;
        final fileBytes = file.bytes;
        if (fileBytes == null) {
          throw Exception('Failed to read file bytes');
        }

        final supabase = SupabaseService.client;
        final userId = supabase.auth.currentUser?.id ?? 'anonymous';
        final storagePath = 'skulmate/uploads/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

        if (kIsWeb) {
          // Web: use uploadBinary for Uint8List
          await supabase.storage
              .from('skulmate_files')
              .uploadBinary(storagePath, fileBytes);
        } else {
          // Mobile: convert bytes to File
          final tempFile = File(file.path!);
          await supabase.storage
              .from('skulmate_files')
              .upload(storagePath, tempFile);
        }

        final publicUrl = supabase.storage
            .from('skulmate_files')
            .getPublicUrl(storagePath);

        setState(() {
          _fileUrl = publicUrl;
          _isLoading = false;
        });

        LogService.success('✅ [Upload] File uploaded: $publicUrl');
      }
    } catch (e) {
      LogService.error('❌ [Upload] Error picking file: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        LogService.info('🖼️ [Upload] Selected image: ${image.path}');

        setState(() => _isLoading = true);

        // Upload to Supabase Storage
        final fileBytes = await image.readAsBytes();
        final supabase = SupabaseService.client;
        final userId = supabase.auth.currentUser?.id ?? 'anonymous';
        final storagePath = 'skulmate/images/$userId/${DateTime.now().millisecondsSinceEpoch}_${image.name}';

        if (kIsWeb) {
          // Web: use uploadBinary for Uint8List
          await supabase.storage
              .from('skulmate_files')
              .uploadBinary(storagePath, fileBytes);
        } else {
          // Mobile: convert XFile to File
          final tempFile = File(image.path);
          await supabase.storage
              .from('skulmate_files')
              .upload(storagePath, tempFile);
        }

        final publicUrl = supabase.storage
            .from('skulmate_files')
            .getPublicUrl(storagePath);

        setState(() {
          _imageUrl = publicUrl;
          _isLoading = false;
        });

        LogService.success('✅ [Upload] Image uploaded: $publicUrl');
      }
    } catch (e) {
      LogService.error('❌ [Upload] Error picking image: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showCustomizationDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => GameCustomizationDialog(),
    );

    if (result != null && mounted) {
      _generateGame(
        difficulty: result['difficulty'] as String?,
        topic: result['topic'] as String?,
        numQuestions: result['numQuestions'] as int?,
      );
    }
  }

  Future<void> _generateGame({
    String? difficulty,
    String? topic,
    int? numQuestions,
  }) async {
    if (_fileUrl == null && _imageUrl == null && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please provide a file, image, or text to generate a game'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameGenerationScreen(
            fileUrl: _fileUrl,
            imageUrl: _imageUrl,
            text: _textController.text.trim().isNotEmpty ? _textController.text.trim() : null,
            childId: widget.childId,
            difficulty: difficulty,
            topic: topic,
            numQuestions: numQuestions,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create New Game',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Upload Content',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: Icon(Icons.upload_file),
                    label: Text('Upload File'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: Icon(Icons.image),
                    label: Text('Pick Image'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Or Enter Text',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _textController,
                    maxLines: 10,
                    decoration: InputDecoration(
                      hintText: 'Enter your content here...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _showCustomizationDialog,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primaryColor,
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
