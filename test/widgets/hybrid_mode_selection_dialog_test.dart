import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/widgets/hybrid_mode_selection_dialog.dart';

/// Widget tests for HybridModeSelectionDialog
void main() {
  testWidgets('renders dialog with mode options', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await HybridModeSelectionDialog.show(
                context,
                sessionAddress: '123 Main Street',
              );
            },
            child: const Text('Show Dialog'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Session Mode'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Onsite'), findsOneWidget);
  });
}
