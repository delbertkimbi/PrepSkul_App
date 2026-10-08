/// Clip timing shared by the native and browser renderers.
double mascotSpeed(String clip) {
  if (const ['02_wave', '06_celebrate', '17_success'].contains(clip)) {
    return 1.55;
  }
  if (const ['33_talk', '31_running'].contains(clip)) return 1.3;
  if (const ['27_sleeping', '30_meditation'].contains(clip)) return .8;
  return 1;
}
