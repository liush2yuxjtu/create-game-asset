# 刀光试作 v0.1 · Git 归档说明

本次只归档现有交付，不修改动作、界面或青岚资产。不自动合并、发布或部署。

## 两种存储范围

- **GitHub 草稿分支**：`archive/xiuluo-v0.1-20260923`，目录 `studies/xiuluo-v0.1/`。保存原始 HTML、README、测试脚本、历史验证 JSON、来源 JSON、raw links、完整交付哈希清单、本次完整性检查和本说明，共 9 个文本文件。
- **完整 Git 归档包**：本次会话的 `xiuluo-study-v0.1-full.bundle`。包含上述资料以及原创 GIF/MP4、透明 PNG、序列图、两张截图与原始 ZIP；可用 `git clone xiuluo-study-v0.1-full.bundle xiuluo-archive` 还原。
- **二进制远端状态**：原创 GIF/MP4/PNG 和原始 ZIP 本轮未上传到 GitHub；其原始字节在完整 Git 包中，GitHub 的 `manifest.json` 记录文件哈希。不要把哈希清单称为二进制文件已经入库。
- **第三方素材**：只记录官方原帖及原始 GIF URL，没有打包第三方 GIF、模型或贴图。

## 冻结版本

原始入口 `index.html` SHA-256：
`7161333eb3c89fbc065cb1701dbae95b2b3d6c91a0de3045149f844191355901`

原始交付包 `distribution/xiuluo-study-v1.zip` SHA-256：
`f0110d369bff3f199ce65d88de8ad860b6dc463eb984a850f36687aa27e3404f`

归档从已交付 ZIP 解出 13 个文件。`manifest.json` 中的 12 项内容全部通过大小及 SHA-256 核对；另外核对了 5 个会话附件与包内对应内容的一致性。原始 HTML 与已有测试报告未修改。

## 验证边界

`evidence/verification.json` 是原交付时的 32 项浏览器检查，不是本次重新运行的结果。本次只检查归档完整性和 Git 对象；没有重跑 Chromium、整个仓库的 npm 验证、官方 GIF 播放或动态相似度验证。

当前仍为原创代码动作提案，`reference_playback` 和 `visual_parity` 未验证；引擎接入、真实伤害和用户美术验收未完成。2022 年官方演示不等于当前版本。

## 下一步

先完整播放官方修罗斩 GIF，再对照形态、方向、运动轨迹、峰值和消散；保留参考与原创实现的区分。完整媒体需要远端归档时，使用完整 Git 包中的原字节，在核对清单后另行提交，不用重新生成的文件替换历史证据。
