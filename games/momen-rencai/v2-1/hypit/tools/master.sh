#!/usr/bin/env bash
# 渲染并母带：hypit 本地构建 → 导出 final.video → loudnorm −14 LUFS / −1.5 dBTP（抖音常用响度）
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-../momen_v2-1_douyin_9x16.mp4}"
(cd packages/douyin-overlay && npx tsc -p tsconfig.json)
python3 tools/gen_svml.py
hypit check momen.svml
BUILD=$(hypit build momen.svrun --follow 2>&1 | tee /dev/stderr | grep -o 'bld_[A-Za-z0-9_]*' | tail -1)
mkdir -p out
hypit get "$BUILD" --output final.video --to out/raw.mp4
ffmpeg -v error -y -i out/raw.mp4 -c:v copy -af "loudnorm=I=-14:TP=-1.5:LRA=11" -c:a aac -b:a 192k -ar 48000 -movflags +faststart "$OUT"
ffprobe -v error -show_entries format=duration:stream=codec_name,width,height -of compact "$OUT"
