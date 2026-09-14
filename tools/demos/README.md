# 专项复现场景

返回 [工具索引](../README.md)。临时看新模型或试听任意声音，优先使用通用展台；这些脚本保留特定实战问题的复现条件。

普通 SceneTree 脚本：`Godot --path . --script tools/demos/文件.gd`。`demo_xin_sweep`、`stage_debris_demo` 使用同名 `.tscn` 场景启动。渲染和录音需要图形运行；参数、输出路径和退出方式以脚本顶部为准，不批量运行。

建筑交互展台见 [专门说明](README_structure_showcase.md)。

| 入口 | 用途提示 |
| --- | --- |
| [apex_audio_review.gd](apex_audio_review.gd) | 实战声音与时间戳；可传 --mode=host / --mode=join 做同场联机复核。 |
| [ashe_audio_demo.gd](ashe_audio_demo.gd) | 联机验证可在两个进程末尾分别加 -- --mode=host/--mode=join --auto-test。 |
| [ashe_volley_collision_preview.gd](ashe_volley_collision_preview.gd) | 实际渲染非穿透 W：前排挡后排、侧箭继续。固定模拟，输出 /Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash-ashe-volley-collision。 |
| [baron_minion_network.gd](baron_minion_network.gd) | -- --mode=host / --mode=join --ip=127.0.0.1；真实 Snapshot 验证双方四种兵 Buff 启停。 |
| [baron_minion_preview.gd](baron_minion_preview.gd) | 男爵强化士兵表现 |
| [baron_projectile_preview.gd](baron_projectile_preview.gd) | 真实弹体系统的男爵炮弹逐帧渲染验收。 |
| [card_audio_batch_demo.gd](card_audio_batch_demo.gd) | 正式工作台出牌/技能事件的可复现录音；输出到 /Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash-card-audio。 |
| [card_playtest_fixes_preview.gd](card_playtest_fixes_preview.gd) | 卡牌实战修订场景 |
| [contact_preview.gd](contact_preview.gd) | 接触/桥口实际渲染验收。保留卡牌定义，仅对演示实例设置快慢行军。 |
| [demo_xin_sweep.gd](demo_xin_sweep.gd) | 赵信部署版「新月护卫」演示：生成首帧 Spell4 并立即击退四周敌人（按质量分级）； |
| [event_audio_network_review.gd](event_audio_network_review.gd) | 双阵营真实预部署/落地录音截图；可传 --mode=host / --mode=join。 |
| [event_audio_review.gd](event_audio_review.gd) | 实际渲染与混音录音；工作台 Spell4 试听、范围护盾及基础单位攻击。 |
| [garen_audio_demo.gd](garen_audio_demo.gd) | 顺序演示 Q、E（不是一场战斗携带两个技能），使用正式表现与技能入口。 |
| [gnar_launch_audio_preview.gd](gnar_launch_audio_preview.gd) | 默认真实渲染/录音；也支持 -- --mode=host 或 --mode=join 核对可靠启停。 |
| [gwen_passive_preview.gd](gwen_passive_preview.gd) | 真实运行格温新被动与万能牌轨迹提示；输出渲染与主混音供复核。 |
| [maintenance_preview.gd](maintenance_preview.gd) | 实际渲染 QA 工具，不是自动 mechanics 入口。截图输出 /Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash-maintenance-render。 |
| [match_audio_review.gd](match_audio_review.gd) | match audio review |
| [missfortune_audio_demo.gd](missfortune_audio_demo.gd) | 录音输出到 /Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash_missfortune_audio.wav，覆盖普攻、W 和死亡。 |
| [nexus_audio_lifecycle_review.gd](nexus_audio_lifecycle_review.gd) | nexus audio lifecycle review |
| [numeric_review.gd](numeric_review.gd) | 数值场景审查 |
| [original_animation_review.gd](original_animation_review.gd) | 原表调整的表现 fixture：正式 play_card 生成、正式 UnitModel3D 消费，固定步长且不运行战斗。 |
| [sett_animation_preview.gd](sett_animation_preview.gd) | 实际工作台模拟 + 同一 3D 世界的近景相机。用 --fixed-fps 30 生成可复查的连续帧。 |
| [stage_debris_demo.gd](stage_debris_demo.gd) | 临时演示：慢放复现公主塔阶段掉块演出（跳播语义）。 |
| [structure_showcase.gd](structure_showcase.gd) | 塔、水晶的交互模型和声音展台 |
| [sun_disc_tombstone_review.gd](sun_disc_tombstone_review.gd) | 圆盘与墓碑的实战声音和表现 |
| [sustained_audio_demo.gd](sustained_audio_demo.gd) | 空转审判 → 死亡中断审判 → 寒冰死亡；同时录制实际 Master 混音供试听。 |
| [twisted_fate_deploy_review.gd](twisted_fate_deploy_review.gd) | 双阵营 1.3 秒预部署 + 0.45 秒部署、原声前 1.75 秒录音截图；可传 --mode=host / --mode=join。 |
| [workbench_preview.gd](workbench_preview.gd) | 非 headless 运行；生成 /Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash-workbench-*.png，并核对工作区暂停边界。 |
| [workbench_scenarios_preview.gd](workbench_scenarios_preview.gd) | 工作台场景与控件验收 |
| [xin_sweep_effect_review.gd](xin_sweep_effect_review.gd) | 实际工作台双阵营部署/主动横扫截图；输出 /Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash-xin-sweep-review。 |
