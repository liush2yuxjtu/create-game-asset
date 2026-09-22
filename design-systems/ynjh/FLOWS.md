# 流程合同

**参考流程全部为 inferred**：仅由截图中的入口、相邻状态和可见任务文案建立；未实际点击游戏。因此箭头代表有依据的候选连接，不代表实玩录像。没有冒充GAMEUI提供了流程标注。

1. F-entry：login → servers → identity → character → appearance → story。区服选择、开局选择、角色选择均有独立屏幕；是否每一步必经未知，取消/返回路径未知。
2. F-cultivate：quest → path → cultivation → growth → breakthrough。738719任务文案要求前往洞府修炼并突破；738722有炼体/修法选项；738724–726展示修炼、增量与突破入口。点击后的数值规则和失败状态未知。
3. F-realm：quest-realm → world → realm-info → realm-map → combat → target。738732明确前往野狼谷收集妖丹；738733/734为地图与野狼谷说明，738735–737为场景内标记及目标指示。奖励领取未观察。
4. F-appearance：character → appearance → character。左右箭头、类别圆钮、默认与随机可见；返回边为推断，未确认入口位置与保存规则。

## 青岚已实现的适配流程

Q-prep → 查看秘境 → Q-info → 进入试剑境 → Q-battle(ready) → 释放 → charge → slash → visual cue@1.20s → dissipate → Q-result@3.20s。

- Q-info：Esc或关闭按钮回准备；原生dialog管理焦点。
- Q-battle：返回准备取消演练并复原；按钮只允许从ready释放。
- Q-result：再练一次回ready（满模拟气血），或返回准备。
- 切换工作台暂停演练；重新进入秘境模式回准备。
- 隐藏页面中断施放，返回ready，避免恢复时突然结算。
- 时间轴采样确定性；命中后的模拟气血固定64，不随重复采样叠加扣血。

以上是我们新增的演练交互，不宣称与原游戏完全相同。参考系统的作用是约束信息层级与流程上下文，青岚自己的3.2秒时序保持不变。
