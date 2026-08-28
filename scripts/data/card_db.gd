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
