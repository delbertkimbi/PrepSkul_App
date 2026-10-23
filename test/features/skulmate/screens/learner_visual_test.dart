import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/design/learner_design.dart';
import 'package:prepskul/features/skulmate/models/lesson_plan_model.dart';
import 'package:prepskul/features/skulmate/screens/learning_journey_screen.dart';

void main() {
  testWidgets('learner map visual at phone size', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(() async {
    final iconFont = FontLoader('MaterialIcons');
    iconFont.addFont(File('${Platform.environment['FLUTTER_ROOT'] ?? File(Process.runSync('which', ['flutter']).stdout.toString().trim()).resolveSymbolicLinksSync().replaceFirst(RegExp(r'/bin/flutter$'), '')}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytes().then((bytes) => ByteData.sublistView(bytes)));
    await iconFont.load();
    });
    tester.view.physicalSize = const Size(390,844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: LearnerDesign.theme(ThemeData()), home: Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: LearningJourneyScreen(onMate: () {}, onTutors: () {}, loadPlans: () async => [
        const LessonPlan(id:'visual-fixture',topic:'Forces and motion',currentStep:1,steps:[
          LessonPlanStep(type:'overview',title:'A push or a pull',status:'completed'),
          LessonPlanStep(type:'concepts',title:'When forces balance'),
          LessonPlanStep(type:'quiz',title:'Try it for yourself'),
        ]),
      ]),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
    await expectLater(find.byType(MaterialApp),matchesGoldenFile('../../../../artifacts/design/learn-mobile.png'));
  });
}
