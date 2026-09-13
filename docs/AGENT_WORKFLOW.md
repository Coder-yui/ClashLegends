# 协作任务导航

先检查 `git status --short --branch`，保留已有修改；共同边界见 [AGENTS](../AGENTS.md)。本页负责选择阅读路径，完整制作步骤只在 [新卡清单](NEW_CARD_CHECKLIST.md) 维护。

| 任务 | 必读 |
| --- | --- |
| 完整新卡 | [新卡清单](NEW_CARD_CHECKLIST.md)、[卡牌机制](CARD_DESIGN.md)，再按素材类型阅读 |
| 卡面 | [美术接入](ART_PIPELINE.md)、[素材目录](../assets/README.md) |
| 近战 / 远程模型 | [美术接入](ART_PIPELINE.md) → [近战](MELEE_3D_INTEGRATION.md) / [远程](RANGED_3D_INTEGRATION.md) → [部署](UNIT_DEPLOYMENT.md) |
| 建筑 / 特殊形态 | 通用美术说明 + [对应单位](units/README.md)动画页和素材目录 README |
| 地图 | [竞技场](units/arena.md)、[候选地图说明](../assets/arena/rift_arena/README.md) |
| 音频 | [音频流程](AUDIO_INTEGRATION.md)、对应单位音频页 |
| 工作台 | [工作台](DEVELOPMENT_WORKBENCH.md)、[测试手册](../tests/README.md) |
| 新机制 / 结构 / 联网 | [维护架构](MAINTENANCE_ARCHITECTURE.md)、[卡牌机制](CARD_DESIGN.md)、受影响专项说明及测试手册 |

常用素材提取、模型摄影、动作预览和声音试听先查 [工具索引](../tools/README.md)，运行代码职责见 [scripts 导航](../scripts/README.md)。

## 素材边界

`ClashLegends-promo-materials/` 是宣传目录，`待开发卡牌美术素材/` 是未立项素材队列。它们都不是 Godot 资源库，不得建立运行时引用；保留 `.gdignore`，清理误生成的 `.import`。

用户指定队列素材时，必须将选定文件及必要同组纹理/依赖**移动**到项目 `assets/`。确认目标可用、源文件已消失后，在素材记录写明“已移动”。不要复制后留在队列，也不要删除同包中其他待开发对象。外部共享原始库则只读提取，保留源包；两类来源不能混用处理方式。

## 文档与交付

- 单位手册面向不阅读代码的用户：总览直接列中文数值与规则，链接动画、音频和适用特效页，均能返回总索引。
- 蓝红版本合篇；独立形态分篇；冰鸟与蛋、大小纳尔、墓碑与小鬼双向链接。不得自动覆盖为字段或源码清单。
- 来源迁移与加工参数放素材记录；详细验收和已结束讨论放归档。缺素材、缺入口和未验收要分清。
- 核心回归、联网、美术目视、音频试听按 [测试手册](../tests/README.md) 和受影响范围执行。只接某个阶段就完成该阶段；完整新卡不能漏掉音频。
