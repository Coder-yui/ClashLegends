extends RefCounted
## 卡牌数值定义库。调整平衡只改这里。
## 卡牌类型 type: "unit"=单位, "spell"=法术, "building"=建筑
## 单位体型使用七档。这里的半径是权威战斗数据，会参与碰撞、寻路与攻击距离；
## 建筑下牌限制只读取 footprint_tiles，不能由 radius 或 visual_radius 反推；
## visual_radius 只负责占位图、队伍圈和状态提示，不得反过来驱动战斗。
const CHARACTER_SCALE_MULTIPLIER := 1.5
## 空军3D模型底部相对权威地面点的统一离地高度。表现层只平移模型，不缩放模型。
const AIR_VISUAL_ELEVATION := 2.3
const VISUAL_RADIUS_PADDING := 3.0 * CHARACTER_SCALE_MULTIPLIER
const SIZE_EXTREMELY_SMALL := &"extremely_small"
const SIZE_SMALL := &"small"
const SIZE_SLIGHTLY_SMALL := &"slightly_small"
const SIZE_MEDIUM := &"medium"
const SIZE_SLIGHTLY_LARGE := &"slightly_large"
const SIZE_LARGE := &"large"
const SIZE_EXTREMELY_LARGE := &"extremely_large"

const RADIUS_EXTREMELY_SMALL := 8.0 * CHARACTER_SCALE_MULTIPLIER - 3.0
const RADIUS_SMALL := 10.0 * CHARACTER_SCALE_MULTIPLIER - 3.0
const RADIUS_SLIGHTLY_SMALL := 12.0 * CHARACTER_SCALE_MULTIPLIER - 3.0
const RADIUS_MEDIUM := 14.0 * CHARACTER_SCALE_MULTIPLIER - 3.0
const RADIUS_SLIGHTLY_LARGE := 16.0 * CHARACTER_SCALE_MULTIPLIER - 3.0
const RADIUS_LARGE := 18.0 * CHARACTER_SCALE_MULTIPLIER - 3.0
const RADIUS_EXTREMELY_LARGE := 20.0 * CHARACTER_SCALE_MULTIPLIER - 3.0
## 权威战场每格 40px；近战至少保留 0.8 格表面攻击距离，避免模型已经贴身仍需补步。
const MELEE_RANGE_MIN := 32.0
## 地面移动速度统一使用七档，避免不同角色只有几 px/s、实机看不出差异。
const SPEED_EXTREMELY_FAST := 88.0
const SPEED_FAST := 76.0
const SPEED_SLIGHTLY_FAST := 68.0
const SPEED_MEDIUM := 60.0
const SPEED_SLIGHTLY_SLOW := 52.0
const SPEED_SLOW := 44.0
const SPEED_EXTREMELY_SLOW := 36.0

# 防御塔与水晶不进入卡池，但其权威数值与表现配置仍归数据层统一管理。
const PRINCESS_TOWER_PROJECTILE_VISUAL_OFFSET := Vector2(12.0, -205.0)
const PRINCESS_TOWER_STATS := {
	"hp": 2100, "damage": 55, "range": 240.0, "interval": 0.8,
	"footprint_tiles": Vector2i(3, 3),
	"radius": 54.0, "visual_radius": 60.0,
	"first_hit": 0.2, "projectile_speed": 420.0,
	"projectile_spawn_at_edge": false, "projectile_spawn_offset": 0.0, "projectile_collision_radius": 7.0,
	"projectile_visual_offset": PRINCESS_TOWER_PROJECTILE_VISUAL_OFFSET,
}
const NEXUS_STATS := {
	"hp": 3600, "damage": 0, "range": 0.0, "interval": 1.0,
	"footprint_tiles": Vector2i(4, 4),
	"radius": 72.0, "visual_radius": 80.0,
	"first_hit": 0.2, "projectile_speed": 0.0, "can_attack": false,
}
const PRINCESS_TOWER_VISUAL_CONFIG := {
	"scene_paths": [
		"res://assets/towers/princess/princess_tower_blue_view.tscn",
		"res://assets/towers/princess/princess_tower_red_view.tscn",
	],
	"ground_cutoff": 0.0,
	"animations": {
		"destroy": "Destroyed",
		"stage_surfaces": ["Base", "Stage1", "Stage2"],
		"final_stage_surface": "Stage3",
		"ruin_surface": "Rubble",
		"debris": [
			{"bones": "Break1", "surface": "Broken1", "animation": "NativeBreak1"},
			{"bones": "Break2", "surface": "Broken2", "animation": "NativeBreak2"},
			{"bones": "Break3", "surface": "Broken3", "animation": "NativeBreak3"},
		],
	},
}
const NEXUS_VISUAL_CONFIG := {
	"scene_paths": [
		"res://assets/towers/nexus/nexus_blue_view.tscn",
		"res://assets/towers/nexus/nexus_red_view.tscn",
	],
	# 保留完整深井（源模型最低约 −4.37）；地下片元另按开口裁切。
	"ground_cutoff": -10.0,
	"animations": {
		"spawn": "Nexus_spawn_anm", "idle": "Idle1_Base", "destroy": "Death",
		"base_bones": ["base", "crystal"],
		"spawn_hold": "Nexus_spawn_hold_anm", "spawn_hold_duration": 0.0,
		"spawn_duration": 5.1666667, "destroy_duration": 8.0, "blend_duration": 0.0,
		"alive_materials": ["SRUAP_OrderNexus_Mat"], "destroyed_materials": ["Destroyed"],
	},
}

const CARD_TYPES := [&"unit", &"spell", &"building"]
const DEPLOY_ZONES := [&"own_side", &"global_no_river", &"global"]
const SIZE_RADII := {
	SIZE_EXTREMELY_SMALL: RADIUS_EXTREMELY_SMALL,
	SIZE_SMALL: RADIUS_SMALL,
	SIZE_SLIGHTLY_SMALL: RADIUS_SLIGHTLY_SMALL,
	SIZE_MEDIUM: RADIUS_MEDIUM,
	SIZE_SLIGHTLY_LARGE: RADIUS_SLIGHTLY_LARGE,
	SIZE_LARGE: RADIUS_LARGE,
	SIZE_EXTREMELY_LARGE: RADIUS_EXTREMELY_LARGE,
}
const PROJECTILE_VISUALS := [&"orb", &"arrow", &"needle", &"boomerang", &"ice_cone"]
const VISUAL_SPAWN_TRANSITIONS := [&"drop", &"rebirth"]
const SPELL_KINDS := [&"freeze", &"heal"]
const ACTIVE_SKILL_KINDS := [&"timed_form", &"nova", &"buff", &"summon", &"dual_form", &"frontal", &"forward_area", &"continuous_area", &"empowered_attack", &"attack_lifesteal", &"area_shield", &"restoration_shield", &"spell_heal"]
const ACTIVE_SKILL_TARGET_SCOPES := [&"self", &"deployment_group"]
const CAST_LOCKS := [&"movement", &"attack", &"facing"]
const VISUAL_ACTION_KINDS := [&"deploy", &"transform", &"skill"]
const VISUAL_ACTION_DESCRIPTOR_FIELDS := [&"animation", &"durations", &"clip_ranges", &"kind", &"priority", &"blend_in", &"blend_out", &"sequence_blend"]
const VISUAL_TRANSITION_DESCRIPTOR_FIELDS := [&"animation", &"blend_in", &"blend_out", &"start_time"]
const TRANSITION_BLEND_FIELDS := [&"default", &"locomotion", &"action_in", &"action_out", &"attack", &"sequence", &"death", &"model_swap"]

## Validator 会检测未知或未登记字段。新增字段必须同时实现运行时读取逻辑、
## validator 登记和对应机制测试，防止只把配置写进 CardDB、却忘记接入权威模拟或表现层。
const CARD_FIELDS := [
	&"card_art", &"name", &"cost", &"type", &"description", &"selectable",
	&"hp", &"damage", &"range", &"speed", &"interval", &"first_hit",
	&"size_tier", &"custom_radius", &"radius", &"visual_radius", &"mass", &"sight", &"color",
	&"is_air", &"is_building", &"building_only", &"can_attack_air", &"is_continuous_attack",
	&"deploy_time", &"pre_deploy_time", &"deploy_zone", &"deploy_ignore_structures", &"show_team_ring", &"footprint_tiles", &"lifespan", &"lifespan_hp_decay", &"tower_ruin_foundation",
	&"deployment_count", &"deployment_spacing", &"deployment_formation",
	&"spawn_id", &"spawn_interval", &"spawn_count", &"spawn_side", &"death_spawn_id", &"death_spawn_count",
	&"death_replacement_id", &"death_replacement_charges", &"death_replacement_visual_transition", &"timed_revival_id", &"timed_revival_delay", &"timed_revival_death_replacement_charges", &"timed_revival_visual_transition",
	&"projectile_spawn_at_edge", &"projectile_spawn_offset", &"projectile_collision_radius",
	&"active_buff_projectile_visual", &"projectile_speed", &"projectile_visual", &"projectile_visual_height",
	&"projectile_visual_forward_offset", &"projectile_visual_scale", &"projectile_impact_visual",
	&"projectile_colors", &"splash_radius", &"knockback",
	&"continuous_beam_color", &"continuous_beam_start_width", &"continuous_beam_end_width",
	&"continuous_beam_origin_height", &"continuous_beam_forward_offset",
	&"deploy_sweep_name", &"deploy_sweep_radius", &"deploy_sweep_damage", &"deploy_sweep_knockback",
	&"deploy_sweep_duration", &"deploy_sweep_mass_factor_max",
	&"heal_every_hits", &"heal_amount", &"charge_time", &"charge_speed_multiplier",
	&"on_hit_max_health_ratio", &"on_hit_tower_damage", &"charge_damage_multiplier", &"shroud_radius", &"attack_pattern", &"attack_damage_multipliers", &"first_strike_damage_multiplier",
	&"attack_extra_hit_damage_multipliers", &"attack_extra_hit_delays",
	&"attack_passive_multipliers", &"attack_lifesteal_ratios", &"form_lifetime", &"form_lifetime_after_transition", &"form_speed_boost_duration", &"form_speed_boost_multiplier", &"form_refresh_on_kill",
	&"cancel_attack_recovery_without_target",
	&"skill_resource_max", &"skill_resource_attack_gain", &"skill_resource_hit_gain", &"skill_resource_kill_gain", &"skill_resource_full_color",
	&"skill_resource_damage_gain_multiplier", &"skill_resource_decay_delay", &"skill_resource_decay_rate",
	&"attack_interval_display", &"transform_after_hits", &"revert_after_hits",
	&"transform_duration", &"active_transform_duration", &"revert_duration", &"transformed_stats",
	&"spell_kind", &"duration", &"active_name", &"active_slow_duration", &"active_slow_multiplier", &"active_skills",
	&"heal_amount", &"active_cost_bonus",
	&"visual_active_buff_scene", &"visual_scene_path", &"visual_scene_paths", &"visual_forward_yaw", &"visual_animations", &"audio",
]
const AUDIO_FIELDS := [&"team_overrides", &"attack_launch_until_impact", &"attack_hit_once_by_segment", &"attack_swing_lead_time", &"attack_swing", &"attack_hit", &"attack_launch_by_segment", &"attack_hit_by_segment", &"empowered_hit", &"first_strike_hit", &"attack_swing_volume_db", &"attack_hit_volume_db", &"events"]
const VISUAL_ANIMATION_FIELDS := [
	&"stun_enter", &"stun_loop", &"stun_exit", &"deploy", &"deploy_durations", &"deploy_clip_ratio", &"idle", &"idle_cycle", &"move", &"move_enter", &"haste_move",
	&"move_cycle", &"attack", &"attack_enter", &"attack_retarget_enter", &"attack_loop",
	&"attack_clip_ranges", &"attack_hit_clip_ranges", &"attack_hit", &"attack_hit_duration", &"attack_recover", &"attack_recover_delay", &"attack_reference_interval",
	&"initial_move", &"attack_structure", &"attack_move", &"attack_to_move",
	&"empowered_idle", &"empowered_move", &"empowered_attack", &"empowered_attack_hit", &"empowered_attack_recover",
	&"empowered_attack_to_move", &"death", &"death_duration", &"death_clip_end",
	&"death_followup_immediate", &"death_followup_scene_path", &"death_followup_animation", &"death_followup_duration", &"visual_actions",
	&"visual_action_durations", &"transitions", &"transition_blends", &"clip_blends",
]
const ACTIVE_SKILL_FIELDS := [
	&"name", &"kind", &"cost", &"max_uses", &"cooldown", &"radius", &"damage", &"knockback", &"knockback_duration", &"knockback_mass_factor_max",
	&"slow_duration", &"slow_multiplier",
	&"shield", &"shield_duration", &"shield_decay", &"shield_on_cast_start", &"resource_shield_max", &"duration", &"speed_multiplier", &"damage_multiplier",
	&"attack_speed_multiplier", &"ignore_movement_slow", &"ignore_attack_speed_slow", &"spawn_id", &"spawn_count", &"length", &"width", &"impact_delay",
	&"transform_impact_delay", &"cast_duration", &"transform_cast_duration", &"stun_duration", &"ground_only",
	&"cast_locks", &"visual_action", &"description", &"shape", &"near_width", &"far_width", &"arc_degrees", &"fan_inner_arc",
	&"projectile_count", &"projectile_visual", &"projectile_launch_delay", &"projectile_flight_duration", &"projectile_stop_on_hit", &"projectile_piercing",
	&"projectile_visual_height", &"projectile_visual_forward_offset", &"projectile_visual_width",
	&"center_ratio", &"center_width", &"center_damage_multiplier", &"resource_damage_scale_max",
	&"uses_skill_resource", &"resource_damage_by_stacks", &"resource_full_damage_multiplier", &"resource_full_stun_multiplier",
	&"resource_visual_actions", &"resource_hit_damage_sequences", &"resource_hit_delay_sequences",
	&"full_resource_visual_action", &"full_resource_cast_duration", &"full_resource_impact_delay", &"full_resource_cast_end_heal", &"cast_end_heal_requires_hit", &"applies_on_hit_passive",
	&"forward_distance", &"shockwave_damage", &"shockwave_duration", &"shockwave_end_radius",
	&"shockwave_slow_duration", &"shockwave_slow_multiplier", &"shockwave_full_only",
	&"zone_duration", &"zone_tick_interval", &"zone_damage", &"zone_slow_duration", &"zone_slow_multiplier",
	&"tick_interval",
	&"empowered_damage_multiplier", &"empowered_speed_multiplier", &"blind_charges",
	&"target_scope", &"heal_ratio", &"max_health_ratio", &"heal_multiplier", &"overheal_shield_ratio", &"global_heal",
]
## building_only: true 时只攻击建筑（塔+建筑卡），无视普通单位
## can_attack_air: false 时无法选中/攻击空中单位（近战地面单位通常不能对空）
## is_continuous_attack: true 时持续伤害（DPS模式，每固定Tick累计 damage*dt，按目标保留余量扣整数）

## 数量字段含嵌套数组；其他玩法数值最多两位，比例按百分数最多两位。
const INTEGER_NUMBER_FIELDS := ["hp", "damage", "heal_amount", "on_hit_tower_damage", "deploy_sweep_damage", "shield", "resource_shield_max", "full_resource_cast_end_heal", "shockwave_damage", "zone_damage", "resource_damage_by_stacks", "resource_hit_damage_sequences", "cost", "active_cost_bonus", "spawn_count", "death_spawn_count", "deployment_count", "max_uses", "blind_charges", "heal_every_hits", "transform_after_hits", "revert_after_hits", "death_replacement_charges", "timed_revival_death_replacement_charges", "projectile_count"]

## 原始定义域归属；共享容器由 CardDefinitionCompiler 递归检查。
const CARD_VISUAL_FIELDS := ["active_buff_projectile_visual", "attack_interval_display", "color", "continuous_beam_color", "continuous_beam_end_width", "continuous_beam_forward_offset", "continuous_beam_origin_height", "continuous_beam_start_width", "death_replacement_visual_transition", "projectile_colors", "projectile_impact_visual", "projectile_visual", "projectile_visual_forward_offset", "projectile_visual_height", "projectile_visual_scale", "show_team_ring", "skill_resource_full_color", "timed_revival_visual_transition", "visual_active_buff_scene", "visual_animations", "visual_forward_yaw", "visual_radius", "visual_scene_path", "visual_scene_paths"]
const SKILL_VISUAL_FIELDS := ["full_resource_visual_action", "projectile_visual", "projectile_visual_forward_offset", "projectile_visual_height", "projectile_visual_width", "resource_visual_actions", "visual_action"]
