> 2026-09-14 整理前快照，可能含已纠正的说明。当前入口见 [文档首页](../../../README.md)。

# 卡牌音频接入流程

当前资料入口：[竞技场总览（全局音频归属入口）](../../../units/arena.md)。

完整新卡顺序：2D 权威逻辑 → 3D 模型/动画 → 卡面 → 音频 → 联合验收。先读 `AGENT_WORKFLOW.md`；本手册用于音频阶段，不要求重读所有模型教程。

目标是让当前玩法实际用到的事件有合适、可追溯的声音，不是把英雄全部素材塞进项目。现有接入样例为 CardDB 的 `garen.audio` 与 `assets/audio/units/garen/README.md`。盖伦只是样例，不得将其事件名、技能数量或素材路径套到其他卡上。

试听入口：[开发工作台](../../../DEVELOPMENT_WORKBENCH.md) 音频页按事件检查变体，实战页检查真实触发；两项分别验收。

## 1. 开始前与产出

1. 看 `git status --short --branch`，保留已有修改；读目标 `docs/units/<card_id>.md`、CardDB 数值/动画/主动候选及当前素材目录。
2. 核对 `scripts/audio/game_audio_manager.gd`、`card_schema.gd` 的 `AUDIO_FIELDS` 与 `card_validator.gd` 的 `_validate_audio_config()`；涉及新增真实命中事件时读对应 battle 模块及 Main RPC。代码与本文不一致时，先确认实际实现，不按过时字段盲配。
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

音频仍由独立 GameAudioManager 管理 24 个短音播放器和最多 24 个持续播放器。模型和音频共同使用 PresentationConfig.for_form；音频挂接 Unit 的实例配置，每次形态变化更新后续动作。无模型、只有死亡音和无攻击建筑可正常配置；attack_swing、attack_hit 都可省略。配置了声音池就必须非空且资源真实存在，不使用假静音文件。

| 配置 | 实际派发/消费 | 能力约束 |
| --- | --- | --- |
| attack_swing | 权威/快照攻击实例序号 | 有普通攻击；有 attack 动画数组时按段对齐，没有模型时由声音池自身定义变体数 |
| attack_hit / first_strike_hit | CombatResolver 真实命中信号 → Main 本地消费/不可靠 RPC | 伤害成功后每次攻击/范围脉冲一次；空挥/免疫不播 |
| events.attack_launch | ProjectileSystem 真实创建弹体 | 有远程攻击 |
| first_strike:cast / missile_cast / missile_launch / hit_location | 首击标记的出手、创建、真实命中 | 配置首击机制；missile 阶段要求远程 |
| empowered_ready / empowered_swing | 准备状态和强化攻击序号 | empowered_attack 机制 |
| active_buff:start / sustain / end | Buff 状态变化，持续状态由 Snapshot 纠正 | buff 机制有持续时间 |
| action:start / sustain / end | Unit 权威动作窗口和序号 | 实际携带候选可以产生该 action，且有 cast_duration |
| action:release | ActiveSkillEffectSystem.apply_frontal | frontal 机制 |
| action:hit | frontal / continuous_area / forward_area 固定持续区域真实脉冲 | 不接受只有动画名、没有对应派发点的配置 |
| death | Unit.died 的表现通知 | Unit/建筑；一次性，停止全部持续层 |
| pre_deploy:start | 预部署创建 → 带 ID 的可靠卡牌事件 | pre_deploy_time > 0，无需 Unit 已存在 |
| spell:cast | 法术成功执行 → 带 ID 的可靠事件 | 纯法术可使用，不依赖 Unit 或 3D 模型 |

`PresentationEvents.supports` 是当前能力表，validator 与实际入口一起维护。nova、dual_form、summon、forward_area 首次落点等尚无独立通用命中 cue 的机制，不得提前配置对应 action:hit；需要时先补真实派发与测试。未配置的可选声音静音。

ProjectileSystem 在出手时保存 card_id、form、serial、first_strike 来源值，CombatResolver 在发放命中收益之前固化来源。攻击者死亡/销毁后弹体仍能播放原形态命中声；Unit 原有死者收益保护继续保留，不能给死者回血、资源或变形。变形前的弹体不改用新形态声音。高频命中仍允许丢失，不转为可靠 RPC；重要法术事件带递增 ID 去重，动作/强化/持续状态通过快照和序号纠正。

持续声音区分 action、buff 与持续普攻 attack 三层：跟随单位、控制时暂停、解除恢复、动作替换只停对应层，死亡/销毁/换场清理全部层。形态变化替换后续持续配置。action/buff sustain 是一次长片段；持续普攻 attack 层在片段结束时续播，直到目标/动作状态退出。它不是 Wwise 样本级无缝循环。

素材状态分别记录：已接入的资源映射仍以各 `assets/audio/units/<id>/README.md` 为准；未携带候选、空挥、免疫命中是有意静音；不支持的机制 cue 属于缺入口；尚未核验可用文件的卡属于未接素材，不能冒称已有声音。spell:cast 已用于治疗术；freeze 当前未配置。没有正式眩晕声音素材接入。

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

死亡声音的素材长度上限为 1.5 秒：仅当源声音超过 1.5 秒时保留前 1.5 秒，前 1 秒保持原采样，最后 0.5 秒按振幅线性淡出至零；较短或恰好 1.5 秒的素材保持原样。此包络离线写入项目 WAV，`tools/audio/death_audio_envelope.py` 由各音频导入器共用，原始来源库不改。manifest 的 `death_envelope` 记录处理前时长/哈希及包络，`duration/sha256` 指向处理后的文件。死亡声时长不改变单位死亡动画或权威结算。

参考 `tools/audio/import_garen_audio.py` 的白名单复制与 manifest 生成方法；该脚本固定盖伦、外部源路径且会覆盖同名输出，不适用于待开发队列迁移。新卡应按实际来源改造/另建明确目标的导入脚本，不直接重跑它。

## 6. 写入逐卡定义 audio 域（仅示意，路径需替换为真实资源）

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

VO 不等于普通对白，也可能包含死亡叫声；SFX 无死亡素材时应检查 Death3D 等 VO 事件。语言包中很小的 Audio BNK 不代表无媒体，实际 WEM 可能位于 WPK；先按事件图定位媒体，再解析 WPK 索引提取并检查边界。语言以源 WAD 包区分，内部路径可能仍标为 en_us。寒冰样例见 tools/audio/import_ashe_death_audio.py 与其 death_event_manifest.json。

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
- 在 `docs/units/<card_id>.md` 保留音频说明入口；音频页用中文更新发声时机、试听与缺项。来源迁移与详细验证日志保留在素材记录或归档。交付不附带无关游戏数值改动。

音频目录 README 是该卡的映射真相来源；本手册只维护通用流程与系统边界，避免每张卡重复复制整份教程。

## 2026-09-11 批量接入扩展

全卡动作、素材与未接入项见 [音频对照](../../../AUDIO_CARD_MAP.md)。`attack_hit_by_segment` 与攻击动画分段数量一致，由出手来源 serial 选择；`empowered_hit` 只供强化攻击，出手来源新增 empowered 布尔值，沿用现有真实命中 RPC。validator 与工作台音频页均识别这两个可选字段。`continuous_attack:start/sustain/end` 仅允许持续攻击单位，由已同步的持续目标状态驱动，独立 attack 层负责暂停、续播和清理。

`deploy:start` 是通用生成音：部署时间大于零的单位可配置；AudioManager 首次附着且部署刚开始（已过去不超过 0.1 秒）时派发，重绑和晚到快照不补播。它消费现有部署状态，不新增 RPC，不影响部署计时。

## 固定区域声音（2026-09-12）

`action:zone_sustain / action:zone_end` 仅支持 `forward_area` 且 `zone_duration > 0` 的真实区域。区域生成派发 card_id、form、action、落点、时长与递增 ID，Main 可靠 RPC 通知客户端，AudioManager 去重。区域音频独立于施法者生命周期，与区域表现共用 tick_visuals；自然到期播一次结束声，换场/工作台清场不补结束声。独立最多 24 个区域播放器，较长区域可续播非无缝片段。该入口不更改伤害/区域模拟，也不接收客户端施法推断。

非穿透扇形技能箭的 `action:release` 在实际创建箭时派发，`action:hit` 在首次成功碰撞伤害时按施法去重；独立来源保存 card_id/form，即使施法者销毁也可发声。命中通过扩展 form 可选参数的既有可靠 card_event 通知，普通法术调用继续使用默认 form=0。不是离弦就提前发放命中音。

`attack_launch_by_segment` 是可选的分段普攻发射池，数量须与攻击动画段数一致；存在时替代 `events.attack_launch`，使用原始事件增益（0 dB 额外增益）。弹体生成事件携带攻击序号至客户端，不依赖接收时快照序号；只播放一次性发射声，不表示持续飞行循环。

多剪技能可配置 `action:hit_first/hit_middle/hit_last`（需 resource_hit_damage_sequences）：权威排程携带剪切阶段，只有成功伤害才派发，每剪多目标一次，未配置时回退 action:hit。穿透扇形弹体每个成功命中目标派发一次 action:hit，同次施法共享目标去重；非穿透箭继续按施法只播首次成功命中。

## 全面复核后新增入口（2026-09-13）

- `attack_swing_lead_time`：非负基础秒数，按单位归一攻击进度在 first_hit − lead 处播放原始出手短音；冻结/眩晕等待，取消不补播，不改变游戏计时。
- `attack_missile_cast`、`empowered_launch`：真实普通弹体创建的附加层及强化发射替代池；后者与普通发射不叠加。
- `continuous_attack:release`：持续吐息进入时的导引短音层；与起音/持有层并行。
- `shroud:start/sustain/end`：读已有缠流状态/快照，独立 shroud 所有权，暂停、结束、死亡/销毁和换场清理。`resource_full` 读已有可见资源比例，只在进入满层时播放。
- `empowered_buff:start/end`：强化待击状态生命周期；`passive_heal` 仅当第三击等规则实际恢复生命。
- `action:impact`：forward_area 落地事件，空放也有落地声；`action:wave_hit`：冲击波成功命中新目标，保存 card_id/form，沿用可靠 card_event 去重。
- `action:hit_center` 为真实中央命中的附加层；多剪 `hit_first_center/middle_center/last_center` 替代对应普通剪切池，未配置时回退普通。中心+边缘同剪按中心音去重播放。
- nova、dual_form 补 `action:hit`；`deploy:hit`、`replacement:start`、`revival:end` 使用可靠卡牌来源事件，避免绑定/销毁顺序导致漏音。

完整证据和适用边界见 [逐英雄复核](../../2026-09-13/research/hero_audio_completeness_audit.md)。原版有不同名称的事件不一定有独立素材，例如格温中剪多层事件是相同媒体按原版间隔重复，不应重复叠入项目时间线。

`revival:sustain`：定时复生单位附着时启动的独占、非循环过程音，死亡/销毁/清场停止；与权威复生倒计时一致，不随冻结/眩晕暂停。`revival:end` 仅真实成功复生触发。声音不会驱动复生计时。

连续复生音可只配置 revival:sustain：成功复生保留同一播放器尾音，真实死亡仍立即停止。attack_hit_once_by_segment 为与普攻动作段等长的布尔数组，适合单条文件已包含多刀的声音；按来源单位/形态/出手序号去重，只影响音频，两刀伤害与各自命中逻辑保持独立。

## 弹体绑定的普通发射声（2026-09-13）

`audio.attack_launch_until_impact` 为可选布尔值，需要普通弹体及 attack_launch 音频池；当前仅小纳尔开启。ProjectileSystem 在真实普通弹体创建/结束时发出携带弹体 ID 的纯表现信号，Main 使用同通道可靠 RPC 同步启停。声音按发射时的 card_id/form/serial 选择，不要求来源单位或客户端模型仍存在。每枚弹体独占播放器（最多 24 个），命中、目标失效、清场或自然播完时释放；来源单位变形/死亡不抢先结束仍在途弹体的声音。客户端按单调弹体 ID 去重，不重复普通一次性 attack_launch RPC。

该选项只改变实战播放生命周期，素材试听保留完整源文件，不裁剪 WAV、不改变音量、模拟或伤害。实际听感需结合实战复听。

### 横扫喊声事件

可选 `deploy:voice` 和技能 `<action>:voice` 与各自 start 同时派发，复用部署重绑去重和动作序号去重；Voice 总线播放一次，无持续循环，不新增权威事件。赵信 R 横扫采用此方式叠加中文施放喊声。

### 待机与表现弹体出膛（2026-09-13）

`idle:sustain` 为可选独立待机声音层：只读 behavior=Idle、无技能窗口且存活；片段结束续播，离开待机停止，控制暂停，死亡/销毁/换形清理。客户端同样读取 Snapshot，无额外网络事件。大炮台引擎使用此配置，部署播放 Q 炮台 Spawn SFX，死亡播放 Destroy SFX，不使用英雄语音。

大炮台激光现使用真实 ProjectileSystem 穿透弹体，0.45 秒创建时 release；沿途每个实际受伤目标 hit，同一目标一次。移除了临时的独立 release 排程。未发射前随控制暂停、死亡取消，已发射后独立继续飞行。

### 范围护盾、生成与阵营音库（2026-09-13）

`spawn:start` 支持零部署单位首次附着；重复附着不重播，首次收到单位的晚到客户端也会播放出生声。`shield:cast` 在范围护盾施放时一次，`shield:applied` 在每个存活、同阵营、范围内且支持 add_shield 的目标实际加盾后一次；两者使用施法者音库、目标坐标和可靠卡牌事件去重，不改变护盾结算。

`audio.team_overrides` 可包含蓝/红两套平级音频覆盖，禁止递归。通用 PresentationConfig.audio_for、单位声音与工作台读取相同选择；命中来源保存 team，弹体不随来源销毁失去阵营。系统塔/水晶配置独立在 `scripts/data/world_audio.gd`，攻击来源复用原命中链路，销毁消费 Tower.destroyed。本轮具体资源与未接入项见 [事件记录](../../2026-09-13/research/event_audio_expansion.md)。

系统建筑出生/待机由 GameAudioManager 独占播放器持有，使用与模型相同的 spawn_duration 表现配置；水晶出生结束与待机交叉淡化 1.5 秒，待机额外增益为 0 dB。idle:sustain 续播，死亡/销毁/换场停止，清理交叉淡化中的两路声音。声音不驱动模型或玩法。

防御塔 damage:stage1 / damage:stage2 按存活塔血量降至 2/3、1/3 的表现阶段各一次，读取与 TowerModel3D 相同的纯函数；消费本地/客户端快照血量，无新 RPC。保持单调阶段，跨阶段仅播放目标，初次附着不补历史阶段，死亡仅走既有 death。销毁清理弱引用。

防御塔最终摧毁 break03 使用完整源事件（蓝方约 7.60 秒、红方时长见 manifest），不再套用单位死亡 1.5 秒裁剪。事件自带增益保留；未额外归一化或增大防御塔音量。

## 离线工具

音频加工与白名单集中在 `tools/audio/`；按 [新卡清单](../../../NEW_CARD_CHECKLIST.md) 使用 `--cards` 明确导入范围并先 `--dry-run`。现有特殊裁剪/混音以逐卡 manifest 为准，不能把早期批量计划直接覆盖到后续人工调校的全部卡牌。
