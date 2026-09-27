# 2026-09-27 · momen-rencai v3 爆款视频验证

- 对象：`games/momen-rencai/v3/momen_v3_douyin_9x16.mp4`（Hypit 0.2.16 本地渲染，build `bld_20260927T115628922Z_390E1224DC`，再经 `tools/master.sh` 响度处理）
- 规格（ffprobe）：h264 1080×1920、SAR 1:1、30fps、33.1s；aac 48kHz
- 响度（ffmpeg ebur128）：I = -14.5 LUFS，Peak = -1.4 dBFS
- 画面：Studio 抽帧（1.5/4.7/6.7/8.3/9.3/13.3/15.7/16.7/18.0/18.7/21.3/24.7/27.3/31.3s）+ 成片 1fps 网格逐屏看过：9 屏字幕与 `story-studio.json` 一致；02/03/05 的慢放/定格落在预期帧（03 定格在「袖口的朱砂」卡，05 定格在「似曾相识」）
- 仓库内工程：`hypit check momen.svrun` 通过；用子集字体在 Studio 抽帧（1.5/16.7/31.3s）字形完整
- 未验证：没有在真机/抖音端播放；仓库内工程未完整重渲染（成片来自同一源文件、完整字体的构建）；新手引导复刻未针对 v3 重新跑 `--autotest`（v3 不改游戏代码）
