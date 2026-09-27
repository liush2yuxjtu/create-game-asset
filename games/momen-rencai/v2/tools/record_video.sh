#!/usr/bin/env bash
# 爆款视频 = 游戏「录屏模式」本身：Godot Movie Maker 按 30fps 逐帧录下 data/viral_script.json 的演出，
# 再用最近邻 ×4 放大到 1080×1920（像素不糊），编码 H.264 + AAC。
# 用法：GODOT=/path/to/godot4.4.1 tools/record_video.sh [输出.mp4]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${1:-video/momen_v2_viral_9x16.mp4}"
TMP="$(mktemp -d)"
RUN=()
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then RUN=(xvfb-run -a -s "-screen 0 1280x1024x24"); fi
"${RUN[@]}" "$GODOT" --path . --rendering-driver opengl3 --write-movie "$TMP/rec.avi" --fixed-fps 30 -- --movie
ffmpeg -y -v error -i "$TMP/rec.avi" -vf "scale=1080:1920:flags=neighbor,format=yuv420p" \
  -c:v libx264 -preset slow -crf 18 -r 30 -af "loudnorm=I=-14:TP=-1.5:LRA=11" -c:a aac -b:a 160k -ar 44100 -movflags +faststart "$OUT"
rm -rf "$TMP"
ffprobe -v error -show_entries format=duration:stream=codec_name,width,height -of compact "$OUT"
