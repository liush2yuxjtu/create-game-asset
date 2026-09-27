# 魔门人材 v3 · 爆款竖屏「只能带一件事」（Hypit）

> 每次死前，我能记住一件事——第100世，我终于选对了那一件。

成片：[`momen_v3_douyin_9x16.mp4`](momen_v3_douyin_9x16.mp4)，1080×1920 · 30fps · 24.2s · -14.4 LUFS。

## 来源：故事工作台的选定组合

故事在 Claude Design 画布「魔门人材 v2 · 爆款视频设计稿（Hypit）」的**故事工作台**里分四层定稿（L1 一句话 → L2 幕 → L3 节拍 → L4 画面，上层改动下层自动重算）。这一版用的是画布上保存的默认组合，完整展开见 [`story-studio.json`](story-studio.json)：

| 层 | 选择 |
|---|---|
| L1 | 角度「只能带一件事」· 钩子「冷开场结果」· 第一人称 · 33 秒 · 显示 99 · AI 暗示 · 带评论钩子 |
| L2 | 首尾循环 · 节奏「匀」· 高潮幕 C「抉择」（4 幕：规则 / 抉择 / 改命 / 留问题） |
| L3 | 字幕说法「问观众」，9 拍 |
| L4 | 金边手机框 · 轻推 1→1.12 · 字幕居中 · 音效开 |

## 9 屏（时间由画面事件决定）

`hypit/screens.json` 是唯一分镜源：每屏是一段**原速**实机源片，屏与屏首尾相接；每条字幕在它所说的画面事件第一次出现的那一帧弹出（`event_src_f`，逐帧标注），到本屏结束消失。字幕放在手机框上方的字幕带里，不压游戏画面；最上方一行常驻 L1 一句话。

| # | 屏时间 | 字幕出现 | 对应画面事件 | 字幕 |
|---|---|---|---|---|
| 01 | 0.0–2.0s | 0.0s | 打开「忆」选出袖口的朱砂 → 隐藏选项（闪前）（源 9.0–11.0s） | 就是这一件 / 救了我的命 |
| 02 | 2.0–6.0s | 4.6s | 「你死了」屏：记忆会随死亡散去，从背包选出一段（源 0.0–4.0s） | 三段记忆 / 只能带一段 |
| 03 | 6.0–7.4s | 6.0s | 记忆卡「袖口的朱砂」出现（源 4.0–5.4s） | 你会选 / 哪一段？ |
| 04 | 7.4–9.2s | 7.4s | 第100世白闪 → 吐纳（源 5.4–7.2s） | 重来一次 / 只多知道一件事 |
| 05 | 9.2–13.0s | 9.2s | 「◆ 这一幕……似曾相识」选项出现（源 7.2–11.0s） | 记忆该什么时候用？ |
| 06 | 13.0–16.4s | 13.0s | 层卡「第一章 · 第2层 师兄的命押在药堂」（源 11.0–14.4s） | 一件小事 / 能改多少？ |
| 07 | 16.4–18.4s | 17.2s | 厉寒：「……这一世，就算了。」（源 23.0–25.0s） | 选对了 / 就能活 |
| 08 | 18.4–20.0s | 18.4s | 「第一章 · 完」还有 2 层没被看见（源 25.0–26.6s） | 下一世 / 你带什么？ |
| 09 | 20.0–24.2s | 20.0s | 结尾卡「魔门人材 · 忆」（源 27.8–32.0s） | 你会带哪段记忆 / 进下一世？ |

01 是闪前（第 9 秒的「用上记忆」提前放到开头），02 起按游戏顺序单调向前，新手引导仍可按同一路线复刻。

**和故事工作台的差异**：工作台按比例给 33 秒排时长；实拍画面里每个事件的真实长度加起来是 24.2 秒。为了让字幕和画面对题，这一版以画面事件为准，不再拉伸或定格去凑 33 秒。

## 重新生成

```bash
# 1) 干净画面（无游戏内字幕、方像素）：给 v2 打补丁后录制，再放大
git apply games/momen-rencai/v3/hypit/clean-plate.patch
cd games/momen-rencai/v2
xvfb-run -a godot --path . --rendering-driver opengl3 --write-movie /tmp/clean.avi --fixed-fps 30 -- --movie --clean
ffmpeg -i /tmp/clean.avi -vf "scale=1080:1920:flags=neighbor,setsar=1,format=yuv420p" -c:v libx264 -crf 16 -r 30 \
  -af loudnorm=I=-15:TP=-1.5:LRA=11 -c:a aac ../v3/hypit/assets/footage/gameplay_clean.mp4

# 2) 改分镜只改 screens.json，然后重新生成源文件并合成（本地渲染，无付费生成）
cd ../v3/hypit
python3 tools/gen_svml.py
npm install -g @hypit/hypit        # 0.2.16
hypit runtime use hypit.runtime.json && hypit runtime up
hypit build momen.svrun --title v3 --follow
hypit get <build-id> --output final.video --to out/v3.mp4
tools/master.sh out/v3.mp4 ../momen_v3_douyin_9x16.mp4

# 3) 验证（字幕版式 + 时间对齐，见 /verify 的 Hypit 视频路线）
cd ../../../..
python3 scripts/verify-hypit-video.py games/momen-rencai/v3 --video games/momen-rencai/v3/momen_v3_douyin_9x16.mp4
```

- `clean-plate.patch`：`director.gd` 加 `--clean`（录屏模式不画游戏内字幕）；`record_video.sh` 加 `setsar=1`。未直接改 v2，按需 `git apply`。
- 发现：v2 现有 `video/momen_v2_viral_9x16.mp4` 带 SAR 1:2 标记（显示比例 9:32），尊重 SAR 的播放器会压扁，补丁里的 `setsar=1` 修这个问题。
- 字体：`assets/fonts/pixel-v3-subset.ttf` 是 Fusion Pixel 12px（SIL OFL 1.1）按本片用字子集化；改字幕需从 v2 的 `pixel.ttf` 重新子集化。
- 音乐与音效来自 v2（BGM 为 v2 `tools/gen_audio.py` 合成；撞击为 Kenney CC0）。

## 已知边界

- 无配音。字幕位置从工作台选的「居中」改为「顶部字幕带」：居中会遮住游戏对话区，与画面内容冲突。
- 「首尾循环」依赖平台自动循环播放，片尾没有额外接回镜头。
