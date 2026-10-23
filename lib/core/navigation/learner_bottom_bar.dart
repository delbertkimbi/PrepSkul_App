import 'package:flutter/material.dart';
import '../design/learner_design.dart';
import '../design/prepskul_icon.dart';

/// Four destinations with a shared, resolution-independent icon family.
class LearnerBottomBar extends StatelessWidget {
  const LearnerBottomBar({
    super.key,
    required this.selected,
    required this.labels,
    required this.onSelected,
  });
  static const _destinationIcons = [
    PrepSkulGlyph.home,
    PrepSkulGlyph.tutors,
    PrepSkulGlyph.mate,
    PrepSkulGlyph.sessions,
  ];

  final int selected;
  final List<String> labels;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              children: List.generate(
                4,
                (i) => Expanded(
                  child: Semantics(
                    selected: selected == i,
                    button: true,
                    label: labels[i],
                    child: ExcludeSemantics(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onSelected(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                width: 52,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: selected == i
                                      ? LearnerDesign.sky
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected == i
                                        ? const Color(0xFFC4E2EF)
                                        : Colors.transparent,
                                  ),
                                  boxShadow: selected == i
                                      ? const [
                                          BoxShadow(
                                            color: Color(0xFFD0E2EC),
                                            offset: Offset(0, 2),
                                          ),
                                        ]
                                      : const [],
                                ),
                                alignment: Alignment.center,
                                child: PrepSkulIcon(
                                  _destinationIcons[i],
                                  size: 28,
                                  active: selected == i,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                labels[i],
                                textAlign: TextAlign.center,
                                style: LearnerDesign.body(11).copyWith(
                                  color: selected == i
                                      ? LearnerDesign.ink
                                      : LearnerDesign.muted,
                                  fontWeight: selected == i
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
