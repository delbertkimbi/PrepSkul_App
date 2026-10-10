/// Stable IDs match assets/mascot/manifest.json for the planned Rive state input.
enum MascotState {
  idle,
  happy,
  wave,
  thumbsUp,
  thinking,
  confused,
  idea,
  studying,
  reading,
  celebrate,
  success,
  tryAgain,
  encourage,
  sad,
  sleeping,
  running,
  pointing,
  teaching,
  graduation,
  calm,
  listening,
}

extension MascotAsset on MascotState {
  String get asset {
    final filename = switch (this) {
      MascotState.thumbsUp => 'thumbs_up',
      MascotState.tryAgain => 'try_again',
      _ => name,
    };
    return 'assets/mascot/$filename.webp';
  }
}
