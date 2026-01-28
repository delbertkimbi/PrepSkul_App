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
import 'dart:typed_data';
import '../services/skulmate_service.dart';
import 'game_generation_screen.dart';
import 'game_library_screen.dart';
import 'text_input_screen.dart';
import '../widgets/photo_upload_bottom_sheet.dart';

/// Screen for uploading notes/documents to create games
class SkulMateUploadScreen extends StatefulWidget {
  final String? childId; // For parents creating games for children

  const SkulMateUploadScreen({Key? key, this.childId}) : super(key: key);

  @override
  State<SkulMateUploadScreen> createState() => _SkulMateUploadScreenState();
}

class _SkulMateUploadScreenState extends State<SkulMateUploadScreen> {
  List<File> _selectedFiles = [];
  List<PlatformFile> _selectedFilesWeb = []; // For web platform
  List<XFile> _selectedImages = [];
  Map<int, Uint8List> _imageBytesCache = {}; // Cache image bytes for web display
  List<String> _selectedFileNames = [];

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Allow all document types
        allowMultiple: true, // Allow multiple files
      );

      if (result != null && result.files.isNotEmpty) {
        safeSetState(() {
          if (kIsWeb) {
            // On web, store PlatformFile objects (they have bytes)
            _selectedFilesWeb = result.files
                .where((file) => file.bytes != null || file.name.isNotEmpty)
                .toList();
            _selectedFiles = []; // Clear mobile files
          } else {
            // On mobile, store File objects (they have paths)
          _selectedFiles = result.files
              .where((file) => file.path != null)
              .map((file) => File(file.path!))
              .toList();
            _selectedFilesWeb = []; // Clear web files
          }
          _selectedFileNames = result.files
              .where((file) => file.name.isNotEmpty)
              .map((file) => file.name)
              .toList();
          _selectedImages = []; // Clear images when documents are selected
        });
      }
    } catch (e) {
      LogService.error('Error picking document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting document: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPhotoOptions() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => PhotoUploadBottomSheet(),
    );

    if (source != null) {
      try {
        final ImagePicker picker = ImagePicker();
        
        if (source == ImageSource.gallery) {
          // Multiple selection from gallery
          final List<XFile> images = await picker.pickMultiImage(
            imageQuality: 85,
          );

          if (images.isNotEmpty) {
            safeSetState(() {
              _selectedImages.addAll(images);
              _selectedFiles = []; // Clear documents when images are selected
              _selectedFilesWeb = []; // Clear web documents
              // Pre-load image bytes for web display
              if (kIsWeb) {
                _loadImageBytesForWeb(images);
              }
            });
          }
        } else {
          // Camera - sequential photo capture
          await _captureSequentialPhotos(picker);
        }
      } catch (e) {
        LogService.error('Error picking photo: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error selecting photo: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _captureSequentialPhotos(ImagePicker picker) async {
    bool continueCapturing = true;
    
    while (continueCapturing && mounted) {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        safeSetState(() {
          _selectedImages.add(image);
          // Pre-load image bytes for web display
          if (kIsWeb) {
            _loadImageBytesForWeb([image]);
          }
        });

        // Ask if user wants to add another photo
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Photo Added',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            content: Text(
              'Would you like to take another photo?',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Done', style: GoogleFonts.poppins()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: Text('Add Another', style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ],
          ),
        );

        continueCapturing = shouldContinue ?? false;
      } else {
        continueCapturing = false;
      }
    }
  }

  /// Load image bytes for web display
  Future<void> _loadImageBytesForWeb(List<XFile> images) async {
    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      try {
        final bytes = await image.readAsBytes();
        final index = _selectedImages.indexOf(image);
        if (index >= 0) {
          _imageBytesCache[index] = bytes;
        }
      } catch (e) {
        LogService.warning('Failed to load image bytes for web: $e');
      }
    }
  }

  Future<void> _navigateToTextInput() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TextInputScreen(childId: widget.childId),
      ),
    );
  }

  Future<void> _uploadAndGenerate() async {
    if (_selectedFiles.isEmpty && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select files or photos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      List<String> fileUrls = [];
      List<String> imageUrls = [];

      final user = await SupabaseService.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload all files
      if (kIsWeb) {
        // On web, use PlatformFile objects
        for (final file in _selectedFilesWeb) {
          final url = await StorageService.uploadDocument(
            userId: user.id,
            documentFile: file,
            documentType: 'skulmate_notes',
          );
          fileUrls.add(url);
        }
      } else {
        // On mobile, use File objects
      for (final file in _selectedFiles) {
        final url = await StorageService.uploadDocument(
          userId: user.id,
          documentFile: file,
          documentType: 'skulmate_notes',
        );
        fileUrls.add(url);
        }
      }

      // Upload all images (XFile works on both web and mobile)
      for (final image in _selectedImages) {
        final url = await StorageService.uploadDocument(
          userId: user.id,
          documentFile: image, // Pass XFile directly - StorageService handles it
          documentType: 'skulmate_notes',
        );
        imageUrls.add(url);
      }

      // Navigate to game generation screen
      // For now, send first file/image URL (API may need update to handle multiple)
    if (mounted) {
        await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameGenerationScreen(
              fileUrl: fileUrls.isNotEmpty ? fileUrls.first : null,
              imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
            childId: widget.childId,
            ),
          ),
        );
      }
    } catch (e) {
      LogService.error('Error uploading/generating: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedFiles.isNotEmpty || _selectedFilesWeb.isNotEmpty || _selectedImages.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sports_esports_rounded,
              size: 18,
              color: AppTheme.textDark,
            ),
            const SizedBox(width: 6),
            Text(
              'skulMate',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_rounded, color: AppTheme.textDark, size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GameLibraryScreen(childId: widget.childId),
                ),
              );
            },
            tooltip: 'Game Dashboard',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Turn Your Notes Into Games!',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Upload your notes, documents, or photos and skulMate will create interactive games to help you learn',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Choose Upload Method
            Text(
              'Choose Upload Method',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),

            const SizedBox(height: 12),

            // Upload Options - Three cards
            _buildUploadCard(
              icon: Icons.picture_as_pdf_rounded,
              title: 'Upload PDF/Document',
              subtitle: 'PDF, DOCX, or TXT files',
              onTap: _pickDocument,
              isSelected: kIsWeb ? _selectedFilesWeb.isNotEmpty : _selectedFiles.isNotEmpty,
            ),
            const SizedBox(height: 12),
            _buildUploadCard(
              icon: Icons.photo_library_rounded,
              title: 'Upload Photo/Image',
              subtitle: 'Take photos or select from gallery',
              onTap: _showPhotoOptions,
              isSelected: _selectedImages.isNotEmpty,
            ),
            const SizedBox(height: 12),
            _buildUploadCard(
              icon: Icons.text_fields_rounded,
              title: 'Enter Text Manually',
              subtitle: 'Type or paste your notes',
              onTap: _navigateToTextInput,
              isSelected: false,
            ),

            // Show selected files/images info
            if (hasSelection) ...[
              const SizedBox(height: 16),
              // Selected files grid
              if (_selectedFiles.isNotEmpty || _selectedFilesWeb.isNotEmpty) ...[
                Text(
                  'Selected Documents (${kIsWeb ? _selectedFilesWeb.length : _selectedFiles.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(kIsWeb ? _selectedFilesWeb.length : _selectedFiles.length, (index) {
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.picture_as_pdf_rounded,
                            color: AppTheme.primaryColor,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedFileNames[index],
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppTheme.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              safeSetState(() {
                                if (kIsWeb) {
                                  _selectedFilesWeb.removeAt(index);
                                } else {
                                _selectedFiles.removeAt(index);
                                }
                                _selectedFileNames.removeAt(index);
                              });
                            },
                            child: Icon(Icons.close, size: 14, color: AppTheme.textMedium),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
              ],
              // Selected images grid
              if (_selectedImages.isNotEmpty) ...[
                Text(
                  'Selected Photos (${_selectedImages.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    final image = _selectedImages[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? FutureBuilder<Uint8List?>(
                                  future: _imageBytesCache.containsKey(index)
                                      ? Future.value(_imageBytesCache[index])
                                      : image.readAsBytes().then((bytes) {
                                          _imageBytesCache[index] = bytes;
                                          return bytes;
                                        }),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData && snapshot.data != null) {
                                      return Image.memory(
                                        snapshot.data!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      );
                                    }
                                    return Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  },
                                )
                              : Image.file(
                                  File(image.path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () {
                              safeSetState(() {
                                _imageBytesCache.remove(index);
                                _selectedImages.removeAt(index);
                                // Re-index the cache after removal
                                final newCache = <int, Uint8List>{};
                                for (int i = 0; i < _selectedImages.length; i++) {
                                  final oldIndex = i < index ? i : i + 1;
                                  if (_imageBytesCache.containsKey(oldIndex)) {
                                    newCache[i] = _imageBytesCache[oldIndex]!;
                                  }
                                }
                                _imageBytesCache = newCache;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  ),
                  const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              // Generate Game Button (only for file/photo uploads)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _uploadAndGenerate,
                    style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Generate Game',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: onTap,
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
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.textMedium,
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
                      fontSize: 13,
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
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primaryColor,
                size: 20,
                  ),
                ],
              ),
            ),
    );
  }
}
