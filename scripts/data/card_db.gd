class_name CardDB
## 卡牌数值定义库。调整平衡只改这里。
## 卡牌类型 type: "unit"=单位, "spell"=法术, "building"=建筑
## 单位体型使用七档。这里的半径是权威战斗数据，会参与碰撞、部署、寻路与攻击距离；
## visual_radius 只负责占位图、队伍圈和状态提示，不得反过来驱动战斗。
const CHARACTER_SCALE_MULTIPLIER := 1.5
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
## 地面移动速度统一使用七档，避免不同角色只有几 px/s、实机看不出差异。
const SPEED_EXTREMELY_FAST := 88.0
const SPEED_FAST := 76.0
const SPEED_SLIGHTLY_FAST := 68.0
const SPEED_MEDIUM := 60.0
const SPEED_SLIGHTLY_SLOW := 52.0
const SPEED_SLOW := 44.0
const SPEED_EXTREMELY_SLOW := 36.0

const CARD_TYPES := [&"unit", &"spell", &"building"]
const SIZE_RADII := {
	SIZE_EXTREMELY_SMALL: RADIUS_EXTREMELY_SMALL,
	SIZE_SMALL: RADIUS_SMALL,
	SIZE_SLIGHTLY_SMALL: RADIUS_SLIGHTLY_SMALL,
	SIZE_MEDIUM: RADIUS_MEDIUM,
	SIZE_SLIGHTLY_LARGE: RADIUS_SLIGHTLY_LARGE,
	SIZE_LARGE: RADIUS_LARGE,
	SIZE_EXTREMELY_LARGE: RADIUS_EXTREMELY_LARGE,
}
const PROJECTILE_VISUALS := [&"orb", &"arrow", &"needle", &"boomerang"]
const ACTIVE_SKILL_KINDS := [&"nova", &"buff", &"summon", &"dual_form"]

## 这里列出的字段都必须有运行时代码读取。新增字段若未登记，validate_all() 会直接报错，
## 防止 Agent 只把配置写进 CardDB、却忘记接入权威模拟或表现层。
const CARD_FIELDS := [
	&"name", &"cost", &"type", &"description", &"selectable",
	&"hp", &"damage", &"range", &"speed", &"interval", &"first_hit",
	&"size_tier", &"radius", &"visual_radius", &"mass", &"sight", &"color",
	&"is_air", &"is_building", &"building_only", &"can_attack_air", &"is_continuous_attack",
	&"deploy_time", &"show_team_ring", &"footprint_tiles", &"lifespan",
	&"spawn_interval", &"spawn_count", &"spawn_side", &"death_spawn_id", &"death_spawn_count",
	&"projectile_speed", &"projectile_visual", &"projectile_visual_height",
	&"projectile_visual_forward_offset", &"projectile_colors", &"splash_radius", &"knockback",
	&"continuous_beam_color", &"continuous_beam_start_width", &"continuous_beam_end_width",
	&"continuous_beam_origin_height", &"continuous_beam_forward_offset",
	&"deploy_sweep_radius", &"deploy_sweep_knockback", &"deploy_sweep_duration",
	&"heal_every_hits", &"heal_amount", &"charge_time", &"charge_speed_multiplier",
	&"charge_damage_multiplier", &"shroud_radius", &"attack_pattern", &"attack_damage_multipliers",
	&"attack_interval_display", &"transform_after_hits", &"revert_after_hits",
	&"transform_duration", &"active_transform_duration", &"revert_duration", &"transformed_stats",
	&"duration", &"active_name", &"active_slow_duration", &"active_slow_multiplier", &"active_skill", &"active_skills",
	&"visual_frames_path", &"visual_scene_path", &"visual_scene_paths", &"visual_forward_yaw", &"visual_animations",
]
const VISUAL_ANIMATION_FIELDS := [
	&"deploy", &"deploy_durations", &"deploy_clip_ratio", &"idle", &"move", &"move_enter",
	&"move_cycle", &"attack", &"attack_enter", &"attack_retarget_enter", &"attack_loop",
	&"attack_hit", &"attack_hit_duration", &"attack_recover", &"attack_recover_delay",
	&"attack_structure", &"attack_to_move", &"move_enter_after_attack", &"death", &"death_duration",
	&"death_followup_scene_path", &"death_followup_animation", &"death_followup_duration", &"visual_actions",
]
const ACTIVE_SKILL_FIELDS := [
	&"name", &"kind", &"radius", &"damage", &"knockback", &"slow_duration", &"slow_multiplier",
	&"shield", &"shield_duration", &"duration", &"speed_multiplier", &"damage_multiplier",
	&"attack_speed_multiplier", &"spawn_id", &"spawn_count", &"length", &"width", &"impact_delay",
	&"transform_impact_delay", &"cast_duration", &"transform_cast_duration", &"stun_duration", &"ground_only",
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
			"hp": 1050.0, "damage": 88.0, "range": 28.0,
			# 命中位于攻击周期约 35% 处，给挥剑留出短前摇，把较长时间留给收招。
			"speed": SPEED_SLOW, "interval": 1.1, "first_hit": 0.38,
			"size_tier": SIZE_LARGE, "radius": RADIUS_LARGE, "visual_radius": RADIUS_LARGE + VISUAL_RADIUS_PADDING,
			"mass": 8.0, "sight": 220.0,
			"color": Color(0.35, 0.55, 0.90),
			"visual_scene_path": "res://assets/units/garen/garen_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn_Base", "idle": "Idle1_Base",
				"move": "Run_Base", "attack": ["Attack1", "Attack2"],
				"death": "Death", "death_duration": 0.8,
			},
			"is_air": false, "building_only": true, "can_attack_air": false,
			"active_skill": {"name": "德玛西亚正义", "kind": "nova", "radius": 90.0, "damage": 150.0, "shield": 180.0, "shield_duration": 4.0},
		},
		"xin": {
			"name": "赵信", "cost": 4, "type": "unit",
			"description": "近战战士，部署时横扫周围地面敌人，连续攻击还能恢复生命。",
			"hp": 620.0, "damage": 68.0, "range": 40.0,
			"speed": SPEED_SLIGHTLY_FAST, "interval": 0.9, "first_hit": 0.3,
			"deploy_time": 1.5,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"mass": 5.0, "sight": 220.0,
			# 横扫千军就是赵信的 1.5 秒部署阶段：生成瞬间播放 Spell4 挥舞，
			# 随后 Spell4_To_Idle 收枪；期间不能移动和攻击，但可被索敌、碰撞和命中。
			# 生成当帧立即击退四周地面敌人。
			# 只击退不造成伤害，击退距离经 apply_knockback 的质量因子衰减：
			# 轻单位飞出圈外，重单位只被顶开一小步。
			"deploy_sweep_radius": 100.0,     # 横扫半径（2.5 格）
			"deploy_sweep_knockback": 90.0,   # 基础击退距离（按质量 4/mass 衰减，clamp 0.35~1.4）
			"deploy_sweep_duration": 0.25,    # 击退位移持续时间（秒）
			# 无畏战吼：三段普攻循环中的第三击（Passive_AA_01）命中时回复少许生命值。
			"heal_every_hits": 3, "heal_amount": 60.0,
			"color": Color(0.85, 0.30, 0.25),
			"visual_scene_path": "res://assets/units/xin/xin_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				# 出场技能：生成当帧播放 Spell4（横扫挥舞），随后快速播放
				# Spell4_To_Idle 收枪；两段总长与 1.5 秒部署锁定一致。
				"deploy": ["Spell4", "Spell4_To_Idle"],
				"deploy_durations": [1.0, 0.5], # Spell4 1 秒，Spell4_To_Idle 0.5 秒
				"idle": "IdleBase", "move": "RunBase",
				# 三段普攻循环：Start 段（Hit 打击动作）在 first_hit 窗口播放，命中时刻切 settle 收势。
				"attack": ["Attack1_Hit", "Attack3_Hit", "Passive_AA_01_hit_XinZhaoRework_anm"],
				"attack_hit": [
					"Attack_AA_01_settle_XinZhaoRework_anm",
					"Attack_AA_03_settle_XinZhaoRework_anm",
					"Passive_AA_01_XinZhaoRework_anm",
				],
				"attack_hit_duration": 0.6,
				"death": "Death", "death_duration": 0.8,
			},
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skill": {"name": "新月护卫", "kind": "nova", "radius": 105.0, "damage": 90.0, "knockback": 90.0},
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
				"attack": ["Attack1", "Attack2"], "death": "Death", "death_duration": 0.8,
			},
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skill": {"name": "万箭齐发", "kind": "nova", "radius": 180.0, "damage": 70.0, "slow_duration": 2.0, "slow_multiplier": 0.55},
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
				"deploy": "Respawn", "idle": "Idle1_Base", "move": "Run_Base",
				# Attack1 播放完的离弦点创建弹体，随后切入 Attack1_ToIdle 完成后摇。
				"attack": ["Attack1_ASU_Teemo_anm"], "attack_hit": ["Attack1_ToIdle"],
				"attack_hit_duration": 0.75, "death": "Death", "death_duration": 0.8,
			},
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skill": {"name": "致盲毒雾", "kind": "nova", "radius": 105.0, "damage": 55.0, "slow_duration": 2.5, "slow_multiplier": 0.50},
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
					"revert": "gnar_runtime/Revert_Transform",
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
				"hp": 820.0, "damage": 85.0, "range": 30.0,
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
						"transform": "gnar_runtime/Rage_Transform",
						"transform_active": "gnar_runtime/Rage_Spell2_Transform",
						"active": "GnarBig_Spell2_anm",
					},
				},
			},
			"active_skill": {
				"name": "怒气爆发", "kind": "dual_form",
				"length": 160.0, "width": 120.0, "damage": 120.0,
				# 两种 Spell2 主体动作均从施法首帧开始，0.8s 手掌触地。
				"impact_delay": 0.8, "transform_impact_delay": 0.8,
				"cast_duration": 1.2, "transform_cast_duration": 1.2,
				"stun_duration": 1.0, "ground_only": true,
			},
		},
		# ===== 水晶兵线（也可作为玩家卡牌） =====
		"melee_minion": {
			"name": "近战兵", "cost": 1, "type": "unit", "selectable": true,
			"description": "基础近战单位，适合成群推进并为后排吸收伤害。",
			"hp": 210.0, "damage": 42.0, "range": 22.0,
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
			"active_skill": {"name": "列阵突击", "kind": "buff", "duration": 4.0, "speed_multiplier": 1.35, "damage_multiplier": 1.25},
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
			"active_skill": {"name": "奥术齐射", "kind": "nova", "radius": 150.0, "damage": 48.0},
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
			"active_skill": {"name": "超载炮击", "kind": "nova", "radius": 180.0, "damage": 100.0, "knockback": 35.0},
		},
		"super_minion": {
			"name": "超级兵", "cost": 4, "type": "unit", "selectable": true,
			"description": "强化型近战单位，生命和伤害更高，适合在一路形成突破。",
			"hp": 720.0, "damage": 72.0, "range": 28.0,
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
			"active_skill": {"name": "超级冲锋", "kind": "buff", "duration": 5.0, "speed_multiplier": 1.35, "damage_multiplier": 1.35, "shield": 140.0, "shield_duration": 5.0},
		},
		# ===== 新增4张 =====
		"freeze": {
			"name": "冰冻", "cost": 3, "type": "spell",
			"description": "范围控制法术，冻结范围内的敌方单位，为己方争取进攻窗口。",
			"active_name": "强化冰冻",
			# 法术卡：不生成单位，在点击位置范围内冻结敌方单位3秒
			"radius": 110.0,    # 影响范围半径
			"duration": 3.0,    # 冰冻持续时间
			"active_slow_duration": 2.0,
			"active_slow_multiplier": 0.50,
			"color": Color(0.40, 0.70, 1.00),
		},
		"masteryi": {
			"name": "剑圣", "cost": 3, "type": "unit",
			"description": "高速近战刺客，攻击频率高，适合快速处理脆弱目标。",
			# 近战高攻速刺客：血薄但攻速极快
			"hp": 480.0, "damage": 52.0, "range": 26.0,
			"speed": SPEED_EXTREMELY_FAST, "interval": 0.45, "first_hit": 0.2,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"mass": 4.0, "sight": 200.0,
			"color": Color(0.20, 0.80, 0.50),
			"visual_scene_path": "res://assets/units/masteryi/masteryi_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn", "idle": "masteryi_2013_idle1_anm",
				"move": "Run", "attack": ["masteryi_2013_attack1_anm", "masteryi_2013_attack2_anm"],
				"death": "Death", "death_duration": 0.8,
			},
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skill": {"name": "高原血统", "kind": "buff", "duration": 5.0, "speed_multiplier": 1.45, "damage_multiplier": 1.20, "attack_speed_multiplier": 1.55},
		},
		"gwen": {
			"name": "格温", "cost": 4, "type": "unit",
			"description": "近战刺客，首次普攻命中后进入缠流，能避开远处敌人的视野和锁定。",
			# 近战刺客：首次普攻命中后开启丝缕缠流；3 格（120px）外的敌方看不到她、不再把她当目标。
			"hp": 580.0, "damage": 62.0, "range": 30.0,
			"speed": SPEED_FAST, "interval": 0.85, "first_hit": 0.28,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"mass": 4.0, "sight": 210.0,
			"shroud_radius": 120.0,   # 3 格 = 3 × 40px；贴身推塔时塔心仍在圈内，会被反击
			"color": Color(0.95, 0.75, 0.85),
			"visual_scene_path": "res://assets/units/gwen/gwen_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn", "idle": "Idle_anm", "move": "Run_anm",
				"attack": ["Attack1", "Attack2", "Attack3"], "death": "Death", "death_duration": 0.8,
			},
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skill": {"name": "神圣裁缝", "kind": "buff", "duration": 4.0, "speed_multiplier": 1.20, "damage_multiplier": 1.30, "shield": 130.0, "shield_duration": 4.0},
		},
		"sett": {
			"name": "腕豪", "cost": 4, "type": "unit",
			"description": "近战拳师，以快速双拳连招输出，第二拳造成更高伤害。",
			# 近战拳师：连招节奏——快速两拳→稍作停顿→再快速两拳→再停顿。
			"hp": 800.0, "damage": 72.0, "range": 18.0,
			"speed": SPEED_MEDIUM, "interval": 1.1, "first_hit": 0.12,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE, "visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"mass": 6.0, "sight": 210.0,
			"attack_pattern": [0.28, 1.05, 0.28, 1.05],  # 两拳→停顿→两拳→停顿
			"attack_damage_multipliers": [1.0, 1.5, 1.0, 1.5],  # 左拳基础伤害，右拳为左拳的1.5倍
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
				"death": "Death", "death_duration": 0.8,
			},
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skill": {"name": "蓄意轰拳", "kind": "nova", "radius": 95.0, "damage": 130.0, "knockback": 55.0, "shield": 170.0, "shield_duration": 4.0},
		},
		"tombstone": {
			"name": "墓碑", "cost": 3, "type": "building",
			"description": "持续召唤小鬼的建筑，适合建立防守屏障并拖延敌军。",
			# 建筑卡：2x2 格占地，物理碰撞使用 2x2 格内切圆，不可移动。
			# 完成部署立即生成两个小鬼，之后每 5 秒在地图中心线对应的一侧生成两个。
			"hp": 400.0, "damage": 0.0, "range": 0.0,
			"speed": 0.0, "interval": 1.0, "radius": 40.0,
			"footprint_tiles": Vector2i(2, 2),
			"color": Color(0.45, 0.40, 0.35),
			"is_air": false, "building_only": false, "can_attack_air": false,
			"is_building": true,
			"lifespan": 10.0,       # 存活时间（秒），到时自动消失
			"spawn_interval": 5.0,  # 每隔多久生成一批小鬼
			"spawn_count": 2,
			"spawn_side": "map_side",
			"death_spawn_id": "imp",
			"death_spawn_count": 2,
			"show_team_ring": false,
			"visual_radius": 40.0,
			"visual_scene_path": "res://assets/units/tombstone/tombstone_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Spawn", "idle": "Idle1", "death": "Death", "death_duration": 0.8,
			},
			"active_skill": {"name": "亡者集结", "kind": "summon", "spawn_id": "imp", "spawn_count": 4},
		},
		"aurelionsol": {
			"name": "龙王", "cost": 4, "type": "unit",
			"description": "空中持续输出单位，吐息能够同时压制目标及其周围敌人。",
			# 空中远程单位：持续喷吐龙息（DPS模式）
			"hp": 580.0, "damage": 55.0, "range": 130.0,
			"speed": SPEED_EXTREMELY_SLOW, "interval": 0.0, "first_hit": 0.4,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE, "visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"mass": 5.0, "sight": 250.0,
			"splash_radius": 34.0,
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
				# 普通进入移动仍用 RunIn；吐息后由 Spell1_2Run 直接接 Run1B，不重复 RunIn。
				"move": "Run1B", "move_enter": "RunIn",
				"move_cycle": ["Run1B", "Run1C", "Run1D", "Run1A"],
				# 移动后首次攻击用 newtst；原地击败目标并直接换目标时用 new_looptoin。
				"attack_enter": "AurelionSol_Spell1_newtst_anm",
				"attack_retarget_enter": "AurelionSol_Spell1_new_looptoin_anm",
				"attack_loop": "AurelionSol_Spell1_loop_anm",
				# 吐息后进入移动：Spell1_2Run 后摇 → Run1B→C→D→A。
				"attack_to_move": "Spell1_2Run",
				"move_enter_after_attack": false,
				"death": "Death", "death_duration": 0.8,
			},
			"is_air": true, "building_only": false, "can_attack_air": true,
			"is_continuous_attack": true,  # 持续伤害：每帧 damage*delta
			"active_skill": {"name": "星穹坠落", "kind": "nova", "radius": 145.0, "damage": 120.0, "slow_duration": 1.5, "slow_multiplier": 0.60},
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

## 召唤物与正式卡共用数据读取入口，避免调用方散落 imp 特判。
static func get_unit_stats(card_id: String) -> Dictionary:
	return imp_stats() if card_id == "imp" else get_card(card_id)

## 返回一张卡可供主动槽选择的技能集合。当前每张卡只有 active_skill 一个技能；
## 未来可改用 active_skills 数组，但一次出战仍只从集合中携带一个。
static func active_skills_for(card_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cards := all()
	if not cards.has(card_id):
		return result
	var stats: Dictionary = cards[card_id]
	for configured_skill in stats.get("active_skills", []):
		if configured_skill is Dictionary:
			result.append((configured_skill as Dictionary).duplicate(true))
	if result.is_empty() and stats.has("active_skill"):
		result.append((stats.active_skill as Dictionary).duplicate(true))
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
	match card_type:
		&"unit":
			_validate_combat_stats(card_id, stats, true, errors)
		&"building":
			_validate_combat_stats(card_id, stats, false, errors)
			_validate_building(card_id, stats, errors)
		&"spell":
			_require_fields(card_id, stats, [&"duration"], errors)
			if float(stats.get("duration", 0.0)) <= 0.0:
				errors.append("%s.duration: 法术持续时间必须 > 0" % card_id)
	_validate_visual_config(card_id, stats, errors)
	_validate_active_skills(card_id, stats, errors)
	if stats.has("transformed_stats"):
		var transformed = stats.get("transformed_stats")
		if not transformed is Dictionary or (transformed as Dictionary).is_empty():
			errors.append("%s.transformed_stats: 必须是非空 Dictionary" % card_id)
		else:
			_validate_known_fields("%s.transformed_stats" % card_id, transformed, CARD_FIELDS, errors)
			_validate_combat_stats("%s.transformed_stats" % card_id, transformed, true, errors)
			_validate_visual_config("%s.transformed_stats" % card_id, transformed, errors)

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
	_validate_projectile(label, stats, errors)

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
	if stats.has("projectile_colors"):
		var colors = stats.projectile_colors
		if not colors is Array or colors.size() != 2 or not colors[0] is Color or not colors[1] is Color:
			errors.append("%s.projectile_colors: 必须是蓝/红双方两个 Color" % label)

static func _validate_building(card_id: String, stats: Dictionary, errors: PackedStringArray) -> void:
	_require_fields(card_id, stats, [&"is_building", &"footprint_tiles", &"lifespan", &"visual_radius"], errors)
	if not bool(stats.get("is_building", false)):
		errors.append("%s.is_building: building 卡必须为 true" % card_id)
	var footprint = stats.get("footprint_tiles")
	if not footprint is Vector2i or footprint.x <= 0 or footprint.y <= 0:
		errors.append("%s.footprint_tiles: 必须是正数 Vector2i" % card_id)
	if float(stats.get("speed", -1.0)) != 0.0:
		errors.append("%s.speed: 建筑必须为 0" % card_id)

static func _validate_visual_config(label: String, stats: Dictionary, errors: PackedStringArray) -> void:
	for path_field in [&"visual_frames_path", &"visual_scene_path"]:
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
	for state in [&"deploy", &"idle", &"move", &"attack", &"attack_hit", &"attack_recover", &"attack_structure", &"move_cycle"]:
		if not animations.has(state):
			continue
		var value = animations[state]
		if not value is String and not value is StringName and not value is Array:
			errors.append("%s.visual_animations.%s: 必须是动画名或动画名数组" % [label, state])
		elif value is Array:
			for animation_name in value:
				if not animation_name is String and not animation_name is StringName:
					errors.append("%s.visual_animations.%s: 数组只能包含动画名" % [label, state])
	if animations.has("visual_actions"):
		var actions = animations.visual_actions
		if not actions is Dictionary:
			errors.append("%s.visual_animations.visual_actions: 必须是 Dictionary" % label)
		else:
			for action in actions:
				if not actions[action] is String and not actions[action] is StringName:
					errors.append("%s.visual_animations.visual_actions.%s: 必须是动画名" % [label, action])
	if animations.has("death_followup_scene_path") and not ResourceLoader.exists(String(animations.death_followup_scene_path)):
		errors.append("%s.visual_animations.death_followup_scene_path: 资源不存在" % label)

static func _validate_active_skills(card_id: String, stats: Dictionary, errors: PackedStringArray) -> void:
	var skills: Array = []
	if stats.has("active_skill"):
		skills.append(stats.active_skill)
	if stats.has("active_skills"):
		if not stats.active_skills is Array:
			errors.append("%s.active_skills: 必须是 Array" % card_id)
		else:
			skills.append_array(stats.active_skills)
	for index in range(skills.size()):
		var skill = skills[index]
		var label := "%s.active_skill[%d]" % [card_id, index]
		if not skill is Dictionary:
			errors.append("%s: 必须是 Dictionary" % label)
			continue
		_validate_known_fields(label, skill, ACTIVE_SKILL_FIELDS, errors)
		_require_fields(label, skill, [&"name", &"kind"], errors)
		var kind := StringName(skill.get("kind", ""))
		if kind not in ACTIVE_SKILL_KINDS:
			errors.append("%s.kind: 系统不支持 %s" % [label, kind])
			continue
		match kind:
			&"nova": _require_fields(label, skill, [&"radius", &"damage"], errors)
			&"buff": _require_fields(label, skill, [&"duration"], errors)
			&"summon": _require_fields(label, skill, [&"spawn_id", &"spawn_count"], errors)
			&"dual_form": _require_fields(label, skill, [&"length", &"width", &"damage", &"impact_delay", &"cast_duration", &"stun_duration"], errors)

static func _require_fields(label: String, data: Dictionary, fields: Array, errors: PackedStringArray) -> void:
	for field in fields:
		if not data.has(field):
			errors.append("%s.%s: 缺少必要字段" % [label, field])

static func _validate_known_fields(label: String, data: Dictionary, known_fields: Array, errors: PackedStringArray) -> void:
	for field in data:
		if StringName(field) not in known_fields:
			errors.append("%s.%s: 字段没有已知运行时读取方" % [label, field])

## 小鬼属性（墓碑生成，非卡牌）— 1费近战单位
static func imp_stats() -> Dictionary:
	return {
		"name": "小鬼",
		# 公主塔单次伤害为 55，小鬼落地后应恰好被防御塔一击击杀。
		"hp": 55.0, "damage": 25.0, "range": 24.0,
		"speed": SPEED_SLIGHTLY_FAST, "interval": 0.7, "first_hit": 0.25,
		"deploy_time": 0.0,
		"size_tier": SIZE_EXTREMELY_SMALL, "radius": RADIUS_EXTREMELY_SMALL, "visual_radius": RADIUS_EXTREMELY_SMALL + VISUAL_RADIUS_PADDING,
		"mass": 1.0, "sight": 180.0,
		"color": Color(0.55, 0.45, 0.80),
		"visual_scene_path": "res://assets/units/imp/imp_view.tscn",
		"visual_forward_yaw": 0.0,
		"visual_animations": {
			"deploy": "Spawn1", "idle": "Idle1", "move": "Run1",
			# 小鬼移动固定循环 Run1；普攻使用短促跃击前摇，权威伤害仍由 first_hit 结算。
			"attack": ["Yorick_ghoul_leapWindup_anm"],
			"death": "Death", "death_duration": 0.5,
		},
		"is_air": false, "building_only": false, "can_attack_air": false,
	}

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
