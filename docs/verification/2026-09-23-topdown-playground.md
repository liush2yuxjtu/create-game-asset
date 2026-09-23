# 2026-09-23 · 俯瞰特效试验场

## 范围与来源

新增 `/playground/`。候选基线 `1ea604298937e31b636eb0f5dc62ebaf84ff071e`，本地生产构建包含本次未提交修改；不是已发布SHA的证据。既有青岚、GLB、纸鹤、36式渲染源码未改动。来源台账保留12项公开资料及排除项；一念江湖与一念逍遥明确分开。

## Fresh local runtime evidence

环境：Linux / Chromium（Playwright 1.63.0），1440×1040，DPR1；窄视口390×844。目标 `http://127.0.0.1:4196/playground/`。

- `npm run verify`：PASS，19项Node测试；原GLB、V2运行包与3.2秒合同完整性PASS；设计技能25个文件哈希不变。
- `scripts/verify-playground.py`：PASS，245项实际浏览器断言，40个技能逐项采样。
- 所有40项在20/49/80%实际像素非空、阶段有变化，100%回到0%宿主背景，倒退49%像素一致。
- 五种fixture画面各不相同；点击落点、键盘移动角色、缩放/旋转、网格/角色/技能开关均改变真实像素。
- 有效自包含JS在隔离Worker产生真实像素；首尾清空。无效合同、>64KB、无限循环绘制均被拒绝/终止，宿主恢复可用。
- 完整连续播放保存13张连续帧与时间；非循环结束、循环回绕、暂停像素稳定、0.25倍时钟检查PASS。
- 搜索空状态、门类过滤、URL参数重载、390px无横向溢出PASS。54个public JS实际HTTP获取通过；全部索引59项（其余为src仓库链接）。
- 旧运行ZIP可访问；应用console/pageerror为0。

运行生成：`verification/playground-local/report.json`、`desktop.png`、`mobile.png`、逐项关键帧、五fixture图和`continuous-*.png`。此目录忽略于Git；GitHub Actions对每个PR/main候选重跑并上传`playground-browser-evidence`，形成可下载、与具体SHA绑定的证据。不是以本记录的数字替代将来的运行结果。

## 发布规则

本文件写入时公共页面验收仍为NOT_RUN。合并后必须读取实际Pages build-info并重复执行同一浏览器脚本；发布结论记录在PR评论及其运行附件/工作流中，不借后续文档提交冒充旧版本测试。

## 分开记录的边界

- 原游戏动态parity：NOT_RUN（视频元数据已读，未播放完整原片）。
- 原图观察：地图两张、火鸟静态图一张；冰鸟原图读取失败。
- 用户美术批准：PENDING。
- 引擎命中、物理、寻路、真机性能、恶意JS安全认证：NOT_RUN。
- Vite大于500kB的既有WebGL bundle警告仍在；不是新试验场错误，也没有性能PASS。
