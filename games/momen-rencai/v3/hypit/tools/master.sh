#!/usr/bin/env bash
# 把 Hypit 导出的成片做响度母带（抖音常用 -14 LUFS），画面流直接拷贝不重编码。
# 用法：tools/master.sh <hypit 导出的 mp4> <输出 mp4>
set -euo pipefail
ffmpeg -y -v error -i "$1" -c:v copy -af "loudnorm=I=-14:TP=-1.5:LRA=11" -c:a aac -b:a 192k -ar 48000 -movflags +faststart "$2"
