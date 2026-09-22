# 青岚剑阵 V2

V2 是 Three.js / WebGL 2 可运行特效包。沿用 V1 主剑和六飞剑造型及 3.2 秒时序，增加程序化笔触剑气、法阵、墨化溶解、玉屑和冲击环。浏览器展示额外采用 UnrealBloomPass 泛光。

## 与 V1 的关系

V1 模型从用户已有的公开样件下载，保留原字节；未改动旧页面。V2 效果在独立运行时实现。GLB 单独打开仅显示原有结构动画，不含 V2 GLSL 或后期泛光。没有把《一念逍遥》素材提取进包；它只是项目历史风格参考。V1 概念图属于此前 AI 生成图，不随此包重分发。

## 本地运行

仓库根目录执行 `npm ci`、`npm run dev`。构建 `npm run build`，使用 `npm run preview` 查看构建结果。所有运行依赖随构建打包，无运行时 CDN 请求。打包需要 Python 3 和 zip：`npm run package:asset`。

## 引擎中立资产规格

一主剑、六飞剑；青玉 #7bcbb0、墨绿 #101d19、旧金 #c2a364。Y 向上、XZ 地面，原点在阵心；沿用 V1 单位，接入游戏时确认米制比例。

| 状态 | 时间 | 行为 |
| --- | --- | --- |
| charge / 蓄势 | 0–1.1 s | 阵形与剑气显现 |
| slash / 斩击 | 1.1–1.8 s | 剑气旋转加速，冲击环扩张 |
| dissipate / 消散 | 1.8–3.2 s | 噪声侵蚀与透明度消退 |
| complete | 3.2 s | 所有效果不可见 |

`impact-cue` = 1.2 s，仅视觉时间点；没有伤害判定。状态可任意前后跳转，和播放历史无关。

## Three.js 接入

安装并固定 `three@0.170.0`，使用有依赖解析能力的构建工具。解压包包含 `runtime/` 和 `models/`：

```js
import { createQinglanVFX } from './runtime/qinglan-vfx.js';
const vfx = await createQinglanVFX({
  modelUrl: '/models/qinglan-v1-source.glb', quality: 'high'
});
scene.add(vfx.root);
vfx.update(0.8); // 或在游戏帧循环中传入技能已播放秒数
vfx.setLayer('ribbons', false);
vfx.setQuality('low');
// 销毁技能实例时释放 GPU 资源
vfx.dispose();
```

图层名：swords、sigil、ribbons、particles。`setPixelRatio` 应与 renderer 同步。设置同名图层后在下一帧调用 update。`update` 范围 0–3.2 秒，超范围截断，拒绝 NaN/Infinity。

宿主负责摄像机、灯光、后期和帧循环。建议 ACESFilmicToneMapping、exposure 1.1；UnrealBloomPass strength .65、radius .65、threshold .7。精细 640 粒子，轻量 220；浏览器样件分别限制像素比 1.75 与 1。这是配置，不是目标设备性能通过声明。

## 精灵图

`sprites/ink-burst-atlas.png` 为程序化 RGBA 冲击辅助纹理：512×512、4×4、每格 128×128、16 帧、20 fps、不循环，直通 alpha。坐标与帧顺序见 sprite-manifest.json。它不是完整剑阵的三维烘焙，也未用于浏览器的点粒子材质；供后续 Unity/UE 移植使用。

## 验收与剩余范围

时间轴测试覆盖边界、归零、消散末端、非法参数、前后跳转。真实浏览器验收见仓库 `docs/validation.md`。下载包内 manifest.json 记录内容 SHA-256。

仍待完成：确定 Unity/UE 及版本、参考视频、手机/PC、角色绑定、技能命中逻辑、实际投放尺寸与并发数、目标设备 WebGL/引擎性能。当前不能称为最终引擎成品或已获美术验收。
