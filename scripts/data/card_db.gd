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
				"move": "Run_Base", "attack": ["Attack1", "Attack2"], "death": "Death",
			},
			"is_air": false, "building_only": true, "can_attack_air": false,
		},
		"xin": {
			"name": "赵信", "cost": 4, "type": "unit",
			"hp": 620.0, "damage": 68.0, "range": 40.0,
			"speed": SPEED_SLIGHTLY_FAST, "interval": 0.9, "first_hit": 0.3,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"mass": 5.0, "sight": 220.0,
			"charge_time": 2.0, "charge_speed_multiplier": 1.45, "charge_damage_multiplier": 2.0,
			"color": Color(0.85, 0.30, 0.25),
			"is_air": false, "building_only": false, "can_attack_air": false,
		},
		"ashe": {
			"name": "艾希", "cost": 3, "type": "unit",
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
				"attack": ["Attack1", "Attack2"], "death": "Death",
			},
			"is_air": false, "building_only": false, "can_attack_air": true,
		},
		"teemo": {
			"name": "提莫", "cost": 2, "type": "unit",
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
				"attack_hit_duration": 0.75, "death": "Death",
			},
			"is_air": false, "building_only": false, "can_attack_air": true,
		},
		# ===== 新增4张 =====
		"freeze": {
			"name": "冰冻", "cost": 3, "type": "spell",
			# 法术卡：不生成单位，在点击位置范围内冻结敌方单位3秒
			"radius": 110.0,    # 影响范围半径
			"duration": 3.0,    # 冰冻持续时间
			"color": Color(0.40, 0.70, 1.00),
		},
		"masteryi": {
			"name": "剑圣", "cost": 3, "type": "unit",
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
				"move": "Run", "attack": ["masteryi_2013_attack1_anm", "masteryi_2013_attack2_anm"], "death": "Death",
			},
			"is_air": false, "building_only": false, "can_attack_air": false,
		},
		"gwen": {
			"name": "格温", "cost": 4, "type": "unit",
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
				"attack": ["Attack1", "Attack2", "Attack3"], "death": "Death",
			},
			"is_air": false, "building_only": false, "can_attack_air": false,
		},
		"sett": {
			"name": "腕豪", "cost": 4, "type": "unit",
			# 近战拳师：连招节奏——快速两拳→稍作停顿→再快速两拳→再停顿。
			"hp": 800.0, "damage": 72.0, "range": 18.0,
			"speed": SPEED_MEDIUM, "interval": 1.1, "first_hit": 0.12,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE, "visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"mass": 6.0, "sight": 210.0,
			"attack_pattern": [0.28, 1.05, 0.28, 1.05],  # 两拳→停顿→两拳→停顿
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
				"death": "Death",
			},
			"is_air": false, "building_only": false, "can_attack_air": false,
		},
		"tombstone": {
			"name": "墓碑", "cost": 3, "type": "building",
			# 建筑卡：2x2 格占地，不可移动，生命值持续衰减，每秒生成一只小鬼
			"hp": 400.0, "damage": 0.0, "range": 0.0,
			"speed": 0.0, "interval": 1.0, "radius": 40.0,
			"footprint_tiles": Vector2i(2, 2),
			"color": Color(0.45, 0.40, 0.35),
			"is_air": false, "building_only": false, "can_attack_air": false,
			"is_building": true,
			"lifespan": 10.0,       # 存活时间（秒），到时自动消失
			"spawn_interval": 1.0,  # 每隔多久生成一只小鬼
		},
		"aurelionsol": {
			"name": "龙王", "cost": 4, "type": "unit",
			# 空中远程单位：持续喷吐龙息（DPS模式）
			"hp": 580.0, "damage": 55.0, "range": 130.0,
			"speed": SPEED_EXTREMELY_SLOW, "interval": 0.0, "first_hit": 0.4,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE, "visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"mass": 5.0, "sight": 250.0,
			"splash_radius": 34.0,
			"color": Color(0.95, 0.75, 0.25),
			"is_air": true, "building_only": false, "can_attack_air": true,
			"is_continuous_attack": true,  # 持续伤害：每帧 damage*delta
		},
	}

## 小鬼属性（墓碑生成，非卡牌）— 1费近战单位
static func imp_stats() -> Dictionary:
	return {
		"name": "小鬼",
		"hp": 120.0, "damage": 25.0, "range": 24.0,
		"speed": SPEED_SLIGHTLY_FAST, "interval": 0.7, "first_hit": 0.25,
		"size_tier": SIZE_EXTREMELY_SMALL, "radius": RADIUS_EXTREMELY_SMALL, "visual_radius": RADIUS_EXTREMELY_SMALL + VISUAL_RADIUS_PADDING,
		"mass": 1.0, "sight": 180.0,
		"color": Color(0.55, 0.45, 0.80),
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
