# 外部技能控制器 v1

入口：`/asset-lab/`。不改现有纸鹤或青岚；两个雨锋实例展示同一模块可以分别控制。

- `controller.js`：纯状态与参数校验，不操作DOM、不拥有动画时钟。
- `assets/rain-blades.js`：原创俯视技能，接收 `(context, time, options)`，只绘制当前时刻。
- `preview.js`：外部时钟、背景、UI、存储与JSON交换。

## 新资产接入合同

```js
export const myAsset = {
  id: 'unique-instance-id',
  name: '技能名称',
  duration: 4.2,
  supports: ['visible', 'body', 'particles', 'speed', 'motion'],
  draw(context, time, options) {
    if (!options.visible) return;
    // 使用所声明的绘图选项；背景与清屏由宿主负责。
    // 相同time/options必须产生相同画面，不累积上次播放状态。
  },
};
```

导入并加入preview.js的assets数组；实例id必须唯一。添加支持项前先在features注册类型、默认值、范围/枚举，然后在renderer或宿主实现对应行为。不能声明却不实现。当前speed/motion由宿主消费，其他项由雨锋renderer消费。不支持的单项控制不展示，也拒绝通过API覆盖。

最终值 = 单资产覆盖（包括false/0）或全局值。`setAsset(id,key,null)`取消该项覆盖；`clearAsset(id)`恢复整项继承；`reset()`重置所有实例及全局。全局visible是可被单项覆盖的默认值，不是强制总静音；预览“暂停”才停止整体时间推进。隐藏不停止时钟；motion=false冻结该实例，但seek仍显式设置时间。

当前14项：visible/body/sigil/trails/particles/glow/impact/ink/motion，speed/intensity/scale/density，以及palette。未来不同资产可声明子集。强度通过整体透明度（最多1）及柔光强度实现；超过1主要增强柔光。

配置JSON version=1，只包含全局值和实例覆盖。导入先在临时控制器完整校验，再整体替换，非法类型、范围、枚举、资产ID或能力拒绝且原状态不变。仅静态导入JS模块，不从JSON执行代码。localStorage保存到当前浏览器，无Airtable云同步。文件导入限制64KB。

播放是预览时钟，单帧delta上限0.1秒以避免卡顿跳跃；不是精确离线时钟或性能测试。失焦隐藏暂停。循环与重播由宿主管理，单资产可各有速度。引擎命中/设备性能未接入。
