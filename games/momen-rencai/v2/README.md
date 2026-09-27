# 魔门人材 v2 ·「忆」—— 死一次，记住一件事

Godot 4.4 · 竖屏 270×480（×4 = 1080×1920，和抖音/TikTok 视频同构图）· 90 年代 GBA 像素风 · 文字冒险 + 俯视 2D 圆圈战斗

> 你在魔门死了 99 次。每次死前都能记住一件事，但只能记住一件。角色由 AI 驱动，他们也记得你。第一章藏着 4 层真相，你能挖到第几层？

## 需求 → 实现

| 需求 | 落在游戏里 |
|---|---|
| 90 年代 GBA 像素美术 | 270×480 原生分辨率、最近邻 ×4 放大；Kenney Tiny Dungeon / Tiny Town（CC0）拼场景；Fusion Pixel 12px 字体；合成 8-bit BGM（`tools/gen_audio.py`） |
| 俯视 2D 战斗，人物用圆圈 | `scripts/stage.gd`：每个角色是一个带字的圆（我/厉/满/骨…），追逐、碰撞、背刺、护卫；玩家随时切换 攻/守/退 |
| 借鉴一念逍遥 / Universal Paperclips / 《苟在初圣魔门当人材》 | 一念逍遥：修仙章节制 + 挂机式「吐纳」；Paperclips：一个按钮起家、数字自己涨（第 10 下后自动吐纳）、每章换一个新数字；小说：只借设定气质（魔门弱肉强食、背刺不算罪、先苟再上位），无原文、无原角色名 |
| 记忆系统（玩家必须亲手记） | 关键节点得到**记忆碎片**（13 片）。本世所得是「未铭刻」，只能回看；**死亡时提示一句线索，玩家必须打开背包亲手选出一片来「铭刻」**，之后每一世都能用。关键处出现「◆ 这一幕……似曾相识」，玩家要自己想起是哪一片并主动使用，才会显出隐藏选项。背包随时可回看（含前世没铭刻的「残影」） |
| 每章唯一冲突、线性章节、冲突多层隐藏（2–5 层） | 5 章 17 层：后山 4 层 / 药堂之夜 3 / 血骨擂台 3 / 正道来客 2 / 血月祭 5。首世只能看到 6/17 层（每章表层 + 第二章第 2 层）。深层要靠后续章节拿到的碎片，或**上一世后续章节的选择（回响）**——例：第二章替小满瞒下续命丹 → 下一世第一章开头多了一只纸鹤 → 揭开第一章第 3 层「树影里有人在看」 |
| Agent 驱动角色（Haiku 4.5，参考 OpenGameAgent） | `scripts/agent.gd`：OpenGameAgent 协议（GameInput → typed tool calls → 游戏校验执行）。`offer_options` 生成 N 个选项措辞、`interpret` 理解自由输入并以角色身份回话、`set_tactic` 决定战斗行为、`remember` 写入跨世记忆（每隔一世 ×0.6 衰减）。游戏始终是权威方：模型只能从游戏给的 choice_id / tactic 里选 |
| N 个选项 + 1 个自由输入框 | 每个对话节点：N 个生成的选项（有 key 时由 Haiku 生成措辞，无 key 时从作者写的变体里生成）+ 1 个输入框。输入框说中了你已铭刻的记忆里的东西 = 直接解开隐藏选项；没证据时角色会搪塞 |
| 避免复杂数值；每章一个新数值，不解释 | 元（魔元）→ 情 → 名 → 伪 → 忆（记得你的人）。只显示字形和数字，不告诉你它有什么用；本章数值在顶栏发亮，旧章数值挪到舞台角落变暗，仍有微弱影响（如魔元≥60 第二、三章各+1） |
| 先做爆款视频，新手引导必须能复刻 | 见下 |

## 爆款视频 = 新手引导 = 同一份分镜

`data/viral_script.json` 是唯一分镜（字幕、点击、输入的时间轴）。`scripts/director.gd` 用它驱动**真实游戏逻辑**：

- **录屏模式**（标题页「录屏模式 · 复刻爆款视频」/ `--record`）：手指光标按时间轴自动点。`video/momen_v2_viral_9x16.mp4` 就是用这个模式 + Godot Movie Maker 逐帧录出来的（`tools/record_video.sh`），所以视频和游戏必然一致。
- **新手引导**（首次进入默认）：同样的镜头与字幕，每一次「点」都停下来等玩家亲手点；输入框预填视频里那句「我也死过99次」，玩家可以改成任何话（有 key 时 Haiku 真实回应）。
- 引导结束 CTA：继续第二章（引导里的第 100 世就是正式存档）/ 录屏模式复刻视频 / 一键复制文案+话题。

32 秒分镜：死于师兄背刺（钩子）→ 死前线索 → 从背包选出「袖口的朱砂」铭刻 → 第 100 世吐纳 → 同一个师兄又来 → 打开「忆」使用记忆 → 隐藏选项出现 → 揭开第一章第 2 层 → 自由输入「我也死过99次」→ 师兄愣住 → 这一世他没有下手 → 第一章 ■■□□ → 第二章新数字「情」→「第一章有4层真相，你能挖到第几层？」

## 运行

```bash
godot --path .                                  # 桌面
godot --path . -- --record                      # 直接进录屏模式
godot --headless --path . -- --autotest         # 新手引导逐 gate、背包/铭刻/使用、自由输入、战斗「守」、回溯、录屏时间轴
godot --headless --path . -- --storytest        # 用穷举出的路线驱动 GDScript 剧情引擎回放 17 层 + 4 结局
python3 tools/build_story.py && python3 tools/verify_story.py   # 改剧情后重建并验证（每层每结局可达、首世不能看穿）
GODOT=godot tools/record_video.sh               # 重新录爆款视频（需 ffmpeg；无显示器时自动用 xvfb）
godot --path . --write-movie demo.avi --fixed-fps 30 -- --storydemo   # 按真结局路线实机演示
godot --headless --path . --export-release "Web" build/web/index.html   # Web（nothreads，任意静态托管）
```

仓库根目录 `npm run verify:games` 会跑本版本全部机器检查（`games/verify.json`）。

## Haiku 4.5

设置 →填入你自己的 Anthropic API key（只存本机 `user://`）。三层自动降级：自己的 key → claude.ai Artifact 内的账号能力 → 离线规则（同一套 tool calls，游戏逻辑只有一条路径）。录屏模式和自测强制离线，保证可复现。

## 借用与许可（「hack 进现有像素游戏」）

- 场景地块：Kenney Tiny Dungeon / Tiny Town（CC0），与 [gdquest godot-open-rpg](https://github.com/gdquest-demos/godot-open-rpg)（MIT）同源
- 打击/界面音效：Kenney Impact / Interface / RPG Audio（CC0），取自 godot-open-rpg 仓库的 `assets/sfx`
- 字体：Fusion Pixel 12px（SIL OFL 1.1，`assets/fonts/OFL.txt`）
- AI 角色协议：[OpenGameAgent](https://github.com/EricSun0218/OpenGameAgent)（Apache-2.0）
- BGM 与其余音效：`tools/gen_audio.py` 合成（本仓库原创）

扩展路线见 `ROADMAP.md`，版本与验证记录见 `VERSION.md`。
