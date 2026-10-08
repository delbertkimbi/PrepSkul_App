# SkulMate character source

The runtime library is public/assets/mascot, mirrored byte-for-byte to the Flutter assets/mascot directory. Twenty standalone transparent WebPs total approximately 587 KB. Load one state at a time.

skulmate-master.svg is an editable vector starting point, not a completed Rive rig. Body height is 335 units and maximum width approximately 240 units: a tapered egg silhouette. Named groups separate body, belly, eyes, pupils, eyebrows, mouth, arms, legs, antenna and bulb. Import into Rive Editor and preserve those groups.

## Rive authoring contract (pending)

Artboard: SkulMate
State machine: SkulMateMascot
Number input: state, using manifest.json stable IDs 0–19.
Boolean input: reducedMotion.
Number input: speechLevel, 0–1, driven by actual audio amplitude; never by a network request starting.

Create timelines for every manifest state. Blend transitions over 160–220 ms.
Idle: 3-second subtle breath, irregular blink every 3–6 seconds.
Wave: 700 ms short forearm rotation, then settle.
Thinking: 2-second slight head tilt and eye glance.
Celebrate: one 800 ms jump, then happy rest; no permanent bouncing.
Sleeping: 4-second breathing cycle, eyes shut.
Running: 650 ms opposing leg/arm cycle.
Bulb glow: subtle opacity pulse; no strobe.
Reduced motion: static expression with immediate state changes.
Use try_again for a wrong answer; reserve sad for narrative contexts. Do not shame a learner.
Props (book, board, cap) need separate editable groups and visibility tracks.

No .riv file has been built or shipped. Official CLI installer exited on this Intel Mac: macOS builds currently support arm64 only. Complete authoring/export through Rive Editor or a supported CLI host, validate state inputs, then connect the runtimes. Do not replace the working WebP fallback with an absent .riv file.
