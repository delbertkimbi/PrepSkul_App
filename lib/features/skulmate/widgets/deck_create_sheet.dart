import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../screens/skulmate_all_decks_screen.dart';
import '../services/deck_library_service.dart';
import 'skulmate_surface_styles.dart';
import 'skulmate_typography.dart';

/// Gizmo-style create-deck sheet — name + accent colour.
class DeckCreateSheet {
  DeckCreateSheet._();

  static const swatchColors = <Color>[
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFFEAB308),
    Color(0xFF84CC16),
    Color(0xFF38BDF8),
    Color(0xFF818CF8),
    Color(0xFFA78BFA),
    Color(0xFFF472B6),
  ];

  static Future<void> show(
    BuildContext context, {
    String? childId,
    bool navigateToAllDecks = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _DeckCreateBody(
        childId: childId,
        navigateToAllDecks: navigateToAllDecks,
      ),
    );
  }
}

class _DeckCreateBody extends StatefulWidget {
  final String? childId;
  final bool navigateToAllDecks;

  const _DeckCreateBody({
    required this.childId,
    required this.navigateToAllDecks,
  });

  @override
  State<_DeckCreateBody> createState() => _DeckCreateBodyState();
}

class _DeckCreateBodyState extends State<_DeckCreateBody> {
  final _nameController = TextEditingController();
  int _selectedColor = 0;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final entry = await DeckLibraryService.createManualDeck(
        title: _nameController.text,
        accentColor: DeckCreateSheet.swatchColors[_selectedColor],
        childId: widget.childId,
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (entry == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not create deck. Try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (!widget.navigateToAllDecks) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SkulMateAllDecksScreen(
            initialDecks: [entry],
            childId: widget.childId,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        copy.deckCreateTitle,
                        style: SkulMateTypography.screenTitle(),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.neutral100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    copy.deckCreateInMyDecks,
                    style: SkulMateTypography.cardMeta(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(copy.deckNameLabel, style: SkulMateTypography.cardMeta()),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: copy.deckNamePlaceholder,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.primaryColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppTheme.neutral200),
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
                const SizedBox(height: 18),
                Text(copy.deckColourLabel, style: SkulMateTypography.cardMeta()),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: DeckCreateSheet.swatchColors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final color = DeckCreateSheet.swatchColors[index];
                      final selected = index == _selectedColor;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = index),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: selected
                                ? Border.all(color: color, width: 3)
                                : null,
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.35),
                                      blurRadius: 0,
                                      spreadRadius: 3,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: SkulMateSurfaceStyles.deckAccentButton(),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(copy.addDeckCta),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
