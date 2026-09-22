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

- 公开 Pages 已部署并实际打开：`9b4d7c1e517ef5e7c08fd2cf35335a16282d9b20`。
- [公开页面验证报告](verification/2026-09-22-pages.md)：机器检查、部署、浏览器操作范围、线上 ZIP 哈希及未测项。
- 本交接/报告的后续文档提交不改变已验证的 VFX 代码。查看最新版 Pages 时仍应读取 `build-info.json`，不要推断线上一定等于本地 HEAD。
