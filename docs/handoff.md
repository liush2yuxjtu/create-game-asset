# 青岚剑阵 V2 — 项目交接

## 当前实现

同一仓库 `liush2yuxjtu/create-game-asset`。V2 首次实现提交 `82ec204cdb2ded15ca7f90c33f711371475df902`。原始结构 GLB 位于 `public/assets/qinglan/v1/`，V2 的材质、动画采样及控制面板位于 `src/`。

制作技能：`.agents/skills/create-game-asset/SKILL.md`。验证技能：`.agents/skills/verify/SKILL.md`（`/verify`）。根目录 `AGENTS.md` 是全项目交接约定；不另建多个技能副本。

## 验证入口

```sh
npm ci
npm run verify
npm run preview
```

`verification/latest.json` 只记录机器检查；浏览器默认 NOT_RUN，必须按技能完成真实交互并补充证据。`docs/validation.md` 保留首版本地浏览器验证。后续公开预览验证写入 `docs/verification/`，报告需含实际源提交与 URL。

## 公开预览发布方式

GitHub Pages 目标：<https://liush2yuxjtu.github.io/create-game-asset/>。

推送 main 触发 `.github/workflows/pages.yml`：先机器验证、检查生成资产可重现和工作树干净，再上传 `dist` 并部署。Pages 使用 GitHub Actions 发布。`build-info.json` 标识实际源提交；它必须与成功发布的 workflow SHA 一致。源码提交不会单独证明站点部署或交互通过。

运行包链接为页面下的 `assets/qinglan/v2/qinglan-v2-runtime.zip`。ZIP 内容由 Python 标准库按固定时间戳打包，重复验证不会因 ZIP 时间戳修改仓库。制作流程仍是 Intent → Asset → States → Validation → Runtime。

## 继续工作时

1. 检查 git status/fetch，读取资产规格和最近验证报告，不覆盖并发修改。
2. 修改源代码后重新生成资产包，运行 `/verify`；任何失败保留 FAIL/NOT_RUN。
3. 发布后读取实际 build-info、验证下载包和真实网页行为。
4. 更新本交接和相应报告；保留历史记录的版本边界。

## 剩余范围

目标游戏引擎/版本、参考技能视频、手机或 PC、释放并发量仍未确定。Unity/UE 材质移植、角色与命中、真机帧率和用户美术验收尚未完成。当前资产包不能标为最终游戏引擎交付，原始 GLB 不能冒充完整 V2 特效。

## 最近已验证发布

- 最新公开实现已部署并实际操作：`043e2b73648d2a0d113a66a53e10d36b09c902ed`，见 [YNJH公开验证报告](verification/2026-09-22-ynjh.md)。
- 历史V2公开实现：`9b4d7c1e517ef5e7c08fd2cf35335a16282d9b20`。
- [公开页面验证报告](verification/2026-09-22-pages.md)：机器检查、部署、浏览器操作范围、线上 ZIP 哈希及未测项。
- 本交接/报告的后续文档提交不改变已验证的 VFX 代码。查看最新版 Pages 时仍应读取 `build-info.json`，不要推断线上一定等于本地 HEAD。

## 独立 design-system 技能接入

已接入 `.agents/skills/design-system/`，来源 https://github.com/liush2yuxjtu/design-system-skill ，固定提交 `f6a01e1944983ce27b28611ff72e0b6714bd318b`。`skills.lock.json` 为逐文件校验真源，`scripts/verify-skill-sync.py` 已接入 npm run verify。用于后续设计系统提取、组件/屏幕/VFX合同工作；接入技能时尚无新战斗HUD；后续YNJH演练已实现，Godot runtime仍未实现。独立技能保留官方/社区来源区别与完整许可。

## 2026-09-22 一念逍遥系统应用

用户明确基线为一念逍遥；`design-systems/ynjh/`保存19个已观察静态样本和4条推断流程，`public/ynjh/`为原创建构示意与原图链接。青岚默认进入秘境演练；保留特效工作台模式。新增准备/说明/演练/结算，木人及模拟气血，纸色HUD、墨绿地台、空间安全区、阶段ARIA与44px控件。原始GLB和V2 runtime包保持原合同。

验收见 `docs/verification/2026-09-22-ynjh.md`。基线真实游戏跳转、全409图覆盖、Godot、真机、美术批准仍未验证。对比范围是布局/信息/流程适配，非原技能逐帧复刻。

下一步验收：真实参考游戏流程确认、用户美术反馈、目标引擎/设备确定后再做命中与性能验收。不要把模拟木人气血当作正式游戏逻辑。

## 2026-09-23 动态特效验证协议

用户收窄关注点为技能动态特效。`/verify`新增动态检查矩阵、参考片段证据流程和报告模板；参考来源在`.agents/skills/verify/references/yinian-vfx-sources.md`。Exa核验17173官方来源转载与TapTap历史玩家资料；视频候选未播放，动态对标仍NOT_RUN。下一步按协议录制青岚完整释放、实际观看基准片段，逐项对照运动/峰值/余韵；不扩展HUD。此轮不修改runtime或原始资产。

## 江湖十六念 · 候选评审

16张独立概念v1与纸鹤俯视v2位于public/jianghu-sixteen/images；完整提示词、SHA256、AI初筛及用户偏好分列于concepts.json。逐张评审页在同目录index.html，05/09/14/16附原创Canvas动作研究。正式选择存Airtable表“江湖十六念 · 概念评审”，当前全部待选择；网页本地选择不自动云同步。先让用户选，再制作对应成品动画，禁止把用户看好某招等同于生成图入选。参考3 GIF见docs/jianghu-sixteen/REFERENCES.md；只做画面取样，未完成逐帧对标。

### 江湖十六念俯视动画修订

最新方向：去掉山水大景，俯视、单个技能范围。新增 `public/jianghu-sixteen/animation.html`、`crane.js` 和 `animations/paper-cranes-v0.2.gif`。原16张概念图保留，05-v2单独增量。验证边界见 `docs/jianghu-sixteen/VERIFY.md`；没有发布或验收新的公共Pages。Airtable17项待用户选择，下一步按选择打磨，不把题材偏好标成生成图通过。

### 项目级 /verify 制作手册

新增 `.agents/skills/verify/references/procedural-2d-vfx.md`，由项目级SKILL.md加载。记录纸鹤JS形变/路径/时序/播放器制作方法、4193真实浏览器操作、倒退采样相邻探针、GIF截图裁切修复及发布边界。此次仅增补文档，runtime verdict为SKIP；历史原型验证仍以其记录的候选为准。用户已授权提交、推送及直接合并PR #3，不代表全部概念美术选择通过。

### 外部资产控制器

新增 `public/asset-lab/`：14项全局默认与单实例覆盖，未来JS通过supports/draw合同接入；当前两个听雨借锋实例用于对比。现有纸鹤与青岚不接入。配置保存在本机，可JSON交换；无Airtable同步。制作/接入说明见同目录README，实际验收见控制器报告。

### 江湖三十六式

`public/asset-lab/catalog.js` / `variants.json` 注册36个新变体，十二机制各三种；每项独立JS描述，共用variant-engine绘制层。/asset-lab/现支持目录、搜索、门类、A/B选择、惊喜配对和精确百分比采样。控制覆盖按资产ID保存，旧纸鹤与原双雨锋文件保留。尚未作为最终游戏美术批准，未接Godot/命中/真机性能。真实浏览器证据和逐项采样结论见36变体验收报告。

### PR #4 发布审查修复

目录预览接入字段由 `public/asset-lab/catalog-contract.js` 在初始化前校验，完整合同见README；`persistence.js`报告真实写入结果，保存失败不会再被导入成功提示覆盖。新增回归检查后13项测试通过。36式绘制算法未变；公开版本仍需发布后按build-info与浏览器实测确认。

### 2026-09-23 俯瞰特效试验场

新增`/playground/`及根`design.md`，40个兼容透明Canvas技能、5种原创mock地形、落点/施法者/旋转/缩放、源码图鉴、隔离本地JS插槽。原纸鹤、四动作研究、青岚WebGL与A/B控制器保持原入口。59项public/src JS由构建自动索引；不是59个技能。

本次参考**天羽游戏的一念江湖**，12项来源台账在`public/playground/sources.json`；既有ynjh仍为一念逍遥，未覆盖。三项空间研究的图形/时长均原创，不冒充原游戏动画。

本地19项机器测试和245项浏览器断言PASS，报告见`verification/2026-09-23-topdown-playground.md`。新增`scripts/verify-playground.py`；Pages工作流在PR/main执行真实浏览器门禁并上传证据。发布后必须重新核对live SHA并运行公开页面脚本。动态parity、用户美术、真实引擎及真机性能未验收。
