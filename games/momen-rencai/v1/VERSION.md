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

## 验证（2026-09-27，本地）

| 检查 | 结果 |
|---|---|
| `python3 tools/verify_story.py` 穷举所有走法 | 8 结局全部可达；真结局最短 77 步，其余 47–48 步 |
| `godot --headless -- --storytest`（8 条路线驱动 GDScript 引擎 + UI 冒烟） | PASS；导出的 Linux 版同样 PASS |
| `godot --headless -- --autotest`（新手引导 gate、轮回、账本炼化、录屏时间轴 28.01 s） | PASS |
| `godot -- --storydemo` 实机按真结局路线通关 | 到达「真 · 飞升」，录像见 `media/` |
| Web 包本地 Chromium 加载 | 引擎启动、标题页与新手引导可交互 |

未验证：Windows/macOS 桌面包未在真机运行（macOS 未签名）；Haiku 4.5 真实 key 下的台词质量；手机真机触控与性能；GitHub Pages 线上页面（需合并后按 `/verify` 流程验收）。

## v1.1 修复（2026-09-27，原地修补，未开新目录）

来自 PR #6 的 CodeRabbit / Codex 审查：

| 问题 | 修复 | 回归检查 |
|---|---|---|
| 设置里「清空存档」不清剧情进度 | `GS.wipe()` 调 `Story.reset_state(false)` | autotest §4 |
| 战利品 6 秒计时器可能结算后一次掉落、或关掉记忆/设置面板 | 每次掉落带编号 `loot_seq`，只关自己的面板 | autotest §4 |
| 「吐纳自动化」已拥有后再点仍扣 30 魔元 | `buy()` 拒绝重复购买 | autotest §4 |
| 自测会覆盖玩家存档和 key | `--autotest/--storytest/--storydemo` 改写 `user://momen_save_test.json` | 放一份哨兵存档跑完两套自测，md5 不变 |
| 视频 CTA 淡入被整帧清空 | 删去覆盖整帧的 `rectangle`；淡入透明度对齐游戏的 0.9 | 重渲染，逐帧查看 24.6 s / 26.5 s |

未采纳：「验证日期是未来日期」——执行日期确为 2026-09-27，审查机器人时区判断有误。

验证：`--autotest` PASS、`--storytest` PASS、`verify_story.py` 8 结局可达；Web 重新导出（仅 `index.pck` 与 `index.html` 的文件大小变更）。

### v1.1 补充：回归加严 + CI 门禁（2026-09-27 北京时间）

- autotest §2a 新增掉落计时器三项：被设置面板盖住的掉落超时仍结算、超时不关掉后打开的面板、旧计时器不结算/关闭新的掉落选择。§4 与 storytest §0 新增「验收只写隔离存档」断言。
- 红→绿：把新测试放到修复前的 `2b3910e` 代码上跑，✘ 掉落超时不会关掉后打开的面板、✘ 旧计时器不会结算/关闭新的掉落选择、✘ 验收只写隔离存档、✘ 吐纳自动化已拥有时不再扣费；v1.1 代码上全部 ✔。
- 测试脚本打进 pck，因此重新导出 `index.pck` 并同步 `index.html` 的 `fileSizes`。
- `npm run verify:games` 进入 Pages 工作流（见仓库 `references/godot-games.md` §A2）。

## 加固（2026-09-27）

- `--autotest` 开头先断言在隔离存档上，不满足直接退出，之后才会清档（原先断言在清档之后，拦不住误删）。
- `verify_story.py` 不再把结局状态入队（结局是终点），峰值内存 6.0 GB → 4.5 GB，8 条路线逐字节不变；此前在 8 GB 沙箱里经 `npm run` 运行时曾被 OOM 杀掉（退出码 null）。
- 补入 PR #8 的第 1 轮线上验收报告（2b3910e），作为历史记录。

## 许可与来源

像素素材 Kenney Tiny Dungeon/Tiny Town（CC0）；字体 Fusion Pixel 12px（OFL 1.1，`assets/fonts/OFL.txt`）；AI 角色协议参考 OpenGameAgent（Apache-2.0）。小说仅借设定气质，无原文与原角色名。
