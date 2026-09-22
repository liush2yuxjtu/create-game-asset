# 组件合同

|组件|参考依据|青岚适配|状态|
|---|---|---|---|
|状态条|g-cultivation/g-combat|秘境名、阶段、模拟气血|ready/casting/result，文本与meter同步|
|纸色说明窗|g-quest/g-realm-info|原生dialog、说明、进入操作|closed/open；Esc取消；焦点可返回|
|主操作|g-login/g-path|墨色矩形按钮|默认/焦点/disabled；最小44px|
|目标标记|g-target|圆形“靶”印与命名目标|仅为木人模拟，不复制角色头像|
|结果面板|g-growth|命中时间、模拟伤害、剩余气血、再练|完成/重试；无真实奖励|
|模式切换|我方新增|秘境演练/特效工作台|aria-pressed同步|
|调试阶段按钮|青岚原组件改进|蓄势/斩击/消散|视觉active与aria-pressed一致|

HUD不复制游戏底部六大系统导航，因为青岚没有对应功能；不放不可用的装饰入口。渲染失败阻止进入演练；WebGL上下文丢失停止播放且禁用释放。
