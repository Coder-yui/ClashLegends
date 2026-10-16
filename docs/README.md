# 项目文档

了解单位、数值、动作和声音，从 **[单位与竞技场手册](units/README.md)** 开始。

理解整个游戏怎样组织，从 **[整体设计地图](MAINTENANCE_ARCHITECTURE.md#整体设计地图)** 开始：游戏循环 → 规则与代码边界 → 固定 Tick 阶段 → 状态所有者 → 扩展入口。当前仍待拆分的内容单列为候选工作，不与已实施结构混写。

## 使用与当前进度

| 想了解什么 | 阅读入口 |
| --- | --- |
| 单位、法术、建筑和地图 | [单位手册](units/README.md) · [逐卡覆盖核对](reference/UNIT_DOC_COVERAGE.md) |
| 如何看模型、试技能、听声音 | [开发工作台](DEVELOPMENT_WORKBENCH.md) |
| 已完成什么、还缺什么 | [当前开发状态](DEV_PLAN.md) |
| 声音的缺项 | [音频覆盖与缺项](AUDIO_CARD_MAP.md) |
| 伤害、吸血、持续效果怎样计算 | [数值规则](NUMERIC_SYSTEM.md) |

## 开发与维护

从 [任务导航](AGENT_WORKFLOW.md) 选择新卡、既有内容修改、通用机制、工具或其他工程任务，只读对应专题。代码入口见 [scripts](../scripts/README.md)，工具入口见 [tools](../tools/README.md)，验证方式见 [tests](../tests/README.md)。

## 文档职责与状态

| 资料 | 维护什么 | 当前入口 |
| --- | --- | --- |
| 整体设计与架构 | 游戏循环、依赖方向、状态所有者、扩展边界；明确未来拆分 | [维护架构](MAINTENANCE_ARCHITECTURE.md) |
| 开发路线与文件定位 | 按任务选择最少资料，定位运行代码和离线工具 | [任务导航](AGENT_WORKFLOW.md) · [scripts](../scripts/README.md) · [tools](../tools/README.md) |
| 玩法与规则 | 单位页写中文玩法；通用文档写机制，状态正文写规则、IMPLEMENTATION 写实际支持能力 | [单位手册](units/README.md) · [卡牌机制](CARD_DESIGN.md) · [状态现状](status/IMPLEMENTATION.md) |
| 精确技术契约 | 网络载荷、配置字段、事件等可核对的接口事实 | [参考索引](reference/README.md) |
| 当前进度与验证 | 已有能力、仍待工程工作和验收范围；命令及通过条件由测试手册维护 | [开发状态](DEV_PLAN.md) · [测试手册](../tests/README.md) |
| 本次结果与历史 | 每任务一份实际改动及证据；历史资料保留追溯用途 | [改动记录规则](AGENT_WORKFLOW.md#改动记录) · [归档](archive/README.md) |

设计地图说明当前系统怎样协作；精确规则链接其所有者，不在地图重复维护数值表。未来方案明确写为“候选/未实施”，历史报告不作为当前结构或验证证明。新增专题只在确有独立维护职责时建立，并接入现有导航。

## 文档如何维护

修改实现时同步核对相关说明，直接改正文，不在末尾叠加互相冲突的“新版补充”。文件存在、测试通过、目视通过和试听通过分别记录。

Agent 默认从 [AGENTS](../AGENTS.md) → [任务导航](AGENT_WORKFLOW.md) → 相关当前专题。历史归档、问题与交付记录只在追溯或用户指定时定向读取；问题档案不能一概视为过时。
