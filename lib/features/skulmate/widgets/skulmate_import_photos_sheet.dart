import 'dart:typed_data';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../services/skulmate_pricing_service.dart';
import 'photo_upload_bottom_sheet.dart';
import 'skulmate_surface_styles.dart';

/// Gizmo-style staging sheet: add photos one at a time, then Continue.
class SkulMateImportPhotosSheet extends StatefulWidget {
  final int initialMaxImages;

  const SkulMateImportPhotosSheet({super.key, this.initialMaxImages = 3});

  static bool _sheetOpening = false;

  static bool get isOpening => _sheetOpening;

  static Future<List<XFile>?> show(BuildContext context) async {
    if (_sheetOpening) return null;
    _sheetOpening = true;
    SkulMateSurfaceStyles.lightTap();
    try {
      if (!context.mounted) return null;
      return showModalBottomSheet<List<XFile>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const SkulMateImportPhotosSheet(),
      );
    } finally {
      _sheetOpening = false;
    }
  }

  @override
  State<SkulMateImportPhotosSheet> createState() =>
      _SkulMateImportPhotosSheetState();
}

class _SkulMateImportPhotosSheetState extends State<SkulMateImportPhotosSheet> {
  final List<XFile> _images = [];
  final _picker = ImagePicker();
  bool _isPicking = false;
  bool _loadingLimit = true;
  int? _maxImages;

  int get _effectiveMax => _maxImages ?? widget.initialMaxImages;

  bool get _canAddMore => _images.length < _effectiveMax;

  bool get _canContinue => _images.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadLimit();
  }

  Future<void> _loadLimit() async {
    final max = await SkulmatePricingService.resolveMaxImagesPerPrompt();
    if (!mounted) return;
    setState(() {
      _maxImages = max;
      _loadingLimit = false;
      while (_images.length > max) {
        _images.removeLast();
      }
    });
  }

  Future<void> _addPhoto() async {
    if (!_canAddMore || _isPicking || _loadingLimit) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => const PhotoUploadBottomSheet(),
    );
    if (source == null || !mounted) return;

    setState(() => _isPicking = true);
    try {
      XFile? picked;
      if (source == ImageSource.gallery) {
        picked = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
      } else {
        picked = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
      }
      if (picked != null && mounted) {
        setState(() => _images.add(picked!));
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _removeAt(int index) {
    setState(() => _images.removeAt(index));
  }

  void _continue() {
    if (!_canContinue) return;
    Navigator.pop(context, List<XFile>.from(_images));
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.softBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppTheme.softBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: AppTheme.primaryColor.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  copy.importPhotosTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              if (_loadingLimit)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppTheme.textDark),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          if (_images.isNotEmpty || !_loadingLimit) ...[
            const SizedBox(height: 4),
            Text(
              copy.importPhotosLimit(_images.length, _effectiveMax),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textMedium,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _images.length; i++)
                _PhotoThumb(
                  file: _images[i],
                  onRemove: () => _removeAt(i),
                ),
              if (_canAddMore && !_loadingLimit)
                _AddPhotoTile(
                  onTap: _isPicking ? null : _addPhoto,
                  loading: _isPicking,
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canContinue ? _continue : null,
              style: SkulMateSurfaceStyles.sheetPrimaryButton(
                enabled: _canContinue,
              ),
              child: Text(
                copy.importPhotosContinue,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;

  const _PhotoThumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 88,
              height: 88,
              color: Colors.white,
              child: _thumbImage(),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbImage() {
    if (!kIsWeb && file.path.isNotEmpty) {
      return Image.file(File(file.path), fit: BoxFit.cover);
    }
    return FutureBuilder<List<int>>(
      future: file.readAsBytes(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return Image.memory(
          Uint8List.fromList(snap.data!),
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;

  const _AddPhotoTile({this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.softBorder),
          ),
          child: loading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Icon(
                  Icons.add_rounded,
                  size: 32,
                  color: AppTheme.textMedium.withValues(alpha: 0.7),
                ),
        ),
      ),
    );
  }
}
