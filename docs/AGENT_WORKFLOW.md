# Agent 任务 Router

本文只回答“这个任务接下来读什么”。共同边界见根目录 `AGENTS.md`，资源命名见 `assets/README.md`。

| 任务 | 必读 | 通常修改 |
| --- | --- | --- |
| 只接卡图 | `assets/README.md` 卡面段落 | `assets/cards/<card_id>_loading.jpg/png/webp` |
| 普通近战模型 | `ART_PIPELINE.md` → `MELEE_3D_INTEGRATION.md` → `UNIT_DEPLOYMENT.md` | `source/`、`<id>_view.tscn`、CardDB 表现字段 |
| 普通远程模型 | 普通近战路径，再读 `RANGED_3D_INTEGRATION.md` | 另核对离弦、弹体类型/高度/速度 |
| 建筑 | `ART_PIPELINE.md`、`assets/README.md` | 包装场景与 CardDB；动画不驱动权威死亡 |
| 特殊角色素材 | 通用文档 + 角色目录 README / `docs/art-special-cases/` | 角色专属包装或过滤脚本 |
| 新普通卡牌 | `CARD_DESIGN.md`；有素材再走美术路径 | CardDB + 素材；通常不改 Unit/Main |
| 新玩法机制 | `CARD_DESIGN.md`、`DEV_PLAN.md`、相关 battle 模块与测试 | SpellSystem / ActiveSkillEffectSystem + 字段/validator + 必要网络 + 领域回归 |
| 联机/快照 | `DEV_PLAN.md`、`network_snapshot_system.gd`、main RPC | 保持主机权威与载荷含义 |

## 普通新卡最短路径

1. 选择稳定英文 `snake_case` `card_id`。
2. 在 CardDB 添加数据，优先复用已有机制字段。
3. 完整 mechanics 自动执行 `CardDB.validate_all()`。
4. 卡面按 `<card_id>_loading.*` 放入 `assets/cards/`，无需登记。
5. 模型放 `assets/units/<card_id>/source/`；包装场景为 `<card_id>_view.tscn`；在 CardDB 配 `visual_scene_path(s)` 和 `visual_animations`。
6. 跑完整回归并目视验收。

只有现有字段无法表达玩法时才扩展通用系统：权威规则 → 可复用机制 → CardDB 字段 → validator → 必要 Snapshot/RPC → 领域测试 → 文档。不要写角色名分支或英雄 Unit 子类。

新增法术必须声明已有 `spell_kind`，执行位于 `scripts/battle/spell_system.gd`；新增主动效果位于 `scripts/battle/active_skill_effect_system.gd`。普通内容自动进入通用场景/动画/卡面契约测试，只有独特玩法或动画时序才新增卡牌专项测试。

交付前确认输出无 `SCRIPT ERROR`，CardDB/机制回归通过，项目能启动；联机改动完成 host/join 冒烟；美术完成双阵营、脚底、朝向和部署/待机/移动/攻击/死亡目视检查；diff 无无关数值、玩法或资产变化。
