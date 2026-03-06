import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/storage_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'dart:io' show File;
import 'dart:typed_data';
import '../services/skulmate_service.dart';
import '../services/game_stats_service.dart';
import '../models/game_stats_model.dart';
import 'game_generation_screen.dart';
import 'game_library_screen.dart';
import 'text_input_screen.dart';
import '../widgets/photo_upload_bottom_sheet.dart';
import '../widgets/generation_context_sheet.dart';

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
  GameStats? _gameStats;

  @override
  void initState() {
    super.initState();
    _loadGameStats();
  }

  Future<void> _loadGameStats() async {
    final stats = await GameStatsService.getStats();
    if (mounted) safeSetState(() => _gameStats = stats);
  }

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
            _selectedFilesWeb = result.files
                .where((file) => file.bytes != null || file.name.isNotEmpty)
                .toList();
            _selectedFiles = [];
            _selectedFileNames = _selectedFilesWeb
                .map((f) => f.name.trim().isEmpty || f.name == '_' ? '' : f.name)
                .toList();
          } else {
            final mobileFiles = result.files
                .where((file) => file.path != null)
                .toList();
            _selectedFiles = mobileFiles
                .map((file) => File(file.path!))
                .toList();
            _selectedFilesWeb = [];
            _selectedFileNames = mobileFiles
                .map((f) => (f.name.trim().isEmpty || f.name == '_') ? '' : f.name)
                .toList();
          }
          _selectedImages = [];
        });
      }
    } catch (e) {
      LogService.error('Error picking document: $e');
      if (mounted) _showFriendlySnackBar('file_selection');
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
              _selectedFiles = [];
              _selectedFilesWeb = [];
              _selectedFileNames = [];
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
        if (mounted) _showFriendlySnackBar('photo_selection');
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

  String _getDisplayFileName(String rawName, int index) {
    final cleaned = rawName.trim();
    if (cleaned.isEmpty || cleaned == '_' || cleaned == '_.pdf' || cleaned == '.pdf') {
      return 'Document ${index + 1}';
    }
    if (cleaned.endsWith('.pdf')) return cleaned;
    if (cleaned.contains('.')) return cleaned;
    return cleaned;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _navigateToTextInput() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TextInputScreen(childId: widget.childId),
      ),
    );
  }

  void _showFriendlySnackBar(String errorType) {
    String message;
    switch (errorType) {
      case 'upload_permission':
        message = 'Couldn\'t upload your file. Try "Enter Text Manually" instead.';
        break;
      case 'file_too_large':
        message = 'File too large. Try a smaller file or text input.';
        break;
      case 'unsupported_format':
        message = 'Unsupported format. Try PDF, DOCX, or images.';
        break;
      case 'network_error':
        message = 'Connection issue. Check your internet or try text input.';
        break;
      case 'no_selection':
        message = 'Please select files, photos, or use text input first.';
        break;
      case 'file_selection':
      case 'photo_selection':
        message = 'Couldn\'t select that file. Try again or use text input.';
        break;
      default:
        message = 'Something went wrong. Try again or use text input.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
        action: errorType != 'no_selection'
            ? SnackBarAction(
                label: 'Text Input',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  _navigateToTextInput();
                },
              )
            : null,
      ),
    );
  }

  void _showFriendlyError(String errorType, String? details) {
    String title;
    String message;
    IconData icon;
    Color iconColor;
    bool showTextInputButton = false;

    switch (errorType) {
      case 'upload_permission':
        title = 'Upload Issue';
        message = 'We couldn\'t upload your file. Try entering text manually instead.';
        icon = Icons.warning_amber_rounded;
        iconColor = Colors.orange;
        showTextInputButton = true;
        break;
      case 'file_too_large':
        title = 'File Too Large';
        message = 'This file is too large. Please select a smaller file or use text input.';
        icon = Icons.folder_off_rounded;
        iconColor = Colors.orange;
        showTextInputButton = true;
        break;
      case 'unsupported_format':
        title = 'Unsupported Format';
        message = 'This file type isn\'t supported. Try PDF, DOCX, or images.';
        icon = Icons.insert_drive_file_outlined;
        iconColor = Colors.orange;
        showTextInputButton = true;
        break;
      case 'network_error':
        title = 'Connection Issue';
        message = 'Upload failed. Check your internet connection and try again, or use text input instead.';
        icon = Icons.wifi_off_rounded;
        iconColor = Colors.orange;
        showTextInputButton = true;
        break;
      case 'no_selection':
        title = 'No Content Selected';
        message = 'Please select files, photos, or use text input to create a game.';
        icon = Icons.info_outline;
        iconColor = AppTheme.primaryColor;
        showTextInputButton = true;
        break;
      case 'file_selection':
      case 'photo_selection':
        title = 'Selection Error';
        message = 'We couldn\'t select that file. Please try again or use text input.';
        icon = Icons.error_outline;
        iconColor = Colors.orange;
        showTextInputButton = true;
        break;
      default:
        title = 'Something Went Wrong';
        message = 'Please try again or use text input.';
        icon = Icons.error_outline;
        iconColor = Colors.red;
        showTextInputButton = true;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (showTextInputButton) ...[
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToTextInput();
                      },
                      child: Text(
                        'Try Text Input',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'OK',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadAndGenerate() async {
    if (_selectedFiles.isEmpty && _selectedFilesWeb.isEmpty && _selectedImages.isEmpty) {
      _showFriendlySnackBar('no_selection');
      return;
    }

    if (!mounted) return;

    // Show optional context questionnaire first
    final contextResult = await GenerationContextSheet.show(context);
    if (!mounted) return;

    final document = kIsWeb && _selectedFilesWeb.isNotEmpty
        ? _selectedFilesWeb.first
        : (!kIsWeb && _selectedFiles.isNotEmpty ? _selectedFiles.first : null);
    final images = _selectedImages.isNotEmpty ? List<XFile>.from(_selectedImages) : null;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameGenerationScreen(
          documentToUpload: document,
          imageToUpload: images != null && images.length == 1 ? images.first : null,
          imagesToUpload: images != null && images.length > 1 ? images : null,
          childId: widget.childId,
          topic: contextResult?.topic,
          difficulty: contextResult?.difficulty,
          gameType: contextResult?.gameType,
        ),
      ),
    );
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
            PhosphorIcon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), color: AppTheme.textDark, size: 20),
            const SizedBox(width: 8),
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
            // Simple hero banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_gameStats != null && _gameStats!.currentStreak > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.orange.shade200, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🔥', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                Text(
                                  '${_gameStats!.currentStreak} day streak',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    'Turn Your Notes Into Games',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Upload notes, documents, or photos — skulMate creates interactive games to help you learn.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.92),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Selected files/images - shown first when user has made a selection
            if (hasSelection) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your selected files',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              Text(
                                'Tap Generate Game below',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_selectedFiles.isNotEmpty || _selectedFilesWeb.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(kIsWeb ? _selectedFilesWeb.length : _selectedFiles.length, (index) {
                          final rawName = index < _selectedFileNames.length ? _selectedFileNames[index] : '';
                          final displayName = _getDisplayFileName(rawName, index);
                          final ext = displayName.contains('.') ? '' : '.pdf';
                          int sizeBytes = 0;
                          if (kIsWeb && index < _selectedFilesWeb.length) {
                            sizeBytes = _selectedFilesWeb[index].size;
                          } else if (!kIsWeb && index < _selectedFiles.length) {
                            sizeBytes = _selectedFiles[index].lengthSync();
                          }
                          final sizeStr = sizeBytes > 0 ? ' (${_formatFileSize(sizeBytes)})' : '';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.picture_as_pdf_rounded, color: AppTheme.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 220),
                                  child: Text(
                                    displayName + ext + sizeStr,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    safeSetState(() {
                                      if (kIsWeb) {
                                        _selectedFilesWeb.removeAt(index);
                                      } else {
                                        _selectedFiles.removeAt(index);
                                      }
                                      if (index < _selectedFileNames.length) {
                                        _selectedFileNames.removeAt(index);
                                      }
                                    });
                                  },
                                  child: Icon(Icons.close, size: 16, color: AppTheme.textMedium),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_selectedImages.isNotEmpty) ...[
                      Text(
                        'Photos (${_selectedImages.length})',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final count = _selectedImages.length;
                          final width = constraints.maxWidth;
                          int crossAxisCount;
                          double cellExtent;
                          if (count == 1) {
                            crossAxisCount = 1;
                            cellExtent = (width - 8).clamp(120.0, 200.0);
                          } else if (count == 2) {
                            crossAxisCount = 2;
                            cellExtent = (width - 8) / 2;
                          } else if (count <= 4) {
                            crossAxisCount = 2;
                            cellExtent = (width - 8) / 2;
                          } else if (count <= 9) {
                            crossAxisCount = 3;
                            cellExtent = (width - 16) / 3;
                          } else {
                            crossAxisCount = 4;
                            cellExtent = (width - 24) / 4;
                          }
                          cellExtent = cellExtent.clamp(56.0, 200.0);
                          final rows = (count / crossAxisCount).ceil();
                          final maxVisibleRows = 3;
                          final maxHeight = rows <= maxVisibleRows
                              ? (cellExtent * rows) + (8 * (rows - 1))
                              : (cellExtent * maxVisibleRows) + (8 * (maxVisibleRows - 1));
                          return ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: maxHeight),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1,
                                  mainAxisExtent: cellExtent,
                                ),
                                itemCount: count,
                                itemBuilder: (context, index) {
                                  final image = _selectedImages[index];
                                  return Stack(
                                    fit: StackFit.expand,
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
                                                      child: SizedBox(
                                                        width: 24,
                                                        height: 24,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      ),
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
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              size: cellExtent > 80 ? 14 : 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

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
              subtitle: 'Select multiple from gallery or take photos',
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
                      PhosphorIcon(
                        PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                        color: Colors.white,
                        size: 18,
                      ),
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
