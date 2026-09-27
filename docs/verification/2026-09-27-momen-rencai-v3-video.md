# 2026-09-27 · momen-rencai v3 爆款视频验证

## 修订 2：字幕版式 + 时间对齐（本次）

- 问题（首版）：字幕居中压住游戏对话区；各屏时长按比例分配，02/03/05 用慢放/定格凑时长，字幕与画面事件错位（例：「你会选哪一段？」出现时画面已进入轮回白闪）。
- 修复：`hypit/screens.json` 成为唯一分镜源，`tools/gen_svml.py` 生成 `momen.svml/svs`；每屏原速播放一段源片、首尾相接；字幕在逐帧标注的事件帧出现、屏尾消失；字幕带移到手机框上方。成片 24.2s。
- 机器检查：`python3 scripts/verify-hypit-video.py games/momen-rencai/v3 --video games/momen-rencai/v3/momen_v3_douyin_9x16.mp4` → 8/8 PASS（A 生成一致、B 时间轴 727f、C 字幕时间、D 版式、E 事件标注偏移 ≤3 帧、F1 1080×1920 SAR 1:1 727 帧、F2 -14.4 LUFS、F3 成片字幕在事件帧出现）
- 回归：同一脚本对修复前成片报 F1/F2/F3 FAIL（990 帧、-22.5 LUFS、s02/s07 字幕早于事件出现）；开发中 D 抓到字幕带过矮、E 抓到 s01 事件帧标错（276→269）
- 人工：`caption-sync-sheet.png` 逐格核对 9 条字幕与画面对题；2fps 网格通看无黑帧/跳帧
- 未验证：真机/抖音端播放；用户审美认可

## 首版（已被修订 2 取代）

- 构建 `bld_20260927T115628922Z_390E1224DC`，33.1s，-14.5 LUFS；`hypit check` 通过、子集字体渲染正常；未做真机播放
