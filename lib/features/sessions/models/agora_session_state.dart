/// Agora Session State
///
/// Represents the current state of an Agora video session.
enum AgoraSessionState {
  /// Not connected to any channel
  disconnected,

  /// Attempting to join channel
  joining,

  /// Connected and active in channel
  connected,

  /// Reconnecting after connection loss
  reconnecting,

  /// Leaving channel
  leaving,

  /// Error state
  error,
}

/// Extension for AgoraSessionState
extension AgoraSessionStateExtension on AgoraSessionState {
  /// Get display name
  String get displayName {
    switch (this) {
      case AgoraSessionState.disconnected:
        return 'Disconnected';
      case AgoraSessionState.joining:
        return 'Joining...';
      case AgoraSessionState.connected:
        return 'Connected';
      case AgoraSessionState.reconnecting:
        return 'Reconnecting...';
      case AgoraSessionState.leaving:
        return 'Leaving...';
      case AgoraSessionState.error:
        return 'Error';
    }
  }

  /// Check if session is active
  bool get isActive => this == AgoraSessionState.connected;

  /// Check if session is connecting
  bool get isConnecting =>
      this == AgoraSessionState.joining ||
      this == AgoraSessionState.reconnecting;

  /// Check if session has error
  bool get hasError => this == AgoraSessionState.error;
}

