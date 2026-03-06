import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:prepskul/core/services/log_service.dart';

/// Combines multiple images into a single PDF for game generation.
class ImageToPdfUtils {
  /// Create a PDF from a list of XFile images (e.g. scanned notes).
  /// Returns PDF bytes, or null if creation fails.
  static Future<Uint8List?> imagesToPdf(List<XFile> images) async {
    if (images.isEmpty) return null;
    if (images.length == 1) {
      try {
        final bytes = await images.first.readAsBytes();
        return _singleImageToPdf(bytes);
      } catch (e) {
        LogService.error('Failed to convert single image to PDF: $e');
        return null;
      }
    }

    try {
      final pdf = pw.Document();
      int pageCount = 0;
      for (final xfile in images) {
        final bytes = await xfile.readAsBytes();
        if (bytes.isEmpty) continue;

        pw.MemoryImage? img;
        try {
          img = pw.MemoryImage(bytes);
        } catch (e) {
          LogService.warning('Skipping image (invalid format): $e');
          continue;
        }

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context context) {
              return pw.Center(
                child: pw.FittedBox(
                  fit: pw.BoxFit.contain,
                  child: pw.Image(img!),
                ),
              );
            },
          ),
        );
        pageCount++;
      }

      if (pageCount == 0) return null;
      return pdf.save();
    } catch (e) {
      LogService.error('Failed to create PDF from images: $e');
      return null;
    }
  }

  static Future<Uint8List?> _singleImageToPdf(Uint8List bytes) async {
    try {
      final img = pw.MemoryImage(bytes);
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.FittedBox(
                fit: pw.BoxFit.contain,
                child: pw.Image(img),
              ),
            );
          },
        ),
      );
      return pdf.save();
    } catch (e) {
      LogService.error('Failed to create PDF from single image: $e');
      return null;
    }
  }
}
