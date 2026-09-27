#!/usr/bin/env bash
# 安装 games/verify.json 固定的 Godot 到 ~/godot（CI 与本地共用）。已存在则跳过。
set -euo pipefail
v="$(node -p "require('./games/verify.json').godotVersion")"
bin="$HOME/godot/Godot_v${v}-stable_linux.x86_64"
if [ ! -x "$bin" ]; then
  mkdir -p "$HOME/godot"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/godot.zip" "https://github.com/godotengine/godot/releases/download/${v}-stable/Godot_v${v}-stable_linux.x86_64.zip"
  unzip -q "$tmp/godot.zip" -d "$HOME/godot"
fi
echo "$bin"
