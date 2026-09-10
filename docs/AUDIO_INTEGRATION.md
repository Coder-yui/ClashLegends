# 卡牌音频接入流程

完整新卡顺序：2D 权威逻辑 → 3D 模型/动画 → 卡面 → 音频 → 联合验收。先读 `AGENT_WORKFLOW.md`；本手册用于音频阶段，不要求重读所有模型教程。

目标是让当前玩法实际用到的事件有合适、可追溯的声音，不是把英雄全部素材塞进项目。现有接入样例为 CardDB 的 `garen.audio` 与 `assets/audio/units/garen/README.md`。盖伦只是样例，不得将其事件名、技能数量或素材路径套到其他卡上。

## 1. 开始前与产出

1. 看 `git status --short --branch`，保留已有修改；读目标 `docs/cards/<card_id>.md`、CardDB 数值/动画/主动候选及当前素材目录。
2. 核对 `scripts/audio/game_audio_manager.gd`、CardDB 的 `AUDIO_FIELDS` / `_validate_audio_config()`；涉及新增真实命中事件时读对应 battle 模块及 Main RPC。代码与本文不一致时，先确认实际实现，不按过时字段盲配。
3. 产出：选定 WAV、CardDB.audio、音频目录 README 与 event_manifest.json、卡牌文档音频段落；必要的通用系统/validator/网络/测试扩展。普通素材接入不需要新英雄脚本。

## 2. 先列事件，再找素材

建立如下工作表，每个当前使用的动作都要有结论（接入 / 有意静音 / 缺素材 / 缺入口）：

| 当前动作/条件 | 项目 cue | 原始音效事件 | 文件/变体 | 触发与停止依据 |
| --- | --- | --- | --- | --- |
| 普攻第 1…N 段 | attack_swing 的第 1…N 池 | 对应出手事件 | 确认后的变体池 | 攻击序号变化 |
| 普攻真实命中 | attack_hit | 对应冲击事件 | 共享池 | 权威命中成功 |
| 已使用主动动作 | action:start / action:end / action:hit | 该技能真实事件 | 已确认的素材 | 见下一节，不能只按文件名推测 |
| 死亡 | death | 死亡事件 | 已确认的素材 | 视觉死亡信号 |

- 对齐 `visual_animations.attack` 顺序，不按 WAV 文件排序猜攻击段；区分动画名（如 Spell3_0）、项目 action 名（如 judgment）与原始事件名（如 Play_sfx_…）。
- 只配本项目实现的技能。多个主动候选要分别检查：可以共享打包所需素材，但运行时只能随所携带/实际触发的技能发声；不能因目录里有 Q/W/E/R 就全配全播。
- 无足音、部署音或对应技能素材时明确记录，不拿其他技能、暴击或台词代替。原始客户端事件名称只提供线索，不证明本项目存在该机制。

## 3. 当前通用事件契约与限制

当前音频入口挂接的是 `Unit`；Main 在本地生成和客户端生成时调用 `attach_unit(unit, stats)`。音频配置在挂接时复制。

| 配置位置 | 实际消费者/触发 | 注意事项 |
| --- | --- | --- |
| audio.attack_swing | GameAudioManager 读取攻击序号，按段选池 | 一段一个非空池，池数等于 visual_animations.attack 数量 |
| audio.attack_hit | Main._notify_attack_audio_hit → play_attack_hit | 普攻成功命中才触发；客户端经 _rpc_attack_audio_hit 重放，不用 first_hit 定时猜实际命中 |
| events.attack_launch | ProjectileSystem.launch 在权威弹体实际创建后通过 BattleContext 通知 Main | 远程离弦事件；无效目标/未生成弹体不发声，客户端经通用音频 RPC 重放 |
| events.empowered_ready | 可视强化准备状态 false → true | 这是状态观察，不是任意 buff 的通用 Cast Start；已准备时再次施放不保证重播 |
| events.empowered_swing | 强化攻击序号对应当前攻击 | 替代此次普通挥击；未配置时回退普通挥击；当前前摇被强化时也会触发，已播放短音尾音不会自动撤销 |
| events.death | Unit.died（notify_visual_death 去重） | 不等于 queue_free；不播放死亡表现的替身/复生分支不会自动有死亡声 |
| events.<action>:start | 新 visual_action 序号且剩余时长 > 0 | action 必须是 visual_animations.visual_actions 的键；0 时长动作不能仅靠此配置发声 |
| events.<action>:sustain | 随 action 起手启动的单位持有声音层 | 原片段单次播放，跟随单位、控制暂停/恢复；结束/替换/死亡/销毁停止，死亡不补播 end；不是无限循环 |
| events.<action>:end | 已跟踪动作剩余时长归零或被新 action 替换 | 死亡移除跟踪项，不补播 end；冻结/眩晕影响动作计时，但不会暂停已播放短音 |
| events.<action>:release | frontal 的 apply_frontal 进入实际 Impact | 可用于释放音，空放也触发；不等于动画起手，不改变 impact_delay |
| events.<action>:hit | Main._notify_unit_audio_event → play_event / _rpc_unit_audio_event | 当前自动派发来自 continuous_area 的真实成功脉冲及 frontal 的真实成功命中；同一脉冲/释放多目标只响一次，空挥静音 |
| events.active_buff:start / :sustain / :end | GameAudioManager 观察 Unit.active_buff_timer（客户端读取快照状态） | 给没有 visual_action 的通用主动 Buff 使用；起止各一次，sustain 是单位持有的一次播放音层，Buff 结束或死亡时停止 |

重要限制：

- validator 允许已有 action 的 `:hit` / `:release`，不代表 nova、forward_area 等其他效果已有派发入口；frontal 已支持 release/hit，continuous_area 支持 hit。需要在对应权威成功命中路径扩展；不能在动画上加方法轨道伪造命中。
- 短音位置固定在触发点，共享 24 个声道，满时回收旧声道；死亡不会切断所有短音。sustain 另用最多 24 个单位持有播放器，支持跟随、暂停恢复、生命周期停止；满时回收最早一条，片段自然结束不重播。目前仍无无限循环、可配置淡出或任意 Wwise Stop 图的完整复刻。
- 当前只要声明 audio，validator 就要求非空 attack_swing 和 attack_hit，不能直接用于“只有死亡音的无攻击单位”、纯法术或空池。需要按任务扩展可选池契约、消费者与测试；不能放假静音文件骗过校验。
- 世界 Tower 不是此 Unit 接口的自动消费者；双形态虽然校验 transformed_stats.audio，当前管理器不会因 form_changed 自动重挂配置。为这些情况接音频时先实现并测试相应通用生命周期，不能只填数据声称完成。
- 技能动作序号/强化状态从权威或客户端快照读取；短暂状态可能因快照间隔被跳过。若任务要求每次施法都必达，需要设计明确的事件传输/去重，不能偷偷将声音变成权威判定条件。

## 4. 获取、解析与转换

### 已有事件 WAV 库

优先读取来源 README、事件清单和映射文件。区分：

- `event_wav/`：按事件组合/渲染的预览，可在核实后选用。
- `by_event/`：事件可达的组成声音，不保证每个文件都是完整事件。
- `raw_wav/<id>.wav`：原始媒体解码；数字 ID 不是动作名称。

盖伦本次来源位于 `/Users/czh/Tools/lol-asset-tools/garen_base_audio/`；这是本机已准备的实例，不是其他环境或其他英雄的默认可用来源。先检查存在性，缺失时报告所需素材。

### 只有 LOL WAD / Wwise BNK 时

在项目外独立工作目录提取，原始 `LOL_Asset_Source` 只读：

1. 用 wadtools 的已安装版本与哈希表定位目标英雄、皮肤的 Audio BNK / Events BNK、皮肤 BIN 和对应共享 init.bnk；VO 语言包与 SFX 分开，不混入其他皮肤。
2. 用 ritobin-tools 解析皮肤 BIN 中的事件名，wwiser 解析 Events/Audio/Init 的层级。恢复名称时校验 Wwise ShortID，不将猜测标签冒充原名。
3. 关系沿 Event → Action → 容器 → Sound → 媒体 ID 解析；保留随机、层叠与 Switch 条件。记录缺失节点、缺失媒体和未归类媒体，不能悄悄忽略。
4. 用 wwiser 生成事件 TXTP，再用 vgmstream 解码/渲染为 WAV；裸 WEM 可用 vgmstream 解码。bnkextr 仅用于需要的媒体提取，不能替代事件图解析。FFmpeg 可检查/转码已能识别的音频，不假定它能直接处理所有 WEM 编码。
5. 保留 TXTP、映射、工具版本和转换参数在项目外来源库。检查循环渲染策略、随机分支覆盖、增益与媒体路径；每个导出失败都要有说明。

本机工具线索：`/Users/czh/Tools/lol-asset-tools/README.md`、同目录 `bin/` 与 `process_garen_audio.py`。执行前读脚本并检查当前版本的 `--help`；盖伦脚本包含英雄/路径假设，不是通用任意英雄解包器。工具缺失时先检查 PATH/Homebrew 和本机安装说明，需安装或升级时遵循当前任务授权，不为了接已有 WAV 重新装整套工具。

解释边界：恢复的是事件名而非音频工程的原 WAV 文件名；未知 Switch 条件保留 ID，不猜“建筑/金属”等材质；Stop 事件本身通常没有 WAV。离线事件渲染不能声称完整复现 Wwise 的实时滤波、空间参数、随机音高或全部嵌套随机组合。

## 5. 归档、命名与来源记录

1. 只选工作表中已使用事件及有必要的变体。优先采用已验证的 PCM WAV，检查时长、采样率、声道、非静音、无截断/爆音；先保留合理的来源增益，不逐个峰值归一化破坏层次。
2. 放到 `assets/audio/units/<card_id>/`；英文 snake_case 保留原事件可辨识部分、变体编号和未知条件 ID，检查规范化命名是否冲突。真实事件名完整记录在 manifest，不能只保留 attack_01 这类无法追源的名字。
3. 外部共享来源库：复制/转换选定成品，原包不变。若用户指定从待开发队列取素材：适用 Router 的“迁移而非复制”；已选素材及必需依赖在目标确认可用后从队列消失并记“已移动”。若指定的是待转换源包，先明确源包归档位置与转换产物关系，不因生成 WAV 就删除唯一源包，也不删除包中其他待开发卡的素材。
4. `event_manifest.json` 至少记录 `file`、`event`、`source_preview`；来源提供时补 `event_id` 与 `media_ids`。README 写清源库/包、皮肤/语言、工具与参数、处理方式、限制及使用权限。media_ids 若是整个事件的候选集合要注明，不能冒充逐变体的精确组成。
5. 若替换实验素材，先确认新文件与引用可用，再仅删除用户授权替换且已无引用的旧文件及 sidecar；不要清空整个目录或其他卡牌资源。Godot 自动生成导入文件，不手改 `.import`。

参考 `tools/import_garen_audio.py` 的白名单复制与 manifest 生成方法；该脚本固定盖伦、外部源路径且会覆盖同名输出，不适用于待开发队列迁移。新卡应按实际来源改造/另建明确目标的导入脚本，不直接重跑它。

## 6. 写入 CardDB（仅示意，路径需替换为真实资源）

以下片段假设该卡已有两段 attack 动画和名为 active 的 visual_action：

```gdscript
"audio": {
    "attack_swing": [
        ["res://assets/audio/units/example/attack1_cast_r1.wav"],
        ["res://assets/audio/units/example/attack2_cast_r1.wav"],
    ],
    "attack_hit": ["res://assets/audio/units/example/attack_hit_r1.wav"],
    "attack_swing_volume_db": 0.0,
    "attack_hit_volume_db": 0.0,
    "events": {
        "active:start": {
            "pool": ["res://assets/audio/units/example/skill_cast_r1.wav"],
            "volume_db": 0.0,
        },
        "death": {
            "pool": ["res://assets/audio/units/example/death.wav"],
            "volume_db": 0.0,
        },
    },
},
```

events 可省略，无素材的可选 cue 不填；填入的 pool 必须非空且每个路径能加载为 AudioStream。事件支持 pool / volume_db / bus，bus 默认为 Combat，可选 Voice（死亡叫声等 VO）。0 dB 代表不追加增益，不代表最终响度一致；在实际混音中按需调整。

VO 不等于普通对白，也可能包含死亡叫声；SFX 无死亡素材时应检查 Death3D 等 VO 事件。语言包中很小的 Audio BNK 不代表无媒体，实际 WEM 可能位于 WPK；先按事件图定位媒体，再解析 WPK 索引提取并检查边界。语言以源 WAD 包区分，内部路径可能仍标为 en_us。寒冰样例见 tools/import_ashe_death_audio.py 与其 death_event_manifest.json。

随机池采用不连续重复模式。相同事件可共享素材，不需为两个攻击段重复存储完全相同的命中文件；不要把“不同条件”未经核实直接当“随机变体”，若有意合并必须说明依据与限制。

## 7. 只有缺少通用入口时才改代码

按“事件语义 → 通用消费者 → CardDB 字段与 validator → 必要 Snapshot/RPC → 领域测试 → 本文”扩展，不新增英雄名分支：

- 出手/开始类：复用权威或快照的动作序号；重复帧不重播。不要在模型动画完成回调里驱动技能或伤害。
- 命中类：在真实结算返回成功后通知 Main 的纯表现入口。先明确按目标、按脉冲还是按施法去重；免疫/空挥/取消不伪造命中。远程命中在弹体实际抵达结算时触发，不使用固定 first_hit 延迟代替。
- 客户端：从主机 authority-only 事件或已有快照重放，不让客户端重复跑伤害推断音频；主机本地和远端各只播一次。参考现有不可靠命中 RPC；若改可靠性需明确理由与去重。
- 长音/循环：必须有单位所有权、开始/停止/替换、死亡/销毁、冻结/眩晕及换场清理规则，并限制并发；不能把导出的单次循环片段塞进随机短音池就算实现。
- 不修改攻速、first_hit、技能 duration、伤害或网络权威来“对齐声音”。需要对齐时处理素材/表现配置；新增表现字段必须有真实读取方。

## 8. 验收与交付清单

从项目根目录运行（Godot 不在 PATH 时使用已确认的可执行文件；本机为 `/Applications/Godot.app/Contents/MacOS/Godot`）：

```sh
Godot --headless --path . --editor --import
Godot --headless --path . --script tests/mechanics_check.gd
git diff --check
```

- 资源：路径/数量、非静音与有效时长、manifest 一一对应；直接复制文件可比对 SHA-256，经过转码则记录转换参数而非要求哈希相等。
- 配置：CardDB.validate_all() 通过；攻击分段、事件键、音量和资源类型正确。未接入项有原因。
- 自动事件测试：参考 `tests/suites/audio_presentation_suite.gd`，验证普通/强化出手、重复帧/快照去重、真实命中与空挥、多目标去重、动作起止、死亡一次性及清理，声音不改变 HP 等权威状态。新增机制补领域断言，沿用唯一 mechanics 入口。
- 实际 F5 观察并试听：双方视角、不同距离、并发多单位、普攻每段、技能每个候选及未携带版本、命中/未命中、冻结/眩晕、死亡中断。检查响度、削波、尾音叠加和时序；日志中的 cue_played 只证明派发，不能代替听感验收。
- 普攻开发面板试听仅验证音色与模拟 first_hit 队列，不证明真实命中路由；技能通过正式主动/已有 preview_active_skill 入口验证。演示工具放 `tools/demos/`，不作为新的自动回归入口。
- 改了网络事件就运行 host/join 冒烟并检查两端日志；核对新增 cue 的客户端重放，不只验证能连接。不能运行/试听时明确记录未验收部分，不能声称全部通过。
- 在 `docs/cards/<card_id>.md` 更新：2D / 3D / 卡面 / 音频阶段状态、已接/未接事件、音频 README 链接、素材来源及迁移情况、验证命令与结果、剩余风险。交付不附带无关游戏数值改动。

音频目录 README 是该卡的映射真相来源；本手册只维护通用流程与系统边界，避免每张卡重复复制整份教程。
