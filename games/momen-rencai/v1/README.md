# 魔门人材 · 带着记忆，苟到飞升

Godot 4.4 · 竖屏 270×480（×4 = 1080×1920，与抖音/TikTok 视频同构图）· GBA 像素风 · 俯视角 2D 战斗 · 挂机修仙

## 玩法一句话
你是魔门外门弟子。会死，但每一世都能**带着记忆**重生；AI 驱动的师兄、长老也**记得你**。

| 借鉴 | 落在游戏里 |
|---|---|
| 一念逍遥 | 挂机魔元产出、境界突破（炼气→飞升）、离线收益（8h 五折） |
| Universal Paperclips | 【账本】纯文字界面（一个「吐纳」按钮起家）；升级按累计魔元逐个解锁；冷峻「纪事」旁白；魔种自我复制；**炼化**：外门→魔门→修仙界→三千世界（每阶段产出 ×10）；结局「万物皆成魔元」→ 带着「我炼化过三千世界」轮回 |
| 《苟在初圣魔门当人材》 | 只借设定气质：魔门弱肉强食、背刺不算罪、主角先苟再上位（无原文、无原角色名） |
| 记忆系统 | `scripts/memory.gd`：玩家记忆卡 + NPC 情景记忆（跨世 ×0.6 衰减）+ 编年史 |
| 可带入记忆 | 死亡 → 轮回界面选 N 条记忆卡带入（夺舍秘术/道痕扩容），每条变成下一世的 perk |
| Agent 驱动角色 | `scripts/agent.gd`：OpenGameAgent 协议（GameInput → tool calls → 游戏校验执行） |

## 剧情模式（参考《底特律：变人》）
- `data/story.json` 是唯一剧情源：7 章 / 90 节点 / 8 结局（每章开头一个次要分支）；由 `tools/build_story.py` 生成（含流程图坐标）
- 每章分支 → 章末**收束点**；章末弹出本章流程图（本世走过的点亮，前世走过的暗亮，没走到的是「？」）
- **死亡即线索**：在本章死去（战斗里可「舍身」故意战死）→ 获得一条轮回记忆 → 回到本章开头，本章标记回滚、记忆保留
- 带锁选项需要特定记忆 / 标记；终章 6 个选项 + 20 秒超时，由前六章累计标记决定 8 个结局
- 章节之间用「修炼」（挂机 + 账本）攒境界：第三章需筑基、第四五章金丹、第六章元婴
- 章节选择：从任一已到达章节开头重玩（标记回到当时，记忆保留）
- `tools/verify_story.py` 穷举所有走法，确认 8 结局可达并输出路线 `data/story_routes.json`；`--storytest` 用同一路线驱动 GDScript 引擎回放

## 角色驱动（三层，自动降级）
1. **Haiku 4.5**：设置里填自己的 Anthropic key → 浏览器直连 `claude-haiku-4-5`（key 只存本机 `user://`）
2. **claude.ai Artifact 内**：设置里开「用我的 Claude 账号驱动」→ 走 artifact `sample` 能力（quick 档，免 key，花观看者自己的额度）
3. **离线规则**：同一套 tool calls（set_tactic / say / remember），游戏只有一条执行路径

游戏是权威方：例如模型想 `betray`，但好感 > -10 或第 1 波，会被降级为 `idle`。

## 新手引导 = 爆款视频
`data/viral_script.json` 是**唯一分镜源**：
- `video/render_viral.py` 用它渲染 28 秒竖屏视频（17–24.5s 为 Paperclips 账本段，布局来自同一文件的 `ledger_layout`）
- `scripts/director.gd` 用它驱动游戏：
  - **新手引导**（interactive）：同镜头，关键处等玩家操作（选记忆卡 / 连点吐纳 / 点突破）
  - **录屏模式**：严格按视频时间轴自动播放 → 玩家直接录屏即得同款视频，结尾一键复制文案+话题

## 运行
```bash
npm run verify:games               # 仓库根目录：本游戏全部机器检查（CI 同款，需 GODOT=Godot 4.4.1）
godot --path .                     # 桌面
godot --headless --path . -- --autotest   # 自动验收（引导全流程 + 轮回 + 录屏时间轴）
godot --headless --path . -- --storytest  # 剧情验收（8 结局路线回放 + UI 冒烟）
godot --path . -- --storydemo             # 按真结局路线自动演示
python3 tools/build_story.py && python3 tools/verify_story.py   # 改剧情后重建并穷举验证
godot --path . -- --record         # 直接进录屏模式
godot --headless --path . --export-release "Web" build/web/index.html  # Web（nothreads，任意静态托管）
python3 video/render_viral.py      # 重新渲染视频（需 ffmpeg / Pillow / numpy）
godot --headless --path . --export-pack "Web" ../../../public/games/momen-rencai/v1/index.pck  # 改了脚本/数据后同步 Web 包（CI 逐字节比对）
```

验收模式（`--autotest` / `--storytest` / `--storydemo`）只读写 `user://momen_save_test.json`，不会动玩家存档和 key。

## 素材与许可
- 像素素材：Kenney Tiny Dungeon / Tiny Town（CC0）
- 字体：Fusion Pixel 12px（SIL OFL 1.1，见 `assets/fonts/OFL.txt`）
- AI 协议参考：OpenGameAgent（Apache-2.0）

## 扩展路线
见 `ROADMAP.md`。
