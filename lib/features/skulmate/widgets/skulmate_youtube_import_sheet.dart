import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import 'skulmate_sheet_scaffold.dart';
import 'skulmate_surface_styles.dart';

/// Gizmo-style YouTube import bottom sheet.
class SkulMateYoutubeImportSheet extends StatefulWidget {
  const SkulMateYoutubeImportSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return SkulMateSheetScaffold.show<String>(
      context,
      child: const SkulMateYoutubeImportSheet(),
    );
  }

  @override
  State<SkulMateYoutubeImportSheet> createState() =>
      _SkulMateYoutubeImportSheetState();
}

class _SkulMateYoutubeImportSheetState extends State<SkulMateYoutubeImportSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _valid {
    final v = _controller.text.trim();
    return v.contains('youtube.com') || v.contains('youtu.be');
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    return SkulMateSheetScaffold(
      title: copy.youtubeImportTitle,
      maxHeightFactor: 0.52,
      body: TextField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: TextInputType.url,
        autocorrect: false,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.poppins(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'https://youtube.com/watch?v=…',
          hintStyle: GoogleFonts.poppins(
            fontSize: 15,
            color: AppTheme.textMedium.withValues(alpha: 0.55),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppTheme.softBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppTheme.primaryColor,
              width: 2,
            ),
          ),
        ),
      ),
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _valid
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
          style: SkulMateSurfaceStyles.sheetPrimaryButton(enabled: _valid),
          child: Text(
            copy.continueLabel,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
