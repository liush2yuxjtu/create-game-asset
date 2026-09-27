# 魔门人材 v3 · 爆款竖屏「只能带一件事」（Hypit）

> 每次死前，我能记住一件事——第100世，我终于选对了那一件。

成片：[`momen_v3_douyin_9x16.mp4`](momen_v3_douyin_9x16.mp4)，1080×1920 · 30fps · 24.2s · -14.3 LUFS · **中文男声口播**（Edge-TTS 云希）+ 字幕同帧。

## 来源：故事工作台的选定组合

故事在 Claude Design 画布「魔门人材 v2 · 爆款视频设计稿（Hypit）」的**故事工作台**里分四层定稿（L1 一句话 → L2 幕 → L3 节拍 → L4 画面，上层改动下层自动重算）。画布源文件在 [`design/`](design/)；工作台保存的默认值就是这一版成片，完整展开见 [`story-studio.json`](story-studio.json)（由 `node .agents/skills/verify/scripts/render-story-studio.cjs` 无头渲染生成），/verify 的 H 检查保证两者逐屏一致：

| 层 | 选择 |
|---|---|
| L1 | 角度「只能带一件事」· 钩子「冷开场结果」· 第一人称 · 显示 99 · AI 暗示 · 带评论钩子 · **口播开 · 云希** |
| L2 | 首尾循环（冷开场闪前）· 高潮幕 C「抉择」· **时长按画面事件**（5 幕） |
| L3 | 字幕说法「问观众」，9 拍，每拍一句口播（主句包含字幕原文） |
| L4 | 金边手机框 · 轻推 1→1.12 · 字幕顶部字幕带 · 音效开 |

## 9 屏（时间由画面事件决定）

`hypit/screens.json` 是唯一分镜源：每屏是一段**原速**实机源片，屏与屏首尾相接；每条字幕在它所说的画面事件第一次出现的那一帧弹出（`event_src_f`，逐帧标注），到本屏结束消失。字幕放在手机框上方的字幕带里，不压游戏画面；最上方一行常驻 L1 一句话。

| # | 屏时间 | 字幕 / 口播开口 | 对应画面事件 | 字幕 | 口播 |
|---|---|---|---|---|---|
| 01 | 0.0–2.0s | 0.0s | 打开「忆」选出袖口的朱砂 → 隐藏选项（闪前） | 就是这一件 / 救了我的命 | 就是这一件，救了我的命。 |
| 02 | 2.0–6.0s | 2.2s 铺垫 · 4.6s 主句 | 背刺 →「你死了」屏：从背包选出一段 | 只能带一段 | 第九十九次，又死在师兄刀下。／只能带一段。 |
| 03 | 6.0–7.4s | 6.0s | 记忆卡「袖口的朱砂」出现 | 你会选 / 哪一段？ | 你会选哪一段？ |
| 04 | 7.4–9.2s | 7.4s | 第100世白闪 → 吐纳 | 重来一次 / 只多知道一件事 | 重来一次，只多知道一件事。 |
| 05 | 9.2–13.0s | 9.2s | 「◆ 这一幕……似曾相识」选项出现 | 记忆该什么时候用？ | 第一百世，同一个后山。记忆，该什么时候用？ |
| 06 | 13.0–16.4s | 13.0s | 层卡「第一章 · 第2层 师兄的命押在药堂」 | 一件小事 / 能改多少？ | 一件小事，揭开了他的秘密。能改多少？ |
| 07 | 16.4–18.4s | 17.2s | 厉寒：「……这一世，就算了。」 | 选对了 / 就能活 | 选对了就能活。 |
| 08 | 18.4–20.0s | 18.4s | 「第一章 · 完」还有 2 层没被看见 | 下一世 / 你带什么？ | 下一世，你带什么？ |
| 09 | 20.0–24.2s | 20.0s | 结尾卡「魔门人材 · 忆」 | 你会带哪段记忆 / 进下一世？ | 死前只能记住一件事。你会带哪段记忆，进下一世？ |

01 是闪前（第 9 秒的「用上记忆」提前放到开头），02 起按游戏顺序单调向前，新手引导仍可按同一路线复刻。

## 口播（人声驱动节奏）

- 每屏一句**主句**，和字幕在同一帧（画面事件帧）开口；主句必须原样包含该屏字幕（字幕 = 口播的关键词）。02 屏在事件前多一句**铺垫句**，从屏头 +4 帧开口。
- 每句口播只能在自己的窗口里说：从开口帧到下一句开口 / 屏尾前 2 帧。`tools/tts_vo.py` 从 +10% 语速开始合成，放不进窗口就每次 +10%，上限 +40%；到上限还放不下就报错，改稿（不许拉长画面去迁就）。本版语速 +10%～+40%（04 屏最紧：1.70s 说完 1.73s 窗口）。
- 音色 Edge-TTS `zh-CN-YunxiNeural`（云希，年轻男声）；每句裁到首尾词边界、归一到 -16 LUFS。BGM 全程压到 ×0.18，音效比开口早 4 帧、音量下调，不盖第一个字。
- 产物：`hypit/assets/vo/<屏>-<序号>.wav` + `vo_timing.json`（每句文本、语速、开口帧、时长、词时间）；`gen_svml.py` 读它生成 `audio:Item`。
- **商用风险**：Edge-TTS 是微软 Edge 的在线朗读接口，没有明确的商用授权。自然流量发布问题不大；**付费投放前换成有商用授权的 TTS 或真人配音**，换完重跑 `gen_svml.py` 和验证即可（时间轴由 `vo_timing.json` 驱动）。

**和故事工作台的关系**：工作台 L2 的「时长」选「按画面事件」时，每拍时长取实拍事件的原速长度，合计 24.2 秒，与成片一致；选「按比例」才会按总时长拉伸（仅作构思用，成片不采用）。

## 重新生成

```bash
# 1) 干净画面（无游戏内字幕、方像素）：给 v2 打补丁后录制，再放大
git apply games/momen-rencai/v3/hypit/clean-plate.patch
cd games/momen-rencai/v2
xvfb-run -a godot --path . --rendering-driver opengl3 --write-movie /tmp/clean.avi --fixed-fps 30 -- --movie --clean
ffmpeg -i /tmp/clean.avi -vf "scale=1080:1920:flags=neighbor,setsar=1,format=yuv420p" -c:v libx264 -crf 16 -r 30 \
  -af loudnorm=I=-15:TP=-1.5:LRA=11 -c:a aac ../v3/hypit/assets/footage/gameplay_clean.mp4

# 2) 改分镜/口播稿只改 screens.json，然后合成口播、重新生成源文件并合成（本地渲染，无付费生成）
cd ../v3/hypit
pip install edge-tts               # 需联网；代理环境加 SSL_CERT_FILE=<CA 包>
python3 tools/tts_vo.py            # → assets/vo/*.wav + vo_timing.json；放不进窗口会报错
python3 tools/gen_svml.py
npm install -g @hypit/hypit        # 0.2.16
hypit runtime use hypit.runtime.json && hypit runtime up
hypit build momen.svrun --title v3 --follow
hypit get <build-id> --output final.video --to out/v3.mp4
tools/master.sh out/v3.mp4 ../momen_v3_douyin_9x16.mp4

# 3) 验证（字幕版式 + 时间对齐 + 口播 + 设计同步，见 /verify 的 Hypit 视频路线）
cd ../../../..
pip install faster-whisper         # 仅 --asr 需要
python3 .agents/skills/verify/scripts/verify-hypit-video.py games/momen-rencai/v3 --video games/momen-rencai/v3/momen_v3_douyin_9x16.mp4 --asr
```

- `clean-plate.patch`：`director.gd` 加 `--clean`（录屏模式不画游戏内字幕）；`record_video.sh` 加 `setsar=1`。未直接改 v2，按需 `git apply`。
- 发现：v2 现有 `video/momen_v2_viral_9x16.mp4` 带 SAR 1:2 标记（显示比例 9:32），尊重 SAR 的播放器会压扁，补丁里的 `setsar=1` 修这个问题。
- 字体：`assets/fonts/pixel-v3-subset.ttf` 是 Fusion Pixel 12px（SIL OFL 1.1）按本片字幕与标题用字子集化；改字幕需从 v2 的 `pixel.ttf` 重新子集化。
- 音乐与音效来自 v2（BGM 为 v2 `tools/gen_audio.py` 合成；撞击为 Kenney CC0）。

## 已知边界

- 口播是 TTS，不是真人；音色与语气尚未经用户审听确认。商用授权见上文。
- 02 屏字幕从「三段记忆 / 只能带一段」收成「只能带一段」：口播要在事件帧后 1.4 秒内说完，长句放不进。
- 「首尾循环」依赖平台自动循环播放，片尾没有额外接回镜头。
