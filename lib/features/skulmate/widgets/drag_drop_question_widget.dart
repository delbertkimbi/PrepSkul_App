import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

class DragDropQuestionWidget extends StatelessWidget {
  final List<Map<String, dynamic>> dragItems;
  final List<Map<String, dynamic>> dropZones;
  final Map<String, int> assignments;
  final bool showCorrection;
  final ValueChanged<Map<String, int>> onAssignmentsChanged;
  final String instructionText;

  const DragDropQuestionWidget({
    super.key,
    required this.dragItems,
    required this.dropZones,
    required this.assignments,
    required this.showCorrection,
    required this.onAssignmentsChanged,
    this.instructionText = 'Drag each item into the correct zone',
  });

  static String itemText(Map<String, dynamic> item) {
    return (item['text'] ?? item['label'] ?? item['item'] ?? '')
        .toString()
        .trim();
  }

  static String zoneLabel(Map<String, dynamic> zone, int index) {
    final value = (zone['name'] ?? zone['label'] ?? zone['id'] ?? '')
        .toString()
        .trim();
    return value.isEmpty ? 'Zone ${index + 1}' : value;
  }

  static String expectedZone(Map<String, dynamic> item) {
    return (item['correctZone'] ??
            item['correct_zone'] ??
            item['zone'] ??
            item['targetZone'] ??
            '')
        .toString()
        .trim();
  }

  static String normalizeZone(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool evaluateAssignments({
    required List<Map<String, dynamic>> dragItems,
    required List<Map<String, dynamic>> dropZones,
    required Map<String, int> assignments,
  }) {
    final zoneByNorm = <String, String>{
      for (int i = 0; i < dropZones.length; i++)
        normalizeZone(zoneLabel(dropZones[i], i)): zoneLabel(dropZones[i], i),
    };
    return assignments.entries.every((entry) {
      final itemIndex = entry.value;
      if (itemIndex < 0 || itemIndex >= dragItems.length) return false;
      final expectedRaw = expectedZone(dragItems[itemIndex]);
      final expectedNorm = normalizeZone(expectedRaw);
      final assignedNorm = normalizeZone(entry.key);
      final resolvedExpected = zoneByNorm[expectedNorm] ?? expectedRaw;
      return normalizeZone(resolvedExpected) == assignedNorm;
    });
  }

  static String buildMappingText(List<Map<String, dynamic>> dragItems) {
    final pairs = <String>[];
    for (final item in dragItems) {
      final text = itemText(item);
      final zone = expectedZone(item);
      if (text.isNotEmpty && zone.isNotEmpty) {
        pairs.add('$text -> $zone');
      }
    }
    return pairs.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          instructionText,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.textMedium,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: dragItems.asMap().entries.map((entry) {
            final itemIndex = entry.key;
            final label = itemText(entry.value);
            final alreadyAssigned = assignments.values.contains(itemIndex);
            if (alreadyAssigned) {
              return const SizedBox.shrink();
            }
            return Draggable<int>(
              data: itemIndex,
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: Chip(label: Text(label)),
              ),
              child: Chip(
                label: Text(label),
                backgroundColor: Colors.white,
                side: BorderSide(color: AppTheme.softBorder),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        ...dropZones.asMap().entries.map((zoneEntry) {
          final zoneIndex = zoneEntry.key;
          final zone = zoneEntry.value;
          final zoneName = zoneLabel(zone, zoneIndex);
          final assignedItemIndex = assignments[zoneName];
          final assignedLabel =
              assignedItemIndex != null && assignedItemIndex < dragItems.length
              ? itemText(dragItems[assignedItemIndex])
              : null;
          final expectedNorm = normalizeZone(
            expectedZone(
              assignedItemIndex != null && assignedItemIndex < dragItems.length
                  ? dragItems[assignedItemIndex]
                  : {},
            ),
          );
          final zoneNorm = normalizeZone(zoneName);
          final showCorrecting = showCorrection && assignedItemIndex != null;
          final isAssignedCorrect =
              showCorrecting && expectedNorm.isNotEmpty && expectedNorm == zoneNorm;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DragTarget<int>(
              onWillAcceptWithDetails: (_) => !showCorrection,
              onAcceptWithDetails: (details) {
                final next = Map<String, int>.from(assignments);
                next.removeWhere((_, value) => value == details.data);
                next[zoneName] = details.data;
                onAssignmentsChanged(next);
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: showCorrecting
                        ? (isAssignedCorrect
                              ? AppTheme.accentGreen.withOpacity(0.18)
                              : Colors.red.withOpacity(0.12))
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: showCorrecting
                          ? (isAssignedCorrect
                                ? AppTheme.accentGreen
                                : Colors.red.shade400)
                          : (candidateData.isNotEmpty
                                ? AppTheme.primaryColor
                                : AppTheme.softBorder),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              zoneName,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMedium,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              assignedLabel ?? 'Drop item here',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: assignedLabel == null
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                                color: assignedLabel == null
                                    ? AppTheme.textMedium
                                    : AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!showCorrection && assignedItemIndex != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            final next = Map<String, int>.from(assignments);
                            next.remove(zoneName);
                            onAssignmentsChanged(next);
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}
