class_name ProjectileSuite
extends RefCounted

var _harness: Object
var _main: Node2D

func _init(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func _check_projectile_travel() -> void:
	var attacker_stats: Dictionary = CardDB.get_card("ashe").duplicate()
	attacker_stats["deploy_time"] = 0.0
	var target_stats: Dictionary = CardDB.get_card("xin").duplicate()
	target_stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	var target := Unit.new()
	attacker.position = Vector2(200.0, 800.0)
	target.position = Vector2(320.0, 800.0)
	attacker.setup(0, attacker_stats, attacker_stats.name)
	target.setup(1, target_stats, target_stats.name)
	_main.add_child(attacker)
	_main.add_child(target)
	var hp_before := target.hp
	_main.launch_attack(attacker, target, 50.0, attacker.projectile_speed, 0.0, 0.0, attacker.color)
	_expect(target.hp == hp_before and not _main._projectiles.is_empty(), "远程攻击先生成弹道，不会瞬时扣血")
	var projectile: Dictionary = _main._projectiles.values()[0]
	var raised_from_bow: bool = is_equal_approx(projectile.visual_height, 45.0) and is_equal_approx(_main._projectile_system._visual_position(projectile).y, attacker.position.y - 45.0)
	_expect(projectile.visual == &"arrow" and projectile.direction.x > 0.9 and is_equal_approx(projectile.radius, 3.0) and raised_from_bow, "寒冰弹体使用朝向目标、从弓部高度出现的蓝色小箭表现")
	for _i in 12:
		_main._tick_projectiles(_main.SIM_DT)
	_expect(target.hp < hp_before and _main._projectiles.is_empty(), "弹道抵达目标碰撞圆后才结算伤害")
	attacker.free()
	target.free()
	var teemo_stats: Dictionary = CardDB.get_card("teemo").duplicate()
	teemo_stats["deploy_time"] = 0.0
	var teemo := Unit.new()
	var teemo_target := Unit.new()
	teemo.position = Vector2(200.0, 800.0)
	teemo_target.position = Vector2(300.0, 800.0)
	teemo.setup(0, teemo_stats, teemo_stats.name)
	teemo_target.setup(1, target_stats, target_stats.name)
	_main.add_child(teemo)
	_main.add_child(teemo_target)
	_main.launch_attack(teemo, teemo_target, 10.0, teemo.projectile_speed, 0.0, 0.0, teemo.color)
	var needle: Dictionary = _main._projectiles.values()[0]
	_expect(needle.visual == &"needle" and needle.color.g > needle.color.r and is_equal_approx(needle.visual_height, 42.0), "提莫生成从放大后吹管口高度飞出的短绿色线条弹体")
	_main._projectiles.clear()
	teemo.free()
	teemo_target.free()

## 防御塔弹体只改变表现起点：权威位置仍从塔心出发，蓝/红塔分别使用蓝/红能量球。
func _check_tower_projectile_visual() -> void:
	var tower_stats: Dictionary = CardDB.PRINCESS_TOWER_STATS
	var target_stats: Dictionary = CardDB.get_card("xin").duplicate()
	target_stats["deploy_time"] = 0.0
	var blue_tower := Tower.new()
	var blue_target := Unit.new()
	blue_tower.position = Vector2(140.0, 900.0)
	blue_target.position = Vector2(140.0, 700.0)
	blue_tower.setup(0, tower_stats, false)
	blue_target.setup(1, target_stats, target_stats.name)
	_main.add_child(blue_tower)
	_main.add_child(blue_target)
	_main.launch_attack(blue_tower, blue_target, blue_tower.damage, blue_tower.projectile_speed, 0.0, 0.0, Tower.BLUE_PROJECTILE_COLOR)
	var blue_projectile: Dictionary = _main._projectiles.values()[0]
	var blue_visual_start: Vector2 = _main._projectile_system._visual_position(blue_projectile)
	var blue_start_ok: bool = (
		blue_projectile.visual == &"tower_orb"
		and blue_projectile.pos == blue_tower.global_position
		and blue_projectile.color == Tower.BLUE_PROJECTILE_COLOR
		and blue_projectile.visual_offset == blue_tower.projectile_visual_offset
		and blue_visual_start == blue_tower.global_position + blue_tower.projectile_visual_offset
	)
	_expect(blue_start_ok, "我方防御塔弹体从权杖晶石位置发出，权威发射点仍在塔心且使用蓝色")
	_main._tick_projectiles(_main.SIM_DT)
	var blue_after_tick: Dictionary = _main._projectiles.values()[0]
	_expect(
		blue_after_tick.pos != blue_tower.global_position
		and blue_after_tick.visual_offset.length() < blue_tower.projectile_visual_offset.length(),
		"塔弹体飞行后视觉偏移回到真实命中轨迹，不改变权威飞行位置",
	)
	_main._projectiles.clear()
	blue_tower.free()
	blue_target.free()

	var red_tower := Tower.new()
	var red_target := Unit.new()
	red_tower.position = Vector2(580.0, 300.0)
	red_target.position = Vector2(580.0, 500.0)
	red_tower.setup(1, tower_stats, false)
	red_target.setup(0, target_stats, target_stats.name)
	_main.add_child(red_tower)
	_main.add_child(red_target)
	_main.launch_attack(red_tower, red_target, red_tower.damage, red_tower.projectile_speed, 0.0, 0.0, Tower.RED_PROJECTILE_COLOR)
	var red_projectile: Dictionary = _main._projectiles.values()[0]
	_expect(
		red_projectile.color == Tower.RED_PROJECTILE_COLOR
		and red_tower.projectile_visual_offset.x < 0.0
		and red_projectile.pos == red_tower.global_position,
		"敌方防御塔弹体使用红色并镜像到另一侧权杖晶石，实际发射位置不变",
	)
	_main._projectiles.clear()
	red_tower.free()
	red_target.free()

func _check_projectile_visual_snapshot() -> void:
	var snapshot_system := NetworkSnapshotSystem.new(_main)
	var payload := snapshot_system._projectile_snapshot_payload(991, {
		"pos": Vector2(120.0, 340.0), "color": Color(1.0, 0.34, 0.08), "radius": 4.0,
		"visual": &"orb", "direction": Vector2.UP, "visual_height": 46.75,
		"visual_offset": Vector2(0.0, -20.0), "visual_scale": 2.25,
	})
	var old_mode: String = _main.mode
	_main.mode = "client"
	_main._client_projectiles.clear()
	snapshot_system._apply_projectiles([payload])
	var client_projectile: Dictionary = _main._client_projectiles.get(991, {})
	_expect(
		payload.size() == NetworkSnapshotSystem.PROJECTILE_PAYLOAD_SIZE
		and is_equal_approx(float(client_projectile.get("visual_scale", 0.0)), 2.25)
		and client_projectile.get("color", Color.BLACK) == Color(1.0, 0.34, 0.08),
		"弹体快照协议同步橙红颜色与纯表现尺寸倍率，客户端不会回退为普通小光球",
	)
	_main._client_projectiles.clear()
	_main.mode = old_mode

## 墓碑小鬼的生命值与公主塔单次伤害一致，确保一次塔击恰好击杀。
func _check_imp_tower_damage() -> void:
	var imp_stats: Dictionary = CardDB.get_unit_stats("imp")
	_expect(
		is_equal_approx(imp_stats.hp, CardDB.PRINCESS_TOWER_STATS.damage),
		"墓碑小鬼生命值恰好等于公主塔单次伤害（一次击杀）",
	)

func _check_splash_and_knockback() -> void:
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
	stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	var primary := Unit.new()
	var secondary := Unit.new()
	attacker.position = Vector2(220.0, 800.0)
	primary.position = Vector2(300.0, 800.0)
	secondary.position = Vector2(340.0, 800.0)
	attacker.setup(0, stats, stats.name)
	primary.setup(1, stats, stats.name)
	secondary.setup(1, stats, stats.name)
	_main.add_child(attacker)
	_main.add_child(primary)
	_main.add_child(secondary)
	var primary_hp := primary.hp
	var secondary_hp := secondary.hp
	_main.launch_attack(attacker, primary, 30.0, 0.0, 34.0, 28.0, attacker.color)
	_expect(primary.hp < primary_hp and secondary.hp < secondary_hp, "范围攻击按命中点和碰撞圆伤害多个目标")
	var before_push := primary.position.x
	primary.sim_tick(_main.SIM_DT)
	_main._apply_unit_movement(_main.SIM_DT)
	_expect(primary.position.x > before_push, "击退方向远离攻击来源并按固定模拟移动")
	attacker.free()
	primary.free()
	secondary.free()
