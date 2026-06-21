import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/skulmate_intake_models.dart';
import '../services/skulmate_intake_coordinator.dart';
import 'skulmate_sheet_scaffold.dart';
import 'skulmate_surface_styles.dart';

/// Gizmo-style paste sheet — single input, no title field.
class SkulMatePasteSheet extends StatefulWidget {
  final String? childId;

  const SkulMatePasteSheet({super.key, this.childId});

  static const minTextLength = 50;

  static Future<void> show(BuildContext context, {String? childId}) {
    return SkulMateSheetScaffold.show<void>(
      context,
      child: SkulMatePasteSheet(childId: childId),
    );
  }

  @override
  State<SkulMatePasteSheet> createState() => _SkulMatePasteSheetState();
}

class _SkulMatePasteSheetState extends State<SkulMatePasteSheet> {
  final _notesController = TextEditingController();
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
    _notesController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _valid =>
      _notesController.text.trim().length >= SkulMatePasteSheet.minTextLength;

  Future<void> _continue() async {
    final text = _notesController.text.trim();
    if (text.length < SkulMatePasteSheet.minTextLength) return;

    Navigator.pop(context);
    if (!context.mounted) return;

    await SkulMateIntakeCoordinator.start(
      context,
      SkulMateIntakePayload(
        source: SkulMateIntakeSource.paste,
        text: text,
        childId: widget.childId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    return SkulMateSheetScaffold(
      title: copy.importFromNotes,
      maxHeightFactor: 0.62,
      body: TextField(
        controller: _notesController,
        focusNode: _focusNode,
        maxLines: 8,
        minLines: 6,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.poppins(fontSize: 15, height: 1.45),
        decoration: InputDecoration(
          hintText: copy.pasteNotesHint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 15,
            color: AppTheme.textMedium.withValues(alpha: 0.55),
            height: 1.45,
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
          onPressed: _valid ? _continue : null,
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
