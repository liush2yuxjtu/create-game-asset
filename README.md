# create-game-asset

An agent skill for production-oriented game asset creation.

## Pipeline

```
Intent
  ↓
Asset Specification
  ↓
Canonical Reference
  ↓
State Generation
  ↓
Visual QA
  ↓
Runtime Package
```

## 青岚剑阵 V2

本仓库同时包含 `create-game-asset` 技能与按该流程制作的青岚剑阵 V2 浏览器 VFX 样件。

- 保留 V1 主剑、六飞剑和 3.2 秒动画；源 GLB 未改动。
- 新增水墨法阵、分层笔触剑气、噪声溶解、冲击环、玉屑与后期泛光。
- 支持播放/暂停、循环、时间轴、阶段跳转、慢动作、图层开关及精细/轻量模式。
- 提供独立运行包、16 帧透明冲击纹理、状态规格和文件哈希。

```sh
npm ci
npm run dev
# 验证与构建
npm test
npm run package:asset
npm run build
npm run preview
```

- [V2 制作与接入说明](docs/qinglan-v2.md)
- [验证记录与未完成项](docs/validation.md)
- [资产规格](public/assets/qinglan/v2/asset-spec.json)
- [下载运行包](public/assets/qinglan/v2/qinglan-v2-runtime.zip)
- [原 V1 公开概念与结构预览](https://winbrain-qinglan-pitch.liushiyuxjtu.chatgpt.site/)

V2 着色器与后期必须使用运行时；源 GLB 本身仍是 V1 结构模型。Unity/UE、角色命中和真机性能尚待目标引擎及设备明确后验收。

## /verify 与交接

- [项目 AGENTS.md](AGENTS.md)：统一约定、完成条件及交接要求。
- [/verify 技能](.agents/skills/verify/SKILL.md)：机器检查与实际浏览器验收步骤。
- [当前交接](docs/handoff.md)：版本、发布方式与剩余范围。

执行 `npm run verify` 运行机器检查；结果写入 `verification/latest.json`。这不会自动把浏览器验收标为通过。公开发布由 GitHub Actions 先验证再部署，页面的 `build-info.json` 可核对实际源提交。

[打开 GitHub Pages 预览](https://liush2yuxjtu.github.io/create-game-asset/)

## 独立设计系统技能

已接入 [design-system](.agents/skills/design-system/SKILL.md)，上游为 [design-system-skill](https://github.com/liush2yuxjtu/design-system-skill)。它负责可追溯的视觉规则、设计变量、组件、屏幕和可选游戏/VFX合同；与现有 create-game-asset 技能配合。版本与文件指纹见 [skills.lock.json](skills.lock.json)。

## 俯瞰特效试验场

[打开 Playground](https://liush2yuxjtu.github.io/create-game-asset/playground/) · [设计合同](design.md) · [来源台账](public/playground/sources.json)

40个透明Canvas技能入口（36个既有变体、1个初版雨锋、3个原创空间研究），5种原创mock地形，落点/角色移动、时序采样与本地自包含JS插入。全仓库JS构建索引保留纸鹤、四项动作研究和青岚WebGL的独立运行入口。

本次参考天羽游戏《一念江湖》，不覆盖既有《一念逍遥》ynjh基线。没有分发游戏素材、没有实际命中或原游戏动态parity。新增JS接入合同、安全限制与复验命令见design.md。
