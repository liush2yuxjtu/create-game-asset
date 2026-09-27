# 魔门人材 v2-1 · 抖音二剪版（Hypit）

成片：[`../momen_v2-1_douyin_9x16.mp4`](../momen_v2-1_douyin_9x16.mp4)（31 s，1080×1920，30 fps，H.264 + AAC，−14 LUFS）

和 v2 的 `../../v2/video/momen_v2_viral_9x16.mp4`（游戏录屏模式原样录制，字幕是游戏里画的）不同，这一版是**用 [Hypit](https://github.com/hypit-ai/hypit) 做的抖音向二剪**：同一段游戏实录做素材，重新剪节奏、加口播和抖音式包装。

## Brief / Treatment

- **目标**：抖音竖屏、首 1.5 秒留人、评论区互动。
- **钩子**：「这个NPC，杀了我99次」→ 红屏「你死了」。
- **结构**：死亡计数 97→98→99（同一个后山 / 同一个师兄 / 同一把刀）→ 死前铭刻「袖口的朱砂」→ 第100世他又来 → 想起朱砂、隐藏选项出现 → 只说一句「我也死过99次」→ 师兄：「……你到底知道多少？」→ 这一世他没有下手 → AI 驱动、他会记得你 → 第一章 4 层真相我只挖到第 2 层 → **你能挖到第几层？👇评论区**。
- **画面**：战斗镜头用 Sampling 放大到「舞台铺满」（zoom z，y = 960 + 300z），像素最近邻放大；其余镜头原比例。
- **声音**：Edge-TTS 口播（旁白 zh-CN-YunxiNeural，师兄 zh-CN-YunjianNeural），游戏自带 8-bit BGM 与音效。

## 结构

| 路径 | 作用 |
|---|---|
| `momen.svml` | 成片源（**由 `tools/gen_svml.py` 生成，改剪辑计划请改脚本**） |
| `momen.svs` / `momen.svrun` / `hypit.runtime.json` | 样式、运行目标、本地 Runtime（media.local + hyperframes.local，零生成费用） |
| `packages/douyin-overlay/` | 项目组件 `@momen/douyin-overlay@1`：hook 大字、逐词弹出口播字幕（按短语切换）、聊天气泡（打字）、死亡计数器、徽章、闪白/闪红 |
| `assets/footage/` | 游戏净画面切片：先把 `clean-plate.patch` 打到 `../../v2`（`git apply games/momen-rencai/v2-1/hypit/clean-plate.patch`），再 `godot --path ../../v2 --write-movie f.png --fixed-fps 30 -- --movie --clean` 录 PNG 序列，`gen_svml.py <png目录>` 切出 |
| `assets/vo/` | 口播台词 `lines.tsv` → `python3 tools/prep_vo.py`（调 `tools/tts.py`，需 `pip install edge-tts`）生成，按词边界裁剪、每句 loudnorm；`timing.json` 是词级时间（字幕据此弹出） |
| `assets/audio/` | 游戏 BGM / 音效副本（短音效补静音到 0.3 s，避免零长度窗口） |

v2-1 只新增文件、不改 v2：录净画面用的 `--clean` 开关（不画分镜字幕）以补丁 `clean-plate.patch` 形式附在这里，**未合入 v2 源码**；`assets/footage/` 已是打补丁后录好的切片，直接重建视频不需要打补丁。

## 重新出片

```bash
npm install -g @hypit/hypit@0.2.16
npm install && (cd packages/douyin-overlay && npm install && rm -rf node_modules/@hypit)
hypit runtime use ./hypit.runtime.json
hypit programs prepare --endpoint hyperframes.local   # 首次：安装 HyperFrames 渲染依赖
tools/master.sh                                       # 生成 SVML → 构建 → 导出 → −14 LUFS 母带
```

没有 GPU、或想用本机已有的 Chromium 时，在 `hypit.runtime.json` 的 `hyperframes.local.config` 里加 `"chromePath": "<chromium 路径>", "browserGpu": "software"`（本片在无 GPU 沙箱里就是这样渲染的）。双核机器上 930 帧约 4 分钟。

## 已知限制

- 口播是 Edge-TTS（微软在线语音，免费但非官方 API）；**商用投放前建议换成自有授权的 TTS 或真人配音**，只需替换 `assets/vo/*.wav` 并重跑 `gen_svml.py`（时间轴按 `timing.json` 走，换音频后需重新生成词级时间）。
- 视频里「我也死过99次」之后的师兄回应来自录屏模式的离线规则，不是现场 Haiku 生成；「AI 驱动」指游戏有 key 时由 Haiku 4.5 驱动角色。
- 气泡里的强调色（`*多少？`）在当前渲染里没有显示成红色，仍是黑字，不影响阅读。
