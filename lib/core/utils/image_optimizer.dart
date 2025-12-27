import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../services/log_service.dart';

/// Image optimization utility
/// 
/// Provides methods to compress and optimize images before upload
/// to reduce file size and improve upload performance.
class ImageOptimizer {
  /// Maximum file size in bytes (10MB)
  static const int maxFileSize = 10 * 1024 * 1024;
  
  /// Maximum image width/height for optimization
  static const int maxDimension = 2048;
  
  /// Quality for JPEG compression (0-100)
  static const int jpegQuality = 85;

  /// Optimize an image file
  /// 
  /// Compresses and resizes the image if needed to reduce file size.
  /// Returns the optimized file path, or the original if optimization isn't needed.
  /// 
  /// [file] - The image file to optimize
  /// [maxSize] - Maximum file size in bytes (default: 10MB)
  /// [maxWidth] - Maximum width in pixels (default: 2048)
  /// [maxHeight] - Maximum height in pixels (default: 2048)
  /// [quality] - JPEG quality 0-100 (default: 85)
  /// 
  /// Returns the optimized file path
  static Future<File?> optimizeImage(
    File file, {
    int? maxSize,
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) async {
    try {
      final fileSize = await file.length();
      final maxFileSize = maxSize ?? ImageOptimizer.maxFileSize;
      
      // If file is already small enough, return original
      if (fileSize <= maxFileSize) {
        LogService.debug('Image already optimized: ${fileSize / 1024}KB');
        return file;
      }

      // Read image file
      final imageBytes = await file.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);
      
      if (originalImage == null) {
        LogService.warning('Could not decode image: ${file.path}');
        return file; // Return original if decode fails
      }
      
      final effectiveMaxWidth = maxWidth ?? maxDimension;
      final effectiveMaxHeight = maxHeight ?? maxDimension;
      final effectiveQuality = quality ?? jpegQuality;
      
      // Resize if needed
      img.Image? processedImage = originalImage;
      if (originalImage.width > effectiveMaxWidth || originalImage.height > effectiveMaxHeight) {
        processedImage = img.copyResize(
          originalImage,
          width: originalImage.width > effectiveMaxWidth ? effectiveMaxWidth : null,
          height: originalImage.height > effectiveMaxHeight ? effectiveMaxHeight : null,
          maintainAspect: true,
        );
        LogService.debug(
          'Image resized: ${originalImage.width}x${originalImage.height} → '
          '${processedImage.width}x${processedImage.height}'
        );
      }
      
      // Determine output format
      final extension = path.extension(file.path).toLowerCase();
      final isJpeg = extension == '.jpg' || extension == '.jpeg';
      
      // Encode with compression
      Uint8List compressedBytes;
      if (isJpeg) {
        compressedBytes = Uint8List.fromList(
          img.encodeJpg(processedImage, quality: effectiveQuality)
        );
      } else {
        // For PNG, use PNG encoding (lossless but larger)
        // Could convert to JPEG for better compression
        compressedBytes = Uint8List.fromList(img.encodePng(processedImage));
        
        // If PNG is still too large, convert to JPEG
        if (compressedBytes.length > maxFileSize) {
          LogService.debug('PNG too large, converting to JPEG');
          compressedBytes = Uint8List.fromList(
            img.encodeJpg(processedImage, quality: effectiveQuality)
          );
        }
      }
      
      // Check if compression helped
      if (compressedBytes.length >= fileSize) {
        LogService.debug('Compression did not reduce size, returning original');
        return file;
      }
      
      // Save compressed image to temp file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputExtension = compressedBytes.length < fileSize && !isJpeg ? '.jpg' : extension;
      final outputFile = File(path.join(
        tempDir.path,
        'optimized_$timestamp$outputExtension'
      ));
      
      await outputFile.writeAsBytes(compressedBytes);
      
      final originalSizeKB = (fileSize / 1024).toStringAsFixed(2);
      final compressedSizeKB = (compressedBytes.length / 1024).toStringAsFixed(2);
      final reductionPercent = ((1 - compressedBytes.length / fileSize) * 100).toStringAsFixed(1);
      
      LogService.success(
        'Image optimized: $originalSizeKB KB → $compressedSizeKB KB '
        '($reductionPercent% reduction)'
      );
      
      return outputFile;
    } catch (e) {
      LogService.error('Error in optimizeImage: $e');
      return file; // Return original on error
    }
  }

  /// Validate image file
  /// 
  /// Checks if the file is a valid image and within size limits.
  /// 
  /// [file] - The file to validate
  /// [maxSize] - Maximum file size in bytes (default: 10MB)
  /// 
  /// Returns error message if invalid, null if valid
  static Future<String?> validateImage(
    File file, {
    int? maxSize,
  }) async {
    try {
      // Check file exists
      if (!await file.exists()) {
        return 'File does not exist';
      }

      // Check file size
      final fileSize = await file.length();
      final maxFileSize = maxSize ?? ImageOptimizer.maxFileSize;
      
      if (fileSize > maxFileSize) {
        final sizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
        final maxMB = (maxFileSize / (1024 * 1024)).toStringAsFixed(0);
        return 'File is too large ($sizeMB MB). Maximum size is $maxMB MB.';
      }

      // Check file extension
      final extension = path.extension(file.path).toLowerCase();
      final allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
      
      if (!allowedExtensions.contains(extension)) {
        return 'Invalid file format. Please use JPG, PNG, GIF, or WEBP.';
      }

      return null; // Valid
    } catch (e) {
      LogService.error('Error validating image: $e');
      return 'Error validating image: $e';
    }
  }

  /// Get image file size in human-readable format
  static Future<String> getFileSizeString(File file) async {
    try {
      final bytes = await file.length();
      if (bytes < 1024) {
        return '$bytes B';
      } else if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(2)} KB';
      } else {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
      }
    } catch (e) {
      return 'Unknown size';
    }
  }

  /// Check if file needs optimization
  static Future<bool> needsOptimization(
    File file, {
    int? maxSize,
  }) async {
    try {
      final fileSize = await file.length();
      final maxFileSize = maxSize ?? ImageOptimizer.maxFileSize;
      return fileSize > maxFileSize;
    } catch (e) {
      return false;
    }
  }

  /// Optimize XFile (from image_picker)
  /// 
  /// Converts XFile to File, optimizes it, and returns optimized XFile.
  /// 
  /// [xFile] - The XFile to optimize
  /// [maxSize] - Maximum file size in bytes (default: 10MB)
  /// [maxWidth] - Maximum width in pixels (default: 2048)
  /// [maxHeight] - Maximum height in pixels (default: 2048)
  /// [quality] - JPEG quality 0-100 (default: 85)
  /// 
  /// Returns optimized XFile, or original if optimization isn't needed/fails
  static Future<XFile?> optimizeXFile(
    XFile xFile, {
    int? maxSize,
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) async {
    try {
      // Convert XFile to File
      final file = File(xFile.path);
      if (!await file.exists()) {
        LogService.warning('XFile path does not exist: ${xFile.path}');
        return xFile; // Return original
      }

      // Optimize the file
      final optimizedFile = await optimizeImage(
        file,
        maxSize: maxSize,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
      );

      if (optimizedFile == null || optimizedFile.path == file.path) {
        // No optimization needed or failed, return original
        return xFile;
      }

      // Convert optimized File back to XFile
      return XFile(optimizedFile.path, mimeType: xFile.mimeType);
    } catch (e) {
      LogService.error('Error optimizing XFile: $e');
      return xFile; // Return original on error
    }
  }
}
