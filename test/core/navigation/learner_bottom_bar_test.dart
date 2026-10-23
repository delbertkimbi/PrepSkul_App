import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/design/prepskul_icon.dart';
import 'package:prepskul/core/navigation/learner_bottom_bar.dart';

void main() {
  testWidgets('destination labels retain their icons and tap targets', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: LearnerBottomBar(
            selected: 0,
            labels: const ['Home', 'Tutors', 'Mate', 'Sessions'],
            onSelected: (i) => selected = i,
          ),
        ),
      ),
    );
    const expected = {
      'Home': PrepSkulGlyph.home,
      'Tutors': PrepSkulGlyph.tutors,
      'Mate': PrepSkulGlyph.mate,
      'Sessions': PrepSkulGlyph.sessions,
    };
    var index = 0;
    for (final entry in expected.entries) {
      final target = find.ancestor(
        of: find.text(entry.key),
        matching: find.byType(InkWell),
      );
      final icon = tester.widget<PrepSkulIcon>(
        find.descendant(of: target, matching: find.byType(PrepSkulIcon)),
      );
      expect(icon.glyph, entry.value);
      await tester.tap(find.text(entry.key));
      expect(selected, index++);
    }
    expect(tester.takeException(), isNull);
  });
}
