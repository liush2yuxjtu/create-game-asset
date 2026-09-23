# 江湖三十六式运行验收

Runtime verdict: PASS — 范围为36项实际渲染、四阶段采样、末帧清空、目录选择与控制继承；不是最终美术、逐招完整连续录像或引擎验收。

候选：2b75a84（采样工作树与该提交运行源一致，提交后重建重载复核）。目标：本机生产预览 `http://127.0.0.1:4193/asset-lab/`。工具：Codex in-app browser / cua_repl，桌面1030宽与390×844窄屏。

## 操作与证据

- 36个独立JS模块全部进入catalog，DOM有36个目录按钮、38个Canvas（含A/B）。零warn/error捕获。
- 逐个用“预览 A 技能”选择v01–v36；通过可见“精确进度 %”输入20、49、80、100并点击采样：保存144张真实浏览器截图。
- 测量实际画布区域再裁切：36项活跃画面全部非空，四阶段截图每项均不同；49%进度的36张画布哈希各不相同。此处不同像素不等于美术质量认证。
- 最初包含卡片边框的末帧裁切出现两种哈希；定位到边缘后收紧到画布内部，36项末帧RGB全部一致，只剩宿主背景。不是重写效果来掩盖差异。
- 目录12门类中“逆向生长”显示3项；无结果查找显示0/36，清空后恢复结果。一次自动化fill空串未清空输入，改用实际全选/退格后成功，不记为筛选故障。点击鹿角卡片载入A。
- 全局隐藏两项；给v26单独显示与朱砂覆盖，切到v11再回v26、刷新：v26恢复两项覆盖且可见，B继续继承隐藏。重置恢复默认。
- 七层开关在56%活跃时刻分别开关并保存前后截图。模块通用包装消费图层选项，主体与墨笔独立，关闭主体不意味着关闭墨笔。
- 惊喜配对实际载入蝶书千结与月缺还圆并播放；24次连续页面状态/截图记录中，A从3.24到4.50，再跨周期到0.34，B持续推进。36招完整时长的实时录像未逐项录制；四阶段覆盖与这段实际连续播放分开陈述。
- 390宽实际文档375，无横向溢出；截图可见两项预览与控件；检查后恢复视口。
- 11项机器测试通过：含36模块/清单一致、216个阶段的有限几何与确定性、画布save/restore平衡、隐藏/零强度/起止无绘制、资产ID配置持久性；原青岚完整性与生产构建通过。保留既有大于500KB打包警告。

原始证据在本次任务交付目录 `outputs/jianghu-36/`：`vNN-{20,49,80,100}.png`、`catalog-full.png`、`browser-pixel-checks.json`、`live-playback.json`与24张live-pair截图、override-persists、mobile-catalog、各图层截图。视觉检查覆盖全部36目录缩略图及阶段抽样；不对每一帧美术质量做未经观察的承诺。

## 边界与清理

12种共享绘制机制 × 3种结构/动作变体；36个模块依赖共享引擎，不是36个复制的独立渲染器。均为原创程序化2D动作样件。图形细节、叙事动作的保真、参考parity、美术批准、Godot、游戏命中、真机性能仍待验。没有生成新AI静态原图或复制第三方GIF。

保留用户预览标签与4193服务；恢复测试视口。目录选择及控制保存本机，无Airtable新选择记录。旧crane.js及雨锋初版未修改。公共Pages未在此报告验收。

## Ship review follow-up

PR #4 review identified two host-contract defects: omitted catalog metadata in the
integration example, and a successful-save notice overriding a storage failure.
The catalog metadata is now documented and validated before clocks initialize;
persistence reports success only after both writes succeed. New regression tests
cover missing metadata/non-finite preview times and first/second storage-write
failures. All 13 tests pass. These changes do not alter asset drawing algorithms.
Public release verification remains a separate post-merge check.
