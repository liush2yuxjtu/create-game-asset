# Hypit 竖屏视频验证手册（字幕版式 + 时间对齐 + 口播 + 设计同步）

适用：`games/<game>/<ver>/hypit/` 里带 `screens.json` 的 Hypit 投放视频（首个：`games/momen-rencai/v3`）。
`screens.json` 是唯一分镜源（含字幕与口播稿）；`tools/tts_vo.py` 由它合成口播 `assets/vo/*.wav` 与 `vo_timing.json`，`tools/gen_svml.py` 再生成 `momen.svml` / `momen.svs`，**不要手改生成物**。顺序：改 `screens.json` → `tts_vo.py` → `gen_svml.py` → 渲染 → `tools/master.sh` → 验证。`<ver>/design/` 是设计画布源文件，工作台默认值必须等于成片。

## 1. 机器检查（必须全 PASS）

```bash
pip install faster-whisper   # 仅 --asr（F5）需要；首次会下载 small 模型
python3 scripts/verify-hypit-video.py games/momen-rencai/v3 \
  --video games/momen-rencai/v3/momen_v3_douyin_9x16.mp4 --asr --out verification/hypit-v3
```

| 检查 | 通过条件 | 抓的是什么问题 |
|---|---|---|
| A 生成一致 | `momen.svml/svs` 与 `screens.json` 重新生成的结果逐字一致 | 手改了生成物、改了分镜没重新生成 |
| B 时间轴 | 各屏首尾相接、总长 = Timeline `end`；源区间在素材内；事件帧在本屏源区间内 | 黑帧空档、重叠、越界 |
| C 字幕时间 | 字幕在「事件帧对应的节目帧」出现、在屏尾消失；显示 ≥ max(1s, 字数/7 字每秒) | 字幕比画面早/晚、字幕跨屏、读不完 |
| D 版式 | 字幕带/标题带不与手机框重叠、在画布内；≤2 行；估算行宽 ≤ 带宽；带高 ≥ 行数×字号×1.2 | 字幕压住游戏对话、溢出、挤行 |
| E 事件标注 | 源片在事件帧 ±3 帧内出现该 ±9 帧窗口里最大的画面变化 | `event_src_f` 标错（例如 s01 标 276，实际变化在 269） |
| F1 成片规格 | 1080×1920、SAR 1:1、帧数 = 总长 ±3 | 压扁（SAR 1:2）、渲错版本 |
| F2 响度 | -15.5 ~ -13 LUFS | 忘了跑 `tools/master.sh` |
| F3 成片字幕对齐 | 字幕出现前 3 帧字幕带为空（σ≤8）、出现后 6 帧有字（σ≥12） | 渲染结果和源文件对不上、字幕提前出现 |
| G1 口播齐全 | `screens.json` 有 `voice` 时每屏有口播且恰好 1 句主句（`main`）；每句 wav 和 `vo_timing.json` 都在；有 `voice` 却没有逐屏口播直接 FAIL | 忘了配音、漏屏、改稿没重新合成 |
| G2 口播时间 | 每句在窗口开口帧开口（主句 = 事件帧 = 字幕出现帧；`at: screen` 句 = 屏头 + `delay_f`）；wav 在窗口内说完（到下一句开口 / 屏尾前 2 帧）；svml `audio:Item` 的 `at` 相同、`for` ≥ wav 实长且不越窗；缺 wav 时只记 G1 FAIL、继续出报告 | 声画错位、话说到下一屏、`vo_timing` 时长比 wav 短导致截尾、生成物没更新 |
| G3 字幕即口播 | 每行字幕（去标点）原样出现在同屏主句里 | 字幕和口播说的不是一件事 |
| G4 语速 | 语速 ≤ `max_rate`（+40%）且 ≤ 8 字/秒 | 为塞进窗口把话说得太快 |
| G5 人声压过音乐 | 最轻一句口播 LUFS − (BGM LUFS + 20·log10 BGM 增益) ≥ 10 LU | 音乐盖人声 |
| H 设计同步 | `design/StoryStudio.dc.html` 存在时，`node scripts/render-story-studio.cjs` 按保存默认值无头渲染：屏数、每屏字幕、口播全文（铺垫 + 主句）、时长（±0.11s）与 `screens.json` 一致 | 改了成片没改设计稿（或反之） |
| F4 成片口播可闻 | 每句开口处，成片音频 20ms RMS 包络与该句 wav 包络的 Pearson r ≥ 0.6（±3 帧对齐） | 渲染漏了口播轨、口播被音效/音乐盖住 |
| F5 转写核对（`--asr`） | faster-whisper small 在每句窗口里转写，与口播稿相似度 ≥ 0.6 | 口播音频错位/错句、听不清 |

回归证据（2026-09-27）：
- 字幕修复：同一脚本对修复前的 v3 成片（`990` 帧、-22.5 LUFS、字幕跟屏头而不是跟事件）给出 F1/F2/F3 FAIL；开发中 D 抓到字幕带高度不够、E 抓到 s01 事件帧标错。
- 口播：旧（无声）分镜 → G FAIL；新分镜 + 旧无声成片 → F4 FAIL（最高 r=0.52）、F5 FAIL；旧设计稿（10 屏、无口播）→ H FAIL。F4 起初用「口播段 RMS 高于 BGM」判定，在无声版上也 PASS，改成包络相关后才有区分度；s03 曾 r=0.38（reveal 音效盖住开口），把音效提前 4 帧并降音量后 ≥ 0.71。PR #19 评审后补：`vo_timing` 把 s04 时长改短 → G2 FAIL（「排了 30f，wav 实长 52f，会被截尾」）；删掉一个 wav → G1 FAIL 且报告照常写出；`tts_vo.py` 放不下时整批不发布，`assets/vo/` 保持原样。

规则：加新检查或修 bug 时，**先让对应检查在旧产物上 FAIL，再修**，并把 FAIL 证据记进验证文档。

## 2. 人工核对（机器 PASS 不等于对题）

- 打开 `verification/hypit-v3/caption-sync-sheet.png`：每条字幕出现后第 6 帧一格。逐格确认**字幕说的就是画面此刻发生的事**（例：「你会选哪一段？」那格必须是「袖口的朱砂」卡；「选对了就能活」那格必须能看到「这一世，就算了」）。
- 完整看一遍成片（带声音），确认字幕切换、音效落点和画面切换同步，没有跳帧/黑帧。
- 听口播：每句是否在字幕弹出的同时开口、有没有被切掉尾音、语速是否能听清、音色和语气是否符合角色。F4/F5 只证明「听得到、说对了字」，不证明好听；音色认可单独记 PENDING。
- 改了口播稿：先跑 `tools/tts_vo.py`（放不进窗口会报错，按报错改稿，不要拉长画面），再 `gen_svml.py`，同时改设计画布工作台里对应拍的口播，否则 H FAIL。
- Edge-TTS 没有明确商用授权：付费投放前换授权 TTS 或真人配音，把 wav 按同名放进 `assets/vo/` 并更新 `vo_timing.json` 后重跑全部检查。
- 新增或改动一屏的 `event_src_f` 时，用 0.1–0.2s 步长导出该段源帧网格逐帧确认，再写回 `screens.json`。

## 3. 记录

把 `report.json` 结论和人工核对结果写进 `docs/verification/<日期>-<game>-<ver>-video.md`。真机/抖音端播放、完播率、用户审美认可单独记 NOT_RUN/PENDING，不能由机器 PASS 推出。
