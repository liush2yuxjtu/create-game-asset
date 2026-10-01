# 刀光试作 01 · v0.1

一版可运行的独立代码特效，以《一念逍遥》官方「修罗斩 2.0」为参考目标。

**这是原创动作提案，不是已经完成逐帧对标的复刻。** 本轮没有重新取得官方 GIF 的完整字节，因此不声称视觉相似度、官方施法时序或当前游戏版本一致性。官方素材与代码试作在界面中分区展示。

## 直接运行

使用普通支持 JavaScript 的桌面浏览器打开 `index.html`。代码效果不依赖网络、npm、第三方库或贴图。当前 ChatGPT 执行环境的浏览器策略阻止了 `file://` 导航，自动测试使用真实 Chromium 内存加载同一份 HTML；这不代表测试过你的本机文件打开环境。

也可以在本文件夹启动本地服务，再访问 `http://localhost:8000`：

```sh
python3 -m http.server 8000
```

官方 GIF 需要联网访问 TapTap CDN。加载失败会明确显示“原图未载入”，不会拿新试作冒充官方原图。官方 GIF 独立循环，**不与代码试作的时间轴同步**。

## 已实现

播放／暂停／重放，0.25×、0.5×、1×、1.5×速度，逐帧步进和拖动时间轴；刀光、笔触、冲击环、粒子四图层开关；三种背景、落点开关、强度调整；透明 PNG 与 4×4 序列图导出。手机宽度下采用单栏布局，并支持减少动态效果偏好。

动画参数为试作自行编排：起势 0–0.34 秒，出锋 0.34–0.80 秒，消散 0.80–1.68 秒。没有将这些参数标为官方数据。Canvas 以曲线、程序化笔触和确定性粒子绘制；没有把参考 GIF 贴在画布上冒充代码实现。

## 文件

- `index.html`：独立可运行的全部 HTML/CSS/JavaScript。
- `preview.gif`、`preview.mp4`：代码样件的动画预览；30fps采样并添加约0.36秒末帧停留便于查看，**不是官方动画**。
- `assets/slash-transparent.png`：1200×720透明单帧。
- `assets/slash-spritesheet-4x4.png`：1536×1536透明序列图，16格，每格384×384，行优先排列。采样映射见HTML中的 `sheetCanvas`。
- `sources.json`、`raw-links.txt`：官方原帖、三个原始GIF URL、来源边界。
- `evidence/verification.json`：32项浏览器行为／导出／移动端检查结果。
- `evidence/desktop.png`、`evidence/mobile.png`：真实浏览器截图。
- `verify.py`：可重跑的浏览器测试脚本。依赖 Python、Pillow、Playwright，以及 `/usr/bin/chromium`；其他环境请将该路径改为已安装的浏览器可执行文件。
- `manifest.json`：交付文件大小及SHA-256。

```sh
python3 -m pip install pillow playwright
python3 verify.py
```

## 官方出处

小师妹 / 策划来信 / 2022-12-17：
https://www.taptap.cn/moment/353176070301681776

火咒术2.0：
https://img2.tapimg.com/bbcode/images/df3b27e20e0026d9a5e80f21c2f851a1.gif

修罗斩2.0：
https://img2.tapimg.com/bbcode/images/7c97b703ab6ac1bf3f2d19f37809d9a0.gif

殇阳剑阵2.0：
https://img2.tapimg.com/bbcode/images/0e5eab78dd91970569af779bc401dbd4.gif

2022年的官方美术演示不是2026年当前版本证明。GIF编码播放时长不等于游戏内施法时长。原始GIF没有打包分发；版权归原权利人，交付包仅保留链接。

## 验证与交付边界

32/32项本地真实Chromium检查通过。范围是代码渲染、控件行为、变速比、末帧清空、图层效果、透明导出及390/768px布局；参考加载失败路径采用测试模拟断网检查，不是官方GIF实际播放验证。

尚未完成：官方原始动画本轮播放、逐帧轨迹与颜色对照、用户美术验收、Godot/Unity/UE接入、角色绑定、碰撞／伤害及目标设备性能验收。未创建公开部署；Airtable记录的是原始URL和这次交付的文件索引，不是可持久访问的线上运行环境。
