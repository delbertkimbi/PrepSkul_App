import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/widgets/alive_mate.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_mascot_media_widget.dart';

void main() {
  test('recording and speech use different character states', () {
    expect(
      poseForMascotState(SkulMateMascotState.listening),
      MascotState.listening,
    );
    expect(moodForMascotState(SkulMateMascotState.speaking), Mood.talk);
    expect(poseForMascotState(SkulMateMascotState.speaking), isNull);
  });

  test('feedback and hints do not collapse into generic happiness', () {
    expect(
      poseForMascotState(SkulMateMascotState.success),
      MascotState.success,
    );
    expect(
      poseForMascotState(SkulMateMascotState.tryAgain),
      MascotState.tryAgain,
    );
    expect(poseForMascotState(SkulMateMascotState.idea), MascotState.idea);
    expect(
      poseForMascotState(SkulMateMascotState.encouraging),
      MascotState.encourage,
    );
  });
}
