import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';

/// Normalized RTC events emitted by [AgoraAdapter].
abstract class RtcEvent {
  const RtcEvent();
}

class RtcJoinSuccess extends RtcEvent {
  const RtcJoinSuccess({required this.uid, required this.channelId});
  final int uid;
  final String channelId;
}

class RtcUserJoined extends RtcEvent {
  const RtcUserJoined(this.uid);
  final int uid;
}

class RtcUserOffline extends RtcEvent {
  const RtcUserOffline(this.uid);
  final int uid;
}

class RtcConnectionStateChanged extends RtcEvent {
  const RtcConnectionStateChanged(this.state);
  final ConnectionStateType state;
}

class RtcErrorEvent extends RtcEvent {
  const RtcErrorEvent(this.message);
  final String message;
}

/// Thin adapter around Agora SDK operations.
///
/// This boundary lets domain/orchestration consume normalized events without
/// coupling UI flows directly to raw SDK callbacks.
class AgoraAdapter {
  AgoraAdapter(this._engine);

  final RtcEngine _engine;
  final StreamController<RtcEvent> _events = StreamController<RtcEvent>.broadcast();

  Stream<RtcEvent> get events => _events.stream;

  void registerCoreHandlers() {
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          _events.add(
            RtcJoinSuccess(
              uid: connection.localUid ?? 0,
              channelId: connection.channelId ?? '',
            ),
          );
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          _events.add(RtcUserJoined(remoteUid));
        },
        onUserOffline: (connection, remoteUid, reason) {
          _events.add(RtcUserOffline(remoteUid));
        },
        onConnectionStateChanged: (connection, state, reason) {
          _events.add(RtcConnectionStateChanged(state));
        },
        onError: (err, msg) {
          _events.add(RtcErrorEvent('$err: $msg'));
        },
      ),
    );
  }

  Future<void> joinChannel({
    required String token,
    required String channelId,
    required int uid,
    required ChannelMediaOptions options,
  }) {
    return _engine.joinChannel(
      token: token,
      channelId: channelId,
      uid: uid,
      options: options,
    );
  }

  Future<void> leaveChannel() => _engine.leaveChannel();

  Future<void> setupLocalCameraVideo() {
    return _engine.setupLocalVideo(
      const VideoCanvas(
        uid: 0,
        sourceType: VideoSourceType.videoSourceCamera,
      ),
    );
  }

  Future<void> setLocalVideoMuted(bool muted) {
    return _engine.muteLocalVideoStream(muted);
  }

  Future<void> startPreview() => _engine.startPreview();

  Future<void> dispose() async {
    await _events.close();
  }
}

