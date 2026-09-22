# 原始来源与取舍

这些来源已读取原文件。新技能为独立编写的综合方案，没有整份复制第三方技能或其宣称的内部提示词。保留社区许可证便于后续审计；引用不表示官方认可。

| 来源 | 权威范围 | 本项目采用与舍弃 |
| --- | --- | --- |
| [Trystan-SA/claude-design-system-prompt](https://github.com/Trystan-SA/claude-design-system-prompt/blob/3c3ddb07d7aa3fef051d83608596470c95cfd8fe/codex/skills/design-system-extract.md) | 社区；仓库自称逆向整理，不视为 Anthropic 官方提示词；MIT | 按源代码提取真实值、缺口与不一致；不采用固定审美禁令 |
| [jiji262/claude-design-skill](https://github.com/jiji262/claude-design-skill/blob/35a20e5ada2c9e768d1bc094ce1ef3218f48684b/SKILL.md) | 社区；自称适配内部提示词，来源真实性未独立确认；MIT | 真实资产、渐进披露、真实浏览器验证；不采用强制三方案、反复询问或固定搜索次数 |
| [plugin87/ux-ui-agent-skills](https://github.com/plugin87/ux-ui-agent-skills/blob/f2e2f7fcc5cb9d99bbd8ec5e0d75cebb98e21e7e/.claude/skills/design-tokens/SKILL.md) | 社区实现；MIT | 分层 token 与别名校验；不将11色阶、4px网格和Major Third比例设为所有项目规则 |
| [Owl-Listener/designer-skills](https://github.com/Owl-Listener/designer-skills/blob/9a6930cf84a822eb458624bd11c61aac5bbdf224/design-systems/README.md) | 社区实现；MIT | 组件状态/API、语义别名、治理和迁移；规模按项目需要选择 |
| [rohitg00/awesome-claude-design](https://github.com/rohitg00/awesome-claude-design/blob/7f60ee56b9340f8c2671a08c2d8aab4037546a64/recipes/repo-to-design-system.md) | 社区整理；九章节是其recipe约定；MIT | 按代码取证、inferred标签、屏幕上下文；不采纳未经核实的90%准确率或token成本营销数字 |
| [google-labs-code/design.md](https://github.com/google-labs-code/design.md/blob/9bf8eae67128b6cc55ad9bf86665767deb4c11cd/docs/spec.md) | Google Labs发布的alpha格式规范；不是Anthropic规范；Apache-2.0 | 可选YAML token与正文理由分离；八类正文顺序。我们的inventory是附加格式，不声称通过完整规范验证 |
| [anthropics/skills](https://github.com/anthropics/skills/blob/34040c9c568585f6929bedeaad110ad08f079624/skills/frontend-design/SKILL.md) | Anthropic官方仓库公开技能；不是其内部系统提示词；Apache-2.0 | 以具体产品任务决定视觉方向、写作与设计审查；不复制其全文或将某种审美禁令普遍化 |

机器可读的版本、文件路径与哈希见 [sources.json](sources.json)。

## 这次纠正的归属

社区九章节 DESIGN.md 与 Google alpha 的八部分正文不是同一份规范。令牌三层组织和“基础→组件→屏幕”是通用/社区方法，不宣称存在一份官方 Claude 五层协议。所谓截图抽取不能证明交互、命中、引擎运行或性能。Godot/VFX合同为本项目新增扩展，不是从上述Web技能中提取出来的已实现能力。

## 来源复查

需要刷新时，先比较源仓库提交与本ledger，再读取相关文件。保留旧版本证据，更新有变化的设计决策；不要仅跟随README星数、宣传数字或二次摘要。
