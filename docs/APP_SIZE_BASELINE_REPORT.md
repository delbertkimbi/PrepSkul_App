# App Size Baseline Report (PrepSkul)

Date: 2026-04-02
Scope: Entire Flutter app repository (`prepskul_app`)

## Baseline Snapshot

- Repository total on disk (includes local build caches, pods, gradle, git objects): **~3005.21 MB**
- Shippable repo footprint (excluding `.git`, `.dart_tool`, `build`, `ios/Pods`, `android/.gradle`, `.idea`): **~54.77 MB**
- Bundled app assets folder (`assets`): **~27.56 MB**

## Biggest Contributors (Shippable Footprint)

- `assets`: **27.56 MB**
- `lib`: **6.99 MB**
- `macos`: **6.91 MB**
- `prepskul_app` (nested content/folder): **4.44 MB**
- `web`: **3.32 MB**
- `docs`: **2.27 MB**

## Top 20 Largest Bundled Assets

1. `assets/images/onboarding1.png` - **6.93 MB**
2. `assets/characters/mascots/celebration.png` - **1.69 MB**
3. `assets/characters/mascots/thinking.png` - **1.53 MB**
4. `assets/characters/mascots/encouraging.png` - **1.46 MB**
5. `assets/characters/mascots/default.png` - **1.44 MB**
6. `assets/images/group-class-prepskul.png` - **1.41 MB**
7. `assets/audio/music/sfx_wrong_mute.ogg` - **0.71 MB**
8. `assets/audio/music/sfx_correct_chime.ogg` - **0.71 MB**
9. `assets/audio/music/bgm_results_soft_loop.ogg` - **0.71 MB**
10. `assets/audio/music/sfx_tap_soft.ogg` - **0.71 MB**
11. `assets/audio/music/bgm_adventure_loop.ogg` - **0.71 MB**
12. `assets/audio/music/sfx_card_flip.ogg` - **0.70 MB**
13. `assets/audio/music/bgm_focus_loop.ogg` - **0.70 MB**
14. `assets/characters/animations/Encouraging.mp4` - **0.60 MB**
15. `assets/characters/animations/Celebrate.mp4` - **0.56 MB**
16. `assets/audio/music/sfx_streak_ping.ogg` - **0.55 MB**
17. `assets/audio/music/sfx_level_up.ogg` - **0.54 MB**
18. `assets/characters/animations/Think.mp4` - **0.50 MB**
19. `assets/audio/music/sfx_victory_short.ogg` - **0.48 MB**
20. `assets/characters/animations/Neutral.mp4` - **0.46 MB**

## Duplicate/Collision Scan

- No duplicate mascot animation filenames currently detected in `assets/characters/animations` (only the intended 4 files are present).
- Non-critical repeated `README.md` filenames exist across asset subfolders; negligible size impact.

## Fastest Wins (Highest Impact First)

1. Convert `assets/images/onboarding1.png` to optimized `webp` and update references.
   - Expected reduction: **50% to 80%** on this file alone.
2. Convert mascot PNGs (`default`, `thinking`, `encouraging`, `celebration`) to `webp`.
   - Expected reduction: **30% to 70%** depending on alpha detail.
3. Re-encode all mascot MP4 loops to mobile profile (`H.264`, lower bitrate, shorter loops if acceptable).
   - Expected reduction: **20% to 50%**.
4. Compress OGG music/SFX with tuned quality targets per category (SFX lower, BGM moderate).
   - Expected reduction: **20% to 40%**.
5. Enable Android release shrinking (`minifyEnabled`, `shrinkResources`, split per ABI).
   - Expected release APK/AAB reduction: **15% to 35%**.

## Recommended Next Commanded Step

Proceed with `skulmate-asset-optimization-pass` first:
- image conversion pipeline (PNG -> WebP),
- audio re-encode pass,
- mp4 bitrate/size pass,
- then rerun this baseline report to compare before/after.
