import 'game_sound_service.dart';
import 'tts_service.dart';

/// Stops in-game voice and music — use before leaving or finishing a game screen.
class GameAudioLifecycle {
  GameAudioLifecycle._();

  static Future<void> stopAll({
    TTSService? tts,
    GameSoundService? sound,
  }) async {
    final ttsService = tts ?? TTSService();
    final soundService = sound ?? GameSoundService();
    await ttsService.stop();
    await soundService.stopMusic(force: true);
  }
}
