import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/profile/screens/account_deletion_screen.dart';
void main() {
  testWidgets('deletion request is optional feedback and requires confirmation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AccountDeletionScreen()));
    expect(find.text('Why are you leaving? (optional)'), findsOneWidget);
    final button = find.widgetWithText(FilledButton, 'Prepare deletion request');
    await tester.scrollUntilVisible(button, 200, scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    expect(find.textContaining('must send it'), findsOneWidget);
  });
}
