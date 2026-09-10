# Agent 任务 Router

本文只回答“这个任务接下来读什么”。共同边界见根目录 `AGENTS.md`，资源命名见 `assets/README.md`。

## 项目外素材目录边界

- `ClashLegends-promo-materials/` 只存放宣传视频、截图、文稿和相关制作素材；它不是游戏资源库。不要在场景、脚本、CardDB 或其他项目文件中引用其中的文件。
- `待开发卡牌美术素材/` 是本地的“未立项卡牌素材队列”，不是 Godot 资源目录；队列中的素材不应被加载，也不应直接作为 `res://` 路径使用。
- 两个目录根部的 `.gdignore` 是有意保留的 Godot 忽略标记。素材目录内不应出现 Godot 生成的 `.import` sidecar；若发现旧 sidecar，应清理而不是把它加入版本库。

## 新卡素材必须“迁移”，不能“复制”

当用户说“从待开发卡牌美术素材拿某个素材制作新卡”时，按以下顺序执行：

1. 先在队列中定位用户指定的源文件，并确认它属于哪一张待开发卡；不要把整个队列当作可用资源扫描或批量接入。
2. 将源素材移动到项目 `assets/cards/`、`assets/units/<card_id>/source/` 或 `assets/audio/units/<card_id>/`。模型若依赖同组纹理/材质，也要一并迁移；必要时可在目标目录按项目命名规范重命名。音频需要解包/转换时，按 `AUDIO_INTEGRATION.md` 区分待开发队列迁移与外部原始素材库只读提取。
3. 先确认目标文件/依赖存在且能被 Godot 使用，再把 CardDB、场景和卡牌文档指向目标路径。
4. 最后检查源文件已不存在于 `待开发卡牌美术素材/`，并删除该目录中因误扫描产生的 `.import` sidecar。不能用“复制一份到 assets、原素材继续留在队列”的方式完成。

卡牌文档的美术素材段落应写明源文件从待开发队列移动到了哪里，并明确该素材已从队列移除。若源文件归属、依赖关系或目标卡不明确，先停在确认阶段，不要擅自复制或删除。

## 美术资源获取优先级

卡面按以下优先级准备：英雄先从 CommunityDragon 下载基础皮肤 Loading Screen；没有原生图但有模型时拍 3D 模型；图像和模型都没有时再用 AI 生成。最终文件放到 `assets/cards/<card_id>_loading.jpg/png/webp`，没有正式卡面时 UI 才显示数据色占位。

已有资源接入后，不应再用 3D 拍摄或 AI 生成结果覆盖它。

| 任务 | 必读 | 通常修改 |
| --- | --- | --- |
| 只接卡图 | `assets/README.md` 卡面段落 | `assets/cards/<card_id>_loading.jpg/png/webp` |
| 接入/替换音频 | `AUDIO_INTEGRATION.md`、`assets/README.md` 音频段落 | CardDB.audio、选定 WAV、事件清单；仅缺少通用事件时扩展音频/战斗系统 |
| 普通近战模型 | `ART_PIPELINE.md` → `MELEE_3D_INTEGRATION.md` → `UNIT_DEPLOYMENT.md` | `source/`、`<id>_view.tscn`、CardDB 表现字段 |
| 普通远程模型 | 普通近战路径，再读 `RANGED_3D_INTEGRATION.md` | 另核对离弦、弹体类型/高度/速度 |
| 建筑 | `ART_PIPELINE.md`、`assets/README.md` | 包装场景与 CardDB；动画不驱动权威死亡 |
| 竞技场地图 | `ART_PIPELINE.md`、`assets/arena/rift_arena/README.md`、同目录 `ART_DIRECTION.md` | Blender 源文件、GLB、地图材质；保持格子、河道、桥宽和塔位 |
| 特殊角色素材 | 通用文档 + 角色目录 README | 角色专属包装或过滤脚本 |
| 完整新卡牌 | `CARD_DESIGN.md` → 对应模型路径 → `assets/README.md` 卡面段落 → `AUDIO_INTEGRATION.md` | 按下方五阶段推进；缺项明确记录 |
| 新玩法机制 | `CARD_DESIGN.md`、`DEV_PLAN.md`、相关 battle 模块与测试 | SpellSystem / ActiveSkillEffectSystem + 字段/validator + 必要网络 + 领域回归 |
| 联机/快照 | `DEV_PLAN.md`、`network_snapshot_system.gd`、main RPC | 保持主机权威与载荷含义 |

## 完整新卡制作流程

1. **2D 权威逻辑**：选定稳定英文 `snake_case` card_id；按 `CARD_DESIGN.md` 在 CardDB 配数值、目标、普攻、被动及主动候选，优先复用机制。先验证生成、移动、伤害、技能资格、固定 Tick 时序与必要联网，不依赖模型或声音驱动逻辑。
2. **3D 模型与动画**：按对应近战/远程/建筑路径接入 `assets/units/<card_id>/source/`、包装场景及 CardDB 动画映射。确认真实动画名、攻击段顺序、技能 action 名和起止时序，目视双方阵营、脚底、朝向及动作。
3. **卡面**：按既定获取优先级归档到 `assets/cards/<card_id>_loading.*`，由 CardArt 自动发现；检查牌库、卡组、详情与手牌。若来自待开发队列，按迁移约定确认源文件消失。
4. **音频**：读 `AUDIO_INTEGRATION.md`；列出当前实际使用的动作/命中事件，选取、转换和归档相应音频，再配置 CardDB.audio。登记项目 cue → 原始事件 → 文件/变体与来源，不导入整套未使用技能音频，不让备战未携带的技能发声。
5. **联合验收与交付**：跑完整 mechanics（含 CardDB validator）；F5 实际观察并试听攻击、所选技能、命中和死亡。新增网络事件跑 host/join 冒烟；在 `docs/cards/<card_id>.md` 记录四阶段状态、素材来源/迁移、音频映射入口、测试结果与未完成项。

只做某个阶段的明确请求只执行该阶段，不擅自补建其他部分；完整新卡不能在接完卡面后跳过音频核对。素材缺失时可暂时静音，但必须记录“未接入/缺素材”及原因，不能用不相关技能音效或伪造静音资源充数。法术、无攻击建筑等没有适用模型/普攻时标明“不适用”；音频是否需扩展入口按专项文档判断。

只有现有字段无法表达玩法时才扩展通用系统：权威规则 → 可复用机制 → CardDB 字段 → validator → 必要 Snapshot/RPC → 领域测试 → 文档。不要写角色名分支或英雄 Unit 子类。

新增法术必须声明已有 `spell_kind`，执行位于 `scripts/battle/spell_system.gd`；新增主动效果位于 `scripts/battle/active_skill_effect_system.gd`。普通内容自动进入通用场景/动画/卡面契约测试，只有独特玩法或动画时序才新增卡牌专项测试。

交付前确认输出无 `SCRIPT ERROR`，CardDB/机制回归通过，项目能启动；联机改动完成 host/join 冒烟；美术完成双阵营、脚底、朝向和部署/待机/移动/攻击/死亡目视检查；音频完成素材可追溯、真实事件触发、去重/中断及实际试听检查；diff 无无关数值、玩法或资产变化。
