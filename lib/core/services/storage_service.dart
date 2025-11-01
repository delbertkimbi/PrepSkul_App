import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'supabase_service.dart';

/// Comprehensive file upload service for PrepSkul
/// Handles images, documents, and videos for Supabase Storage
class StorageService {
  static final ImagePicker _imagePicker = ImagePicker();

  // Bucket names
  static const String profilePhotosBucket = 'profile-photos';
  static const String documentsBucket = 'documents';
  static const String videosBucket = 'videos';

  // File size limits (in bytes)
  static const int maxImageSize = 2 * 1024 * 1024; // 2 MB
  static const int maxDocumentSize = 5 * 1024 * 1024; // 5 MB
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

      print('✅ Profile photo uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error uploading profile photo: $e');
      rethrow;
    }
  }

  /// Upload document (PDF, image)
  /// Handles both File and XFile for cross-platform support
  static Future<String> uploadDocument({
    required String userId,
    required dynamic documentFile, // File or XFile
    required String documentType, // e.g., 'id_front', 'degree', etc.
  }) async {
    try {
      File uploadableFile;
      String? mimeType;
      String fileExtension;

      // Handle different file types - convert to File for upload
      if (documentFile is XFile) {
        // XFile: For mobile, use path. For web, throw error (not supported yet)
        if (kIsWeb) {
          throw Exception(
            'Web uploads are not yet supported. Please use mobile app for file uploads.',
          );
        }

        mimeType = lookupMimeType(documentFile.name);
        fileExtension = path.extension(documentFile.name);
        uploadableFile = File(documentFile.path);
      } else if (documentFile is File) {
        uploadableFile = documentFile;
        mimeType = lookupMimeType(documentFile.path);
        fileExtension = path.extension(documentFile.path);
      } else {
        throw Exception('Unsupported file type: ${documentFile.runtimeType}');
      }

      // Validate file size
      final fileSize = await uploadableFile.length();
      if (fileSize > maxDocumentSize) {
        throw Exception(
          'Document too large. Maximum size is ${maxDocumentSize ~/ (1024 * 1024)} MB',
        );
      }

      // Validate file type
      if (mimeType == null ||
          (!mimeType.startsWith('image/') && mimeType != 'application/pdf')) {
        throw Exception(
          'Invalid file type. Only images and PDF files are allowed',
        );
      }

      // Create storage path
      final storagePath = '$userId/$documentType$fileExtension';

      // Upload to Supabase using File
      await SupabaseService.client.storage
          .from(documentsBucket)
          .upload(storagePath, uploadableFile);

      // Get authenticated URL (documents are private)
      final signedUrl = await SupabaseService.client.storage
          .from(documentsBucket)
          .createSignedUrl(storagePath, 3600 * 24 * 365); // 1 year

      print('✅ Document uploaded: $documentType');
      return signedUrl;
    } catch (e) {
      print('❌ Error uploading document: $e');
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

      print('✅ Video uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error uploading video: $e');
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
      print('❌ Error picking image: $e');
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
      print('❌ Error taking photo: $e');
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
      print('❌ Error picking document: $e');
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
      print('❌ Error picking video: $e');
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

      print('✅ File deleted: $filePath');
    } catch (e) {
      print('❌ Error deleting file: $e');
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
      print('❌ Error getting file URL: $e');
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
      print('❌ Error uploading with progress: $e');
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
