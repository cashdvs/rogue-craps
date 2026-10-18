#!/usr/bin/env bash
# Renders the boot splash to video/GIF/key frames (needs xvfb-run + ffmpeg).
# Usage: tools/capture_splash.sh [out_dir]   (default /workspace/dice/captures/splash)
set -euo pipefail
GODOT="${GODOT:-/home/box/tools/godot/godot}"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-/workspace/dice/captures/splash}"
TMP="$(mktemp -d)"
mkdir -p "$OUT"
xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path "$DIR" --rendering-driver opengl3 \
	--resolution 1280x720 --write-movie "$TMP/f.png" --fixed-fps 30 --quit-after 84 >/dev/null 2>&1
ffmpeg -loglevel error -y -framerate 30 -i "$TMP/f%08d.png" -i "$TMP/f.wav" -c:v libx264 -pix_fmt yuv420p -crf 18 -c:a aac -shortest "$OUT/splash.mp4"
ffmpeg -loglevel error -y -framerate 30 -i "$TMP/f%08d.png" -vf "fps=25,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" "$OUT/splash.gif"
cp "$TMP/f00000018.png" "$OUT/key_01_strike.png"
cp "$TMP/f00000021.png" "$OUT/key_02_sparks.png"
cp "$TMP/f00000050.png" "$OUT/key_03_lockup.png"
rm -rf "$TMP"
echo "wrote $OUT/{splash.mp4,splash.gif,key_0*.png}"
