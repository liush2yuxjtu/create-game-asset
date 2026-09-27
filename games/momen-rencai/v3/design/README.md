# v3 设计稿（Claude Design 画布导出）

这里是画布「魔门人材 v2 · 爆款视频设计稿（Hypit）」的源文件快照，和成片 v3 同一次提交：

| 文件 | 内容 |
|---|---|
| `Index.dc.html` | 目录 |
| `StoryStudio.dc.html` | **故事工作台**：L1 一句话 → L2 幕 → L3 节拍 → L4 画面四层联动，含口播开关、音色、口播稿与「字幕在口播里」校验、时长排法（按画面事件 / 按比例） |
| `Timeline.dc.html` | P3 · v3 的 Hypit 轨道（画面 / 字幕 / 口播 / 音效） |
| `Main.dc.html` · `Layout.dc.html` | P1 设计语言与管线 · P2 版式规格 |
| `Storyboard.dc.html` | 参考：旧版「他也记得」13 屏（静态） |
| `canvas.json` | 画板位置与标题 |

- **工作台保存的默认值 = 成片 v3**：`.agents/skills/verify/scripts/verify-hypit-video.py` 的 H 检查用 `.agents/skills/verify/scripts/render-story-studio.cjs` 按默认值无头渲染工作台，逐屏比对字幕、口播全文、时长与 `hypit/screens.json`。改了画布或改了成片，两边要一起改，否则 H 会 FAIL。
- 画板里的截图和字体是画布上传的资源（`/_blob/...`），离线打开这些 `.dc.html` 不会显示；要看效果请打开画布本身（claude.ai 上的私有 artifact，需要所有者分享）。
- `.dc.html` 是 Claude Design 的画板格式（HTML + `<x-dc>` 模板 + `DCLogic` 脚本），不是本仓库网页构建的一部分。
