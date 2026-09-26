# 魔门人材 v1 线上 Pages 验收（第 1 轮：已合并的未修复版）

- 日期：2026-09-27 02:10 北京时间（UTC+8）
- 目标 URL：<https://liush2yuxjtu.github.io/create-game-asset/games/momen-rencai/v1/>（HTTP 200，已确认存在）
- 被测源提交：`2b3910e466ccd06293d8a998b883ab0d9e5d01b5`（`main`，PR #6 merge commit，内含首版 `ac40448`，**不含**评审修复 `a915a7d`）
- 环境：云端容器，Playwright 1.56 + Chromium 1194 headless（WebGL2 走 SwiftShader），视口 540×960
- 结论：**线上 v1 可玩，Games route 第 5 条 Release 检查 PASS**；评审修复尚未上线，修复合并后需第 2 轮。

| # | 检查 | 结果 | 观察 |
|---|------|------|------|
| 1 | 部署 workflow 成功 | 间接 PASS | 本会话无法读取 Actions API（仓库未授权）；线上 `build-info.json` 只由 Pages workflow 产出，且内容为当前 main，视为部署成功。修复 PR 合并后请在 Actions 页面直接确认。 |
| 2 | `build-info.json` `sourceSha` = 部署提交 | PASS | `{"sourceSha":"2b3910e466…","dirty":false}`，等于 `main` HEAD。 |
| 3 | 引擎启动 | PASS | 控制台：`Godot Engine v4.4.1.stable.official`、`OpenGL ES 3.0 (WebGL 2.0)`；画布渲染出标题页。 |
| 4 | 资源 MIME | PASS | `index.wasm` → `application/wasm`；`index.js`/`index.pck`/`index.png` 均 200。 |
| 5 | 控制台无报错 | PASS | 全程只有上面 2 条 `log`，无 warning/error/pageerror。 |
| 6 | 标题页可点 | PASS | 点「新的一世（序幕：爆款视频）」进入新手引导（证据 `momen-v1-live-title.png`）。 |
| 7 | 新手引导过第一个 gate | PASS | 第一个 gate「点一张记忆卡，带进这一世」（`momen-v1-live-gate1.png`）；点第 1 张「师兄会在第3波背刺」后剧情继续，经过“师兄由 AI 驱动 / 我记得”，停在第二个 gate「点【突破】」（`momen-v1-live-gate2.png`）。 |

备注：
- 点非第 1 张卡只弹 toast 不前进，这是设计（`director.gd` `_pick_card`），首次自动化点错卡时误以为卡住，UX 上 toast 可能不够醒目，可作为后续打磨项，不算失败。
- 未测：手机真机/触屏、Haiku 真 key 对话、Win/mac 桌面包、用户验收。
- 评审修复（`GS.wipe` 剧情状态、`tuna_auto` 重复购买、掉落计时器、测试存档隔离、CTA 帧）在线上**未修复**，等修复 PR 合并后复测。
