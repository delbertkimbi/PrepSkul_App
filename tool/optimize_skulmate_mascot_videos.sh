#!/usr/bin/env bash
# Optional: shrink bundled mascot clips (~2MB total) for smaller APK/IPA/Web.
# Requires: brew install ffmpeg   (or your OS package manager)
# Run from repo root:  bash prepskul_app/tool/optimize_skulmate_mascot_videos.sh
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../assets/characters/animations" && pwd)"
TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

for f in Neutral Think Encouraging Celebrate; do
  src="$DIR/${f}.mp4"
  out="$TMP/${f}.mp4"
  if [[ ! -f "$src" ]]; then
    echo "skip (missing): $src"
    continue
  fi
  # H.264 + tiny AAC track (widget plays at 0 volume; some decoders prefer a stream present).
  ffmpeg -y -i "$src" -vf "scale='min(720,iw)':-2" -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 26 -preset slow -c:a aac -b:a 32k -movflags +faststart "$out"
  before=$(wc -c <"$src" | tr -d ' ')
  after=$(wc -c <"$out" | tr -d ' ')
  echo "$f: ${before} -> ${after} bytes"
  if (( after < before && after > 0 )); then
    mv "$out" "$src"
    echo "  replaced $src"
  else
    echo "  kept original (new file not smaller)"
  fi
done
echo "Done. Run: cd prepskul_app && flutter test / flutter build apk --debug  to verify playback."
