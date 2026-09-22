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
