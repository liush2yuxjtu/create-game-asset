# 魔门人材 v3 · 爆款竖屏「只能带一件事」（Hypit）

> 每次死前，我能记住一件事——第100世，我终于选对了那一件。

成片：[`momen_v3_douyin_9x16.mp4`](momen_v3_douyin_9x16.mp4)，1080×1920 · 30fps · 33.1s · -14.5 LUFS。

## 来源：故事工作台的选定组合

故事在 Claude Design 画布「魔门人材 v2 · 爆款视频设计稿（Hypit）」的**故事工作台**里分四层定稿（L1 一句话 → L2 幕 → L3 节拍 → L4 画面，上层改动下层自动重算）。这一版用的是画布上保存的默认组合，完整展开见 [`story-studio.json`](story-studio.json)：

| 层 | 选择 |
|---|---|
| L1 | 角度「只能带一件事」· 钩子「冷开场结果」· 第一人称 · 33 秒 · 显示 99 · AI 暗示 · 带评论钩子 |
| L2 | 首尾循环 · 节奏「匀」· 高潮幕 C「抉择」（4 幕：规则 / 抉择 / 改命 / 留问题） |
| L3 | 字幕说法「问观众」，9 拍 |
| L4 | 金边手机框 · 轻推 1→1.12 · 字幕居中 · 音效开 |

## 9 屏

| # | 时间 | 画面 | 字幕 |
|---|---|---|---|
| 01 | 0.0–3.1s | 背刺 | 就是这一件 / 救了我的命 |
| 02 | 3.1–6.1s | 铭刻记忆（0.47× 慢放） | 三段记忆 / 只能带一段 |
| 03 | 6.1–10.7s | 袖口的朱砂（首帧定格） | 你会选 / 哪一段？ |
| 04 | 10.7–15.3s | 第100世 | 重来一次 / 只多知道一件事 |
| 05 | 15.3–19.9s | 似曾相识 → 隐藏选项（首帧定格） | 记忆该什么时候用？ |
| 06 | 19.9–22.9s | 层卡 | 一件小事 / 能改多少？ |
| 07 | 22.9–26.0s | 这一世，就算了 | 选对了 / 就能活 |
| 08 | 26.0–29.0s | 章末 → 第二章「情」 | 下一世 / 你带什么？ |
| 09 | 29.0–33.0s | 结尾卡 | 你会带哪段记忆 / 进下一世？ |

顶部常驻 L1 一句话。所有画面都是 v2 录屏模式的实机画面，**顺序单调向前、不倒放**（只跳过 v2 的自由输入/战斗段），所以 v2 新手引导按同一路线仍可复刻；02/03/05 的慢放与定格只作用于成片。

## 重新生成

```bash
# 1) 干净画面（无游戏内字幕、方像素）：给 v2 打补丁后录制，再放大
git apply games/momen-rencai/v3/hypit/clean-plate.patch
cd games/momen-rencai/v2
xvfb-run -a godot --path . --rendering-driver opengl3 --write-movie /tmp/clean.avi --fixed-fps 30 -- --movie --clean
ffmpeg -i /tmp/clean.avi -vf "scale=1080:1920:flags=neighbor,setsar=1,format=yuv420p" -c:v libx264 -crf 16 -r 30 \
  -af loudnorm=I=-15:TP=-1.5:LRA=11 -c:a aac ../v3/hypit/assets/footage/gameplay_clean.mp4

# 2) Hypit 合成（本地渲染，无付费生成）
cd ../v3/hypit
npm install -g @hypit/hypit        # 0.2.16
hypit runtime use hypit.runtime.json && hypit runtime up
hypit build momen.svrun --title v3 --follow
hypit get <build-id> --output final.video --to out/v3.mp4
tools/master.sh out/v3.mp4 ../momen_v3_douyin_9x16.mp4
```

- `clean-plate.patch`：`director.gd` 加 `--clean`（录屏模式不画游戏内字幕）；`record_video.sh` 加 `setsar=1`。未直接改 v2，按需 `git apply`。
- 发现：v2 现有 `video/momen_v2_viral_9x16.mp4` 带 SAR 1:2 标记（显示比例 9:32），尊重 SAR 的播放器会压扁，补丁里的 `setsar=1` 修这个问题。
- 字体：`assets/fonts/pixel-v3-subset.ttf` 是 Fusion Pixel 12px（SIL OFL 1.1）按本片用字子集化；改字幕需从 v2 的 `pixel.ttf` 重新子集化。
- 音乐与音效来自 v2（BGM 为 v2 `tools/gen_audio.py` 合成；撞击为 Kenney CC0）。

## 已知边界

- 无配音；字幕居中会遮挡部分游戏对话区（工作台里选的是「居中」，可改回「顶部」）。
- 「首尾循环」依赖平台自动循环播放，片尾没有额外接回镜头。
