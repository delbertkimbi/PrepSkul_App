import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prejoin lobby wires readiness probe and session context', () async {
    final file = File('lib/features/sessions/screens/agora_prejoin_screen.dart');
    final content = await file.readAsString();

    expect(content.contains('DeviceReadinessService.probe'), isTrue);
    expect(content.contains('_buildReadinessChecklist'), isTrue);
    expect(content.contains('_buildSessionContextCard'), isTrue);
    expect(content.contains('_loadSessionContext'), isTrue);
    expect(content.contains('Pre-class readiness'), isTrue);
  });
}
