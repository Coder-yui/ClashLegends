class_name CardDB
## 卡牌数值定义库。调整平衡只改这里。
## 卡牌类型 type: "unit"=单位, "spell"=法术, "building"=建筑
## 尺寸对应 CR 分级：
##   小(半径10): 骷髅/小兵类 — 被推,容易被 AOE 一锅端
##   中(半径12-14): 骑士/弓箭手类
##   大(半径16+): 巨人/坦克类 — 能推动中小型,抗 AOE
## 速度对应 CR: 慢(40-50) / 中(50-65) / 快(65-85) / 冲锋(>90)
## building_only: true 时只攻击建筑（塔+建筑卡），无视普通单位
## can_attack_air: false 时无法选中/攻击空中单位（近战地面单位通常不能对空）
## is_continuous_attack: true 时持续伤害（DPS模式，每帧造成 damage*delta）

static func all() -> Dictionary:
	return {
		# ===== 原有4张 =====
		"garen": {
			"name": "盖伦", "cost": 5, "type": "unit",
			"hp": 1050.0, "damage": 88.0, "range": 32.0,
			"speed": 46.0, "interval": 1.1, "first_hit": 0.4, "radius": 16.0, "visual_radius": 19.0, "mass": 8.0, "sight": 220.0,
			"color": Color(0.35, 0.55, 0.90),
			"is_air": false, "building_only": true, "can_attack_air": false,
		},
		"xin": {
			"name": "赵信", "cost": 4, "type": "unit",
			"hp": 620.0, "damage": 68.0, "range": 30.0,
			"speed": 72.0, "interval": 0.9, "first_hit": 0.3, "radius": 14.0, "visual_radius": 17.0, "mass": 5.0, "sight": 220.0,
			"charge_time": 2.0, "charge_speed_multiplier": 1.45, "charge_damage_multiplier": 2.0,
			"color": Color(0.85, 0.30, 0.25),
			"is_air": false, "building_only": false, "can_attack_air": false,
		},
		"ashe": {
			"name": "艾希", "cost": 3, "type": "unit",
			"hp": 340.0, "damage": 58.0, "range": 130.0,
			"speed": 52.0, "interval": 1.0, "first_hit": 0.35, "radius": 12.0, "visual_radius": 15.0, "mass": 3.0, "sight": 240.0,
			"projectile_speed": 480.0,
			"color": Color(0.50, 0.85, 0.95),
			"is_air": false, "building_only": false, "can_attack_air": true,
		},
		"teemo": {
			"name": "提莫", "cost": 2, "type": "unit",
			"hp": 230.0, "damage": 38.0, "range": 105.0,
			"speed": 66.0, "interval": 0.8, "first_hit": 0.25, "radius": 10.0, "visual_radius": 13.0, "mass": 2.0, "sight": 210.0,
			"projectile_speed": 380.0,
			"color": Color(0.60, 0.80, 0.30),
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
			"hp": 480.0, "damage": 52.0, "range": 28.0,
			"speed": 78.0, "interval": 0.45, "first_hit": 0.2, "radius": 12.0, "visual_radius": 16.0, "mass": 4.0, "sight": 200.0,
			"color": Color(0.20, 0.80, 0.50),
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
			"hp": 580.0, "damage": 55.0, "range": 110.0,
			"speed": 50.0, "interval": 0.0, "first_hit": 0.4, "radius": 15.0, "visual_radius": 20.0, "mass": 5.0, "sight": 250.0,
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
		"speed": 70.0, "interval": 0.7, "first_hit": 0.25, "radius": 9.0, "visual_radius": 11.0, "mass": 1.0, "sight": 180.0,
		"color": Color(0.55, 0.45, 0.80),
		"is_air": false, "building_only": false, "can_attack_air": false,
	}
