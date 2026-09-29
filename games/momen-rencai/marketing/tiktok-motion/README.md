# 魔门人材 · TikTok / 抖音 竖屏动效短片（Remotion）

1080×1920 · 30fps。纯代码动效 + 本地合成原创配乐（numpy），无第三方素材、无付费生成。

| 版本 | Composition | 时长 | 内容 |
|---|---|---|---|
| v1 | `MomenRencai` | 21.0s | 纯动效；按早期 v1 设定（7 章 / 8 结局 / 第 37 次） |
| **v2（投放用）** | `MomenRencaiV2` | 21.5s | 动效 + v2「忆」实机画面（`v3/hypit/assets/footage/gameplay_clean.mp4`）；口径对齐当前游戏：第 99 世、死前只能带一段记忆、5 章 17 层、4 结局 |

## 动效参考（motionface.cc 广场公开的 Remotion 复刻仓库，只借运动思路，代码重写）
| 段落 | 参考 | 借用的运动结构 |
|---|---|---|
| 钩子 / 反转 | [pinterest-focus](https://github.com/guangjun5952/motionface-pinterest-focus) | 硬切、错峰挤压大字、超画幅数字、巨型字挤满画面 |
| 记忆环（v1） | pinterest-focus 文字环 | 相邻环反向旋转、错相位 |
| 放大镜 | [eagle-lens](https://github.com/guangjun5952/motionface-eagle-lens-20260922) | 模糊场 + 镜内清晰层 + 按节拍跳点 |
| 章节画廊（v1）/ 实机手机框（v2） | [six-card-gallery](https://github.com/guangjun5952/motionface-six-card-gallery) v2 | 分段线性关键帧 × 高斯卷积 → 位置与速度连续的运镜 |
| 分支收束、像素标题、首尾循环 | 原创 | 流程图自绘；末帧「你」接回开头 |

## v2 时间轴（120BPM，每拍 15 帧，所有切点落在拍上）
| 帧 | 段落 | 画面 |
|---|---|---|
| 0–60 | 钩子 | 「你已经死了」+ 计数滚到 99 |
| 60–120 | 反转 | 「但这一次」→ 巨字「你 记 得」·「死前 只能带走一段记忆」 |
| 120–225 | 实机 1 | 背刺 → 你死了 → 选记忆「袖口的朱砂」 |
| 225–330 | 放大镜 | 师兄/背刺/长老/药堂… → 落在「袖口的朱砂」 |
| 330–450 | 实机 2 | 第100世「似曾相识」→ 打开「忆」→ 层卡「师兄的命押在药堂」 |
| 450–525 | 分支收束 | 5 章 · 17 层 → 4 种结局 |
| 525–570 | 实机 3 | 「第一章 · 完」还有 2 层没被看见 |
| 570–645 | 标题 | 像素飞入「魔门人材」+「你会带哪段记忆 进下一世？」→ 末帧回到开头 |

## 运行
```bash
npm i
npm run assets     # 生成像素标题点阵 src/pixtext.json，并拷入实机素材
npm run audio      # → out/score.wav、out/score-v2.wav
npm run stills     # 关键帧预览（COMP=MomenRencaiV2 npm run stills 看 v2）
npm run render:v2  # → out/MomenRencaiV2-silent.mp4
ffmpeg -i out/MomenRencaiV2-silent.mp4 -i out/score-v2.wav -map 0:v -map 1:a -c:v copy -c:a aac -shortest final.mp4
```
注意必须 `-map 0:v -map 1:a`：Remotion 输出自带一条静音音轨，不指定会混出无声视频。
`render.mjs` 里的 `browserExecutable` 指向沙箱的 headless shell，本地运行时删掉该参数即可用 Remotion 自带浏览器。

改文案 / 节奏：`src/Video.tsx`（`CUTS_V2`、`HOPS_V2`、各段 props）；动效实现：`src/Scenes.tsx`、`src/GameClip.tsx`。

## 验证（2026-09-29，云端沙箱）
- 1080×1920、30fps、21.5s，视频 + AAC 音轨；平均 -18.6 dB，峰值 -0.5 dB。
- 三轮关键帧拼图逐张检查，修正：卡片压字幕、流程图节点错位、段首空帧、实机片段起点与字幕不对应。
- 未验证：没有实时播放完整成片和试听；手机端 TikTok/抖音界面遮挡没有实测。
