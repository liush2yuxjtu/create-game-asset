# games/

用 create-game-asset 流程做出的**完整小游戏**。每个游戏一个目录，每个版本一个子目录，旧版本保留不覆盖。

| 游戏 | 最新版本 | 引擎 | 浏览器试玩 | 说明 |
|---|---|---|---|---|
| [魔门人材](momen-rencai/) | [v1](momen-rencai/v1/) | Godot 4.4 | [Pages](https://liush2yuxjtu.github.io/create-game-asset/games/momen-rencai/v1/)（合并到 main 后生效） | GBA 像素竖屏挂机修仙 · 7 章 8 结局 · 记忆轮回 · Haiku 驱动角色 |

## 约定

- 源码：`games/<游戏>/<版本>/`（完整工程，可直接用引擎打开）。
- 浏览器版：`public/games/<游戏>/<版本>/`（引擎导出的 Web 包，随 Pages 发布）。
- 桌面安装包体积大（Windows ≈ 100 MB），不进仓库；放 GitHub Release `<游戏>-<版本>`，或由各版本 README 说明来源。
- 新版本：复制上一版目录为 `vN+1/` 再改，保留旧版本可对比、可回滚；在本表与游戏目录 README 里登记。
