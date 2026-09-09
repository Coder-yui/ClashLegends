class_name CardDB
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
	"hp": 2100.0, "damage": 55.0, "range": 240.0, "interval": 0.8,
	"footprint_tiles": Vector2i(3, 3),
	"radius": 54.0, "visual_radius": 60.0,
	"first_hit": 0.2, "projectile_speed": 420.0,
	"projectile_visual_offset": PRINCESS_TOWER_PROJECTILE_VISUAL_OFFSET,
}
const NEXUS_STATS := {
	"hp": 3600.0, "damage": 0.0, "range": 0.0, "interval": 1.0,
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
			{"bones": "Break1", "surface": "Broken1", "window": [10.0, 15.0]},
			{"bones": "Break2", "surface": "Broken2", "window": [8.0, 15.0]},
			{"bones": "Break3", "surface": "Broken3", "window": [8.0, 15.0]},
		],
		"debris_duration": 2.0,
	},
}
const NEXUS_VISUAL_CONFIG := {
	"scene_paths": [
		"res://assets/towers/nexus/nexus_blue_view.tscn",
		"res://assets/towers/nexus/nexus_red_view.tscn",
	],
	"ground_cutoff": 0.0,
	"animations": {
		"spawn": "Nexus_spawn_anm", "idle": "Idle1_Base", "destroy": "Death",
		"spawn_duration": 2.5, "destroy_duration": 4.0,
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
const ACTIVE_SKILL_KINDS := [&"nova", &"buff", &"summon", &"dual_form", &"frontal", &"forward_area", &"continuous_area", &"empowered_attack", &"attack_lifesteal", &"area_shield"]
const ACTIVE_SKILL_TARGET_SCOPES := [&"self", &"deployment_group"]
const CAST_LOCKS := [&"movement", &"attack", &"facing"]
const VISUAL_ACTION_KINDS := [&"deploy", &"transform", &"skill"]
const VISUAL_ACTION_DESCRIPTOR_FIELDS := [&"animation", &"durations", &"clip_ranges", &"kind", &"priority", &"blend_in", &"blend_out", &"sequence_blend"]
const VISUAL_TRANSITION_DESCRIPTOR_FIELDS := [&"animation", &"blend_in", &"blend_out"]
const TRANSITION_BLEND_FIELDS := [&"default", &"locomotion", &"action_in", &"action_out", &"attack", &"sequence", &"death", &"model_swap"]

## Validator 会检测未知或未登记字段。新增字段必须同时实现运行时读取逻辑、
## validator 登记和对应机制测试，防止只把配置写进 CardDB、却忘记接入权威模拟或表现层。
const CARD_FIELDS := [
	&"name", &"cost", &"type", &"description", &"selectable",
	&"hp", &"damage", &"range", &"speed", &"interval", &"first_hit",
	&"size_tier", &"radius", &"visual_radius", &"mass", &"sight", &"color",
	&"is_air", &"is_building", &"building_only", &"can_attack_air", &"is_continuous_attack",
	&"deploy_time", &"pre_deploy_time", &"deploy_zone", &"deploy_ignore_structures", &"show_team_ring", &"footprint_tiles", &"lifespan", &"lifespan_hp_decay", &"tower_ruin_foundation",
	&"deployment_count", &"deployment_spacing",
	&"spawn_id", &"spawn_interval", &"spawn_count", &"spawn_side", &"death_spawn_id", &"death_spawn_count",
	&"death_replacement_id", &"death_replacement_charges", &"death_replacement_visual_transition", &"timed_revival_id", &"timed_revival_delay", &"timed_revival_death_replacement_charges", &"timed_revival_visual_transition",
	&"projectile_speed", &"projectile_visual", &"projectile_visual_height",
	&"projectile_visual_forward_offset", &"projectile_visual_scale", &"projectile_impact_visual",
	&"projectile_colors", &"splash_radius", &"knockback",
	&"continuous_beam_color", &"continuous_beam_start_width", &"continuous_beam_end_width",
	&"continuous_beam_origin_height", &"continuous_beam_forward_offset",
	&"deploy_sweep_name", &"deploy_sweep_radius", &"deploy_sweep_damage", &"deploy_sweep_knockback",
	&"deploy_sweep_duration", &"deploy_sweep_mass_factor_max",
	&"heal_every_hits", &"heal_amount", &"charge_time", &"charge_speed_multiplier",
	&"charge_damage_multiplier", &"shroud_radius", &"attack_pattern", &"attack_damage_multipliers", &"first_strike_damage_multiplier",
	&"attack_extra_hit_damage_multipliers", &"attack_extra_hit_delays",
	&"cancel_attack_recovery_without_target",
	&"skill_resource_max", &"skill_resource_attack_gain", &"skill_resource_hit_gain", &"skill_resource_kill_gain", &"skill_resource_full_color",
	&"skill_resource_damage_gain_multiplier", &"skill_resource_decay_delay", &"skill_resource_decay_rate",
	&"attack_interval_display", &"transform_after_hits", &"revert_after_hits",
	&"transform_duration", &"active_transform_duration", &"revert_duration", &"transformed_stats",
	&"spell_kind", &"duration", &"active_name", &"active_slow_duration", &"active_slow_multiplier", &"active_skills",
	&"heal_amount", &"active_heal_multiplier", &"active_shield", &"active_shield_duration", &"active_cost_bonus",
	&"visual_scene_path", &"visual_scene_paths", &"visual_forward_yaw", &"visual_animations", &"audio",
]
const AUDIO_FIELDS := [&"attack_swing", &"attack_hit", &"attack_swing_volume_db", &"attack_hit_volume_db"]
const VISUAL_ANIMATION_FIELDS := [
	&"deploy", &"deploy_durations", &"deploy_clip_ratio", &"idle", &"idle_cycle", &"move", &"move_enter", &"haste_move",
	&"move_cycle", &"attack", &"attack_enter", &"attack_retarget_enter", &"attack_loop",
	&"attack_hit", &"attack_hit_duration", &"attack_recover", &"attack_recover_delay",
	&"attack_structure", &"attack_move", &"attack_to_move",
	&"empowered_move", &"empowered_attack", &"empowered_attack_hit", &"empowered_attack_recover",
	&"empowered_attack_to_move", &"death", &"death_duration",
	&"death_followup_scene_path", &"death_followup_animation", &"death_followup_duration", &"visual_actions",
	&"visual_action_durations", &"transitions", &"transition_blends",
]
const ACTIVE_SKILL_FIELDS := [
	&"name", &"kind", &"cost", &"max_uses", &"cooldown", &"radius", &"damage", &"knockback", &"knockback_duration", &"knockback_mass_factor_max",
	&"slow_duration", &"slow_multiplier",
	&"shield", &"shield_duration", &"shield_decay", &"shield_on_cast_start", &"resource_shield_max", &"duration", &"speed_multiplier", &"damage_multiplier",
	&"attack_speed_multiplier", &"spawn_id", &"spawn_count", &"length", &"width", &"impact_delay",
	&"transform_impact_delay", &"cast_duration", &"transform_cast_duration", &"stun_duration", &"ground_only",
	&"cast_locks", &"visual_action", &"description", &"shape", &"near_width", &"far_width", &"arc_degrees", &"fan_inner_arc",
	&"projectile_count", &"projectile_visual", &"projectile_launch_delay", &"projectile_flight_duration",
	&"projectile_visual_height", &"projectile_visual_forward_offset", &"projectile_visual_width",
	&"center_ratio", &"center_width", &"center_damage_multiplier", &"resource_damage_scale_max",
	&"uses_skill_resource", &"resource_damage_by_stacks", &"resource_full_damage_multiplier", &"resource_full_stun_multiplier",
	&"resource_visual_actions", &"resource_hit_damage_sequences", &"resource_hit_delay_sequences",
	&"full_resource_visual_action", &"full_resource_cast_duration", &"full_resource_impact_delay", &"full_resource_cast_end_heal",
	&"forward_distance", &"shockwave_damage", &"shockwave_duration", &"shockwave_end_radius",
	&"shockwave_slow_duration", &"shockwave_slow_multiplier", &"shockwave_full_only",
	&"zone_duration", &"zone_tick_interval", &"zone_damage", &"zone_slow_duration", &"zone_slow_multiplier",
	&"tick_interval",
	&"empowered_damage_multiplier", &"empowered_speed_multiplier", &"blind_charges",
	&"target_scope", &"heal_ratio", &"max_health_ratio",
]
## building_only: true 时只攻击建筑（塔+建筑卡），无视普通单位
## can_attack_air: false 时无法选中/攻击空中单位（近战地面单位通常不能对空）
## is_continuous_attack: true 时持续伤害（DPS模式，每帧造成 damage*delta）

static func all() -> Dictionary:
	return {
		# ===== 原有4张 =====
		"garen": {
			"name": "盖伦", "cost": 5, "type": "unit",
			"description": "高生命值的近战战士，专注攻击建筑，适合在前线持续推进。",
			"hp": 1050.0, "damage": 88.0, "range": MELEE_RANGE_MIN,
			# 命中位于攻击周期约 35% 处，给挥剑留出短前摇，把较长时间留给收招。
			"speed": SPEED_SLOW, "interval": 1.1, "first_hit": 0.38,
			"size_tier": SIZE_LARGE, "radius": RADIUS_LARGE, "visual_radius": RADIUS_LARGE + VISUAL_RADIUS_PADDING,
			"mass": 8.0, "sight": 220.0,
			"color": Color(0.35, 0.55, 0.90),
			"visual_scene_path": "res://assets/units/garen/garen_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn_Base", "idle": "Idle1_Base",
				"move": "Run_Base", "empowered_move": "Run_Spell1",
				"attack": ["Attack1", "Attack2"], "empowered_attack": "Spell1",
				"visual_actions": {
					"judgment": {"animation": "Spell3_0", "durations": [3.0], "kind": "skill"},
				},
				"death": "Death", "death_duration": 0.8,
			},
			"audio": {
				# 两套挥剑动作分别使用原事件的 4 个 OnCast 变体；命中使用共享 OnHit 池。
				"attack_swing": [
					[
						"res://assets/audio/units/garen/garen_basic_attack_swing_01.wav",
						"res://assets/audio/units/garen/garen_basic_attack_swing_02.wav",
						"res://assets/audio/units/garen/garen_basic_attack_swing_03.wav",
						"res://assets/audio/units/garen/garen_basic_attack_swing_04.wav",
					],
					[
						"res://assets/audio/units/garen/garen_basic_attack_swing_05.wav",
						"res://assets/audio/units/garen/garen_basic_attack_swing_06.wav",
						"res://assets/audio/units/garen/garen_basic_attack_swing_07.wav",
						"res://assets/audio/units/garen/garen_basic_attack_swing_08.wav",
					],
				],
				"attack_hit": [
					"res://assets/audio/units/garen/garen_basic_attack_hit_01.wav",
					"res://assets/audio/units/garen/garen_basic_attack_hit_02.wav",
					"res://assets/audio/units/garen/garen_basic_attack_hit_03.wav",
					"res://assets/audio/units/garen/garen_basic_attack_hit_04.wav",
					"res://assets/audio/units/garen/garen_basic_attack_hit_05.wav",
					"res://assets/audio/units/garen/garen_basic_attack_hit_06.wav",
					"res://assets/audio/units/garen/garen_basic_attack_hit_07.wav",
					"res://assets/audio/units/garen/garen_basic_attack_hit_08.wav",
					"res://assets/audio/units/garen/garen_basic_attack_hit_09.wav",
					"res://assets/audio/units/garen/garen_basic_attack_hit_10.wav",
					"res://assets/audio/units/garen/garen_basic_attack_hit_11.wav",
					"res://assets/audio/units/garen/garen_basic_attack_hit_12.wav",
					"res://assets/audio/units/garen/garen_basic_attack_hit_13.wav",
					"res://assets/audio/units/garen/garen_basic_attack_hit_14.wav",
					"res://assets/audio/units/garen/garen_basic_attack_hit_15.wav",
					"res://assets/audio/units/garen/garen_basic_attack_hit_16.wav",
				],
				"attack_swing_volume_db": -5.0,
				"attack_hit_volume_db": -4.0,
			},
			"is_air": false, "building_only": true, "can_attack_air": false,
			"active_skills": [
				{
					"name": "致命打击", "kind": "empowered_attack",
					"cost": 1, "max_uses": 2, "cooldown": 6.0,
					"description": "强化下一次普通攻击，使其造成双倍伤害；强化尚未打出时移动速度提高两档。技能不会重置或延后当前攻击节奏。",
					"empowered_damage_multiplier": 2.0,
					# 盖伦基础为“慢”，提高两档后达到“中等”。强化攻击出手后立即失去加速。
					"empowered_speed_multiplier": SPEED_MEDIUM / SPEED_SLOW,
				},
				{
					"name": "审判", "kind": "continuous_area",
					"cost": 2, "max_uses": 1, "cooldown": 10.0,
					"description": "旋转 3 秒，对当前身边的地面敌人每秒造成 60 点伤害；施放期间只锁定攻击，仍可移动和改变朝向。",
					"radius": 90.0, "damage": 60.0, "ground_only": true,
					"duration": 3.0, "tick_interval": 1.0,
					"impact_delay": 0.0, "cast_duration": 3.0,
					"cast_locks": ["attack"], "visual_action": "judgment",
				},
			],
		},
		"xin": {
			"name": "赵信", "cost": 4, "type": "unit",
			"description": "近战战士，部署时发动新月护卫伤害并击退周围地面敌人，连续攻击还能恢复生命。",
			"hp": 620.0, "damage": 68.0, "range": 40.0,
			"speed": SPEED_SLIGHTLY_FAST, "interval": 0.9, "first_hit": 0.3,
			"deploy_time": 1.0,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"mass": 5.0, "sight": 220.0,
			# 部署时发动新月护卫：1 秒部署阶段只播放 Spell4，生成当帧立即伤害并击退四周地面敌人。
			# 期间不能移动和攻击，但可被索敌、碰撞和命中。
			# 建筑/防御塔会受伤但不会被击退；轻单位的质量倍率封顶 1.0，避免超过基础击退距离。
			"deploy_sweep_name": "新月护卫（部署）",
			"deploy_sweep_radius": 90.0,
			"deploy_sweep_damage": 90.0,
			"deploy_sweep_knockback": 90.0,
			"deploy_sweep_duration": 0.25,
			"deploy_sweep_mass_factor_max": 1.0,
			# 无畏战吼：三段普攻循环中的第三击（Passive_AA_01）命中时回复少许生命值。
			"heal_every_hits": 3, "heal_amount": 60.0,
			"color": Color(0.85, 0.30, 0.25),
			"visual_scene_path": "res://assets/units/xin/xin_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				# 部署与主动新月护卫都使用完整 1 秒 Spell4；动作本身不驱动权威效果。
				"deploy": "Spell4",
				"idle": "IdleBase", "move": "RunBase", "move_enter": "RunIn",
				# 前两段按 Hit→settle 播放；第三段只使用完整 Passive_AA_01，不再播放其 hit 前置片段。
				"attack": ["Attack1_Hit", "Attack3_Hit", "Passive_AA_01_XinZhaoRework_anm"],
				"attack_hit": [
					"Attack_AA_01_settle_XinZhaoRework_anm",
					"Attack_AA_03_settle_XinZhaoRework_anm",
					"",
				],
				"attack_hit_duration": 0.6,
				# 第一、二段攻击复用通用 RunIn；第三段被动攻击使用素材专用转跑动作。
				"attack_to_move": ["", "", "PassiveAA_to_Run_XinZhaoRework_anm"],
				"visual_actions": {
					"active": {"animation": "Spell4", "durations": [1.0], "kind": "skill"},
				},
				"transitions": {
					"deploy>move": "Spell4_To_Run",
					"skill>move": "Spell4_To_Run",
				},
				"death": "Death", "death_duration": 0.8,
			},
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{
				"name": "新月护卫", "kind": "nova",
				"cost": 1, "max_uses": 2, "cooldown": 8.0,
				"description": "挥舞长枪震开周围敌人，造成范围伤害与击退；施放期间锁定移动、攻击和朝向。",
				"radius": 90.0, "damage": 90.0, "knockback": 90.0,
				"knockback_duration": 0.25, "knockback_mass_factor_max": 1.0,
				"ground_only": true,
				"impact_delay": 0.0, "cast_duration": 1.0,
				"cast_locks": ["movement", "attack", "facing"],
				"visual_action": "active",
			}],
		},
		"ashe": {
			"name": "艾希", "cost": 3, "type": "unit",
			"description": "远程射手，能攻击空中和地面目标，在安全距离持续输出。",
			"hp": 340.0, "damage": 58.0, "range": 170.0,
			# Attack1/2 的箭矢在素材约 44% 处离弦；first_hit 表示动画开始到弹体生成的时间。
			"speed": SPEED_SLIGHTLY_SLOW, "interval": 1.0, "first_hit": 0.45,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"mass": 3.0, "sight": 240.0,
			"projectile_speed": 480.0,
			"projectile_visual": "arrow",
			# 只影响弹体绘制高度：寒冰离弦时弓位于地面原点上方约 30px。
			"projectile_visual_height": 30.0 * CHARACTER_SCALE_MULTIPLIER,
			"color": Color(0.50, 0.85, 0.95),
			"visual_scene_path": "res://assets/units/ashe/ashe_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Idle1", "idle": "Idle1", "move": "Run",
				"attack": ["Attack1", "Attack2"],
				"visual_actions": {
					"active": {"animation": "Spell2", "kind": "skill", "durations": [1.0], "blend_in": 0.05, "blend_out": 0.10},
				},
				"death": "Death", "death_duration": 0.8,
			},
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{
				"name": "万箭齐发", "kind": "frontal", "shape": "fan",
				"cost": 2, "max_uses": 1, "cooldown": 10.0,
				"description": "使用 Spell2 朝前方扇形区域射出 8 根箭矢，造成 70 点伤害并减速 1 秒。",
				"length": 190.0, "arc_degrees": 72.0, "projectile_count": 8, "fan_inner_arc": true,
				"damage": 70.0, "slow_duration": 1.0, "slow_multiplier": 0.55,
				"impact_delay": 0.62, "cast_duration": 1.833333,
				"cast_locks": ["movement", "attack", "facing"], "visual_action": "active",
			}],
		},
		"teemo": {
			"name": "提莫", "cost": 2, "type": "unit",
			"description": "灵活的远程射手，移速较快，擅长用毒针干扰敌人。",
			"hp": 230.0, "damage": 38.0, "range": 160.0,
			"speed": SPEED_FAST, "interval": 1.0, "first_hit": 0.25,
			"size_tier": SIZE_SMALL, "radius": RADIUS_SMALL, "visual_radius": RADIUS_SMALL + VISUAL_RADIUS_PADDING,
			"mass": 2.0, "sight": 210.0,
			"projectile_speed": 380.0,
			"projectile_visual": "needle",
			# 提莫身形较矮，吹箭从约 28px 高的吹管口出现；暂用短绿色线段代替正式毒针素材。
			"projectile_visual_height": 28.0 * CHARACTER_SCALE_MULTIPLIER,
			"color": Color(0.60, 0.80, 0.30),
			"visual_scene_path": "res://assets/units/teemo/teemo_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn", "idle": "Idle1_Base", "move": "Run_Base", "move_enter": "Run_In_ASU_Teemo_anm",
				# Attack1 播放完的离弦点创建弹体，随后切入 Attack1_ToIdle 完成后摇。
				"attack": ["Attack1_ASU_Teemo_anm"], "attack_hit": ["Attack1_ToIdle"],
				"attack_hit_duration": 0.75,
				"empowered_attack": "Spell1", "empowered_attack_hit": "Spell1_ToIdle",
				"empowered_attack_to_move": "Spell1_ToRun",
				"death": "Death", "death_duration": 0.8,
			},
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{
				"name": "致盲", "kind": "empowered_attack",
				"cost": 0, "max_uses": 2, "cooldown": 4.0,
				"description": "强化下一次普通攻击；命中单位后使其接下来的两次普通攻击（包括强化普攻）不造成伤害。技能不改变攻击间隔。",
				"empowered_damage_multiplier": 1.0, "blind_charges": 2,
			}],
		},
		"gnar": {
			"name": "纳尔", "cost": 4, "type": "unit",
			"description": "循环双形态战士。小纳尔第6次命中变大，大纳尔第4次命中变小；小形态远程对空，大形态极大近战。",
			# 默认形态：小纳尔。投掷回旋镖的权威弹体抵达目标后才结算伤害和被动层数。
			"hp": 430.0, "damage": 50.0, "range": 150.0,
			"speed": SPEED_FAST, "interval": 0.85, "first_hit": 0.30,
			"size_tier": SIZE_SMALL, "radius": RADIUS_SMALL,
			"visual_radius": RADIUS_SMALL + VISUAL_RADIUS_PADDING,
			"mass": 2.5, "sight": 230.0,
			"projectile_speed": 420.0, "projectile_visual": "boomerang",
			"projectile_visual_height": 30.0 * CHARACTER_SCALE_MULTIPLIER,
			"color": Color(0.93, 0.58, 0.18),
			"visual_scene_path": "res://assets/units/gnar/gnar_small_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn", "idle": "Idle1_Base",
				"move": "Run_Base", "move_enter": "Run1_In",
				"attack": ["Gnar_Attack1_anm", "Gnar_Attack2_anm"],
				"death": "Death", "death_duration": 0.8,
				"visual_actions": {
					"revert": {
						"animation": "gnar_runtime/Revert_Transform", "kind": "transform",
						"durations": [1.333333], "blend_out": 0.12,
					},
				},
			},
			"is_air": false, "building_only": false, "can_attack_air": true,
			"transform_after_hits": 6,
			"revert_after_hits": 4,
			"transform_duration": 1.5,
			"active_transform_duration": 1.2,
			"revert_duration": 1.333333,
			# 变身只替换权威战斗字段与表现映射；单位、net_id 和主动技能归属保持不变。
			"transformed_stats": {
				"name": "大纳尔",
				"hp": 820.0, "damage": 85.0, "range": MELEE_RANGE_MIN,
				"speed": SPEED_SLIGHTLY_SLOW, "interval": 1.15, "first_hit": 0.40,
				"size_tier": SIZE_EXTREMELY_LARGE, "radius": RADIUS_EXTREMELY_LARGE,
				"visual_radius": RADIUS_EXTREMELY_LARGE + VISUAL_RADIUS_PADDING,
				"mass": 9.0, "sight": 210.0,
				"projectile_speed": 0.0, "projectile_visual": "orb",
				"projectile_visual_height": 0.0,
				"is_air": false, "building_only": false, "can_attack_air": false,
				"visual_scene_path": "res://assets/units/gnar/gnar_mega_view.tscn",
				"visual_forward_yaw": 0.0,
				"visual_animations": {
					"deploy": "Idle1_Base", "idle": "Idle1_Base",
					"move": "Run_Base", "move_enter": "Run_In",
					"attack": ["GnarBig_Attack1_anm", "GnarBig_Attack2_anm"],
					"attack_structure": ["GnarBig_Turret_Attack01_anm", "GnarBig_Turret_Attack_Fast_anm"],
					"death": "GnarBig_Death_anm", "death_duration": 0.27,
					"death_followup_scene_path": "res://assets/units/gnar/gnar_small_view.tscn",
					"death_followup_animation": "Death",
					"death_followup_duration": 0.8,
					"visual_actions": {
						"transform": {
							"animation": "gnar_runtime/Rage_Transform", "kind": "transform",
							"durations": [1.5], "blend_out": 0.12,
						},
						"transform_active": {
							"animation": "gnar_runtime/Rage_Spell2_Transform", "kind": "transform",
							"durations": [1.2], "blend_out": 0.12,
						},
						"active": {
							"animation": "GnarBig_Spell2_anm", "kind": "skill",
							"durations": [1.2], "blend_in": 0.06, "blend_out": 0.12,
						},
					},
				},
			},
			"active_skills": [{
				"name": "怒气爆发", "kind": "dual_form",
				"cost": 2, "max_uses": 1, "cooldown": 8.0,
				"description": "当前形态立即释放前方重击；小形态会先变为大形态。命中时造成伤害并眩晕地面敌人。",
				"length": 140.0, "width": 60.0, "damage": 120.0,
				# 两种 Spell2 主体动作均从施法首帧开始，0.8s 手掌触地。
				"impact_delay": 0.8, "transform_impact_delay": 0.8,
				"cast_duration": 1.2, "transform_cast_duration": 1.2,
				"stun_duration": 1.0, "ground_only": true,
				"cast_locks": ["movement", "attack", "facing"], "visual_action": "active",
			}],
		},
		# ===== 水晶兵线（也可作为玩家卡牌） =====
		"melee_minion": {
			"name": "近战兵", "cost": 1, "type": "unit", "selectable": true,
			"description": "基础近战单位，适合成群推进并为后排吸收伤害。",
			"hp": 210.0, "damage": 42.0, "range": MELEE_RANGE_MIN,
			"speed": SPEED_MEDIUM, "interval": 1.0, "first_hit": 0.32,
			"size_tier": SIZE_SMALL, "radius": RADIUS_SMALL,
			"visual_radius": RADIUS_SMALL + VISUAL_RADIUS_PADDING,
			"mass": 2.0, "sight": 180.0,
			"color": Color(0.58, 0.62, 0.70),
			"visual_scene_paths": [
				"res://assets/units/melee_minion/melee_minion_order_view.tscn",
				"res://assets/units/melee_minion/melee_minion_chaos_view.tscn",
			],
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Idle1", "idle": "Idle1", "move": "Run",
				"attack": ["Attack1", "Attack2"], "death": "Death", "death_duration": 0.5,
			},
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{"name": "列阵突击", "kind": "buff", "cost": 0, "max_uses": 2, "cooldown": 5.0, "duration": 4.0, "speed_multiplier": 1.35, "damage_multiplier": 1.25}],
		},
		"ranged_minion": {
			"name": "远程兵", "cost": 1, "type": "unit", "selectable": true,
			"description": "后排远程单位，能够攻击空中和地面目标并持续输出。",
			"hp": 135.0, "damage": 32.0, "range": 150.0,
			# Attack1/2 约在动作前段举杖发射；first_hit 是权威弹体生成时刻。
			"speed": SPEED_MEDIUM, "interval": 1.25, "first_hit": 0.42,
			"size_tier": SIZE_SMALL, "radius": RADIUS_SMALL,
			"visual_radius": RADIUS_SMALL + VISUAL_RADIUS_PADDING,
			"mass": 1.8, "sight": 210.0,
			"projectile_speed": 360.0, "projectile_visual": "orb",
			# 权杖高度与前向偏移只决定小光球的绘制起点，不参与伤害、碰撞或射程。
			"projectile_visual_height": 19.0,
			"projectile_visual_forward_offset": 10.0,
			"projectile_colors": [Color(0.18, 0.66, 1.0), Color(1.0, 0.18, 0.22)],
			"color": Color(0.58, 0.62, 0.70),
			"visual_scene_paths": [
				"res://assets/units/ranged_minion/ranged_minion_order_view.tscn",
				"res://assets/units/ranged_minion/ranged_minion_chaos_view.tscn",
			],
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Idle1", "idle": "Idle1", "move": "Run",
				"attack": ["Attack1", "Attack2"], "death": "Death", "death_duration": 0.5,
			},
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{"name": "奥术齐射", "kind": "nova", "cost": 0, "max_uses": 2, "cooldown": 5.0, "radius": 150.0, "damage": 48.0}],
		},
		"siege_minion": {
			"name": "炮车兵", "cost": 3, "type": "unit", "selectable": true,
			"description": "远程炮击单位，攻击距离较远，适合从后方压制敌方建筑。",
			"hp": 390.0, "damage": 58.0, "range": 170.0,
			"speed": SPEED_MEDIUM, "interval": 1.65, "first_hit": 0.55,
			"size_tier": SIZE_SLIGHTLY_SMALL, "radius": RADIUS_SLIGHTLY_SMALL,
			"visual_radius": RADIUS_SLIGHTLY_SMALL + VISUAL_RADIUS_PADDING,
			"mass": 4.5, "sight": 230.0,
			"projectile_speed": 310.0, "projectile_visual": "orb",
			# 黑色小炮弹从炮口高度、炮身前方出现；这些仍是纯表现偏移。
			"projectile_visual_height": 28.0,
			"projectile_visual_forward_offset": 24.0,
			"projectile_colors": [Color(0.055, 0.055, 0.06), Color(0.055, 0.055, 0.06)],
			"color": Color(0.38, 0.40, 0.44),
			"visual_scene_paths": [
				"res://assets/units/siege_minion/siege_minion_order_view.tscn",
				"res://assets/units/siege_minion/siege_minion_chaos_view.tscn",
			],
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Idle1", "idle": "Idle1", "move": "Run",
				"attack": ["Attack1_BASE", "Attack2_BASE"], "death": "Death", "death_duration": 0.5,
			},
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{"name": "超载炮击", "kind": "nova", "cost": 1, "max_uses": 2, "cooldown": 8.0, "radius": 180.0, "damage": 100.0, "knockback": 35.0}],
		},
		"super_minion": {
			"name": "超级兵", "cost": 4, "type": "unit", "selectable": true,
			"description": "强化型近战单位，生命和伤害更高，适合在一路形成突破。",
			"hp": 720.0, "damage": 72.0, "range": MELEE_RANGE_MIN,
			"speed": SPEED_MEDIUM, "interval": 1.15, "first_hit": 0.38,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"mass": 6.0, "sight": 200.0,
			"color": Color(0.52, 0.55, 0.62),
			"visual_scene_paths": [
				"res://assets/units/super_minion/super_minion_order_view.tscn",
				"res://assets/units/super_minion/super_minion_chaos_view.tscn",
			],
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Idle1", "idle": "Idle1", "move": "Run",
				"attack": ["Attack1", "Attack2"], "death": "Death_Base", "death_duration": 0.5,
			},
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{"name": "超级冲锋", "kind": "buff", "cost": 2, "max_uses": 1, "cooldown": 7.0, "duration": 5.0, "speed_multiplier": 1.35, "damage_multiplier": 1.35, "shield": 140.0, "shield_duration": 5.0}],
		},
		"pix": {
			"name": "皮克斯", "cost": 2, "type": "unit",
			"description": "一次部署五只皮克斯。体型极小的近距离空中射手，会发射紫色光弹。",
			# 生命和单次伤害都严格等于公主塔的一次攻击伤害。
			"hp": PRINCESS_TOWER_STATS.damage, "damage": PRINCESS_TOWER_STATS.damage,
			"range": 1.2 * 40.0,
			# Attack1/2 都约在 40% 处完成蓄势；first_hit 在固定模拟中生成光弹。
			"speed": SPEED_FAST, "interval": 1.0, "first_hit": 0.40,
			"size_tier": SIZE_EXTREMELY_SMALL, "radius": RADIUS_EXTREMELY_SMALL,
			"visual_radius": RADIUS_EXTREMELY_SMALL + VISUAL_RADIUS_PADDING,
			"mass": 1.0, "sight": 180.0,
			"deployment_count": 5, "deployment_spacing": 36.0,
			"projectile_speed": 360.0, "projectile_visual": "orb",
			# 统一悬空后的施法手位约在权威地面点上方 84px；只影响紫色光弹绘制起点。
			"projectile_visual_height": 84.0,
			"projectile_visual_forward_offset": 4.0,
			"projectile_colors": [Color(0.72, 0.24, 1.0), Color(0.72, 0.24, 1.0)],
			"color": Color(0.72, 0.24, 1.0),
			"visual_scene_path": "res://assets/units/pix/pix_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Idle1", "idle": "Idle1", "move": "Run",
				"attack": ["Attack1", "Attack2"],
			},
			"is_air": true, "building_only": false, "can_attack_air": true,
			"active_skills": [{
				"name": "仙灵汲取", "kind": "attack_lifesteal",
				"cost": 1, "max_uses": 1, "cooldown": 0.0,
				"target_scope": "deployment_group",
				"heal_ratio": 0.25, "max_health_ratio": 1.5,
				"description": "使这次部署中仍存活的所有皮克斯此后的每次普通攻击命中都回复该次伤害25%的生命；可溢出生命上限，最高达到150%。",
			}],
		},
		# ===== 新增4张 =====
		"freeze": {
			"name": "冰冻", "cost": 3, "type": "spell",
			"spell_kind": "freeze",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"description": "范围控制法术，冻结范围内的敌方单位，为己方争取进攻窗口。",
			"active_name": "强化冰冻",
			# 法术卡：不生成单位，在点击位置范围内冻结敌方单位3秒
			"radius": 110.0,    # 影响范围半径
			"duration": 3.0,    # 冰冻持续时间
			"active_slow_duration": 2.0,
			"active_slow_multiplier": 0.50,
			"color": Color(0.40, 0.70, 1.00),
		},
		"heal": {
			"name": "治疗术", "cost": 3, "type": "spell",
			"spell_kind": "heal",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"description": "范围治疗法术，立刻回复范围内友军单位的生命值；对建筑卡、防御塔和水晶无效。",
			"active_name": "强化治疗",
			# 法术卡：不生成单位，点击位置范围内友军单位立刻回复生命。
			"radius": 110.0,    # 影响范围半径
			"duration": 1.2,    # 治疗光效持续时间（治疗本身立即结算）
			"heal_amount": 300.0,
			# 强化治疗（主动槽）：费用 +1；全图友军单位获得略提高的治疗，范围内友军额外获得护盾（含建筑）。
			"active_cost_bonus": 1,
			"active_heal_multiplier": 1.25,
			"active_shield": 240.0,
			"active_shield_duration": 3.0,
			"color": Color(1.00, 0.93, 0.60),
		},
		"masteryi": {
			"name": "剑圣", "cost": 3, "type": "unit",
			"description": "高速近战刺客，攻击频率高，适合快速处理脆弱目标。",
			# 近战高攻速刺客：血薄但攻速极快
			"hp": 480.0, "damage": 52.0, "range": MELEE_RANGE_MIN,
			"speed": SPEED_EXTREMELY_FAST, "interval": 0.45, "first_hit": 0.2,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"mass": 4.0, "sight": 200.0,
			"color": Color(0.20, 0.80, 0.50),
			"visual_scene_path": "res://assets/units/masteryi/masteryi_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn", "idle": "masteryi_2013_idle1_anm",
				"move": "Run", "haste_move": "2013_Run_Haste",
				"attack": ["masteryi_2013_attack1_anm", "masteryi_2013_attack2_anm", "masteryi_2013_passive_anm"],
				"death": "Death", "death_duration": 0.8,
			},
			# 双重打击：第三段被动动作在首刀后追加一次 50% 伤害的普通攻击判定。
			"attack_extra_hit_damage_multipliers": [[], [], [0.5]],
			"attack_extra_hit_delays": [[], [], [0.12]],
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{"name": "高原血统", "kind": "buff", "cost": 1, "max_uses": 2, "cooldown": 6.0, "duration": 5.0, "speed_multiplier": 1.5, "damage_multiplier": 1.0, "attack_speed_multiplier": 1.5}],
		},
		"twisted_fate": {
			"name": "卡牌大师", "cost": 4, "type": "unit",
			"description": "远程法师，可攻击地面与空中目标；能在河道外的全图地面落点部署。",
			"hp": 460.0, "damage": 62.0, "range": 190.0,
			"speed": SPEED_MEDIUM, "interval": 1.2, "first_hit": 0.25,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"mass": 3.0, "sight": 250.0,
			"projectile_speed": 520.0, "projectile_visual": "orb", "projectile_visual_height": 60.0,
			"color": Color(0.34, 0.56, 0.92),
			# deploy_time 是单位出现后的部署锁定；pre_deploy_time 是出现前只显示卡牌落点提示的阶段。
			"deploy_time": 1.0, "pre_deploy_time": 1.0, "deploy_zone": "global",
			"visual_scene_path": "res://assets/units/twisted_fate/twisted_fate_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "twistedfate_2012_idle_enter_anm", "idle": "twistedfate_2012_idle1_anm",
				"move": "Run1",
				"attack": ["Attack1", "Attack2", "Attack3", "Attack4", "Spell3"],
				"visual_actions": {
					"wild_cards": {"animation": "Spell1", "durations": [0.9677415], "kind": "skill", "blend_in": 0.06, "blend_out": 0.10},
				},
				"death": "Death", "death_duration": 0.8,
			},
			# 第五次普攻使用 Spell3 动作，并在同一次攻击窗口追加 50% 伤害。
			"attack_extra_hit_damage_multipliers": [[], [], [], [], [0.5]],
			"attack_extra_hit_delays": [[], [], [], [], [0.12]],
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{
				"name": "万能牌", "kind": "frontal", "shape": "fan",
				"cost": 1, "max_uses": 2, "cooldown": 8.0,
				"description": "朝前方扇出 3 张牌，命中敌方地面或空中单位造成伤害。",
				"length": 190.0, "arc_degrees": 54.0, "projectile_count": 3, "projectile_visual": "card",
				# 纯表现卡牌在 Spell1 的出手 tick 生成，再飞到扇形末端；不驱动权威伤害。
				"projectile_launch_delay": 0.25, "projectile_flight_duration": 0.7177415,
				"damage": 100.0, "impact_delay": 0.25, "cast_duration": 0.9677415,
				"cast_locks": ["movement", "attack", "facing"], "visual_action": "wild_cards",
			}],
		},
		"gwen": {
			"name": "格温", "cost": 4, "type": "unit",
			"description": "近战刺客，首次普攻命中后进入缠流，能避开远处敌人的视野和锁定。",
			# 近战刺客：首次普攻命中后开启丝缕缠流；3 格（120px）外的敌方看不到她、不再把她当目标。
			"hp": 580.0, "damage": 62.0, "range": MELEE_RANGE_MIN,
			"speed": SPEED_FAST, "interval": 0.85, "first_hit": 0.28,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"mass": 4.0, "sight": 210.0,
			"shroud_radius": 120.0,   # 3 格 = 3 × 40px；贴身推塔时塔心仍在圈内，会被反击
			"skill_resource_max": 3.0, "skill_resource_hit_gain": 1.0,
			"skill_resource_full_color": Color(0.28, 0.72, 1.0, 0.96),
			"color": Color(0.95, 0.75, 0.85),
			"visual_scene_path": "res://assets/units/gwen/gwen_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn", "idle": "Idle_anm", "move": "Run_anm", "move_enter": "Into_Run",
				"attack": ["Attack1", "Attack2", "Attack3"],
				# 第一、二段攻击用普通 Into_Run；第三段攻击使用反向 180° 的专用转跑动作。
				"attack_to_move": ["Into_Run", "Into_Run", "INTO_Run_180_anm"],
				"death": "Death", "death_duration": 0.8,
				"visual_actions": {
					# Spell1_B 保持素材原本的 0.1667 秒，并从 Spell1_0 尾部持姿区占用等量时间；四档总时长固定为 1.5 秒。
					# 素材本身逐帧衔接，技能序列内部必须直接切换，不做 crossfade。
					"active_0": {"animation": ["Spell1_0", "Spell1_C_anm"], "durations": [0.9493669, 0.5506331], "kind": "skill", "sequence_blend": 0.0},
					"active_1": {"animation": ["Spell1_0", "Spell1_B", "Spell1_C_anm"], "durations": [0.7827002, 0.1666667, 0.5506331], "clip_ranges": [[0.0, 1.3740740], [0.0, 0.1666667], [0.0, 0.9666671]], "kind": "skill", "sequence_blend": 0.0},
					"active_2": {"animation": ["Spell1_0", "Spell1_B", "Spell1_B", "Spell1_C_anm"], "durations": [0.6160335, 0.1666667, 0.1666667, 0.5506331], "clip_ranges": [[0.0, 1.0814813], [0.0, 0.1666667], [0.0, 0.1666667], [0.0, 0.9666671]], "kind": "skill", "sequence_blend": 0.0},
					"active_3": {"animation": ["Spell1_0", "Spell1_B", "Spell1_B", "Spell1_B", "Spell1_C_anm"], "durations": [0.4493668, 0.1666667, 0.1666667, 0.1666667, 0.5506331], "clip_ranges": [[0.0, 0.7888886], [0.0, 0.1666667], [0.0, 0.1666667], [0.0, 0.1666667], [0.0, 0.9666671]], "kind": "skill", "sequence_blend": 0.0},
				},
				"transitions": {"skill>move": "Spell1_C_to_Run_anm"},
			},
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{
				"name": "快刀乱剪", "kind": "frontal", "shape": "fan",
				"cost": 2, "max_uses": 1, "cooldown": 8.0,
				"description": "普通攻击命中充能，最多 3 层；必定先剪 40 点、最后剪 60 点，每层充能在中间追加一次 20 点剪切。满层结束时回复 100 点生命值。",
				"uses_skill_resource": true,
				"length": 135.0, "arc_degrees": 78.0, "projectile_count": 0,
				"center_width": 30.0, "center_damage_multiplier": 1.2,
				"damage": 40.0,
				"resource_hit_damage_sequences": [[40.0, 60.0], [40.0, 20.0, 60.0], [40.0, 20.0, 20.0, 60.0], [40.0, 20.0, 20.0, 20.0, 60.0]],
				"resource_hit_delay_sequences": [[0.0949367, 1.0443036], [0.0949367, 0.9493669, 1.0443036], [0.0949367, 0.7827002, 0.9493669, 1.0443036], [0.0949367, 0.6160335, 0.7827002, 0.9493669, 1.0443036]],
				"impact_delay": 0.0949367, "cast_duration": 1.5,
				"cast_locks": ["movement", "attack", "facing"],
				"visual_action": "active_0", "resource_visual_actions": ["active_0", "active_1", "active_2", "active_3"],
				"full_resource_cast_end_heal": 100.0,
				"ground_only": true,
			}],
		},
		"sett": {
			"name": "腕豪", "cost": 4, "type": "unit",
			"description": "近战拳师，以快速双拳连招输出，第二拳造成更高伤害。",
			# 近战拳师：连招节奏——快速两拳→稍作停顿→再快速两拳→再停顿。
			"hp": 800.0, "damage": 72.0, "range": MELEE_RANGE_MIN,
			"speed": SPEED_MEDIUM, "interval": 1.1, "first_hit": 0.12,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE, "visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"mass": 6.0, "sight": 210.0,
			"attack_pattern": [0.28, 1.05, 0.28, 1.05],  # 两拳→停顿→两拳→停顿
			"attack_damage_multipliers": [1.0, 1.5, 1.0, 1.5],  # 左拳基础伤害，右拳为左拳的1.5倍
			# 两拳结束后没有下一次可攻击目标时立即追击，不播放被动段 Into_Idle 收势。
			"cancel_attack_recovery_without_target": true,
			# 豪意为通用技能资源：受实际生命伤害按 1:1、每次挥拳按固定值积攒；脱战后延迟衰减。
			"skill_resource_max": 200.0, "skill_resource_attack_gain": 20.0, "skill_resource_damage_gain_multiplier": 1.0,
			"skill_resource_decay_delay": 1.0, "skill_resource_decay_rate": 100.0,
			"skill_resource_full_color": Color(1.0, 0.82, 0.24, 0.96),
			"attack_interval_display": 1.05,  # 属性面板显示两拳结束后的循环间隔
			"color": Color(0.85, 0.55, 0.25),
			"visual_scene_path": "res://assets/units/sett/sett_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn", "idle": "Idle_Base", "move": "Run_Base",
				# 四次命中依次为：第一套左/右拳、第二套左/右拳；不再误用 Q 技能 Spell1。
				"attack": ["Attack1_Start", "Attack1_Passive_Start", "Attack2_Start", "Attack2_Passive_Start"],
				"attack_hit": ["Attack1_Hit", "Sett_Attack1_Passive_anm", "Attack2_Hit", "Sett_Attack2_Passive_anm"],
				"attack_recover": ["", "Attack1_Passive_Into_Idle", "", "Attack2_Passive_Into_Idle"],
				"attack_recover_delay": 0.32,
				# 第二、第四拳没有下一目标而提前追击时，使用被动拳专用转跑片段。
				"attack_move": ["Run_Passive", "Run_Base", "Run_Passive", "Run_Base"],
				"attack_to_move": ["", "Sett_Passive_INTO_Run_anm", "", "Sett_Passive_INTO_Run_anm"],
				"visual_actions": {
					"active": {"animation": "Sett_spell2_anm", "kind": "skill", "durations": [1.4]},
					"active_strong": {"animation": "Spell2_Strong", "kind": "skill", "durations": [1.4]},
				},
				"death": "Death", "death_duration": 0.8,
			},
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{
				"name": "蓄意轰拳", "kind": "frontal", "shape": "trapezoid",
				"description": "消耗 2 金币。锁定移动、朝向和攻击后向前轰出梯形冲击波；豪意令伤害最高提高至 2 倍，中央区域再造成 1.5 倍伤害。释放瞬间按豪意获得护盾，0 豪意无护盾，满豪意 300 点并在 2 秒内衰减至 0。每个腕豪最多释放 1 次，冷却 8 秒。",
				"cost": 2, "max_uses": 1, "cooldown": 8.0,
				"length": 155.0, "near_width": 54.0, "far_width": 170.0,
				"center_ratio": 0.34, "center_damage_multiplier": 1.5,
				"damage": 130.0, "resource_damage_scale_max": 2.0,
				"resource_shield_max": 300.0, "shield_duration": 2.0, "shield_on_cast_start": true, "shield_decay": true,
				"uses_skill_resource": true,
				"impact_delay": 0.72, "cast_duration": 1.4,
				"cast_locks": ["movement", "attack", "facing"],
				"visual_action": "active", "full_resource_visual_action": "active_strong",
				"ground_only": true,
			}],
		},
		"tombstone": {
			"name": "墓碑", "cost": 3, "type": "building",
			"description": "持续召唤小鬼的建筑，适合建立防守屏障并拖延敌军。",
			# 建筑卡：3x3 格部署占地；权威碰撞仍使用 radius=40 的圆柱，不可移动。
			# 完成部署立即生成两个小鬼，之后每 5 秒在地图中心线对应的一侧生成两个。
			"hp": 400.0, "damage": 0.0, "range": 0.0,
			"speed": 0.0, "interval": 1.0, "radius": 40.0,
			"footprint_tiles": Vector2i(3, 3),
			"color": Color(0.45, 0.40, 0.35),
			"is_air": false, "building_only": false, "can_attack_air": false,
			"is_building": true,
			"lifespan": 10.0,       # 存活时间（秒），到时自动消失
			"spawn_id": "imp",
			"spawn_interval": 5.0,  # 每隔多久生成一批小鬼
			"spawn_count": 2,
			"spawn_side": "map_side",
			"death_spawn_id": "imp",
			"death_spawn_count": 2,
			"show_team_ring": false,
			"visual_radius": 50.0,
			"visual_scene_path": "res://assets/units/tombstone/tombstone_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Spawn", "idle": "Idle1", "death": "Death", "death_duration": 0.8,
			},
			"active_skills": [{"name": "亡者集结", "kind": "summon", "cost": 1, "max_uses": 1, "cooldown": 10.0, "spawn_id": "imp", "spawn_count": 4}],
		},
		"apex_turret": {
			"name": "H-28Q尖端炮台", "cost": 5, "type": "building",
			"description": "强力的远程防守建筑。炮弹只攻击地面目标并造成小范围伤害，可额外发射两次穿透激光弹。",
			# 3x3 格部署占地，权威碰撞半径仍为 40；无外部伤害时，1450 生命会在 45 秒寿命内匀速衰减到 0。
			"hp": 1450.0, "damage": 130.0, "range": 220.0,
			"speed": 0.0, "interval": 1.5, "first_hit": 0.55,
			"radius": 40.0, "visual_radius": 55.0,
			"footprint_tiles": Vector2i(3, 3),
			"lifespan": 45.0, "lifespan_hp_decay": true,
			"projectile_speed": 420.0, "projectile_visual": "orb",
			"projectile_visual_height": 46.75, "projectile_visual_forward_offset": 46.75,
			"projectile_visual_scale": 2.25, "projectile_impact_visual": "splash_wave",
			"projectile_colors": [Color(1.0, 0.34, 0.08), Color(1.0, 0.22, 0.055)],
			"splash_radius": 32.0,
			"color": Color(0.20, 0.72, 0.86),
			"is_air": false, "building_only": false, "can_attack_air": false,
			"is_building": true, "show_team_ring": false,
			"visual_scene_path": "res://assets/units/apex_turret/apex_turret_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Spawn", "idle": "Idle1", "attack": "Attack1",
				"visual_actions": {
					"laser": {"animation": "Attack_Beam", "durations": [1.6666664], "kind": "skill"},
				},
				"death": "Death", "death_duration": 0.8,
			},
			"active_skills": [{
				"name": "海克斯穿透激光", "kind": "frontal", "shape": "trapezoid",
				"cost": 1, "max_uses": 2, "cooldown": 2.0,
				"description": "沿当前朝向发射一枚可穿透的激光弹，对 270（4.5格）长路径上的所有地面敌人造成 240 点伤害。",
				"length": 270.0, "near_width": 28.8, "far_width": 28.8,
				"damage": 240.0, "ground_only": true,
				# 激光在动作 0.45 秒时离开炮口，0.30 秒后到达路径末端并统一结算。
				"projectile_count": 1, "projectile_visual": "electromagnetic_wave", "projectile_visual_width": 28.8,
				"projectile_visual_height": 46.75, "projectile_visual_forward_offset": 46.75,
				"projectile_launch_delay": 0.45, "projectile_flight_duration": 0.30,
				"impact_delay": 0.75, "cast_duration": 1.6666664,
				"cast_locks": ["movement", "attack", "facing"], "visual_action": "laser",
			}],
		},
		"sun_disc": {
			"name": "太阳圆盘", "cost": 4, "type": "building",
			"description": "建立在防御塔废墟之上的远程建筑，可攻击空中与地面目标。主动为攻击范围内的友军提供护盾；建于塔墟时不再随时间失去生命。",
			# 普通地面部署时使用 40 秒建筑寿命；中心落在已毁防御塔九格内时，
			# tower_ruin_foundation 会保留完整生命且取消寿命倒计时。
			"hp": 1200.0, "damage": 105.0, "range": 220.0,
			"speed": 0.0, "interval": 1.4, "first_hit": 0.5,
			"radius": 40.0, "visual_radius": 60.0,
			"footprint_tiles": Vector2i(3, 3),
			"lifespan": 40.0, "lifespan_hp_decay": true,
			"tower_ruin_foundation": true,
			"projectile_speed": 440.0, "projectile_visual": "orb",
			# 圆盘中心约在权威地面点上方 154px；不沿目标方向偏移，保证双方镜像一致。
			"projectile_visual_height": 154.0, "projectile_visual_forward_offset": 0.0,
			"projectile_visual_scale": 1.65,
			"projectile_colors": [Color(1.0, 0.78, 0.18), Color(1.0, 0.52, 0.10)],
			"color": Color(0.96, 0.72, 0.16),
			"is_air": false, "building_only": false, "can_attack_air": true,
			"is_building": true, "show_team_ring": false,
			"visual_scene_paths": [
				"res://assets/units/sun_disc/sun_disc_blue_view.tscn",
				"res://assets/units/sun_disc/sun_disc_red_view.tscn",
			],
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Spawn",
				"idle": "Idle1_Base",
				"idle_cycle": ["Idle1_Base", "Idle1_Base", "Idle2_Base"],
				"attack": "Attack1_BASE",
				"death": "Death", "death_duration": 1.0,
			},
			"active_skills": [{
				"name": "日耀庇护", "kind": "area_shield",
				"cost": 1, "max_uses": 1, "cooldown": 0.0,
				"radius": 220.0, "shield": 180.0, "shield_duration": 6.0,
				"description": "立即为太阳圆盘攻击范围内的所有存活友军、友方建筑、防御塔与水晶提供 180 点护盾，持续 6 秒。每个圆盘只能使用 1 次。",
			}],
		},
		"aurelionsol": {
			"name": "龙王", "cost": 4, "type": "unit",
			"description": "空中持续输出单位，吐息能够同时压制目标及其周围敌人。",
			# 空中远程单位：持续喷吐龙息（DPS模式）
			"hp": 580.0, "damage": 55.0, "range": 130.0,
			"speed": SPEED_EXTREMELY_SLOW, "interval": 0.0, "first_hit": 0.0,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE, "visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"mass": 5.0, "sight": 250.0,
			"splash_radius": 34.0,
			"skill_resource_max": 5.0, "skill_resource_kill_gain": 1.0,
			"skill_resource_full_color": Color(0.58, 0.42, 1.0, 0.96),
			"color": Color(0.95, 0.75, 0.25),
			# 正式吐息素材接入前，用嘴部窄、目标端宽的半透明浅蓝梯形光柱占位。
			# 这些字段只控制 2D 表现，不参与持续伤害、范围或命中判定。
			"continuous_beam_color": Color(0.42, 0.84, 1.0, 0.70),
			"continuous_beam_start_width": 4.0,
			"continuous_beam_end_width": 14.0,
			"continuous_beam_origin_height": 78.0,
			"continuous_beam_forward_offset": 20.0,
			"visual_scene_path": "res://assets/units/aurelionsol/aurelionsol_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				# 只取 Respawn 前半段翻滚；后半段由普通状态机接管，不做龙王专用保护。
				"deploy": "Respawn", "deploy_clip_ratio": 0.5, "idle": "Idle1_Base",
				# RunIn 是部署、待机或无专用转跑素材的普攻进入移动时共用的通用衔接。
				"move": "Run1B", "move_enter": "RunIn",
				"move_cycle": ["Run1B", "Run1C", "Run1D", "Run1A"],
				# 移动后首次攻击用 newtst；原地击败目标并直接换目标时用 new_looptoin。
				"attack_enter": "AurelionSol_Spell1_newtst_anm",
				"attack_retarget_enter": ["AurelionSol_Spell1_new_looptoin_anm", "AurelionSol_Spell1_newtst_anm"],
				"attack_loop": "AurelionSol_Spell1_loop_anm",
				# 吐息后进入移动：Spell1_2Run 后摇 → Run1B→C→D→A。
				"transitions": {"attack>move": "Spell1_2Run"},
				"visual_actions": {
					"active": {"animation": "Spell4", "durations": [1.9333328], "kind": "skill"},
					"active_strong": {"animation": "AurelionSol_Spell4_base_anm", "durations": [1.8999995], "kind": "skill"},
				},
				"death": "Death", "death_duration": 0.8,
			},
			"is_air": true, "building_only": false, "can_attack_air": true,
			"is_continuous_attack": true,  # 持续伤害：每帧 damage*delta
			"active_skills": [{
				"name": "星落/天瀑", "kind": "forward_area",
				"cost": 2, "max_uses": 1, "cooldown": 10.0,
				"description": "击杀敌方单位充能，最多 5 层。向前方圆形区域降下星辰并眩晕；满层升级为伤害和眩晕提高 50% 的天瀑，且只有天瀑落地后会产生扩散至全场的冲击波。",
				"uses_skill_resource": true,
				"forward_distance": 175.0, "radius": 92.0,
				"damage": 120.0, "stun_duration": 1.2,
				"resource_full_damage_multiplier": 1.5, "resource_full_stun_multiplier": 1.5,
				"shockwave_damage": 55.0, "shockwave_duration": 1.4, "shockwave_end_radius": 1500.0,
				"shockwave_slow_duration": 2.0, "shockwave_slow_multiplier": 0.60, "shockwave_full_only": true,
				"impact_delay": 1.15, "cast_duration": 1.9333328,
				"full_resource_impact_delay": 1.12, "full_resource_cast_duration": 1.8999995,
				"cast_locks": ["movement", "attack", "facing"],
				"visual_action": "active", "full_resource_visual_action": "active_strong",
			}],
		},
		"anivia": {
			"name": "艾尼维亚（冰晶凤凰）", "cost": 5, "type": "unit",
			"description": "远程空中单位，攻速较慢；施放冰雪风暴在身前制造持续伤害与减速区域。被动可化为蛋，3秒未被击破后满血复活。",
			"hp": 620.0, "damage": 78.0, "range": 190.0,
			"speed": SPEED_EXTREMELY_SLOW, "interval": 1.4, "first_hit": 0.58,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE, "visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"mass": 5.0, "sight": 270.0,
			"projectile_speed": 420.0, "projectile_visual": "ice_cone", "projectile_visual_height": 62.0,
			"color": Color(0.45, 0.82, 1.0),
			"visual_scene_path": "res://assets/units/anivia/anivia_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Idle1", "idle": "Idle1", "move": "Run",
				"attack": ["Attack1", "Attack2"],
				"visual_actions": {
					"frost_storm": {"animation": "Spell4", "durations": [1.166667], "kind": "skill"},
				},
				"death": "Death", "death_duration": 2.4,
			},
			"is_air": true, "building_only": false, "can_attack_air": true,
			"death_replacement_id": "anivia_egg", "death_replacement_charges": 1, "death_replacement_visual_transition": "drop",
			"active_skills": [{
				"name": "冰雪风暴", "kind": "forward_area",
				"cost": 2, "max_uses": 1, "cooldown": 10.0,
				"description": "使用 Spell4 在身前创造冰雪风暴；落地造成伤害，区域持续 3 秒并周期性造成伤害与减速。施法期间锁定攻击、移动和朝向。",
				"forward_distance": 125.0, "radius": 86.0,
				"damage": 90.0, "stun_duration": 0.0, "slow_duration": 1.0, "slow_multiplier": 0.65,
				"zone_duration": 3.0, "zone_tick_interval": 1.0, "zone_damage": 42.0,
				"zone_slow_duration": 1.1, "zone_slow_multiplier": 0.60,
				"impact_delay": 0.72, "cast_duration": 1.166667,
				"cast_locks": ["movement", "attack", "facing"], "visual_action": "frost_storm",
			}],
		},
		"anivia_egg": {
			"name": "冰晶凤凰蛋", "cost": 0, "type": "unit", "selectable": false,
			"description": "冰晶凤凰被动复活期间的地面蛋形态；存活 3 秒后满血孵化。",
			"hp": PRINCESS_TOWER_STATS.damage * 3.0, "damage": 0.0, "range": 0.0,
			"speed": 0.0, "interval": 1.0,
			"size_tier": SIZE_SMALL, "radius": RADIUS_SMALL, "visual_radius": RADIUS_SMALL + VISUAL_RADIUS_PADDING,
			"mass": 3.0, "sight": 0.0,
			"color": Color(0.50, 0.86, 1.0),
			"visual_scene_path": "res://assets/units/anivia/anivia_egg_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Idle1", "idle": "Idle1", "death": "Death", "death_duration": 1.066667,
			},
			"is_air": false, "building_only": false, "can_attack_air": false,
			"timed_revival_id": "anivia", "timed_revival_delay": 3.0,
			"timed_revival_death_replacement_charges": 0, "timed_revival_visual_transition": "rebirth",
		},
		"missfortune": {
			"name": "赏金猎人", "cost": 3, "type": "unit",
			"description": "远程双枪射手，对每个敌方目标的首次攻击造成1.5倍伤害；主动技大步流星可短时提升移速与攻速。",
			# 远程双枪：Attack1/2 举枪射击的出手点在动作前段（约 12%），first_hit 按此调校。
			"hp": 380.0, "damage": 62.0, "range": 165.0,
			"speed": SPEED_MEDIUM, "interval": 0.95, "first_hit": 0.12,
			# 先声夺人：对每个敌方目标的首次普通攻击造成 1.5 倍伤害。
			"first_strike_damage_multiplier": 1.5,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"mass": 3.0, "sight": 230.0,
			"projectile_speed": 500.0, "projectile_visual": "orb",
			# 双枪枪口约在身高中段偏上；高度只影响弹体绘制起点，不参与权威判定。
			"projectile_visual_height": 52.0,
			"color": Color(0.80, 0.35, 0.60),
			"visual_scene_path": "res://assets/units/missfortune/missfortune_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn", "idle": "Idle1_Base", "move": "Run",
				# 大步流星生效期间（移速倍率 > 1）移动表现切换为 Run2，由通用 haste_move 机制驱动。
				"haste_move": "Run2",
				"attack": ["Attack1", "Attack2"],
				"death": "Death", "death_duration": 0.8,
			},
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{
				"name": "大步流星", "kind": "buff", "cost": 0, "max_uses": 1, "cooldown": 5.0,
				"duration": 3.0, "speed_multiplier": 1.5, "damage_multiplier": 1.0, "attack_speed_multiplier": 1.3,
			}],
		},
		# 系统召唤物仍属于 CardDB 数据，只通过 selectable=false 排除出玩家卡池。
		"imp": {
			"name": "小鬼", "cost": 0, "type": "unit", "selectable": false,
			"description": "墓碑及召唤技能生成的系统近战单位。",
			# 公主塔单次伤害为 55，小鬼落地后应恰好被防御塔一击击杀。
			"hp": 55.0, "damage": 25.0, "range": MELEE_RANGE_MIN,
			"speed": SPEED_SLIGHTLY_FAST, "interval": 0.7, "first_hit": 0.25,
			"deploy_time": 0.0,
			"size_tier": SIZE_EXTREMELY_SMALL, "radius": RADIUS_EXTREMELY_SMALL,
			"visual_radius": RADIUS_EXTREMELY_SMALL + VISUAL_RADIUS_PADDING,
			"mass": 1.0, "sight": 180.0,
			"color": Color(0.55, 0.45, 0.80),
			"visual_scene_path": "res://assets/units/imp/imp_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Spawn1", "idle": "Idle1", "move": "Run1",
				"attack": ["Yorick_ghoul_leapWindup_anm"],
				"death": "Death", "death_duration": 0.5,
			},
			"is_air": false, "building_only": false, "can_attack_air": false,
		},
	}

## 玩家卡池。保留 selectable 开关供未来纯系统单位使用；当前四类兵线单位也可选。
static func selectable_ids() -> Array:
	var ids: Array = []
	var cards := all()
	for card_id in cards:
		if bool(cards[card_id].get("selectable", true)):
			ids.append(card_id)
	return ids

## 统一读取入口。调用方在确认 has_card() 后可以安全读取；未知 id 返回空字典。
static func get_card(card_id: String) -> Dictionary:
	return all().get(card_id, {})

static func has_card(card_id: String) -> bool:
	return all().has(card_id)

## 只读取可生成的单位/建筑数据；系统召唤物同样是 selectable=false 的正式条目。
static func get_unit_stats(card_id: String) -> Dictionary:
	var stats := get_card(card_id)
	if StringName(stats.get("type", "")) not in [&"unit", &"building"]:
		return {}
	return stats

## 返回一张卡可供主动槽选择的技能集合；一次出战仍只从候选集合中携带一个。
static func active_skills_for(card_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cards := all()
	if not cards.has(card_id):
		return result
	var stats: Dictionary = cards[card_id]
	for configured_skill in stats.get("active_skills", []):
		if configured_skill is Dictionary:
			result.append((configured_skill as Dictionary).duplicate(true))
	return result

## 返回当前全部配置错误。空数组表示 CardDB 可以安全进入运行时。
static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	var cards := all()
	for raw_card_id in cards:
		var card_id := String(raw_card_id)
		var stats: Dictionary = cards[raw_card_id]
		_validate_card_id(card_id, errors)
		_validate_known_fields(card_id, stats, CARD_FIELDS, errors)
		_validate_card(card_id, stats, errors)
		_validate_references(card_id, stats, cards, errors)
	return errors

static func _validate_card_id(card_id: String, errors: PackedStringArray) -> void:
	if card_id.is_empty() or card_id != card_id.to_snake_case() or card_id.to_lower() != card_id:
		errors.append("%s: card_id 必须是非空英文 snake_case" % card_id)

static func _validate_card(card_id: String, stats: Dictionary, errors: PackedStringArray) -> void:
	_require_fields(card_id, stats, [&"name", &"cost", &"type", &"description", &"radius", &"color"], errors)
	var card_type := StringName(stats.get("type", ""))
	if card_type not in CARD_TYPES:
		errors.append("%s.type: 不支持的卡牌类型 %s" % [card_id, card_type])
		return
	if String(stats.get("name", "")).is_empty():
		errors.append("%s.name: 不能为空" % card_id)
	if float(stats.get("cost", -1.0)) < 0.0:
		errors.append("%s.cost: 必须 >= 0" % card_id)
	if float(stats.get("radius", 0.0)) <= 0.0:
		errors.append("%s.radius: 必须 > 0" % card_id)
	if stats.has("deploy_zone"):
		var dz := StringName(stats.get("deploy_zone", ""))
		if dz not in DEPLOY_ZONES:
			errors.append("%s.deploy_zone: 必须是 DEPLOY_ZONES 之一 (%s)" % [card_id, "、".join(DEPLOY_ZONES)])
	if stats.has("deploy_ignore_structures") and typeof(stats.deploy_ignore_structures) != TYPE_BOOL:
		errors.append("%s.deploy_ignore_structures: 必须是 bool" % card_id)
	if stats.has("pre_deploy_time") and float(stats.get("pre_deploy_time", 0.0)) < 0.0:
		errors.append("%s.pre_deploy_time: 必须 >= 0" % card_id)
	if float(stats.get("pre_deploy_time", 0.0)) > 0.0 and card_type == &"spell":
		errors.append("%s.pre_deploy_time: 法术不能使用单位预部署阶段" % card_id)
	if stats.has("deployment_count"):
		if card_type != &"unit":
			errors.append("%s.deployment_count: 只有单位卡可以编队部署" % card_id)
		var deployment_count := int(stats.get("deployment_count", 0))
		if deployment_count <= 0:
			errors.append("%s.deployment_count: 必须 > 0" % card_id)
		if deployment_count > 1 and float(stats.get("deployment_spacing", 0.0)) <= 0.0:
			errors.append("%s.deployment_spacing: 编队数量大于 1 时必须 > 0" % card_id)
	match card_type:
		&"unit":
			_validate_combat_stats(card_id, stats, true, errors)
		&"building":
			_validate_combat_stats(card_id, stats, false, errors)
			_validate_building(card_id, stats, errors)
		&"spell":
			_require_fields(card_id, stats, [&"spell_kind", &"duration"], errors)
			var spell_kind := StringName(stats.get("spell_kind", ""))
			if spell_kind not in SPELL_KINDS:
				errors.append("%s.spell_kind: 系统不支持 %s" % [card_id, spell_kind])
			if float(stats.get("duration", 0.0)) <= 0.0:
				errors.append("%s.duration: 法术持续时间必须 > 0" % card_id)
			match spell_kind:
				&"heal":
					if float(stats.get("heal_amount", 0.0)) <= 0.0:
						errors.append("%s.heal_amount: 治疗法术必须配置 > 0 的治疗量" % card_id)
					if stats.has("active_cost_bonus") and int(stats.active_cost_bonus) < 0:
						errors.append("%s.active_cost_bonus: 必须是 >= 0 的整数" % card_id)
					if stats.has("active_heal_multiplier") and float(stats.active_heal_multiplier) < 1.0:
						errors.append("%s.active_heal_multiplier: 强化治疗倍率必须 >= 1" % card_id)
					if stats.has("active_shield"):
						if float(stats.active_shield) <= 0.0:
							errors.append("%s.active_shield: 强化护盾必须 > 0" % card_id)
						elif float(stats.get("active_shield_duration", 0.0)) <= 0.0:
							errors.append("%s.active_shield_duration: 配置强化护盾时必须 > 0" % card_id)
	_validate_visual_config(card_id, stats, errors)
	_validate_audio_config(card_id, stats, errors)
	_validate_active_skills(card_id, stats, errors)
	if stats.has("transformed_stats"):
		var transformed = stats.get("transformed_stats")
		if not transformed is Dictionary or (transformed as Dictionary).is_empty():
			errors.append("%s.transformed_stats: 必须是非空 Dictionary" % card_id)
		else:
			_validate_known_fields("%s.transformed_stats" % card_id, transformed, CARD_FIELDS, errors)
			_validate_combat_stats("%s.transformed_stats" % card_id, transformed, true, errors)
			_validate_visual_config("%s.transformed_stats" % card_id, transformed, errors)
			_validate_audio_config("%s.transformed_stats" % card_id, transformed, errors)

static func _validate_audio_config(label: String, stats: Dictionary, errors: PackedStringArray) -> void:
	if not stats.has("audio"):
		return
	var audio = stats.get("audio")
	if not audio is Dictionary:
		errors.append("%s.audio: 必须是 Dictionary" % label)
		return
	_validate_known_fields("%s.audio" % label, audio as Dictionary, AUDIO_FIELDS, errors)
	var swing = (audio as Dictionary).get("attack_swing", [])
	if not swing is Array or (swing as Array).is_empty():
		errors.append("%s.audio.attack_swing: 必须是按攻击段排列的非空声音池数组" % label)
	else:
		var animations = stats.get("visual_animations", {})
		var configured_attacks = (animations as Dictionary).get("attack", []) if animations is Dictionary else []
		var attack_count := (configured_attacks as Array).size() if configured_attacks is Array else (0 if String(configured_attacks).is_empty() else 1)
		if attack_count != (swing as Array).size():
			errors.append("%s.audio.attack_swing: 声音池数量必须与 visual_animations.attack 数量一致" % label)
		for index in (swing as Array).size():
			_validate_audio_path_pool("%s.audio.attack_swing[%d]" % [label, index], (swing as Array)[index], errors)
	_validate_audio_path_pool("%s.audio.attack_hit" % label, (audio as Dictionary).get("attack_hit", []), errors)
	for volume_field in [&"attack_swing_volume_db", &"attack_hit_volume_db"]:
		if (audio as Dictionary).has(volume_field) and typeof((audio as Dictionary)[volume_field]) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append("%s.audio.%s: 必须是分贝数值" % [label, volume_field])

static func _validate_audio_path_pool(label: String, configured: Variant, errors: PackedStringArray) -> void:
	if not configured is Array or (configured as Array).is_empty():
		errors.append("%s: 必须是非空资源路径数组" % label)
		return
	for index in (configured as Array).size():
		var path := String((configured as Array)[index])
		if path.is_empty() or not path.begins_with("res://"):
			errors.append("%s[%d]: 必须是 res:// 音频资源路径" % [label, index])
		elif not ResourceLoader.exists(path):
			errors.append("%s[%d]: 资源不存在 %s" % [label, index, path])
		elif not load(path) is AudioStream:
			errors.append("%s[%d]: 资源不是 AudioStream" % [label, index])

static func _validate_combat_stats(label: String, stats: Dictionary, require_size_tier: bool, errors: PackedStringArray) -> void:
	_require_fields(label, stats, [&"hp", &"damage", &"range", &"speed", &"interval", &"is_air", &"building_only", &"can_attack_air"], errors)
	if float(stats.get("damage", 0.0)) > 0.0:
		_require_fields(label, stats, [&"first_hit"], errors)
	for field in [&"hp", &"range", &"speed", &"interval"]:
		if float(stats.get(field, -1.0)) < 0.0:
			errors.append("%s.%s: 必须 >= 0" % [label, field])
	if float(stats.get("hp", 0.0)) <= 0.0:
		errors.append("%s.hp: 必须 > 0" % label)
	if stats.has("first_hit") and float(stats.first_hit) < 0.0:
		errors.append("%s.first_hit: 必须 >= 0" % label)
	if require_size_tier:
		_require_fields(label, stats, [&"size_tier", &"mass", &"sight", &"visual_radius"], errors)
		var size_tier := StringName(stats.get("size_tier", ""))
		if not SIZE_RADII.has(size_tier):
			errors.append("%s.size_tier: 不属于七档体型" % label)
		elif not is_equal_approx(float(stats.get("radius", 0.0)), float(SIZE_RADII[size_tier])):
			errors.append("%s.radius: 与 size_tier=%s 的规范半径不匹配" % [label, size_tier])
	if stats.has("visual_radius") and float(stats.visual_radius) < float(stats.get("radius", 0.0)):
		errors.append("%s.visual_radius: 不得小于权威 radius" % label)
	if stats.has("timed_revival_delay"):
		if float(stats.get("timed_revival_delay", 0.0)) <= 0.0:
			errors.append("%s.timed_revival_delay: 必须 > 0" % label)
	if stats.has("death_replacement_id") and int(stats.get("death_replacement_charges", 0)) <= 0:
		errors.append("%s.death_replacement_charges: 声明死亡替身时必须 > 0" % label)
	if stats.has("timed_revival_death_replacement_charges") and int(stats.get("timed_revival_death_replacement_charges", -1)) < 0:
		errors.append("%s.timed_revival_death_replacement_charges: 必须 >= 0" % label)
	for transition_field in [&"death_replacement_visual_transition", &"timed_revival_visual_transition"]:
		if stats.has(transition_field) and not StringName(stats.get(transition_field, "")) in VISUAL_SPAWN_TRANSITIONS:
			errors.append("%s.%s: 只支持 %s" % [label, transition_field, VISUAL_SPAWN_TRANSITIONS])
	if stats.has("deploy_sweep_radius"):
		_require_fields(label, stats, [&"deploy_sweep_damage", &"deploy_sweep_knockback", &"deploy_sweep_duration", &"deploy_sweep_mass_factor_max"], errors)
		if float(stats.get("deploy_sweep_radius", 0.0)) <= 0.0:
			errors.append("%s.deploy_sweep_radius: 必须 > 0" % label)
		for deploy_nonnegative in [&"deploy_sweep_damage", &"deploy_sweep_knockback"]:
			if float(stats.get(deploy_nonnegative, 0.0)) < 0.0:
				errors.append("%s.%s: 必须 >= 0" % [label, deploy_nonnegative])
		for deploy_positive in [&"deploy_sweep_duration", &"deploy_sweep_mass_factor_max"]:
			if float(stats.get(deploy_positive, 0.0)) <= 0.0:
				errors.append("%s.%s: 必须 > 0" % [label, deploy_positive])
	if stats.has("first_strike_damage_multiplier") and float(stats.first_strike_damage_multiplier) <= 0.0:
		errors.append("%s.first_strike_damage_multiplier: 必须 > 0" % label)
	for resource_field in [&"skill_resource_max", &"skill_resource_attack_gain", &"skill_resource_hit_gain", &"skill_resource_kill_gain", &"skill_resource_damage_gain_multiplier"]:
		if float(stats.get(resource_field, 0.0)) < 0.0:
			errors.append("%s.%s: 必须 >= 0" % [label, resource_field])
	for resource_decay_field in [&"skill_resource_decay_delay", &"skill_resource_decay_rate"]:
		if float(stats.get(resource_decay_field, 0.0)) < 0.0:
			errors.append("%s.%s: 必须 >= 0" % [label, resource_decay_field])
	if (
		float(stats.get("skill_resource_attack_gain", 0.0)) > 0.0
		or float(stats.get("skill_resource_hit_gain", 0.0)) > 0.0
		or float(stats.get("skill_resource_kill_gain", 0.0)) > 0.0
		or float(stats.get("skill_resource_damage_gain_multiplier", 0.0)) > 0.0
	) and float(stats.get("skill_resource_max", 0.0)) <= 0.0:
		errors.append("%s.skill_resource_max: 配置资源获取时必须 > 0" % label)
	_validate_projectile(label, stats, errors)
	var attack_extras = stats.get("attack_extra_hit_damage_multipliers", [])
	var attack_delays = stats.get("attack_extra_hit_delays", [])
	if attack_extras is Array:
		if not (attack_delays is Array) or (attack_delays as Array).size() != (attack_extras as Array).size():
			errors.append("%s.attack_extra_hit_delays: 必须与额外刀伤害配置长度一致" % label)
		else:
			for index in (attack_extras as Array).size():
				var multipliers = (attack_extras as Array)[index]
				var delays = (attack_delays as Array)[index]
				if not multipliers is Array or not delays is Array or (multipliers as Array).size() != (delays as Array).size():
					errors.append("%s.attack_extra_hit_damage_multipliers[%d]: 伤害与延迟必须是等长数组" % [label, index])
					continue
				for value in multipliers:
					if float(value) <= 0.0:
						errors.append("%s.attack_extra_hit_damage_multipliers[%d]: 倍率必须 > 0" % [label, index])
				for value in delays:
					if float(value) < 0.0:
						errors.append("%s.attack_extra_hit_delays[%d]: 延迟必须 >= 0" % [label, index])

static func _validate_projectile(label: String, stats: Dictionary, errors: PackedStringArray) -> void:
	var speed := float(stats.get("projectile_speed", 0.0))
	if speed < 0.0:
		errors.append("%s.projectile_speed: 必须 >= 0" % label)
	if speed <= 0.0:
		return
	var visual := StringName(stats.get("projectile_visual", "orb"))
	if visual not in PROJECTILE_VISUALS:
		errors.append("%s.projectile_visual: 不支持 %s" % [label, visual])
	if float(stats.get("projectile_visual_height", 0.0)) < 0.0 or float(stats.get("projectile_visual_forward_offset", 0.0)) < 0.0:
		errors.append("%s: 弹体表现高度和前向偏移必须 >= 0" % label)
	if float(stats.get("projectile_visual_scale", 1.0)) <= 0.0:
		errors.append("%s.projectile_visual_scale: 必须 > 0" % label)
	if StringName(stats.get("projectile_impact_visual", "")) not in [&"", &"splash_wave"]:
		errors.append("%s.projectile_impact_visual: 只支持 splash_wave" % label)
	if stats.has("projectile_colors"):
		var colors = stats.projectile_colors
		if not colors is Array or colors.size() != 2 or not colors[0] is Color or not colors[1] is Color:
			errors.append("%s.projectile_colors: 必须是蓝/红双方两个 Color" % label)

static func _validate_building(card_id: String, stats: Dictionary, errors: PackedStringArray) -> void:
	_require_fields(card_id, stats, [&"is_building", &"footprint_tiles", &"lifespan", &"visual_radius"], errors)
	if not bool(stats.get("is_building", false)):
		errors.append("%s.is_building: building 卡必须为 true" % card_id)
	if stats.has("lifespan_hp_decay") and typeof(stats.lifespan_hp_decay) != TYPE_BOOL:
		errors.append("%s.lifespan_hp_decay: 必须是 bool" % card_id)
	if stats.has("tower_ruin_foundation") and typeof(stats.tower_ruin_foundation) != TYPE_BOOL:
		errors.append("%s.tower_ruin_foundation: 必须是 bool" % card_id)
	var footprint = stats.get("footprint_tiles")
	if not footprint is Vector2i or footprint.x <= 0 or footprint.y <= 0:
		errors.append("%s.footprint_tiles: 必须是正数 Vector2i" % card_id)
	if float(stats.get("speed", -1.0)) != 0.0:
		errors.append("%s.speed: 建筑必须为 0" % card_id)
	if float(stats.get("spawn_interval", 0.0)) < 0.0:
		errors.append("%s.spawn_interval: 必须 >= 0" % card_id)
	if float(stats.get("spawn_interval", 0.0)) > 0.0:
		_require_fields(card_id, stats, [&"spawn_id", &"spawn_count"], errors)
		if int(stats.get("spawn_count", 0)) <= 0:
			errors.append("%s.spawn_count: 周期召唤数量必须 > 0" % card_id)
	if int(stats.get("death_spawn_count", 0)) < 0:
		errors.append("%s.death_spawn_count: 必须 >= 0" % card_id)
	elif int(stats.get("death_spawn_count", 0)) > 0 and String(stats.get("death_spawn_id", "")).is_empty():
		errors.append("%s.death_spawn_id: 亡语召唤数量大于 0 时不能为空" % card_id)


static func _validate_references(card_id: String, stats: Dictionary, cards: Dictionary, errors: PackedStringArray) -> void:
	for field in [&"spawn_id", &"death_spawn_id", &"death_replacement_id", &"timed_revival_id"]:
		var referenced_id := String(stats.get(field, ""))
		if not referenced_id.is_empty() and not _unit_reference_exists(referenced_id, cards):
			errors.append("%s.%s: 引用了不存在或不可生成的单位 %s" % [card_id, field, referenced_id])
	var skills: Array = stats.get("active_skills", []) if stats.get("active_skills", []) is Array else []
	for index in range(skills.size()):
		var skill = skills[index]
		if not skill is Dictionary or StringName(skill.get("kind", "")) != &"summon":
			continue
		var spawn_id := String(skill.get("spawn_id", ""))
		if not _unit_reference_exists(spawn_id, cards):
			errors.append("%s.active_skills[%d].spawn_id: 引用了不存在或不可生成的单位 %s" % [card_id, index, spawn_id])


static func _unit_reference_exists(card_id: String, cards: Dictionary) -> bool:
	if not cards.has(card_id):
		return false
	return StringName((cards[card_id] as Dictionary).get("type", "")) in [&"unit", &"building"]

static func _validate_visual_config(label: String, stats: Dictionary, errors: PackedStringArray) -> void:
	for path_field in [&"visual_scene_path"]:
		var path := String(stats.get(path_field, ""))
		if not path.is_empty() and not ResourceLoader.exists(path):
			errors.append("%s.%s: 资源不存在 %s" % [label, path_field, path])
	if stats.has("visual_scene_paths"):
		var paths = stats.visual_scene_paths
		if not paths is Array or paths.size() != 2:
			errors.append("%s.visual_scene_paths: 必须是蓝/红双方两个路径" % label)
		else:
			for path in paths:
				if not path is String or not ResourceLoader.exists(path):
					errors.append("%s.visual_scene_paths: 资源不存在 %s" % [label, path])
	if not stats.has("visual_animations"):
		return
	var animations = stats.visual_animations
	if not animations is Dictionary:
		errors.append("%s.visual_animations: 必须是 Dictionary" % label)
		return
	_validate_known_fields("%s.visual_animations" % label, animations, VISUAL_ANIMATION_FIELDS, errors)
	for state in [
		&"deploy", &"idle", &"idle_cycle", &"move", &"move_enter", &"haste_move", &"move_cycle", &"attack", &"attack_hit", &"attack_recover",
		&"attack_structure", &"attack_move", &"attack_to_move", &"empowered_move", &"empowered_attack",
		&"empowered_attack_hit", &"empowered_attack_recover", &"empowered_attack_to_move",
	]:
		if not animations.has(state):
			continue
		var value = animations[state]
		if not value is String and not value is StringName and not value is Array:
			errors.append("%s.visual_animations.%s: 必须是动画名或动画名数组" % [label, state])
		elif value is Array:
			for animation_name in value:
				if not animation_name is String and not animation_name is StringName:
					errors.append("%s.visual_animations.%s: 数组只能包含动画名" % [label, state])
	var attack_values = animations.get("attack", [])
	var attack_count: int = attack_values.size() if attack_values is Array else (1 if animations.has("attack") else 0)
	for route_key in [&"attack_move", &"attack_to_move"]:
		if not animations.has(route_key):
			continue
		var route_values = animations.get(route_key, [])
		if route_values is Array and attack_count > 0 and route_values.size() != attack_count:
			errors.append("%s.visual_animations.%s: 按攻击段配置时必须与 attack 数量一致" % [label, route_key])
	if animations.has("visual_actions"):
		var actions = animations.visual_actions
		if not actions is Dictionary:
			errors.append("%s.visual_animations.visual_actions: 必须是 Dictionary" % label)
		else:
			for action in actions:
				var action_label := "%s.visual_animations.visual_actions.%s" % [label, action]
				var action_config = actions[action]
				if action_config is Dictionary:
					_validate_visual_action_descriptor(action_label, action_config, errors)
				else:
					_validate_animation_name_value(action_label, action_config, errors)
	if animations.has("visual_action_durations"):
		var durations = animations.visual_action_durations
		if not durations is Dictionary:
			errors.append("%s.visual_animations.visual_action_durations: 必须是 Dictionary" % label)
		else:
			for action in durations:
				_validate_positive_number_or_array("%s.visual_animations.visual_action_durations.%s" % [label, action], durations[action], errors)
	if animations.has("transitions"):
		var transitions = animations.transitions
		if not transitions is Dictionary:
			errors.append("%s.visual_animations.transitions: 必须是 Dictionary" % label)
		else:
			for transition in transitions:
				var transition_label := "%s.visual_animations.transitions.%s" % [label, transition]
				var transition_config = transitions[transition]
				if transition_config is Dictionary:
					_validate_visual_transition_descriptor(transition_label, transition_config, errors)
				else:
					_validate_animation_name_value(transition_label, transition_config, errors)
	if animations.has("transition_blends"):
		var blends = animations.transition_blends
		if not blends is Dictionary:
			errors.append("%s.visual_animations.transition_blends: 必须是 Dictionary" % label)
		else:
			_validate_known_fields("%s.visual_animations.transition_blends" % label, blends, TRANSITION_BLEND_FIELDS, errors)
			for blend_key in blends:
				var blend_value = blends[blend_key]
				if (not blend_value is float and not blend_value is int) or float(blend_value) < 0.0:
					errors.append("%s.visual_animations.transition_blends.%s: 必须是 >= 0 的秒数" % [label, blend_key])
	if animations.has("death_followup_scene_path") and not ResourceLoader.exists(String(animations.death_followup_scene_path)):
		errors.append("%s.visual_animations.death_followup_scene_path: 资源不存在" % label)

static func _validate_visual_action_descriptor(label: String, descriptor: Dictionary, errors: PackedStringArray) -> void:
	_validate_known_fields(label, descriptor, VISUAL_ACTION_DESCRIPTOR_FIELDS, errors)
	_require_fields(label, descriptor, [&"animation", &"kind"], errors)
	_validate_animation_name_value("%s.animation" % label, descriptor.get("animation", ""), errors)
	var kind := StringName(descriptor.get("kind", ""))
	if kind not in VISUAL_ACTION_KINDS:
		errors.append("%s.kind: 不支持的动作类型 %s" % [label, kind])
	if descriptor.has("durations"):
		_validate_positive_number_or_array("%s.durations" % label, descriptor.durations, errors)
		var animation_value = descriptor.get("animation", null)
		var duration_value = descriptor.get("durations", null)
		if animation_value is Array and duration_value is Array and animation_value.size() != duration_value.size():
			errors.append("%s.durations: 与 animation 数组长度必须匹配" % label)
	if descriptor.has("clip_ranges"):
		var clip_ranges = descriptor.clip_ranges
		var animation_value = descriptor.get("animation", null)
		if not clip_ranges is Array:
			errors.append("%s.clip_ranges: 必须是 Array" % label)
		elif animation_value is Array and clip_ranges.size() != animation_value.size():
			errors.append("%s.clip_ranges: 与 animation 数组长度必须匹配" % label)
		else:
			for clip_range in clip_ranges:
				if not clip_range is Array or clip_range.size() != 2:
					errors.append("%s.clip_ranges: 每段必须是 [开始秒, 结束秒]" % label)
					break
				if float(clip_range[0]) < 0.0 or float(clip_range[1]) <= float(clip_range[0]):
					errors.append("%s.clip_ranges: 必须满足 0 <= 开始秒 < 结束秒" % label)
					break
	for blend_field in [&"blend_in", &"blend_out", &"sequence_blend"]:
		if descriptor.has(blend_field):
			var blend_value = descriptor[blend_field]
			if (not blend_value is float and not blend_value is int) or float(blend_value) < 0.0:
				errors.append("%s.%s: 必须是 >= 0 的秒数" % [label, blend_field])
	if descriptor.has("priority") and int(descriptor.priority) < 0:
		errors.append("%s.priority: 必须 >= 0" % label)

static func _validate_visual_transition_descriptor(label: String, descriptor: Dictionary, errors: PackedStringArray) -> void:
	_validate_known_fields(label, descriptor, VISUAL_TRANSITION_DESCRIPTOR_FIELDS, errors)
	_require_fields(label, descriptor, [&"animation"], errors)
	_validate_animation_name_value("%s.animation" % label, descriptor.get("animation", ""), errors)
	for blend_field in [&"blend_in", &"blend_out"]:
		if not descriptor.has(blend_field):
			continue
		var blend_value = descriptor[blend_field]
		if (not blend_value is float and not blend_value is int) or float(blend_value) < 0.0:
			errors.append("%s.%s: 必须是 >= 0 的秒数" % [label, blend_field])

static func _validate_animation_name_value(label: String, value: Variant, errors: PackedStringArray) -> void:
	if value is String or value is StringName:
		if String(value).is_empty():
			errors.append("%s: 动画名不能为空" % label)
		return
	if value is Array:
		if value.is_empty():
			errors.append("%s: 动画数组不能为空" % label)
		for animation_name in value:
			if (not animation_name is String and not animation_name is StringName) or String(animation_name).is_empty():
				errors.append("%s: 数组只能包含非空动画名" % label)
		return
	errors.append("%s: 必须是动画名或动画名数组" % label)

static func _validate_positive_number_or_array(label: String, value: Variant, errors: PackedStringArray) -> void:
	var values: Array = value if value is Array else [value]
	if values.is_empty():
		errors.append("%s: 不能为空" % label)
		return
	for duration in values:
		if (not duration is float and not duration is int) or float(duration) <= 0.0:
			errors.append("%s: 必须是正数或正数数组" % label)
			return

static func _validate_active_skills(card_id: String, stats: Dictionary, errors: PackedStringArray) -> void:
	var skills: Array = []
	if stats.has("active_skills"):
		if not stats.active_skills is Array:
			errors.append("%s.active_skills: 必须是 Array" % card_id)
		else:
			skills.append_array(stats.active_skills)
	for index in range(skills.size()):
		var skill = skills[index]
		var label := "%s.active_skills[%d]" % [card_id, index]
		if not skill is Dictionary:
			errors.append("%s: 必须是 Dictionary" % label)
			continue
		_validate_known_fields(label, skill, ACTIVE_SKILL_FIELDS, errors)
		_require_fields(label, skill, [&"name", &"kind", &"cost", &"max_uses", &"cooldown"], errors)
		var kind := StringName(skill.get("kind", ""))
		if kind not in ACTIVE_SKILL_KINDS:
			errors.append("%s.kind: 系统不支持 %s" % [label, kind])
			continue
		var skill_cost := float(skill.get("cost", -1.0))
		if skill_cost < 0.0:
			errors.append("%s.cost: 必须 >= 0" % label)
		var max_uses := int(skill.get("max_uses", 0))
		if max_uses <= 0:
			errors.append("%s.max_uses: 必须 > 0" % label)
		if float(skill.get("cooldown", -1.0)) < 0.0:
			errors.append("%s.cooldown: 必须 >= 0" % label)
		match kind:
			&"nova": _require_fields(label, skill, [&"radius", &"damage"], errors)
			&"buff": _require_fields(label, skill, [&"duration"], errors)
			&"area_shield":
				_require_fields(label, skill, [&"radius", &"shield", &"shield_duration"], errors)
				for positive_field in [&"radius", &"shield", &"shield_duration"]:
					if float(skill.get(positive_field, 0.0)) <= 0.0:
						errors.append("%s.%s: 必须 > 0" % [label, positive_field])
			&"summon": _require_fields(label, skill, [&"spawn_id", &"spawn_count"], errors)
			&"dual_form": _require_fields(label, skill, [&"length", &"width", &"damage", &"impact_delay", &"cast_duration", &"stun_duration"], errors)
			&"frontal":
				_require_fields(label, skill, [&"shape", &"length", &"damage", &"impact_delay", &"cast_duration"], errors)
				var shape := StringName(skill.get("shape", ""))
				if float(skill.get("length", 0.0)) <= 0.0:
					errors.append("%s.length: 必须 > 0" % label)
				if float(skill.get("damage", 0.0)) < 0.0:
					errors.append("%s.damage: 必须 >= 0" % label)
				if shape == &"fan":
					_require_fields(label, skill, [&"arc_degrees"], errors)
					var arc_degrees := float(skill.get("arc_degrees", 0.0))
					if arc_degrees <= 0.0 or arc_degrees >= 180.0:
						errors.append("%s.arc_degrees: 必须在 0 到 180 之间" % label)
					if int(skill.get("projectile_count", 0)) < 0:
						errors.append("%s.projectile_count: 必须 >= 0" % label)
				elif shape == &"trapezoid":
					_require_fields(label, skill, [&"near_width", &"far_width"], errors)
					if float(skill.get("near_width", 0.0)) <= 0.0 or float(skill.get("far_width", 0.0)) <= 0.0:
						errors.append("%s: near_width/far_width 必须 > 0" % label)
				else:
					errors.append("%s.shape: 只支持 fan/trapezoid" % label)
			&"forward_area":
				_require_fields(label, skill, [&"forward_distance", &"radius", &"damage", &"stun_duration", &"impact_delay", &"cast_duration"], errors)
				var has_shockwave_config: bool = skill.has("shockwave_damage") or skill.has("shockwave_duration") or skill.has("shockwave_end_radius")
				if has_shockwave_config:
					_require_fields(label, skill, [&"shockwave_damage", &"shockwave_duration", &"shockwave_end_radius"], errors)
				for positive_field in [&"forward_distance", &"radius", &"cast_duration"]:
					if float(skill.get(positive_field, 0.0)) <= 0.0:
						errors.append("%s.%s: 必须 > 0" % [label, positive_field])
				if has_shockwave_config:
					for positive_field in [&"shockwave_duration", &"shockwave_end_radius"]:
						if float(skill.get(positive_field, 0.0)) <= 0.0:
							errors.append("%s.%s: 必须 > 0" % [label, positive_field])
				for nonnegative_field in [&"damage", &"stun_duration", &"impact_delay", &"shockwave_damage", &"shockwave_slow_duration"]:
					if skill.has(nonnegative_field) and float(skill.get(nonnegative_field, 0.0)) < 0.0:
						errors.append("%s.%s: 必须 >= 0" % [label, nonnegative_field])
				if skill.has("zone_duration"):
					if float(skill.get("zone_duration", 0.0)) <= 0.0:
						errors.append("%s.zone_duration: 必须 > 0" % label)
					if float(skill.get("zone_tick_interval", 0.0)) <= 0.0:
						errors.append("%s.zone_tick_interval: 必须 > 0" % label)
					if float(skill.get("zone_damage", 0.0)) < 0.0:
						errors.append("%s.zone_damage: 必须 >= 0" % label)
					if float(skill.get("zone_slow_duration", 0.0)) < 0.0:
						errors.append("%s.zone_slow_duration: 必须 >= 0" % label)
					if float(skill.get("zone_slow_multiplier", 1.0)) < 0.1 or float(skill.get("zone_slow_multiplier", 1.0)) > 1.0:
						errors.append("%s.zone_slow_multiplier: 必须在 0.1 到 1.0 之间" % label)
			&"continuous_area":
				_require_fields(label, skill, [&"radius", &"damage", &"duration", &"tick_interval", &"cast_duration"], errors)
				for positive_field in [&"radius", &"duration", &"tick_interval", &"cast_duration"]:
					if float(skill.get(positive_field, 0.0)) <= 0.0:
						errors.append("%s.%s: 必须 > 0" % [label, positive_field])
				if float(skill.get("damage", 0.0)) < 0.0:
					errors.append("%s.damage: 必须 >= 0" % label)
				if float(skill.get("duration", 0.0)) > float(skill.get("cast_duration", 0.0)):
					errors.append("%s.duration: 不得大于 cast_duration" % label)
			&"empowered_attack":
				_require_fields(label, skill, [&"empowered_damage_multiplier"], errors)
				if float(skill.get("empowered_damage_multiplier", 0.0)) <= 0.0:
					errors.append("%s.empowered_damage_multiplier: 必须 > 0" % label)
				if float(skill.get("empowered_speed_multiplier", 1.0)) < 1.0:
					errors.append("%s.empowered_speed_multiplier: 必须 >= 1" % label)
				if int(skill.get("blind_charges", 0)) < 0:
					errors.append("%s.blind_charges: 必须 >= 0" % label)
			&"attack_lifesteal":
				_require_fields(label, skill, [&"heal_ratio", &"max_health_ratio"], errors)
				if float(skill.get("heal_ratio", 0.0)) <= 0.0:
					errors.append("%s.heal_ratio: 必须 > 0" % label)
				if float(skill.get("max_health_ratio", 0.0)) < 1.0:
					errors.append("%s.max_health_ratio: 必须 >= 1" % label)
		var target_scope := StringName(skill.get("target_scope", "self"))
		if target_scope not in ACTIVE_SKILL_TARGET_SCOPES:
			errors.append("%s.target_scope: 只支持 self/deployment_group" % label)
		if skill.has("center_ratio") and (float(skill.center_ratio) < 0.0 or float(skill.center_ratio) > 1.0):
			errors.append("%s.center_ratio: 必须在 0 到 1 之间" % label)
		if skill.has("center_width") and float(skill.center_width) < 0.0:
			errors.append("%s.center_width: 必须 >= 0" % label)
		if skill.has("fan_inner_arc") and typeof(skill.fan_inner_arc) != TYPE_BOOL:
			errors.append("%s.fan_inner_arc: 必须是 bool" % label)
		if skill.has("projectile_visual") and StringName(skill.projectile_visual) not in [&"arrow", &"card", &"orb", &"laser", &"electromagnetic_wave"]:
			errors.append("%s.projectile_visual: 只支持 arrow/card/orb/laser/electromagnetic_wave" % label)
		if skill.has("projectile_launch_delay") and float(skill.projectile_launch_delay) < 0.0:
			errors.append("%s.projectile_launch_delay: 必须 >= 0" % label)
		if skill.has("projectile_flight_duration") and float(skill.projectile_flight_duration) < 0.0:
			errors.append("%s.projectile_flight_duration: 必须 >= 0" % label)
		if skill.has("projectile_visual_height") and float(skill.projectile_visual_height) < 0.0:
			errors.append("%s.projectile_visual_height: 必须 >= 0" % label)
		if skill.has("projectile_visual_forward_offset") and float(skill.projectile_visual_forward_offset) < 0.0:
			errors.append("%s.projectile_visual_forward_offset: 必须 >= 0" % label)
		if skill.has("projectile_visual_width") and float(skill.projectile_visual_width) <= 0.0:
			errors.append("%s.projectile_visual_width: 必须 > 0" % label)
		if skill.has("projectile_launch_delay") and skill.has("cast_duration") and float(skill.projectile_launch_delay) > float(skill.cast_duration):
			errors.append("%s.projectile_launch_delay: 不得大于 cast_duration" % label)
		if skill.has("knockback_duration") and float(skill.knockback_duration) <= 0.0:
			errors.append("%s.knockback_duration: 必须 > 0" % label)
		if skill.has("knockback_mass_factor_max") and float(skill.knockback_mass_factor_max) <= 0.0:
			errors.append("%s.knockback_mass_factor_max: 必须 > 0" % label)
		if float(skill.get("center_damage_multiplier", 1.0)) < 1.0:
			errors.append("%s.center_damage_multiplier: 必须 >= 1" % label)
		if skill.has("resource_damage_scale_max"):
			if float(skill.resource_damage_scale_max) < 1.0:
				errors.append("%s.resource_damage_scale_max: 必须 >= 1" % label)
			if float(stats.get("skill_resource_max", 0.0)) <= 0.0:
				errors.append("%s.resource_damage_scale_max: 卡牌必须配置正数 skill_resource_max" % label)
		if bool(skill.get("uses_skill_resource", false)) and float(stats.get("skill_resource_max", 0.0)) <= 0.0:
			errors.append("%s.uses_skill_resource: 卡牌必须配置正数 skill_resource_max" % label)
		if skill.has("resource_shield_max"):
			if float(skill.resource_shield_max) < 0.0:
				errors.append("%s.resource_shield_max: 必须 >= 0" % label)
			if not bool(skill.get("uses_skill_resource", false)):
				errors.append("%s.resource_shield_max: 必须搭配 uses_skill_resource" % label)
		if bool(skill.get("shield_on_cast_start", false)):
			if float(skill.get("shield_duration", 0.0)) <= 0.0:
				errors.append("%s.shield_on_cast_start: 必须配置正数 shield_duration" % label)
		if bool(skill.get("shield_decay", false)) and float(skill.get("shield_duration", 0.0)) <= 0.0:
			errors.append("%s.shield_decay: 必须配置正数 shield_duration" % label)
		if skill.has("resource_damage_by_stacks"):
			var damage_tiers = skill.resource_damage_by_stacks
			var expected_tiers := int(round(float(stats.get("skill_resource_max", 0.0)))) + 1
			if not damage_tiers is Array or (damage_tiers as Array).size() != expected_tiers:
				errors.append("%s.resource_damage_by_stacks: 必须覆盖 0 到满层的所有档位" % label)
		var expected_resource_tiers := int(round(float(stats.get("skill_resource_max", 0.0)))) + 1
		if skill.has("resource_visual_actions"):
			var resource_actions = skill.resource_visual_actions
			if not resource_actions is Array or (resource_actions as Array).size() != expected_resource_tiers:
				errors.append("%s.resource_visual_actions: 必须覆盖 0 到满层的所有档位" % label)
			elif resource_actions is Array:
				for resource_action in resource_actions:
					if String(resource_action).is_empty() or not _has_visual_action(stats, String(resource_action)):
						errors.append("%s.resource_visual_actions: visual_actions 中不存在 %s" % [label, resource_action])
		var hit_damage_tiers = skill.get("resource_hit_damage_sequences", null)
		var hit_delay_tiers = skill.get("resource_hit_delay_sequences", null)
		if hit_damage_tiers != null or hit_delay_tiers != null:
			if not hit_damage_tiers is Array or not hit_delay_tiers is Array:
				errors.append("%s.resource_hit_*_sequences: 两项都必须是 Array" % label)
			elif hit_damage_tiers.size() != expected_resource_tiers or hit_delay_tiers.size() != expected_resource_tiers:
				errors.append("%s.resource_hit_*_sequences: 必须覆盖 0 到满层的所有档位" % label)
			else:
				for tier_index in expected_resource_tiers:
					var damages = hit_damage_tiers[tier_index]
					var delays = hit_delay_tiers[tier_index]
					if not damages is Array or not delays is Array or damages.is_empty() or damages.size() != delays.size():
						errors.append("%s.resource_hit_*_sequences[%d]: 伤害与时刻必须是等长非空数组" % [label, tier_index])
						continue
					var previous_delay := -1.0
					for hit_index in damages.size():
						var hit_damage := float(damages[hit_index])
						var hit_delay := float(delays[hit_index])
						if hit_damage < 0.0:
							errors.append("%s.resource_hit_damage_sequences[%d]: 伤害必须 >= 0" % [label, tier_index])
						if hit_delay < 0.0 or hit_delay > float(skill.get("cast_duration", 0.0)) or hit_delay < previous_delay:
							errors.append("%s.resource_hit_delay_sequences[%d]: 时刻必须递增且位于施法窗口内" % [label, tier_index])
						previous_delay = hit_delay
		if skill.has("full_resource_cast_end_heal") and float(skill.full_resource_cast_end_heal) < 0.0:
			errors.append("%s.full_resource_cast_end_heal: 必须 >= 0" % label)
		if skill.has("full_resource_cast_duration") and float(skill.full_resource_cast_duration) <= 0.0:
			errors.append("%s.full_resource_cast_duration: 必须 > 0" % label)
		if skill.has("full_resource_impact_delay"):
			var full_cast := float(skill.get("full_resource_cast_duration", skill.get("cast_duration", 0.0)))
			if float(skill.full_resource_impact_delay) < 0.0 or float(skill.full_resource_impact_delay) > full_cast:
				errors.append("%s.full_resource_impact_delay: 必须位于满层施法窗口内" % label)
		if skill.has("cast_locks"):
			if not skill.cast_locks is Array:
				errors.append("%s.cast_locks: 必须是 Array" % label)
			else:
				for cast_lock in skill.cast_locks:
					if StringName(cast_lock) not in CAST_LOCKS:
						errors.append("%s.cast_locks: 不支持 %s" % [label, cast_lock])
		var visual_action := String(skill.get("visual_action", ""))
		if skill.has("visual_action") and visual_action.is_empty():
			errors.append("%s.visual_action: 动作名不能为空" % label)
		elif not visual_action.is_empty() and not _has_visual_action(stats, visual_action):
			errors.append("%s.visual_action: visual_animations.visual_actions 中不存在 %s" % [label, visual_action])
		var full_resource_action := String(skill.get("full_resource_visual_action", ""))
		if not full_resource_action.is_empty() and not _has_visual_action(stats, full_resource_action):
			errors.append("%s.full_resource_visual_action: visual_animations.visual_actions 中不存在 %s" % [label, full_resource_action])
		if not visual_action.is_empty() and skill.has("cast_locks") and skill.cast_locks is Array and StringName("attack") not in skill.cast_locks:
			errors.append("%s.cast_locks: 使用全身 visual_action 时必须包含 attack" % label)
		if skill.has("cast_duration") and float(skill.cast_duration) < 0.0:
			errors.append("%s.cast_duration: 必须 >= 0" % label)
		if skill.has("impact_delay"):
			var impact_delay := float(skill.impact_delay)
			if impact_delay < 0.0:
				errors.append("%s.impact_delay: 必须 >= 0" % label)
			if impact_delay > 0.0 and not skill.has("cast_duration") and kind != &"dual_form":
				errors.append("%s.impact_delay: 大于 0 时必须配置 cast_duration" % label)
			elif skill.has("cast_duration") and impact_delay > float(skill.cast_duration):
				errors.append("%s.impact_delay: 不得大于 cast_duration" % label)
		if skill.has("transform_cast_duration") and float(skill.transform_cast_duration) < 0.0:
			errors.append("%s.transform_cast_duration: 必须 >= 0" % label)
		if skill.has("transform_impact_delay"):
			var transform_impact_delay := float(skill.transform_impact_delay)
			if transform_impact_delay < 0.0:
				errors.append("%s.transform_impact_delay: 必须 >= 0" % label)
			if transform_impact_delay > 0.0 and not skill.has("transform_cast_duration"):
				errors.append("%s.transform_impact_delay: 大于 0 时必须配置 transform_cast_duration" % label)
			elif skill.has("transform_cast_duration") and transform_impact_delay > float(skill.transform_cast_duration):
				errors.append("%s.transform_impact_delay: 不得大于 transform_cast_duration" % label)

static func _has_visual_action(stats: Dictionary, action_name: String) -> bool:
	var candidates: Array[Dictionary] = [stats]
	var transformed = stats.get("transformed_stats")
	if transformed is Dictionary:
		candidates.append(transformed)
	for candidate in candidates:
		var animations = candidate.get("visual_animations", {})
		if animations is Dictionary and animations.get("visual_actions", {}) is Dictionary:
			if (animations.get("visual_actions", {}) as Dictionary).has(action_name):
				return true
	return false

static func _require_fields(label: String, data: Dictionary, fields: Array, errors: PackedStringArray) -> void:
	for field in fields:
		if not data.has(field):
			errors.append("%s.%s: 缺少必要字段" % [label, field])

static func _validate_known_fields(label: String, data: Dictionary, known_fields: Array, errors: PackedStringArray) -> void:
	for field in data:
		if StringName(field) not in known_fields:
			errors.append("%s.%s: 未知或未登记字段" % [label, field])

## 美术开发面板专用木桩，不进入正式卡牌池。
static func training_dummy_stats() -> Dictionary:
	return {
		"name": "训练木桩", "hp": 1000000.0, "damage": 0.0, "range": 0.0,
		"speed": 0.0, "interval": 1.0, "first_hit": 0.2,
		"radius": 18.0, "visual_radius": 20.0, "mass": 1000.0, "sight": 0.0,
		"color": Color(0.48, 0.30, 0.16), "is_air": false,
		"building_only": false, "can_attack_air": false, "is_building": true,
	}

static func speed_tier_name(speed: float) -> String:
	if speed >= (SPEED_EXTREMELY_FAST + SPEED_FAST) * 0.5:
		return "极快"
	if speed >= (SPEED_FAST + SPEED_SLIGHTLY_FAST) * 0.5:
		return "快"
	if speed >= (SPEED_SLIGHTLY_FAST + SPEED_MEDIUM) * 0.5:
		return "稍快"
	if speed >= (SPEED_MEDIUM + SPEED_SLIGHTLY_SLOW) * 0.5:
		return "中"
	if speed >= (SPEED_SLIGHTLY_SLOW + SPEED_SLOW) * 0.5:
		return "稍慢"
	if speed >= (SPEED_SLOW + SPEED_EXTREMELY_SLOW) * 0.5:
		return "慢"
	return "极慢"

static func size_tier_name(size_tier: StringName) -> String:
	match size_tier:
		SIZE_EXTREMELY_SMALL:
			return "极小"
		SIZE_SMALL:
			return "小"
		SIZE_SLIGHTLY_SMALL:
			return "稍小"
		SIZE_MEDIUM:
			return "中"
		SIZE_SLIGHTLY_LARGE:
			return "稍大"
		SIZE_LARGE:
			return "大"
		SIZE_EXTREMELY_LARGE:
			return "极大"
	return "未分档"
