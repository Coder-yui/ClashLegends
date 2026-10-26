# 专项复现场景

- `samira_review.gd`：工作台正式出牌、双方枪刀/R、寒冰/金克丝尺寸参照、卡面与技能图标、冰冻/死亡中断及混音录制。`--attack-audit`逐套核验莎弥拉四种普攻的四朝向、连续攻击节点、枪口投影与弹体，输出固定步实机截图和事件JSON。`--passive-review`验证双方被动叠层、原版满层特效、4秒到期与R消耗切换，并输出实机截图及层数/移速日志。`--ready-audit`固定满层时刻，核对双方四朝向、模型/附着层原点及源缩放，并输出实机截图与坐标JSON。

- `void_scuttle_crab_review.gd`：虚空河蟹双方与普通河蟹尺寸对比、舞蹈、自尽/被击杀治疗区及清场录音截图。

返回 [工具索引](../README.md)。联网统一用 `python3 tools/dev.py verify --network-render` 或 `bash tools/run_local_multiplayer.sh`（一服两端）。本页脚本仅作单机专项复现，旧联网参数会明确报错。

临时看新模型或试听任意声音，优先使用通用展台；这些脚本保留特定实战问题的复现条件。

普通 SceneTree 脚本：`Godot --path . --script tools/demos/文件.gd`。`demo_xin_sweep`、`stage_debris_demo` 使用同名 `.tscn` 场景启动。渲染和录音需要图形运行；参数、输出路径和退出方式以脚本顶部为准，不批量运行。

建筑交互展台见 [专门说明](README_structure_showcase.md)。

| 入口 | 用途提示 |
| --- | --- |
| [apex_audio_review.gd](apex_audio_review.gd) | 实战声音与时间戳；单机录音与截图。 |
| [ashe_audio_demo.gd](ashe_audio_demo.gd) | 寒冰普攻与技能单机声音复现。 |
| [ashe_volley_collision_preview.gd](ashe_volley_collision_preview.gd) | 实际渲染非穿透 W：前排挡后排、侧箭继续。固定模拟，输出 /Users/czh/Projects/ClashLegends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash-ashe-volley-collision。 |
| [baron_minion_preview.gd](baron_minion_preview.gd) | 男爵强化士兵表现 |
| [baron_projectile_preview.gd](baron_projectile_preview.gd) | 真实弹体系统的男爵炮弹逐帧渲染验收。 |
| [card_audio_batch_demo.gd](card_audio_batch_demo.gd) | 正式工作台出牌/技能事件的可复现录音；输出到 /Users/czh/Projects/ClashLegends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash-card-audio。 |
| [card_playtest_fixes_preview.gd](card_playtest_fixes_preview.gd) | 卡牌实战修订场景 |
| [contact_preview.gd](contact_preview.gd) | 接触/桥口实际渲染验收。保留卡牌定义，仅对演示实例设置快慢行军。 |
| [demo_xin_sweep.gd](demo_xin_sweep.gd) | 赵信部署版「新月护卫」演示：生成首帧 Spell4 并立即击退四周敌人（按质量分级）； |
| [event_audio_network_review.gd](event_audio_network_review.gd) | 双阵营真实预部署/落地录音截图；单机录音与截图。 |
| [event_audio_review.gd](event_audio_review.gd) | 实际渲染与混音录音；工作台 Spell4 试听、范围护盾及基础单位攻击。 |
| [garen_audio_demo.gd](garen_audio_demo.gd) | 顺序演示 Q、E（不是一场战斗携带两个技能），使用正式表现与技能入口。 |
| [gnar_launch_audio_preview.gd](gnar_launch_audio_preview.gd) | 默认真实渲染/录音。 |
| [gwen_passive_preview.gd](gwen_passive_preview.gd) | 真实运行格温新被动与万能牌轨迹提示；输出渲染与主混音供复核。 |
| [maintenance_preview.gd](maintenance_preview.gd) | 实际渲染 QA 工具，不是自动 mechanics 入口。截图输出 /Users/czh/Projects/ClashLegends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash-maintenance-render。 |
| [match_audio_review.gd](match_audio_review.gd) | match audio review |
| [missfortune_audio_demo.gd](missfortune_audio_demo.gd) | 录音输出到 /Users/czh/Projects/ClashLegends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash_missfortune_audio.wav，覆盖普攻、W 和死亡。 |
| [nexus_audio_lifecycle_review.gd](nexus_audio_lifecycle_review.gd) | nexus audio lifecycle review |
| [numeric_review.gd](numeric_review.gd) | 数值场景审查 |
| [original_animation_review.gd](original_animation_review.gd) | 原表调整的表现 fixture：正式 play_card 生成、正式 UnitModel3D 消费，固定步长且不运行战斗。 |
| [sett_animation_preview.gd](sett_animation_preview.gd) | 实际工作台模拟 + 同一 3D 世界的近景相机。用 --fixed-fps 30 生成可复查的连续帧。 |
| [stage_debris_demo.gd](stage_debris_demo.gd) | 临时演示：慢放复现公主塔阶段掉块演出（跳播语义）。 |
| [structure_rush_review.gd](structure_rush_review.gd) | 峡谷先锋双阵营冲撞、准备打断、旋转重拳与蠕虫爆出，保存渲染帧与混音。 |
| [structure_showcase.gd](structure_showcase.gd) | 塔、水晶的交互模型和声音展台 |
| [sun_disc_tombstone_review.gd](sun_disc_tombstone_review.gd) | 圆盘与墓碑的实战声音和表现 |
| [sustained_audio_demo.gd](sustained_audio_demo.gd) | 空转审判 → 死亡中断审判 → 寒冰死亡；同时录制实际 Master 混音供试听。 |
| [twisted_fate_deploy_review.gd](twisted_fate_deploy_review.gd) | 双阵营 1.3 秒预部署 + 0.45 秒部署、原声前 1.75 秒录音截图；单机录音与截图。 |
| [workbench_preview.gd](workbench_preview.gd) | 非 headless 运行；生成 /Users/czh/Projects/ClashLegends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash-workbench-*.png，并核对工作区暂停边界。 |
| [workbench_scenarios_preview.gd](workbench_scenarios_preview.gd) | 工作台场景与控件验收 |
| [xin_sweep_effect_review.gd](xin_sweep_effect_review.gd) | 实际工作台双阵营部署/主动横扫截图；输出 /Users/czh/Projects/ClashLegends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash-xin-sweep-review。 |

- `darius_review.gd`：双阵营流血、血怒、断头台斩杀/免费技能、原生混音与卡面检查。

- `kayn_review.gd`：正式出牌与技能预览入口，双方三形态普攻、Q、冻结、死亡截图及实战混音。

- `pantheon_review.gd`：潘森双方落地、短Q与满怒、普攻、死亡、详情和混音录制。

- `mirror_review.gd`：镜像卡部署、复制技能及单机战斗表现复核。
- `sion_review.gd`：双阵营赛恩部署、护盾、复生、普攻、死亡与录音复核。

## 潘森落地逐层评审包

复用`pantheon_review.gd`录制当前正式资源，不修改卡牌配置。包含112个单层、7个系统组合、长矛与两段人物代理，以及双方真实出牌的俯视/侧面同步视角；统一编码为¼倍速。

```sh
Godot --path . --fixed-fps 30 --script tools/demos/pantheon_review.gd -- --review-pack
python3 tools/demos/pantheon_review_media.py --input /本次输出/pantheon-review --output /素材库内新的评审目录
```

输出包含`index.html`离线视频目录、`manifest.json`、`items.csv`与MP4/海报；L编号对应粒子层，G对应组合，P对应长矛/人物。单层使用灰底自动取景，不能根据缩略图比较实际尺寸。完整部署调用真实`play_card()`，两个相机观察同一个世界，保留正式表现朝向。

录制每帧主动渲染，避免macOS后台窗口停刷。中断后可加`--review-output=/原输出/pantheon-review`复用已完整输出的单层；仅在运行素材未改变时续拍，审查期间保留原始帧；用户确认定稿后，核对成片和manifest完整，可清理可再生成的PNG逐帧缓存，保留清单、日志和关键截图。视频打包要求新目录，避免覆盖旧评审意见所对应的编号和素材。


潘森审查页“不要”清单：使用 `python3 tools/demos/pantheon_review_server.py --directory <审查包目录> --port 8768` 启动。单层、独立对象及组合卡支持勾选，组操作展开到各层；保存到该审查包的 `selections.json`，只写审查意见，不直接改游戏。页面支持只看已选、取消和导出；下一轮按清单修改时读取该文件的稳定编号、系统/发射器名。勿覆盖用户已保存的清单；新生成的包才初始化当前已停用层。静态文件方式打开只提供浏览器缓存/导出，请优先用本地服务。

- `tristana_review.gd`：麦林炮手双方普攻、Q启停、冻结、死亡，提莫/纳尔同场尺寸、卡面及真实混音录制。


`tryndamere_review.gd`：正式工作台中的双方模型对比、连续普攻/暴击、大招、冻结及死亡录音与截图；使用通用工作台，不承担验收持久化。

- `corki_review.gd`：库奇双方模型、艾希/冰鸟同场尺寸、卡面、三枚导弹循环、冻结恢复及死亡录音与截图。

已退役 `baron_minion_network.gd`、`kayn_network_review.gd`、`mirror_network_review.gd` 及可选双进程分支：它们依赖玩家主机、固定阵营或客户端完整手牌，与现行协议不兼容。保留对应本地配方和领域套件；三进程集成负责真实会话/副本同步。逐卡专有网络视觉组合不因此自动视为已覆盖，必要时扩展现有网络夹具。旧源码可从 Git 历史追溯。

虚空行者双方浮空模型、河面动作、常驻能量刃、原版R生命周期与运行音频：`Godot --path . --script tools/demos/kassadin_review.gd`。产物自动进入开发素材库，源程序只用于表现验证。

- `yorick_review.gd`：牧魂人双方、同档尺寸、Q与范围提示、死亡和运行录音。

`scuttle_crab_review.gd`：峡谷迅捷蟹双方模型与艾希对比、舞蹈、兰顿施放、死亡治疗区多个时点及清场截图与运行录音。

- `kassadin_review.gd -- --range`：双阵营实际战场特效叠加技能数据中的伤害半径圈，仅预览脚本创建。默认暂停在落地后0.15秒，可播放/暂停、拖动0—1.2秒时间轴，或选择0.05/0.15/0.3/0.6秒关键帧。圈内接触敌方身体即满足距离判定；不把目标半径额外画成技能半径。

`ekko_review.gd`：工作台双阵营部署、第三击、R回溯、影子配色、卡面与运行混音取证；附加 `-- --viewer-team=1` 检查红方观察视角。

莎弥拉持枪/持刀待机、跑步、收武器与切换审核：`samira_review.gd -- --stance-review`，正式工作台出牌后以确定性表现状态驱动双方四个模型，输出截图与片段/时间JSON；不将此演示作为权威索敌验证。

莎弥拉R结束衔接审核：`samira_review.gd -- --r-exit-review`，以同一表现预览场景检查双方移动/静止退出R，输出截图和片段进度JSON。

`blitzcrank_review.gd`（`--hook-interrupt` 检查出钩后冻结/死亡与目标移远；`--tower-pull` 检查隔塔拉取正在攻击防御塔的人马）：正式工作台双阵营Q牵引、E强化眩晕、冻结、死亡语音、卡面与实际混音；`-- --viewer-team=1`复核红方观察视角。

`jayce_review.gd`：工作台双阵营周期换形、超能电荷、冻结、死亡、卡面图标和运行录音检查。

`tidal_wave_review.gd`：正式工作台双方浪潮、友军加速、空军排除、卡面与运行音轨记录。`-- --no-units`用于空场粒子遮挡观察；输出由DevelopmentPaths统一管理。

- `powder_keg_review.gd`：双阵营火药桶/木桩尺寸、Timer受击、主动与普通爆炸、金币及实际混音截图录音。

杰斯 `jayce_review.gd -- --anchors-review`：在现有工作台固定双形态位置，依次拍摄首击待发、换形、远程W与出手；仅演示夹具，不改变对战规则。

- `event_horizon_review.gd`：正式工作台双方空间边界、黑暗物质、卡面信息和混音录制，输出到开发素材库的独立批次。

`medium_lightning_review.gd`：工作台正式出牌入口的双方落雷、塔失效恢复、卡面与音频录制，产物进入开发素材库。
