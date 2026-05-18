import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Screen-share owner transitions', () {
    test('agora service tracks owner uid and emits owner in sharing events', () async {
      final serviceFile = File(
        'lib/features/sessions/services/agora_service.dart',
      );
      final content = await serviceFile.readAsString();

      expect(content.contains('_screenShareOwnerUid'), isTrue);
      expect(content.contains("'ownerUid': _screenShareOwnerUid"), isTrue);
      expect(
        content.contains('if (_screenShareOwnerUid == remoteUid)'),
        isTrue,
      );
    });

    test('session screen derives local/remote share flags from owner uid', () async {
      final screenFile = File(
        'lib/features/sessions/screens/agora_video_session_screen.dart',
      );
      final content = await screenFile.readAsString();

      expect(content.contains('_screenShareOwnerUid'), isTrue);
      expect(content.contains("final ownerUid = data['ownerUid'] as int?;"), isTrue);
      expect(content.contains('_activeRemoteScreenShare'), isTrue);
      expect(content.contains('_anyScreenShareActive'), isTrue);
      expect(content.contains('_localScreenShareCapturing'), isTrue);
      expect(
        content.contains(
          '_remoteIsScreenSharing = myUid != null && ownerUid == _remoteUID',
        ),
        isTrue,
      );
      expect(
        content.contains(
          '_isScreenSharing = myUid != null && ownerUid == myUid',
        ),
        isTrue,
      );
    });

    test('web camera setup is skipped while publishing screen', () async {
      final serviceFile = File(
        'lib/features/sessions/services/agora_service.dart',
      );
      final viewFile = File(
        'lib/features/sessions/widgets/agora_video_view.dart',
      );
      final service = await serviceFile.readAsString();
      final view = await viewFile.readAsString();

      expect(
        service.contains('if (_isPublishingScreen) return;'),
        isTrue,
      );
      expect(
        view.contains('skipCameraSetupWhileSharing'),
        isTrue,
      );
      expect(view.contains('AgoraService().isPublishingScreen'), isTrue);
    });
  });
}

