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
