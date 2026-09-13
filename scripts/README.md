# 游戏运行代码导航

返回 [项目入口](../README.md)。离线提取、转换、摄影与试听工具在 [tools](../tools/README.md)；这里仅放游戏运行和工作台代码。

| 位置 | 职责与复用方式 |
| --- | --- |
| `main.gd` | 比赛生命周期和编排；新机制优先放对应领域 |
| `battle/` | 固定时钟、规则、移动、攻击时间线、弹体、快照和战场服务 |
| `unit.gd`、`tower.gd` | 通用战斗实体；普通新卡复用 Unit，不另建英雄子类 |
| `data/` | 卡牌定义、注册、字段校验；每卡按 gameplay / visual / card_art / audio 分域 |
| `presentation/` | 只读权威状态的模型、动画、特效表现 |
| `audio/` | 只读表现事件的音频播放与共用播放器创建 |
| `ui/` | 主界面、备战和开发工作台 |
| `ui/workbench/` | 工作台内的模型预览等组件；独立摄影展台复用 `model_preview.gd` |

新增卡牌先读 [新卡清单](../docs/NEW_CARD_CHECKLIST.md)；结构修改读 [维护架构](../docs/MAINTENANCE_ARCHITECTURE.md)。共享组件留在所属领域，离线工具通过公开入口复用，避免复制整套摄影棚或把工具逻辑塞入 Main。
