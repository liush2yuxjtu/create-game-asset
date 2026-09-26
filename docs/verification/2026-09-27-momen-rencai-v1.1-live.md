# 魔门人材 v1.1 线上验收（2026-09-27）

- 目标：https://liush2yuxjtu.github.io/create-game-asset/games/momen-rencai/v1/
- 源码 SHA：`0929eb00a8b2820703aaaec3117aaf4e042c8854`（PR #7 合并提交）
- 环境：无头 Chromium（Playwright 1.56，SwiftShader WebGL），视口 540×960
- 命令：`python3 scripts/verify-game-web.py --url <目标> --local public/games/momen-rencai/v1 --sha 0929eb0…`

| 检查 | 结果 | 观察 |
|---|---|---|
| build-info sourceSha / dirty | PASS | 0929eb0 / false |
| index.html / js / wasm / pck 大小与已提交一致 | PASS | 5488 / 317142 / 43699190 / 2354016 |
| wasm MIME | PASS | application/wasm |
| 引擎启动（#status 加载层被移除） | PASS | |
| 标题画面非空白 | PASS | 截图 `evidence/2026-09-27-momen-rencai-v1.1/title.png`：标题与四个菜单按钮 |
| 首个按钮「新的一世」有反应 | PASS | `after-click.png`：进入第 100 世序幕，记忆卡与吐纳按钮出现 |
| 控制台 / 页面报错 | PASS | 无 |
| 反例：用旧 SHA 2b3910e 运行 | 按预期 FAIL | 说明脚本会拦截过期的部署 |

工程自测（本地，同一源码）：`--autotest` PASS（含第 4 节回归：清档、一次性升级、掉落计时器）、`--storytest` PASS、`verify_story.py` 8 结局可达。

NOT_RUN：通关级游玩（本次只到序幕）、手机真机触控与性能、Haiku 真 key、Windows/macOS 桌面包。美术和剧情是否满意由用户认可（PENDING）。
