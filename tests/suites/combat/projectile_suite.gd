class_name ProjectileSuite
extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_client_state_ownership()
	_check_projectile_travel()
	_check_tower_projectile_visual()
	_check_projectile_visual_snapshot()
	_check_imp_tower_damage()
	_check_splash_and_knockback()
	_check_authority_ignores_presentation()

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
	_expect(target.hp == hp_before and not _main._projectile_system.projectiles.is_empty(), "远程攻击先生成弹道，不会瞬时扣血")
	var projectile: Dictionary = _main._projectile_system.projectiles.values()[0]
	var raised_from_bow: bool = is_equal_approx(projectile.visual_height, 45.0) and is_equal_approx(_main._projectile_system._visual_position(projectile).y, attacker.position.y - 45.0)
	_expect(projectile.visual == &"arrow" and projectile.direction.x > 0.9 and is_equal_approx(projectile.radius, 3.0) and raised_from_bow, "寒冰弹体使用朝向目标、从弓部高度出现的蓝色小箭表现")
	for _i in 12:
		_main._tick_projectiles(_main.SIM_DT)
	_expect(target.hp < hp_before and _main._projectile_system.projectiles.is_empty(), "弹道抵达目标碰撞圆后才结算伤害")
	attacker.set_meta("projectile_model_offset", Vector2(5, -35))
	target.set_meta("projectile_model_offset", Vector2(0, -80))
	_main.launch_attack(attacker, target, 10.0, attacker.projectile_speed, 0.0, 0.0, attacker.color)
	var anchored: Dictionary = _main._projectile_system.projectiles.values()[0]
	var visual_start: Vector2 = _main._projectile_system._visual_position(anchored)
	_expect(visual_start == attacker.position + Vector2(5, -35) and anchored.pos != visual_start, "远程弹体画面从模型锚点创建，权威出生点独立")
	_main._tick_projectiles(_main.SIM_DT)
	anchored = _main._projectile_system.projectiles.values()[0]
	var visual_mid: Vector2 = _main._projectile_system._visual_position(anchored)
	_expect(visual_mid.y < visual_start.y and _main._projectile_system._direction(anchored).y < 0.0, "远程弹体向目标模型锚点抬升并沿可见轨迹朝向")
	_main._projectile_system.clear_all()
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
	var needle: Dictionary = _main._projectile_system.projectiles.values()[0]
	_expect(needle.visual == &"needle" and needle.color.g > needle.color.r and is_equal_approx(needle.visual_height, 42.0), "提莫生成从放大后吹管口高度飞出的短绿色线条弹体")
	_main._projectile_system.projectiles.clear()
	_main.launch_attack(teemo, teemo_target, 10.0, teemo.projectile_speed, 0.0, 0.0, teemo.color, {"blind_charges": 2})
	var blind_needle: Dictionary = _main._projectile_system.projectiles.values()[0]
	_expect(blind_needle.visual == &"blind_needle" and blind_needle.effects.blind_charges == 2, "提莫致盲吹箭使用独立紫色表现类型，保留两次致盲权威效果")
	_main._projectile_system.projectiles.clear()
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
	var blue_projectile: Dictionary = _main._projectile_system.projectiles.values()[0]
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
	var blue_after_tick: Dictionary = _main._projectile_system.projectiles.values()[0]
	_expect(
		blue_after_tick.pos != blue_tower.global_position
		and blue_after_tick.visual_offset.length() < blue_tower.projectile_visual_offset.length(),
		"塔弹体飞行后视觉偏移回到真实命中轨迹，不改变权威飞行位置",
	)
	_main._projectile_system.projectiles.clear()
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
	var red_projectile: Dictionary = _main._projectile_system.projectiles.values()[0]
	_expect(
		red_projectile.color == Tower.RED_PROJECTILE_COLOR
		and red_tower.projectile_visual_offset.x < 0.0
		and red_projectile.pos == red_tower.global_position,
		"敌方防御塔弹体使用红色并镜像到另一侧权杖晶石，实际发射位置不变",
	)
	_main._projectile_system.projectiles.clear()
	red_tower.free()
	red_target.free()

func _check_projectile_visual_snapshot() -> void:
	var snapshot_system := NetworkSnapshotSystem.new(_main, _main._projectile_system)
	var payload := snapshot_system._projectile_snapshot_payload(991, {
		"pos": Vector2(120.0, 340.0), "color": Color(1.0, 0.34, 0.08), "radius": 4.0,
		"visual": &"orb", "direction": Vector2.UP, "visual_height": 46.75,
		"visual_offset": Vector2(0.0, -20.0), "visual_scale": 2.25,
	})
	var old_mode: String = _main.mode
	_main.mode = "client"
	_main._projectile_system.clear_client()
	snapshot_system._apply_projectiles([payload])
	var client_projectile: Dictionary = _main._projectile_system.client_snapshot().get(991, {})
	_expect(
		payload.size() == NetworkSnapshotSystem.PROJECTILE_PAYLOAD_SIZE
		and is_equal_approx(float(client_projectile.get("visual_scale", 0.0)), 2.25)
		and client_projectile.get("color", Color.BLACK) == Color(1.0, 0.34, 0.08),
		"弹体快照协议同步橙红颜色与纯表现尺寸倍率，客户端不会回退为普通小光球",
	)
	_main._projectile_system.clear_client()
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
	_main._movement._apply_unit_movement(_main.SIM_DT, _main._movement._active_mobile_units())
	_expect(primary.position.x > before_push, "击退方向远离攻击来源并按固定模拟移动")
	attacker.free()
	primary.free()
	secondary.free()

## 确定性轨迹重放：定义/形态只换表现后，逐 Tick 位置、掉血和死亡必须一致。
func _check_authority_ignores_presentation() -> void:
	for card_id in CardDB.all():
		var stats: Dictionary = CardDB.get_unit_stats(card_id)
		if float(stats.get("projectile_speed", 0.0)) <= 0.0:
			continue
		for team in 2:
			for lethal in [false, true]:
				var original := _attack_trace(card_id, stats, team, lethal, false)
				var changed := _attack_trace(card_id, stats, team, lethal, true)
				_expect(original == changed, "%s 阵营%d lethal=%s：仅换弹体/模型/音频配置，逐 Tick 权威轨迹与伤亡不变" % [card_id, team, lethal])
	for team in 2:
		_expect(_attack_trace("kayle_ranged", CardDB.get_unit_stats("kayle_ranged"), team, false, false, true) == _attack_trace("kayle_ranged", CardDB.get_unit_stats("kayle_ranged"), team, false, true, true), "光剑及伴随焰浪仅改表现不改变逐Tick伤亡")
	# 防御塔与建筑卡走不同实体路径；两者都覆盖。
	for team in 2:
		_expect(_attack_trace("tower", CardDB.PRINCESS_TOWER_STATS, team, true, false) == _attack_trace("tower", CardDB.PRINCESS_TOWER_STATS, team, true, true), "防御塔阵营%d：纯表现偏移不改命中 Tick" % team)
	for card_id in ["ashe", "twisted_fate", "apex_turret"]:
		for team in 2:
			_expect(_fan_trace(card_id, team, false) == _fan_trace(card_id, team, true), "%s 阵营%d：扇形/穿透技能仅换外观不改逐 Tick 命中、生命和控制" % [card_id, team])

func _attack_trace(card_id: String, configured: Dictionary, team: int, lethal: bool, change_visual: bool, include_wave := false) -> Array:
	seed(9014)
	_main._projectile_system.clear_all()
	var stats := configured.duplicate(true)
	stats["deploy_time"] = 0.0
	if change_visual:
		stats["projectile_visual"] = "orb" if String(stats.get("projectile_visual", "orb")) != "orb" else "arrow"
		stats["attack_wave_visual"] = "orb"
		stats["attack_wave_visual_height"] = 190.0
		stats["projectile_visual_height"] = 100.0
		stats["projectile_visual_forward_offset"] = 70.0
		stats["projectile_visual_offset"] = Vector2(25, -100)
		stats["projectile_visual_scale"] = 3.0
		stats["visual_radius"] = 100.0
		stats["visual_scene_path"] = ""
		stats["visual_animations"] = {}
		stats["audio"] = {}
	var attacker: Node2D = Tower.new() if card_id == "tower" else Unit.new()
	attacker.position = Vector2(10000, 10000)
	if attacker is Tower:
		attacker.setup(team, stats, false)
	else:
		attacker.setup(team, stats, stats.name)
		# 单弹体参考几何独立验证；伴随波另做完整轨迹比较。
		if not include_wave: attacker.attack_wave.clear()
	var target := Unit.new()
	var target_stats := CardDB.training_dummy_stats()
	target_stats["hp"] = 40 if lethal else 100
	target_stats["deploy_time"] = 0.0
	target.setup(1 - team, target_stats, "轨迹木桩")
	target.position = attacker.position + Vector2(185, 0)
	_main.add_child(attacker)
	_main.add_child(target)
	_main.launch_attack(attacker, target, 50.0, attacker.projectile_speed, 0.0, 0.0, Color.WHITE)
	var shot: Dictionary = _main._projectile_system.projectiles.values()[0]
	# 独立几何基线：旧卡保持迁移前规则；新远程天使采用身体边缘+7.5。
	var legacy_edge := card_id in ["ashe", "teemo", "gnar", "anivia", "kayle_ranged"]
	var expected_start := attacker.position + Vector2(attacker.body_radius + 7.5, 0) if legacy_edge else attacker.position
	var expected_radius := 7.0 if card_id == "tower" else (3.0 if card_id == "ashe" else 4.0)
	if not change_visual:
		_expect(shot.pos == expected_start and shot.radius == expected_radius, "%s：保持迁移前权威出生点与碰撞半径" % card_id)
	var trace: Array = [[shot.pos, shot.radius, target.hp]]
	var reference_position := expected_start
	var expected_hp: float = target.hp
	var reference_alive := true
	for tick in 30:
		target.position = Vector2(10185 - tick * 0.75, 10000 + sin(tick * 0.2) * 4.0)
		if reference_alive:
			reference_position = reference_position.move_toward(target.position, attacker.projectile_speed * _main.SIM_DT)
			if reference_position.distance_to(target.position) <= target.body_radius + expected_radius:
				expected_hp = maxf(expected_hp - 50.0, 0.0)
				reference_alive = false
		_main._tick_projectiles(_main.SIM_DT)
		var alive: bool = not _main._projectile_system.projectiles.is_empty()
		trace.append([tick, target.hp, target.hp <= 0.0, _main._projectile_system.projectiles.values()[0].pos if alive else Vector2.ZERO])
		if not change_visual and not include_wave:
			_expect(target.hp == expected_hp and alive == reference_alive, "%s Tick%d：原始几何重放的命中/伤亡保持不变" % [card_id, tick])
	_main._projectile_system.clear_all()
	attacker.free()
	target.free()
	return trace

func _fan_trace(card_id: String, team: int, change_visual: bool) -> Array:
	seed(9014)
	_main._projectile_system.clear_all()
	var stats := CardDB.get_card(card_id).duplicate(true)
	stats["deploy_time"] = 0.0
	var source := Unit.new()
	source.setup(team, stats, stats.name)
	source.position = Vector2(12000, 12000)
	_main.add_child(source)
	var skill: Dictionary = stats.active_skills[0].duplicate(true)
	if change_visual:
		skill["projectile_visual"] = "orb"
		skill["projectile_visual_width"] = 90.0
		skill["projectile_visual_height"] = 150.0
		skill["projectile_visual_forward_offset"] = 180.0
	var targets: Array[Unit] = []
	for index in 3:
		var target := Unit.new()
		var target_stats := CardDB.training_dummy_stats()
		target_stats["hp"] = 40 if index == 0 else 300
		target_stats["deploy_time"] = 0.0
		target.setup(1 - team, target_stats, "技能木桩")
		target.position = source.position + Vector2(90 + index * 45, 0)
		_main.add_child(target)
		targets.append(target)
	_main._projectile_system.launch_skill_fan(source, skill, Vector2.RIGHT)
	var trace: Array = []
	for tick in 12:
		for index in targets.size():
			targets[index].position.y = 12000 + sin(tick * 0.1) * index
		_main._tick_projectiles(_main.SIM_DT)
		var state: Array = []
		for target in targets:
			state.append([target.hp, target.hp <= 0.0, target.control.slow_timer, target.control.stun_timer])
		for projectile in _main._projectile_system.projectiles.values():
			state.append([projectile.pos, projectile.radius, projectile.remaining])
		trace.append(state)
	_main._projectile_system.clear_all()
	for target in targets:
		target.free()
	source.free()
	return trace

func _check_client_state_ownership() -> void:
	var owner := ProjectileSystem.new()
	var targets := {1: {"pos": Vector2(10, 20), "target_pos": Vector2(10, 20), "visual_offset": Vector2(3, 4), "meta": {"value": 1}}}
	owner.apply_client_targets(targets)
	targets[1].pos = Vector2.ZERO
	targets[1].meta.value = 99
	var first := owner.client_snapshot()
	_expect(first[1].pos == Vector2(10, 20) and first[1].meta.value == 1, "客户端弹体接收深副本，外部修改输入不改变内部状态")
	first[1].pos = Vector2.ZERO
	first[1].meta.value = 88
	_expect(owner.client_snapshot()[1].pos == Vector2(10, 20) and owner.client_snapshot()[1].meta.value == 1, "弹体读取副本不泄露内部嵌套状态")
	owner.apply_client_targets({1: {"pos": Vector2(30, 40), "target_pos": Vector2(30, 40), "visual_offset": Vector2(8, 9)}, 2: {"pos": Vector2.ONE, "visual_offset": Vector2.ZERO}})
	var newer := owner.client_snapshot()
	_expect(newer[1].pos == Vector2(10, 20) and newer[1].target_pos == Vector2(30, 40) and newer[1].visual_offset == Vector2(3, 4) and newer.has(2), "后续快照更新目标并保留插值位置，新弹体从首个位置出现")
	owner.apply_client_targets({2: {"pos": Vector2.ONE, "visual_offset": Vector2.ZERO}})
	_expect(owner.client_snapshot().keys() == [2], "弹体所有者删除完整快照中消失的 id")
	owner.clear_client()
	_expect(owner.client_snapshot().is_empty(), "客户端弹体清场入口可重复调用")
	owner.clear_client()
	owner.free()
