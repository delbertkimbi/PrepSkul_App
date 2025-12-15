import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';

/// Comprehensive file upload service for PrepSkul
/// Handles images, documents, and videos for Supabase Storage
class StorageService {
  static final ImagePicker _imagePicker = ImagePicker();

  // Bucket names
  static const String profilePhotosBucket = 'profile-photos';
  static const String documentsBucket = 'documents';
  static const String videosBucket = 'videos';

  // File size limits (in bytes)
  // Note: Supabase allows up to 50 MB by default, but you can increase this in your project settings
  static const int maxImageSize =
      10 * 1024 * 1024; // 10 MB (increased from 2 MB)
  static const int maxDocumentSize =
      10 * 1024 * 1024; // 10 MB (increased from 5 MB)
  static const int maxVideoSize = 50 * 1024 * 1024; // 50 MB

  /// Upload profile photo
  static Future<String> uploadProfilePhoto({
    required String userId,
    required File imageFile,
    String fileName = 'avatar.jpg',
  }) async {
    try {
      // Validate file size
      final fileSize = await imageFile.length();
      if (fileSize > maxImageSize) {
        throw Exception(
          'Image too large. Maximum size is ${maxImageSize ~/ (1024 * 1024)} MB',
        );
      }

      // Validate file type
      final mimeType = lookupMimeType(imageFile.path);
      if (mimeType == null || !mimeType.startsWith('image/')) {
        throw Exception('Invalid file type. Please select an image file');
      }

      // Create storage path
      final storagePath = '$userId/$fileName';

      // Upload to Supabase
      await SupabaseService.client.storage
          .from(profilePhotosBucket)
          .upload(storagePath, imageFile);

      // Get public URL
      final publicUrl = SupabaseService.client.storage
          .from(profilePhotosBucket)
          .getPublicUrl(storagePath);

      LogService.success('Profile photo uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      LogService.error('Error uploading profile photo: $e');
      rethrow;
    }
  }

  /// Delete existing document file(s) before re-upload
  /// Handles multiple file extensions to prevent conflicts
  static Future<void> _deleteExistingDocument(
    String userId,
    String documentType,
  ) async {
    try {
      // List of possible extensions for this document type
      final extensions = ['.jpg', '.jpeg', '.png', '.pdf'];

      for (final ext in extensions) {
        final path = '$userId/$documentType$ext';
        try {
          await SupabaseService.client.storage.from(documentsBucket).remove([
            path,
          ]);
          LogService.info('[DEBUG] Deleted existing file: $path');
        } catch (e) {
          // File doesn't exist, continue silently
        }
      }
    } catch (e) {
      // Ignore errors - file might not exist
      LogService.warning('[DEBUG] Could not delete existing file: $e');
    }
  }

  /// Upload document (PDF, image)
  /// Handles File, XFile, and PlatformFile for cross-platform support
  static Future<String> uploadDocument({
    required String userId,
    required dynamic documentFile, // File, XFile, or PlatformFile
    required String documentType, // e.g., 'id_front', 'degree', etc.
  }) async {
    try {
      String? mimeType;
      String fileExtension;
      int fileSize;
      dynamic uploadData; // File, XFile, Uint8List, or PlatformFile

      LogService.debug(
        '🔍 [DEBUG] uploadDocument called with type: ${documentFile.runtimeType}',
      );
      LogService.debug('[DEBUG] isWeb: $kIsWeb');

      // Handle PlatformFile (from file_picker, works on all platforms)
      if (documentFile is PlatformFile) {
        LogService.debug('[DEBUG] Detected PlatformFile: ${documentFile.name}');

        final fileName = documentFile.name;
        fileExtension = path.extension(fileName).isEmpty
            ? '.jpg'
            : path.extension(fileName);
        mimeType = lookupMimeType(fileName) ?? 'image/jpeg';

        if (kIsWeb) {
          // Web: PlatformFile has bytes
          if (documentFile.bytes != null) {
            fileSize = documentFile.bytes!.length;
            uploadData = documentFile.bytes!;
            LogService.debug(
              '🔍 [DEBUG] Web: Using PlatformFile bytes (${fileSize} bytes)',
            );
          } else {
            throw Exception('PlatformFile bytes are null on web');
          }
        } else {
          // Mobile: PlatformFile has path
          if (documentFile.path != null && documentFile.path!.isNotEmpty) {
            final File file = File(documentFile.path!);
            fileSize = await file.length();
            uploadData = file;
            LogService.debug(
              '🔍 [DEBUG] Mobile: Using PlatformFile path (${fileSize} bytes)',
            );
          } else {
            throw Exception('PlatformFile path is null on mobile');
          }
        }
      }
      // Handle XFile (from image_picker, works on all platforms)
      else if (documentFile is XFile) {
        LogService.debug('[DEBUG] Detected XFile: ${documentFile.name}');

        // Get file name and extension - handle web vs mobile differently
        String fileName = documentFile.name;

        if (kIsWeb) {
          // On web: Use name directly, never access .path
          if (fileName.isEmpty || fileName == '') {
            // Default for web when name is missing
            fileName = 'upload.jpg';
            fileExtension = '.jpg';
            mimeType = 'image/jpeg';
            LogService.debug('[DEBUG] Web: Using default name and extension');
          } else {
            fileExtension = path.extension(fileName).isEmpty
                ? '.jpg'
                : path.extension(fileName);
            mimeType = lookupMimeType(fileName) ?? 'image/jpeg';
            LogService.debug(
              '🔍 [DEBUG] Web: Using name for extension: $fileExtension, mime: $mimeType',
            );
          }

          // Web: Use bytes (NEVER access .path on web)
          LogService.debug('[DEBUG] Web platform: Reading as bytes');
          try {
            final Uint8List bytes = await documentFile.readAsBytes();
            fileSize = bytes.length;
            uploadData = bytes;
            LogService.debug('[DEBUG] Read ${fileSize} bytes');
          } catch (e) {
            LogService.error('[DEBUG] Error reading XFile bytes: $e');
            throw Exception('Failed to read file data: $e');
          }
        } else {
          // Mobile: Can safely use both name and path
          if (fileName.isEmpty || fileName == '') {
            // Fallback: try to get name from path (mobile only)
            try {
              final filePath = documentFile.path;
              if (filePath.isNotEmpty) {
                fileExtension = path.extension(filePath).isEmpty
                    ? '.jpg'
                    : path.extension(filePath);
                mimeType = lookupMimeType(filePath) ?? 'image/jpeg';
                fileName = path.basename(filePath);
                LogService.debug(
                  '🔍 [DEBUG] Mobile: Using path for extension: $fileExtension',
                );
              } else {
                fileExtension = '.jpg';
                mimeType = 'image/jpeg';
                LogService.debug('[DEBUG] Mobile: Using default extension');
              }
            } catch (e) {
              LogService.warning('[DEBUG] Error accessing path, using defaults: $e');
              fileExtension = '.jpg';
              mimeType = 'image/jpeg';
            }
          } else {
            fileExtension = path.extension(fileName).isEmpty
                ? '.jpg'
                : path.extension(fileName);
            mimeType = lookupMimeType(fileName) ?? 'image/jpeg';
            LogService.debug(
              '🔍 [DEBUG] Mobile: Using name for extension: $fileExtension, mime: $mimeType',
            );
          }

          // Mobile: Use File path
          LogService.debug('[DEBUG] Mobile platform: Using file path');
          try {
            final filePath = documentFile.path;
            if (filePath.isEmpty) {
              throw Exception('File path is empty. Cannot upload on mobile.');
            }
            final File file = File(filePath);
            fileSize = await file.length();
            uploadData = file;
            LogService.debug('[DEBUG] File size: $fileSize bytes');
          } catch (e) {
            LogService.error('[DEBUG] Error creating File from path: $e');
            throw Exception('Failed to access file: $e');
          }
        }
      } else if (documentFile is File) {
        // File objects should only come from mobile, but handle safely
        LogService.debug('[DEBUG] Detected File');
        if (kIsWeb) {
          // On web, File objects are NOT supported
          // File.path will throw NoSuchMethodError on web
          LogService.error('[DEBUG] File object detected on web - not supported');
          throw Exception(
            'File objects are not supported on web. Please use Gallery or Files option to select files.',
          );
        } else {
          // Mobile: Use File normally
          uploadData = documentFile;
          mimeType = lookupMimeType(documentFile.path) ?? 'image/jpeg';
          fileExtension = path.extension(documentFile.path).isEmpty
              ? '.jpg'
              : path.extension(documentFile.path);
          fileSize = await documentFile.length();
          LogService.debug(
            '🔍 [DEBUG] File size: $fileSize bytes, extension: $fileExtension',
          );
        }
      } else if (documentFile is Uint8List) {
        LogService.debug('[DEBUG] Detected Uint8List directly');
        uploadData = documentFile;
        fileSize = documentFile.length;
        // For Uint8List, we can't determine mime type easily
        mimeType = 'image/jpeg'; // Default
        fileExtension = '.jpg'; // Default
        LogService.debug('[DEBUG] Uint8List size: $fileSize bytes');
      } else {
        LogService.error('[DEBUG] Unsupported file type: ${documentFile.runtimeType}');
        throw Exception(
          'Unsupported file type: ${documentFile.runtimeType}. Expected File, XFile, or PlatformFile.',
        );
      }

      // Validate file size
      if (fileSize > maxDocumentSize) {
        throw Exception(
          'Document too large. Maximum size is ${maxDocumentSize ~/ (1024 * 1024)} MB',
        );
      }

      // Validate file type
      if (!mimeType.startsWith('image/') && mimeType != 'application/pdf') {
        throw Exception(
          'Invalid file type. Only images and PDF files are allowed',
        );
      }

      // Create storage path
      final storagePath = '$userId/$documentType$fileExtension';

      // Delete existing file(s) before upload to prevent conflicts
      // This handles file extension changes (e.g., .jpeg to .png)
      await _deleteExistingDocument(userId, documentType);

      // Upload to Supabase - use uploadBinary on web for Uint8List, upload for mobile File
      LogService.debug('[DEBUG] Uploading to path: $storagePath');
      LogService.debug('[DEBUG] Upload data type: ${uploadData.runtimeType}');
      LogService.debug('[DEBUG] Platform: ${kIsWeb ? "Web" : "Mobile"}');

      try {
        if (kIsWeb && uploadData is Uint8List) {
          // Web: use uploadBinary for Uint8List
          LogService.debug('[DEBUG] Using uploadBinary for web upload');
          await SupabaseService.client.storage
              .from(documentsBucket)
              .uploadBinary(
                storagePath,
                uploadData,
                fileOptions: FileOptions(
                  contentType: mimeType,
                  upsert:
                      false, // We deleted the file above, so no need for upsert
                ),
              );
          LogService.success('[DEBUG] uploadBinary completed successfully');
        } else {
          // Mobile: use regular upload with File
          LogService.debug('[DEBUG] Using regular upload for mobile');
          await SupabaseService.client.storage
              .from(documentsBucket)
              .upload(
                storagePath,
                uploadData,
                fileOptions: const FileOptions(
                  upsert:
                      false, // We deleted the file above, so no need for upsert
                ),
              );
          LogService.success('[DEBUG] Regular upload completed successfully');
        }
      } catch (uploadError) {
        // Handle specific upload errors
        final errorString = uploadError.toString();

        // Check if it's a StorageException and extract status code
        int? statusCode;
        if (uploadError is Exception) {
          final errorMessage = uploadError.toString();
          // Try to extract status code from error message
          final statusMatch = RegExp(
            r'statusCode:\s*(\d+)',
          ).firstMatch(errorMessage);
          if (statusMatch != null) {
            statusCode = int.tryParse(statusMatch.group(1)!);
          }
        }

        // If 409 error (duplicate), try deleting and retrying once
        if (statusCode == 409 ||
            errorString.contains('409') ||
            errorString.contains('already exists') ||
            errorString.contains('Duplicate')) {
          LogService.warning('[DEBUG] Duplicate file detected, deleting and retrying...');
          // Delete the exact file path and retry
          try {
            await SupabaseService.client.storage.from(documentsBucket).remove([
              storagePath,
            ]);
            LogService.info('[DEBUG] Deleted duplicate file: $storagePath');

            // Retry upload
            if (kIsWeb && uploadData is Uint8List) {
              await SupabaseService.client.storage
                  .from(documentsBucket)
                  .uploadBinary(
                    storagePath,
                    uploadData,
                    fileOptions: FileOptions(
                      contentType: mimeType,
                      upsert: false,
                    ),
                  );
            } else {
              await SupabaseService.client.storage
                  .from(documentsBucket)
                  .upload(
                    storagePath,
                    uploadData,
                    fileOptions: const FileOptions(upsert: false),
                  );
            }
            LogService.success('[DEBUG] Retry upload successful');
          } catch (retryError) {
            LogService.error('[DEBUG] Retry failed: $retryError');
            throw Exception(
              'Failed to upload document. Please try again or contact support if the issue persists.',
            );
          }
        }
        // If 403 error (RLS policy), provide user-friendly message
        else if (statusCode == 403 ||
            errorString.contains('403') ||
            errorString.contains('row-level security') ||
            errorString.contains('Unauthorized')) {
          LogService.error('[DEBUG] RLS policy error: $uploadError');
          throw Exception(
            'Upload failed due to permissions. Please ensure you are logged in and try again. If the issue persists, contact support.',
          );
        }
        // Re-throw other errors
        else {
          rethrow;
        }
      }

      // Get authenticated URL (documents are private)
      final signedUrl = await SupabaseService.client.storage
          .from(documentsBucket)
          .createSignedUrl(storagePath, 3600 * 24 * 365); // 1 year

      LogService.success('Document uploaded: $documentType');
      return signedUrl;
    } catch (e) {
      LogService.error('Error uploading document: $e');
      rethrow;
    }
  }

  /// Upload video
  static Future<String> uploadVideo({
    required String userId,
    required File videoFile,
    String fileName = 'intro.mp4',
  }) async {
    try {
      // Validate file size
      final fileSize = await videoFile.length();
      if (fileSize > maxVideoSize) {
        throw Exception(
          'Video too large. Maximum size is ${maxVideoSize ~/ (1024 * 1024)} MB',
        );
      }

      // Validate file type
      final mimeType = lookupMimeType(videoFile.path);
      if (mimeType == null || !mimeType.startsWith('video/')) {
        throw Exception('Invalid file type. Please select a video file');
      }

      // Create storage path
      final storagePath = '$userId/$fileName';

      // Upload to Supabase
      await SupabaseService.client.storage
          .from(videosBucket)
          .upload(storagePath, videoFile);

      // Get public URL
      final publicUrl = SupabaseService.client.storage
          .from(videosBucket)
          .getPublicUrl(storagePath);

      LogService.success('Video uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      LogService.error('Error uploading video: $e');
      rethrow;
    }
  }

  /// Pick image from gallery
  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return null;

      return File(image.path);
    } catch (e) {
      LogService.error('Error picking image: $e');
      return null;
    }
  }

  /// Pick image from camera
  static Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return null;

      return File(image.path);
    } catch (e) {
      LogService.error('Error taking photo: $e');
      return null;
    }
  }

  /// Pick document (PDF or image)
  static Future<File?> pickDocument() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result == null || result.files.isEmpty) return null;

      final filePath = result.files.single.path;
      if (filePath == null) return null;

      return File(filePath);
    } catch (e) {
      LogService.error('Error picking document: $e');
      return null;
    }
  }

  /// Pick video
  static Future<File?> pickVideo() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
      );

      if (result == null || result.files.isEmpty) return null;

      final filePath = result.files.single.path;
      if (filePath == null) return null;

      return File(filePath);
    } catch (e) {
      LogService.error('Error picking video: $e');
      return null;
    }
  }

  /// Delete file from storage
  static Future<void> deleteFile({
    required String bucket,
    required String filePath,
  }) async {
    try {
      await SupabaseService.client.storage.from(bucket).remove([filePath]);

      LogService.success('File deleted: $filePath');
    } catch (e) {
      LogService.error('Error deleting file: $e');
      rethrow;
    }
  }

  /// Get file URL (public or signed)
  static Future<String> getFileUrl({
    required String bucket,
    required String filePath,
    bool isPublic = true,
  }) async {
    try {
      if (isPublic) {
        return SupabaseService.client.storage
            .from(bucket)
            .getPublicUrl(filePath);
      } else {
        return await SupabaseService.client.storage
            .from(bucket)
            .createSignedUrl(
              filePath,
              3600 * 24 * 365, // 1 year
            );
      }
    } catch (e) {
      LogService.error('Error getting file URL: $e');
      rethrow;
    }
  }

  /// Upload with progress tracking
  static Future<String> uploadWithProgress({
    required String bucket,
    required File file,
    required String storagePath,
    required Function(double progress) onProgress,
  }) async {
    try {
      // Note: Supabase storage doesn't support progress callbacks yet
      // This is a placeholder for future implementation
      onProgress(0.0);

      await SupabaseService.client.storage
          .from(bucket)
          .upload(storagePath, file);

      onProgress(1.0);

      return SupabaseService.client.storage
          .from(bucket)
          .getPublicUrl(storagePath);
    } catch (e) {
      LogService.error('Error uploading with progress: $e');
      rethrow;
    }
  }

  /// Show image picker dialog (Gallery or Camera)
  static Future<File?> showImagePickerDialog({
    required Function() onGallery,
    required Function() onCamera,
  }) async {
    // This should be called from a widget context
    // For now, return null - implement in UI layer
    return null;
  }

  /// Validate file size
  static Future<bool> isFileSizeValid(File file, int maxSize) async {
    final fileSize = await file.length();
    return fileSize <= maxSize;
  }

  /// Get file size in MB
  static Future<double> getFileSizeInMB(File file) async {
    final fileSize = await file.length();
    return fileSize / (1024 * 1024);
  }

  /// Get file extension
  static String getFileExtension(File file) {
    return path.extension(file.path);
  }

  /// Check if file is image
  static bool isImage(File file) {
    final mimeType = lookupMimeType(file.path);
    return mimeType != null && mimeType.startsWith('image/');
  }

  /// Check if file is PDF
  static bool isPDF(File file) {
    final mimeType = lookupMimeType(file.path);
    return mimeType == 'application/pdf';
  }

  /// Check if file is video
  static bool isVideo(File file) {
    final mimeType = lookupMimeType(file.path);
    return mimeType != null && mimeType.startsWith('video/');
  }
}
