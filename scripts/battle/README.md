# 权威战斗系统导航

本目录只维护战场规则、状态与网络状态投影；[Main](../main.gd) 装配并按固定阶段调用，[Unit](../unit.gd)/[Tower](../tower.gd) 通过 BattleContext 使用服务。完整所有权合同见[维护架构](../../docs/MAINTENANCE_ARCHITECTURE.md)。

| 修改内容 | 文件 |
| --- | --- |
| 时钟、比赛、金币、简单单机 AI | `fixed_step_clock`、`minion_wave_schedule`、`match_rules`、`elixir_manager`、`ai_opponent` |
| 手牌、镜像、局内成长 | `card_cycle`、`card_play_history`、`match_card_growth` |
| 排程、付款、主动资格 | `command_schedule`、`command_payment`、`active_skill_roster`、`active_skill_lifecycle` |
| 部署、预部署轨迹 | `unit_spawn_request`、`deployment_rules`、`pre_deployment_sweep` |
| 地图、导航、碰撞与落点 | `arena_rules`、`nav_lane_layout`、`nav_grid`、`battle_path_search`、`movement_system`、`unit_landing_query` |
| 攻击与状态 | `attack_timeline`、`status_instances`、`control_state`、`shield_state`、`bleed_state`、`death_form_state` |
| 特殊位移状态 | `knockback_state`、`structure_rush_state`、`terrain_traversal_state`、`dash_strike_state`、`ornn_charge_state` |
| 周期队伍普攻增幅、锻造时序与在途锤子 | `team_attack_boost_system` |
| 效果准入与结算 | `combat_interaction`、`target_protection_state`、`battle_numbers`、`combat_resolver` |
| 弹体、法术、主动效果 | `projectile_system`、`spell_system`、`active_skill_effect_system` |
| 会话与副本 | `match_session`、`network_entity_lifecycle`、`network_snapshot_system` |
| 战场服务边界 | `battle_context` |

表内文件均为 `.gd`。不为每张英雄卡新增系统；先看现有能力能否由四域定义组合。纯表现去 `scripts/presentation/`，声音去 `scripts/audio/`，离线加工去 `tools/`。对应自动测试按[测试领域](../../tests/README.md#分类与覆盖所有者)定位。

导航分工：`nav_lane_layout` 仅保存静态路线偏好；`nav_grid` 持有网格、永久/动态阻挡及其引用计数，完成端点修正与平滑；`battle_path_search` 只执行 A*，保留等价路线的堆顺序。动态阻挡不改写静态路线代价。
