# 项目文档

了解单位、数值、动作和声音，从 **[单位与竞技场手册](units/README.md)** 开始。

## 使用与当前进度

| 想了解什么 | 阅读入口 |
| --- | --- |
| 单位、法术、建筑和地图 | [单位手册](units/README.md) |
| 如何看模型、试技能、听声音 | [开发工作台](DEVELOPMENT_WORKBENCH.md) |
| 已完成什么、还缺什么 | [当前开发状态](DEV_PLAN.md) |
| 声音的缺项 | [音频覆盖与缺项](AUDIO_CARD_MAP.md) |
| 伤害、吸血、持续效果怎样计算 | [数值规则](NUMERIC_SYSTEM.md) |

## 开发与维护

| 任务 | 阅读入口 |
| --- | --- |
| 新增卡牌或接入素材 | [新卡清单](NEW_CARD_CHECKLIST.md)；协作者先看 [任务导航](AGENT_WORKFLOW.md) |
| 模型、卡面与地图 | [美术接入](ART_PIPELINE.md) → [近战模型](MELEE_3D_INTEGRATION.md) / [远程差异](RANGED_3D_INTEGRATION.md) |
| 部署与动画时序 | [部署规则](UNIT_DEPLOYMENT.md)、[动画系统](ANIMATION_STATE_SYSTEM.md) |
| 获取与接入音频 | [音频流程](AUDIO_INTEGRATION.md) |
| 控制、增益、减益与特殊状态设计 | [状态与效果规则](status/README.md)（区分已实现、确定未实现与待定） |
| 修改玩法或项目结构 | [卡牌机制](CARD_DESIGN.md)、[维护架构](MAINTENANCE_ARCHITECTURE.md)、[移动与接触](BATTLE_CONTACT_MODEL.md) |
| 查开发细节、跑验证 | [技术参考](reference/README.md)、[测试手册](../tests/README.md) |
| 查旧讨论与验收证据 | [历史归档](archive/README.md) |

## 文档如何维护

单位手册写当前玩法、数值与观看说明；通用文档写跨单位的规则和流程；技术参考保留实现契约；历史讨论和当次验收留在归档。

修改实现时同步核对相关说明，直接改正文，不在末尾叠加互相冲突的“新版补充”。文件存在、测试通过、目视通过和试听通过分别记录。

Agent 默认从 [AGENTS](../AGENTS.md) → [任务导航](AGENT_WORKFLOW.md) → 相关当前专题。历史归档、问题与交付记录只在追溯或用户指定时定向读取；问题档案不能一概视为过时。
