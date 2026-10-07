# 项目文档

了解单位、数值、动作和声音，从 **[单位与竞技场手册](units/README.md)** 开始。

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

## 文档如何维护

单位手册写当前玩法、数值与观看说明；通用文档写跨单位的规则和流程；技术参考保留实现契约；本次改动与验收写入任务唯一记录，规则见 [改动记录](AGENT_WORKFLOW.md#改动记录)。

修改实现时同步核对相关说明，直接改正文，不在末尾叠加互相冲突的“新版补充”。文件存在、测试通过、目视通过和试听通过分别记录。

Agent 默认从 [AGENTS](../AGENTS.md) → [任务导航](AGENT_WORKFLOW.md) → 相关当前专题。历史归档、问题与交付记录只在追溯或用户指定时定向读取；问题档案不能一概视为过时。
