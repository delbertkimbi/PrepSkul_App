import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/feedback/app_feedback.dart';
import 'package:prepskul/core/feedback/feedback_severity.dart';

void main() {
  testWidgets('AppFeedback.showToast shows branded snackbar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    AppFeedback.showToast(
                      context,
                      FeedbackSeverity.info,
                      'Hello from tests',
                    );
                  },
                  child: const Text('Go'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Hello from tests'), findsOneWidget);
  });
}
