# 魔门人材 v1.1 + CI 游戏门禁 线上验收（2026-09-27 北京时间）

- 目标：https://liush2yuxjtu.github.io/create-game-asset/games/momen-rencai/v1/
- 源码 SHA：`f35f64bd2580b66f7d4ee0b2fced64d419e2d494`（PR #11 合并提交）
- 部署：Pages workflow run 36265083829（main push）；轮询 `build-info.json` 约 5 分钟后出现目标 SHA
- 环境：云端无头 Chromium（Playwright 1.56，SwiftShader WebGL2），视口 540×960

## CI 门禁（首次在 GitHub runner 上运行）

PR #11 run 36264651666：Install Godot 4.4.1 → `npm run verify:games`：verify_story、import、`RESULT: STORYTEST PASS`、`RESULT: AUTOTEST PASS`、web-pack-in-sync PASS（runner 重导 pck 与提交逐字节一致）、index.html-fileSizes PASS。

## 浏览器（`scripts/verify-game-web.py --sha f35f64b…`）

| 检查 | 结果 | 观察 |
|---|---|---|
| build-info sourceSha / dirty | PASS | f35f64b / false |
| 四个导出文件 200 且大小与已提交一致 | PASS | 5488 / 317142 / 43699190 / 2355120（pck 为本次重导） |
| wasm MIME | PASS | application/wasm |
| 引擎启动 | PASS | 3.9 s |
| 标题非空白 / 首个按钮有反应 | PASS | `title.png`、`after-click.png`，已人工查看 |
| 控制台 / 页面报错 | PASS | 无 |
| 新手引导过第一个 gate（手动脚本） | PASS | `gate1.png`「点一张记忆卡」→ 点第 1 张「师兄会在第3波背刺」→ 剧情继续到第二个 gate「点【突破】」（`gate2.png`） |

NOT_RUN：通关级游玩、手机真机触控与性能、Haiku 真 key、Win/mac 桌面包；美术与剧情满意度待用户认可。
