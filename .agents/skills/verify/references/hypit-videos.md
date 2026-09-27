# Hypit 竖屏视频验证手册（字幕版式 + 时间对齐）

适用：`games/<game>/<ver>/hypit/` 里带 `screens.json` 的 Hypit 投放视频（首个：`games/momen-rencai/v3`）。
`screens.json` 是唯一分镜源；`tools/gen_svml.py` 由它生成 `momen.svml` / `momen.svs`，**不要手改生成物**。

## 1. 机器检查（必须全 PASS）

```bash
python3 .agents/skills/verify/scripts/verify-hypit-video.py games/momen-rencai/v3 \
  --video games/momen-rencai/v3/momen_v3_douyin_9x16.mp4 --out verification/hypit-v3
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

回归证据（2026-09-27）：同一脚本对修复前的 v3 成片（`990` 帧、-22.5 LUFS、字幕跟屏头而不是跟事件）给出 F1/F2/F3 FAIL；开发中 D 抓到字幕带高度不够、E 抓到 s01 事件帧标错。修 bug 时先让对应检查在旧产物上 FAIL，再修。

## 2. 人工核对（机器 PASS 不等于对题）

- 打开 `verification/hypit-v3/caption-sync-sheet.png`：每条字幕出现后第 6 帧一格。逐格确认**字幕说的就是画面此刻发生的事**（例：「你会选哪一段？」那格必须是「袖口的朱砂」卡；「选对了就能活」那格必须能看到「这一世，就算了」）。
- 完整看一遍成片（带声音），确认字幕切换、音效落点和画面切换同步，没有跳帧/黑帧。
- 新增或改动一屏的 `event_src_f` 时，用 0.1–0.2s 步长导出该段源帧网格逐帧确认，再写回 `screens.json`。

## 3. 记录

把 `report.json` 结论和人工核对结果写进 `docs/verification/<日期>-<game>-<ver>-video.md`。真机/抖音端播放、完播率、用户审美认可单独记 NOT_RUN/PENDING，不能由机器 PASS 推出。
