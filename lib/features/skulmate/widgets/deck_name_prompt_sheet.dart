import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../widgets/skulmate_surface_styles.dart';

/// Result from the post-generation deck save prompt.
class DeckSavePromptResult {
  final bool saveToLibrary;
  final String title;

  const DeckSavePromptResult({
    required this.saveToLibrary,
    required this.title,
  });
}

/// Optional deck naming after first upload/generation.
Future<DeckSavePromptResult?> showDeckNamePromptSheet({
  required BuildContext context,
  required String suggestedName,
}) {
  return showModalBottomSheet<DeckSavePromptResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _DeckNamePromptSheet(suggestedName: suggestedName),
  );
}

class _DeckNamePromptSheet extends StatefulWidget {
  final String suggestedName;

  const _DeckNamePromptSheet({required this.suggestedName});

  @override
  State<_DeckNamePromptSheet> createState() => _DeckNamePromptSheetState();
}

class _DeckNamePromptSheetState extends State<_DeckNamePromptSheet> {
  late final TextEditingController _controller;
  bool _saveDeck = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.suggestedName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            copy.saveDeckTitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            copy.saveDeckSubtitle,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textMedium,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _saveDeck,
            onChanged: (v) => setState(() => _saveDeck = v),
            title: Text(
              copy.saveDeckToggle,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
          if (_saveDeck) ...[
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: copy.saveDeckNameLabel,
                hintText: widget.suggestedName,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
          ],
          FilledButton(
            onPressed: () {
              if (!_saveDeck) {
                Navigator.pop(
                  context,
                  const DeckSavePromptResult(
                    saveToLibrary: false,
                    title: '',
                  ),
                );
                return;
              }
              final name = _controller.text.trim();
              Navigator.pop(
                context,
                DeckSavePromptResult(
                  saveToLibrary: true,
                  title: name.isEmpty ? widget.suggestedName : name,
                ),
              );
            },
            style: SkulMateSurfaceStyles.deckPrimaryButton(minHeight: 50),
            child: Text(
              _saveDeck ? copy.saveDeckConfirm : copy.saveDeckSkip,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
          if (_saveDeck)
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                const DeckSavePromptResult(saveToLibrary: false, title: ''),
              ),
              child: Text(copy.saveDeckSkip),
            ),
        ],
      ),
    );
  }
}
