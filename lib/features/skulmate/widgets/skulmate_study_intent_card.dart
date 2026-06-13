import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import 'skulmate_intake_popup_menu.dart';
import 'skulmate_surface_styles.dart';

/// Intent card — simple neumorphic surface; send appears on type.
class SkulMateStudyIntentCard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final String? childId;

  const SkulMateStudyIntentCard({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.childId,
  });

  @override
  State<SkulMateStudyIntentCard> createState() => _SkulMateStudyIntentCardState();
}

class _SkulMateStudyIntentCardState extends State<SkulMateStudyIntentCard> {
  static const _noBorder = InputBorder.none;
  bool _hasText = false;
  final _addButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 112),
      decoration: SkulMateSurfaceStyles.homeCard(
        radius: SkulMateSurfaceStyles.intentCardRadius,
        compact: true,
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, 16, _hasText ? 50 : 18, 44),
            child: Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: TextField(
                controller: widget.controller,
                maxLines: 2,
                minLines: 2,
                decoration: InputDecoration(
                  hintText: copy.intentPlaceholder,
                  filled: true,
                  fillColor: Colors.transparent,
                  border: _noBorder,
                  enabledBorder: _noBorder,
                  focusedBorder: _noBorder,
                  disabledBorder: _noBorder,
                  errorBorder: _noBorder,
                  focusedErrorBorder: _noBorder,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textMedium.withValues(alpha: 0.65),
                    height: 1.35,
                  ),
                ),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textDark,
                  height: 1.35,
                ),
                textAlignVertical: TextAlignVertical.top,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => widget.onSubmit(),
              ),
            ),
          ),
          Positioned(
            left: 14,
            bottom: 12,
            child: Material(
              key: _addButtonKey,
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  final box = _addButtonKey.currentContext
                      ?.findRenderObject() as RenderBox?;
                  if (box != null && box.hasSize) {
                    SkulMateIntakePopupMenu.showAddSources(
                      context,
                      anchor: box,
                      childId: widget.childId,
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.add_rounded,
                    size: 22,
                    color: AppTheme.textDark.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 12,
            child: AnimatedOpacity(
              opacity: _hasText ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_hasText,
                child: Material(
                  color: AppTheme.primaryColor,
                  shape: const CircleBorder(),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onSubmit,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
