# Godot 完整游戏验证手册（games/）

适用于 `games/<游戏>/<版本>/`（Godot 工程）和 `public/games/<游戏>/<版本>/`（Web 导出）。首个实例：魔门人材 v1（`games/momen-rencai/v1`）。

## A. 工程内自测（本地，需要 Godot 4.4.1）

在 `games/<游戏>/<版本>/` 下：

```bash
G=/path/to/Godot_v4.4.1-stable_linux.x86_64
$G --headless --path . --import                      # 首次或资源变更后
$G --headless --path . -- --autotest                 # 新手引导 gate、轮回、账本炼化、录屏时间轴、回归（§4）
$G --headless --path . -- --storytest                # 8 条结局路线回放 + UI 冒烟
python3 tools/verify_story.py                        # 穷举剧情，8 结局可达，写 data/story_routes.json
```

判定：输出行 `RESULT: AUTOTEST PASS` / `RESULT: STORYTEST PASS`，`verify_story.py` 每个结局都是 ✔。只看退出码不够：Godot 的 `SCRIPT ERROR` 可能不影响退出码，要 grep `ERROR`。

存档隔离：`--autotest/--storytest/--storydemo` 写 `user://momen_save_test.json`，不碰玩家存档。改到存档代码时，先放一份哨兵 `momen_save.json`，跑完两套自测对比 md5 不变。

改剧情：先 `python3 tools/build_story.py` 再 `verify_story.py`，最后 `--storytest`（它读取新的 `story_routes.json`）。

改视频（`video/render_viral.py` 或 `data/viral_script.json`）：重渲染后抽帧（`ffmpeg -ss <t> -frames:v 1`）逐镜头查看，并跑 `--autotest` 第 3 节，确认录屏模式时长仍与视频一致（±0.3 s）。

## B. Web 导出

```bash
$G --headless --path . --export-release "Web" <out>/index.html   # nothreads，不需要 COOP/COEP
```

复制到 `public/games/<游戏>/<版本>/`。通常只有 `index.pck` 和 `index.html`（其中的 fileSizes）会变；`index.wasm` 是引擎本体，引擎版本不变时它也不应变化，变了要查原因。

## C. 浏览器验收（本地预览与线上 Pages 各跑一次）

```bash
npm run build && npm run preview -- --port 4196 &
python3 scripts/verify-game-web.py --url http://127.0.0.1:4196/games/<游戏>/<版本>/ \
  --local public/games/<游戏>/<版本> --out verification/game-local
# 合并到 main、Pages 部署后：
python3 scripts/verify-game-web.py --url https://liush2yuxjtu.github.io/create-game-asset/games/<游戏>/<版本>/ \
  --local public/games/<游戏>/<版本> --sha <合并提交完整 SHA> --out verification/game-live
```

脚本检查：build-info 的 SHA 与 dirty 标记、四个文件 200 且大小与已提交文件一致、wasm MIME、引擎启动（Godot 的 `#status` 加载层被移除）、标题画面不是空白、点第一个菜单按钮后画面变化、控制台无报错。最后输出 `RUNTIME PASS/FAIL/BLOCKED`（退出码 0/1/2）。验证机自己的网络中断（下载不完整、`net::ERR_*`）会先重试，仍失败则判 BLOCKED：这时重跑即可，不要当成站点 FAIL 上报。报告写到 `report.json`，截图为 `title.png` 和 `after-click.png`。**必须打开截图看一眼**：像素变化只能证明画面有反应，不能证明内容正确。

Pages 部署后生效需要 1–3 分钟。先轮询 `build-info.json?t=<随机数>`，等到目标 SHA 出现再跑；不要拿缓存里的旧 SHA 判 FAIL。

## D. 证据边界

- 脚本 PASS 只是冒烟测试。可玩性、手机真机触控与性能、Haiku 真 key 下的台词、Windows/macOS 桌面包都要单独记录；没做就写 NOT_RUN。
- 美术或剧情是否满意由用户认可，不属于技术 PASS。
- 历史 PASS 只对当时记录的 SHA 有效。

## E. 推送受阻时（云端会话无仓库写权限）

这不属于验证，只是为了让被验证的提交能到达 main：把增量提交打成 git bundle（`origin/main..<分支>`），经临时中转（例如 litterbox，24 小时后失效）交给带用户 gh 登录的机器（Mac mini），在那台机器上核对 sha256、在新目录克隆、fetch bundle、推送并开 PR，完成后清理临时文件。

- 只中转本来就要公开进仓库的内容。
- 远端已有同名分支时，先确认它的内容再推；不要 force-push。
