import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group classes app UI flow', () {
    test('tutor flow uses create page and publish flow', () async {
      final tutorScreen = File(
        'lib/features/group_classes/screens/tutor_group_classes_screen.dart',
      );
      final createScreen = File(
        'lib/features/group_classes/screens/create_group_class_screen.dart',
      );
      final tutorContent = await tutorScreen.readAsString();
      final createContent = await createScreen.readAsString();

      expect(tutorContent.contains('CreateGroupClassScreen'), isTrue);
      expect(tutorContent.contains('My Group Classes'), isTrue);
      expect(createContent.contains('Create Group Class'), isTrue);
      expect(createContent.contains('Step 1 of 3 - Class details'), isTrue);
      expect(createContent.contains('Step 2 of 3 - Learning + flyer'), isTrue);
      expect(createContent.contains('Step 3 of 3 - Schedule + pricing'), isTrue);
      expect(createContent.contains('Flyer image URL (optional)'), isTrue);
      expect(createContent.contains('Upload flyer image'), isTrue);
      expect(createContent.contains('Copy Prompt'), isTrue);
      expect(createContent.contains('Use this in ChatGPT to generate a flyer:'), isTrue);
      expect(createContent.contains('Class runs until'), isTrue);
      expect(createContent.contains('Class days'), isTrue);
      expect(createContent.contains('GroupClassApiService.create('), isTrue);
      expect(createContent.contains('GroupClassApiService.publish('), isTrue);
    });

    test('learner discovery screen supports reserve seat', () async {
      final file = File(
        'lib/features/group_classes/screens/group_classes_discovery_screen.dart',
      );
      final content = await file.readAsString();

      expect(content.contains('GroupClassApiService.getPublished'), isTrue);
      expect(content.contains('GroupClassApiService.enroll'), isTrue);
      expect(content.contains('Reserve Seat'), isTrue);
      expect(content.contains('No group classes available yet'), isTrue);
      expect(content.contains('assets/images/group_learn.jpeg'), isTrue);
      expect(content.contains('Image.network'), isTrue);
      expect(content.contains('tutorAvatarUrl'), isTrue);
    });

    test('entry points are wired from tutor home and tutor discovery', () async {
      final tutorHome = File('lib/features/tutor/screens/tutor_home_screen.dart');
      final discovery = File('lib/features/discovery/screens/find_tutors_screen.dart');
      final tutorHomeContent = await tutorHome.readAsString();
      final discoveryContent = await discovery.readAsString();

      expect(tutorHomeContent.contains('TutorGroupClassesScreen'), isTrue);
      expect(discoveryContent.contains('GroupClassesDiscoveryScreen'), isTrue);
      expect(discoveryContent.contains('Icons.groups_outlined'), isTrue);
    });
  });
}

