extends "res://tests/suites/battle_suite.gd"

func run(harness: Object) -> void:
	_harness = harness
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	_check_growth()
	_check_sacrifice_and_replica()
	_check_exceptions()
	_main.free()
	_main = null

func _spawn(id: String, pos: Vector2, deploy: float = 0.0) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(0, id, pos, {"deploy_time_override": deploy, "position_resolved": true}))

func _clear_units() -> void:
	_main.runtime._commands.clear()
	for actor in _main.get_tree().get_nodes_in_group("combatants"):
		if actor is Unit: actor.free()

func _check_growth() -> void:
	var tower: Tower = _main.world.towers_snapshot()[0]
	var original := tower.position + Vector2(0, -80)
	var unit := _spawn("garen", original, 1.0)
	var lulu := _spawn("lulu", original + Vector2(180, 0))
	var hp := unit.hp
	_expect(_main.world.is_ground_position_walkable(original, unit.body_radius, unit), "盖伦原始半径在塔前合法")
	_expect(_main._active_skill_effect_system.apply(lulu, CardDB.active_skills_for("lulu")[0]), "正式璐璐R命中部署中的盖伦")
	_expect(is_equal_approx(unit.body_radius, 31.2) and unit.growth_body_scale == 1.3, "增长使用正式倍率")
	_expect(unit.position != original and _main.world.is_ground_position_walkable(unit.position, unit.body_radius, unit), "成长当场完成新半径空间交接")
	_expect(unit._prev_pos == unit.position and unit.net_target_pos == unit.position, "安全交接重置插值端点")
	var grown_hp := unit.hp
	var resolved := unit.position
	_expect(grown_hp > hp and not unit.apply_permanent_growth(0.3, 1.3) and unit.hp == grown_hp and unit.position == resolved, "重复成长不叠生命或重复位移")
	# 删除施法者，排除璐璐或皮克斯的推挤；正式20Hz单位/移动阶段继续前进。
	lulu.free()
	_main.runtime._commands.clear()
	_run_main_ticks(40)
	_expect(unit.position.distance_to(resolved) > 5.0 and _main.world.is_ground_position_walkable(unit.position, unit.body_radius, unit), "部署完成后盖伦靠自身移动脱离塔边")
	var payload: Array = preload("res://tests/fixtures/network_fixture.gd").snapshot_payload(_main._snapshot_system, unit.net_id, unit)
	_check_new_replica(payload, "garen", unit.hp, unit.max_hp, unit.body_radius)
	_clear_units()
	var gnar := _spawn("gnar", original)
	gnar.apply_permanent_growth(0.3, 1.3)
	var bonus := gnar.growth_health_bonus
	gnar.transform_to_mega(true)
	_expect(_main.world.is_ground_position_walkable(gnar.position, gnar.body_radius, gnar) and gnar.max_hp == BattleNumbers.quantity(float(gnar.transformed_stats.hp)) + bonus, "普通换形复用收尾并保留一次成长生命")
	var mega_pos := gnar.position
	gnar.transform_to_small()
	_expect(gnar.position == mega_pos and is_equal_approx(gnar.body_radius, float(gnar._base_form_stats.radius) * 1.3), "缩小不重复移位或叠成长")
	_clear_units()

func _check_sacrifice_and_replica() -> void:
	var pos: Vector2 = _main.world.towers_snapshot()[0].position + Vector2(0, -(_main.world.towers_snapshot()[0].body_radius + float(CardDB.get_unit_stats("void_spawn").radius) + 2.0))
	var unit := _spawn("void_spawn", pos)
	var caster := unit
	var skill: Dictionary = CardDB.active_skills_for("void_spawn").filter(func(s): return s.kind == "sacrifice_empower")[0]
	unit.deployment_group_id = 100
	var hp := unit.hp
	_expect(_main._active_skill_effect_system.apply(caster, skill), "虚空兽强化使用正式技能入口")
	_expect(unit.position != pos and _main.world.is_ground_position_walkable(unit.position, unit.body_radius, unit) and unit.hp == hp + unit.sacrifice_stats.x, "虚空兽强化满足空间和一次生命增量")
	var applied := unit.sacrifice_stats
	var maximum := unit.max_hp
	var radius := unit.body_radius
	var stable := unit.position
	unit.set_sacrifice_stats(applied)
	_expect(unit.max_hp == maximum and is_equal_approx(unit.body_radius, radius) and unit.position == stable, "重复强化赋值不叠属性或移位")
	# 使用正式快照字段生成和副本消费入口，同一payload重复应用。
	var payload: Array = preload("res://tests/fixtures/network_fixture.gd").snapshot_payload(_main._snapshot_system, unit.net_id, unit)
	_check_new_replica(payload, "void_spawn", unit.hp, maximum, radius)
	_clear_units()

func _check_new_replica(payload: Array, card: String, expected_hp: float, expected_max: float, expected_radius: float) -> void:
	var client = preload("res://tests/fixtures/authority_battle.gd").new()
	_harness.root.add_child(client)
	client.runtime.mode = "client"
	var server_position := Vector2(payload[NetworkSnapshotSystem.U_X], payload[NetworkSnapshotSystem.U_Y])
	var replica: Unit = client._spawn_unit(UnitSpawnRequest.new(0, card, server_position, {"position_resolved": true, "deploy_time_override": 0.0}))
	replica.net_id = int(payload[NetworkSnapshotSystem.U_ID])
	client.world.register_replica_unit(replica)
	_expect(replica.growth_body_scale == 1.0 and replica.sacrifice_stats == Vector3(0, 1, 1) and replica.max_hp < expected_max and replica.body_radius < expected_radius, "新客户端实例尚未成长或强化:" + card)
	var calls: int = client.resize_requests
	client._snapshot_system._apply_units([payload])
	_expect(replica.hp == expected_hp and replica.max_hp == expected_max and is_equal_approx(replica.body_radius, expected_radius), "首次副本接收增加生命上限和半径字段:" + card)
	_expect(client.resize_requests == calls and replica.position == server_position and replica.net_target_pos == server_position, "首次半径增大不调用权威空间修正且保留服务器位置:" + card)
	client._snapshot_system._apply_units([payload])
	_expect(replica.hp == expected_hp and replica.max_hp == expected_max and is_equal_approx(replica.body_radius, expected_radius) and replica.position == server_position and client.resize_requests == calls, "重复副本不叠属性或重新判落点:" + card)
	client.free()

func _check_exceptions() -> void:
	for id in ["corki", "kayn"]:
		var pos := Vector2(360, 640)
		var unit := _spawn(id, pos)
		unit.apply_permanent_growth(0.3, 1.3)
		_expect(unit.position == pos, "空军或穿地形保持既有空间资格:" + id)
		_clear_units()
	var building := _spawn("tombstone", Vector2(360, 900))
	_expect(not building.apply_permanent_growth(0.3, 1.3), "建筑仍不是成长目标")
	_clear_units()
	var unit := _spawn("garen", _main.world.towers_snapshot()[0].position + Vector2(0, -80))
	var start := unit.position
	unit.knockback.replace_forced(start, start + Vector2(0, -100), Vector2.UP, 100, 0.5, 100)
	unit.apply_permanent_growth(0.3, 1.3)
	_expect(unit.position == start and unit.knockback.in_transit, "外力途中成长不提前落地")
	_run_main_ticks(14)
	_expect(not unit.knockback.in_transit and _main.world.is_ground_position_walkable(unit.position, unit.body_radius, unit), "强制位移到达后按新半径完成落点")
	_clear_units()
