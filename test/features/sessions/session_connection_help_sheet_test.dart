import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/widgets/session_connection_help_sheet.dart';

void main() {
  group('connection help labels', () {
    test('connectionHelpRtcStateLabel handles null', () {
      expect(connectionHelpRtcStateLabel(null), 'Checking…');
    });

    test('connectionHelpRtcStateLabel maps connected', () {
      expect(
        connectionHelpRtcStateLabel(ConnectionStateType.connectionStateConnected),
        'Connected',
      );
    });

    test('connectionHelpRtcStateLabel maps reconnecting', () {
      expect(
        connectionHelpRtcStateLabel(
          ConnectionStateType.connectionStateReconnecting,
        ),
        'Reconnecting',
      );
    });

    test('connectionHelpUplinkLabel maps tiers', () {
      expect(connectionHelpUplinkLabel(null), 'Not measured yet');
      expect(connectionHelpUplinkLabel(QualityType.qualityExcellent), 'Good');
      expect(connectionHelpUplinkLabel(QualityType.qualityPoor), 'Fair to weak');
      expect(connectionHelpUplinkLabel(QualityType.qualityDown), 'Poor');
    });
  });
}
