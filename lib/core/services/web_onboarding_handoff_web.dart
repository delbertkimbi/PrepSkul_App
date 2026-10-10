import 'dart:html' as html;

Future<String?> consume() async {
  final storage = html.window.localStorage;
  final value = storage['ps_onboarding_handoff'];
  storage.remove('ps_onboarding_handoff');
  return value;
}
