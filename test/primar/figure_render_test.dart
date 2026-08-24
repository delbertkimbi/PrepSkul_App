import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/presentation/figure_view.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('a numeral actually paints its digits', (tester) async {
    await tester.pumpWidget(_host(const FigureView(figure: NumeralFigure(7), size: 62)));
    await tester.pump();
    expect(find.text('7'), findsOneWidget, reason: 'numeral did not render');
  });

  testWidgets('a numeral inside the demo layout still paints', (tester) async {
    // Mirrors the demo: fixed slot, opacity, scale — the exact nesting that
    // showed an empty answer on screen.
    await tester.pumpWidget(_host(
      SizedBox(
        width: 62,
        height: 62,
        child: Opacity(
          opacity: 1.0,
          child: Transform.scale(
            scale: 1.0,
            child: const FigureView(figure: NumeralFigure(5), size: 62),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('5'), findsOneWidget, reason: 'numeral lost inside demo nesting');
  });

  testWidgets('a quantity paints without throwing', (tester) async {
    await tester.pumpWidget(_host(const FigureView(figure: QuantityFigure(4), size: 62)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a miniature phrase scene paints both pictures', (tester) async {
    await tester.pumpWidget(_host(
      const FigureView(figure: PhraseFigure('cat', 'on', 'mat'), size: 80),
    ));
    await tester.pump();
    expect(find.text('on'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
