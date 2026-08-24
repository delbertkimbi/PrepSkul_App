#version 460 core
#include <flutter/runtime_effect.glsl>

// Paper, made of light rather than of drawing calls.
//
// ## Why this replaced a CustomPainter
//
// The old ground stamped a dot grid in Dart: at 7 logical pixels of spacing on
// a 1080x2400 screen that is roughly 52,000 drawCircle calls, on the CPU, on
// the phones this product exists for. It also looked like graph paper, because
// a perfect lattice is the one thing real paper never is.
//
// This is one GPU pass. It costs about the same at any resolution, and it can
// afford the irregularity that makes a surface read as a material: fibre,
// mottling, a warm centre and cooler corners.
//
// ## Why it does not move
//
// There is no time uniform, on purpose. An animated background would repaint
// every frame forever, which on a 2GB Android is measurable battery for a
// decoration — and a moving surface behind a reading exercise competes with the
// letters, which are the only thing on screen a child is meant to look at.
// Playful is in the texture, not in motion.

uniform vec2 uSize;

// Passed in rather than hardcoded so the shader follows the theme instead of
// becoming a second, silently diverging source of colour.
uniform vec3 uPaper;
uniform vec3 uTint;

out vec4 fragColor;

// Cheap hash. Good enough for fibre; nobody is inspecting the distribution.
float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Value noise — hash at lattice corners, smoothstep between them.
float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
    u.y
  );
}

// Two octaves. A third is invisible at this amplitude and costs a full extra
// noise evaluation per pixel.
float fibre(vec2 p) {
  return noise(p) * 0.6 + noise(p * 2.7) * 0.4;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;

  vec3 col = uPaper;

  // Pulp grain, stretched horizontally so it reads as fibre laid down by a
  // roller rather than as television static.
  float grain = fibre(frag * vec2(0.35, 1.1));
  col += (grain - 0.5) * 0.032;

  // Broad mottling — the slow unevenness of a sheet held up to a window. This
  // is the part that stops it looking like a flat fill.
  float mottle = fibre(frag * 0.006);
  col = mix(col, uTint, mottle * 0.085);

  // A warm centre falling off to cooler corners, so the screen has a middle.
  // Very shallow: strong vignetting on a phone held at arm's length in
  // daylight just reads as a dirty screen.
  float d = distance(uv, vec2(0.5, 0.42));
  col *= 1.0 - d * d * 0.11;

  // Fine speckle, near the threshold of visible. Its whole job is to break up
  // the banding that a smooth gradient shows on cheap 6-bit panels.
  col += (hash(frag) - 0.5) * 0.006;

  // Amplitudes note: these were roughly halved on the first pass and the
  // result was invisible on a phone — technically a paper texture, in
  // practice a flat grey. They are now set to where the sheet reads as a
  // material at arm's length in daylight, and no further: everything here
  // sits behind letters a child is decoding, and contrast spent on the
  // background is contrast taken from the lesson.

  fragColor = vec4(col, 1.0);
}
