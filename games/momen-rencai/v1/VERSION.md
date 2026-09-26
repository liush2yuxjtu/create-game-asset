# 魔门人材 v1 · 版本记录

## 包含

| 路径 | 内容 |
|---|---|
| `project.godot`、`scenes/`、`scripts/` | Godot 4.4.1 工程（GDScript） |
| `data/story.json` | 唯一剧情源：7 章 / 90 节点 / 8 结局，含流程图坐标（`tools/build_story.py` 生成） |
| `data/story_routes.json` | 8 个结局各一条最短路线（`tools/verify_story.py` 穷举生成） |
| `data/viral_script.json` | 爆款视频分镜；视频渲染器与游戏新手引导/录屏模式共用 |
| `video/render_viral.py`、`video/momen_viral_9x16.mp4` | 28 秒 1080×1920 竖屏视频及其渲染器 |
| `media/story_true_ending_demo.mp4` | 按真结局路线自动通关的实机录像（约 3 分 40 秒） |
| `media/ingame_record_mode.mp4` | 游戏「录屏模式」实录，与爆款视频逐镜对照 |
| `../../../public/games/momen-rencai/v1/` | Web 导出（nothreads，无需 COOP/COEP） |

## 剧情结构（设计稿摘要）

- 七章：第九十九次 → 外门考核 → 药堂之夜 → 血骨 → 正道来客 → 血月祭 → 第一百世。每章开头一个次要分支，中段主抉择，章末收束点。
- 死亡即线索：在章内死亡获得一条轮回记忆（共 7 条），回到本章开头，本章标记回滚、记忆保留；带锁选项需要特定记忆或标记。
- 终章「最后的选择」由前六章标记解锁，20 秒不选为「第一百零一次」。结局：真 · 飞升 / 同门 / 焚火 / 正道之剑 / 新宗主 / 替身 / 万物皆魔元 / 第一百零一次。
- 可视化流程图设计稿在 claude.ai 的 Design 画布（私有，需所有者分享）；其数据与 `data/story.json` 同源，可随时由该文件重建。

## 验证（2026-09-27 北京时间，本地，首版 `ac40448`）

| 检查 | 结果 |
|---|---|
| `python3 tools/verify_story.py` 穷举所有走法 | 8 结局全部可达；真结局最短 77 步，其余 47–48 步 |
| `godot --headless -- --storytest`（8 条路线驱动 GDScript 引擎 + UI 冒烟） | PASS；导出的 Linux 版同样 PASS |
| `godot --headless -- --autotest`（新手引导 gate、轮回、账本炼化、录屏时间轴 28.01 s） | PASS |
| `godot -- --storydemo` 实机按真结局路线通关 | 到达「真 · 飞升」，录像见 `media/` |
| Web 包本地 Chromium 加载 | 引擎启动、标题页与新手引导可交互 |

## 评审修复与测试左移（2026-09-27 北京时间，本地，Godot 4.4.1 headless）

PR #6 评审指出的问题已修复，每项都有自动回归（修复前在同一测试下 FAIL，修复后 PASS）：

| 问题 | 修复 | 回归检查（`--autotest` / `--storytest`） |
|---|---|---|
| 清空存档不清剧情进度 | `GS.wipe()` 同时 `Story.reset_state(false)` | 「清空存档同时清空剧情进度」「清档后写盘的剧情进度为空」 |
| 自动验收会覆盖玩家真实存档与 key | `--autotest/--storytest/--storydemo` 只写 `user://momen_save_test.json` | 「验收只写隔离存档」×2；实测玩家存档 SHA 前后一致 |
| 吐纳自动化可重复扣费 | `buy("tuna_auto")` 已拥有时拒绝 | 「已拥有的自动吐纳不再扣费」 |
| 掉落 6 秒计时器误结算/误关面板 | 每次掉落一个编号，只关自己的面板 | 「掉落超时不会关掉后打开的面板」「旧计时器不会结算/关闭新的掉落选择」等 5 项 |
| 视频 CTA 段整帧被擦掉 | 删去 `render_viral.py` 中对 RGBA 画布的全帧透明填充，重新渲染 `video/momen_viral_9x16.mp4` | 24.7 s 帧对比：修复前纯色底，修复后竞技场在渐暗层下可见 |

`npm run verify:games`（新增，CI 同款）：剧情穷举 8 结局可达、`--storytest` PASS、`--autotest` PASS（连续 3 次）、Web `.pck` 与源码重新导出逐字节一致（导出可复现，干净检出两次 SHA 相同）。日志中无 `ERROR` 行。

未验证：Windows/macOS 桌面包未在真机运行（macOS 未签名）；Haiku 4.5 真实 key 下的台词质量；手机真机触控与性能；GitHub Pages 线上页面（需合并后按 `/verify` 流程验收）。

## 许可与来源

像素素材 Kenney Tiny Dungeon/Tiny Town（CC0）；字体 Fusion Pixel 12px（OFL 1.1，`assets/fonts/OFL.txt`）；AI 角色协议参考 OpenGameAgent（Apache-2.0）。小说仅借设定气质，无原文与原角色名。
