# 魔门人材 v2 ·「忆」· 版本记录

## 包含

| 路径 | 内容 |
|---|---|
| `project.godot`、`scenes/`、`scripts/` | Godot 4.4.1 工程（GDScript），与 v1 独立，v1 保留不动 |
| `tools/build_story.py` → `data/story.json` | 唯一剧情源：5 章 / 80 节点 / 17 层冲突 / 13 记忆碎片 / 4 结局 |
| `tools/verify_story.py` → `data/story_routes.json` | 跨世搜索：每层每结局一条可回放路线；检查首世不能看穿任何一章 |
| `data/viral_script.json` | 爆款视频 / 新手引导 / 录屏模式共用分镜 |
| `video/momen_v2_viral_9x16.mp4`、`tools/record_video.sh` | 32 秒 1080×1920 竖屏视频，由游戏录屏模式经 Godot Movie Maker 逐帧录制 |
| `media/true_ending_demo.mp4` | `--storydemo` 按真结局路线（第 10 世）实机通关录像，1 分 43 秒 |
| `../../../public/games/momen-rencai/v2/` | Web 导出（nothreads），GitHub Pages 发布 |

## 验证（2026-09-27，本地沙箱）

| 检查 | 结果 |
|---|---|
| `verify_story.py` | PASS：17/17 层、4/4 结局可达；首世可见 6/17 层；真结局找到的路线为第 10 世（束搜索上界，非证明最少） |
| `--storytest`（21 条路线驱动 GDScript 引擎，1423 项断言） | PASS |
| `--autotest`（42 项：引导 18 个 gate 逐个真点、非目标点击无效、背包回看/铭刻/使用对错、自由输入命中/搪塞、战斗切「守」挡背刺、回溯、录屏时间轴 32.0 s） | PASS |
| `npm run verify:games`（v1 + v2 全部机器检查，含 web pck 与源码一致） | PASS |
| 视频逐帧抽查（24 帧 + 全分辨率裁切） | 字幕不挡关键信息；像素最近邻清晰；音轨 loudnorm −14 LUFS |
| Web 包本地 Chromium（Playwright） | 引擎启动、标题页、新手引导 gate 高亮可点 |

未验证：Haiku 4.5 真实 key 下的选项与回应质量（沙箱无 key；视频里「我也死过99次」的回应来自离线规则）；手机真机触控与中文输入法；GitHub Pages 线上页面（合并后按 `/verify` 验收）；Windows/macOS 桌面包。
