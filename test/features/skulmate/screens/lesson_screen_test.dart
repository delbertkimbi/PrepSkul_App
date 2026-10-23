import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/features/skulmate/models/lesson_plan_model.dart';
import 'package:prepskul/features/skulmate/models/skulmate_intake_models.dart';
import 'package:prepskul/features/skulmate/screens/skulmate_path_overview_screen.dart';
void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('opens the lesson directly and leaving does not acknowledge reading', (tester) async {
    const plan = LessonPlan(id:'saved',topic:'Forces',currentStep:0,steps:[
      LessonPlanStep(type:'overview',title:'A push or a pull',body:'A force can change motion.'),
      LessonPlanStep(type:'quiz',title:'Try a question'),
    ]);
    await tester.pumpWidget(MaterialApp(home: Builder(builder:(context)=>Scaffold(body:TextButton(
      onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SkulMatePathOverviewScreen(
        initialLesson:plan,payload:SkulMateIntakePayload(source:SkulMateIntakeSource.typedTopic,topicHint:'Forces')))),
      child:const Text('Open lesson'))))));
    await tester.tap(find.text('Open lesson'));await tester.pumpAndSettle();
    expect(find.text('A push or a pull'),findsOneWidget);
    expect(find.text('Try a question'),findsNothing);
    expect(find.text('I’ve read this step'),findsOneWidget);
    expect(find.text('Generating Game'),findsNothing);
    await tester.pageBack();await tester.pumpAndSettle();
    expect(plan.steps.first.status,isNot('completed'));
    expect(tester.takeException(),isNull);
  });
}
