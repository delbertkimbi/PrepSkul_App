import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/widgets/prep_skul_alert_dialog.dart';

void main() {
  testWidgets('showPrepSkulAlert shows branded title and message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showPrepSkulAlert(
                    context: context,
                    title: 'Test title',
                    message: 'Test message body',
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(PrepSkulAlertDialog), findsOneWidget);
    expect(find.text('Test title'), findsOneWidget);
    expect(find.text('Test message body'), findsOneWidget);
  });
}
