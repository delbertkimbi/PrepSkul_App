import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/navigation/learner_return_policy.dart';
void main() {
  test('first launch does not claim a return', () {
    expect(LearnerReturnPolicy.shouldWelcome(now: 5000000,lastActive:null),false);
  });
  test('quick relaunch does not repeat the celebration', () {
    expect(LearnerReturnPolicy.shouldWelcome(now:5000000,lastActive:4990000),false);
  });
  test('fresh launch after thirty minutes welcomes back', () {
    expect(LearnerReturnPolicy.shouldWelcome(now:5000000,lastActive:3200000),true);
  });
  test('clock rollback never triggers a welcome', () {
    expect(LearnerReturnPolicy.shouldWelcome(now:1000,lastActive:2000),false);
  });
}
