extends "res://tests/suites/battle_suite.gd"

func _aim(source: Unit, ticks: int = 20) -> void:
	for i in ticks: source.auto_pull.tick(source, 0.05)

func _flight(ticks: int = 6) -> void:
	for i in ticks: _main._projectile_system.tick(0.05)

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var source := _spawn_ready_unit("blitzcrank", 0, Vector2(300, 1000))
	var target := _spawn_ready_unit("garen", 1, Vector2(480, 1000))
	target.can_attack = false
	_expect(source.attack_range == 56.0 and source.sight_range == 220.0, "普攻1.4格、视野5.5格")
	source.attack_timeline.cooldown = 9.0
	_expect(source.auto_pull.try_start(source), "瞄准不等待普攻冷却")
	_expect(source.attack_timeline.cooldown == 0.0, "瞄准沿用通用施法锁刷新普攻")
	_aim(source, 19)
	_expect(not source.auto_pull.launched and _main._projectile_system.projectiles.is_empty(), "瞄准未满1秒不出钩")
	_expect(source.attack_timeline.cooldown == 0.0, "瞄准保持通用施法节奏")
	target.position = Vector2(300, 800)
	_aim(source, 1)
	_expect(source.auto_pull.launched and source.active_skill_cast_facing.y < -0.9, "瞄准跟随目标朝向，满1秒释放")
	var id := source.auto_pull.projectile_id
	var snapshots := NetworkSnapshotSystem.new(main, main._projectile_system)
	var fixture = preload("res://tests/fixtures/network_fixture.gd")
	var payload: Array = snapshots._projectile_snapshot_payload(id, main._projectile_system.projectiles[id])
	var packet: Array = fixture.packet(snapshots, [], [payload], fixture.tower_payloads(snapshots), 0.0, main.runtime._match_rules.time_left, false)
	_expect(snapshots.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE)) != null, "独立飞爪沿用弹体快照并通过客户端校验")
	target.position = Vector2(650, 1000)
	source.position = Vector2(300, 1100)
	source.freeze(1.0)
	_expect(main._projectile_system.projectiles.has(id), "出钩后来源冻结不撤销弹体")
	_flight()
	_expect(target.knockback.in_transit, "出钩后目标超过5.5格仍被拉取")
	var endpoint := target.knockback.endpoint
	_expect(is_equal_approx(endpoint.distance_to(Vector2(300,1000)), source.body_radius + target.body_radius + 28.0), "拉回以出钩位置为准，不跟随来源位移")
	_main._projectile_system.clear_all()
	target.knockback.cancel(&"test")
	source.control.hard.clear_family(&"freeze")
	source.position = Vector2(300,1000)
	target.position = Vector2(480,1000)
	_expect(source.auto_pull.try_start(source), "取消后允许重新选择")
	_aim(source, 10)
	target.position = Vector2(600,1000)
	_aim(source, 1)
	_expect(not source.auto_pull.active(), "瞄准期间超过5.5格取消")
	target.position = Vector2(480,1000)
	source.auto_pull.try_start(source)
	_aim(source, 19)
	_expect(not source.auto_pull.launched, "重新瞄准不继承上次进度")
	source.stun(1.0)
	_expect(not source.auto_pull.active(), "眩晕打断瞄准")
	source.control.hard.clear_family(&"stun")
	target.is_building = true
	_expect(not source.auto_pull.try_start(source), "飞爪不选择建筑")
	target.is_building = false
	target.is_air = true
	_expect(not source.auto_pull.try_start(source), "飞爪不选择空中单位")
	target.is_air = false
	target.position = Vector2(550,1000)
	_expect(not source.auto_pull.try_start(source), "4.5格外目标不能开始瞄准")
	target.position = Vector2(480,1000)
	var near := _spawn_ready_unit("garen", 1, Vector2(400,1000))
	near.can_attack = false
	_expect(not source.auto_pull.try_start(source), "1.4至2格目标追击优先于远处钩子")
	near.free()
	source.auto_pull.try_start(source)
	target.position = Vector2(370,1000)
	_aim(source,1)
	_expect(not source.auto_pull.active(), "锁定目标主动贴脸则取消瞄准")
	target.position = Vector2(480,1000)
	source.auto_pull.try_start(source)
	target.apply_stasis(1.0)
	_aim(source,1)
	_expect(not source.auto_pull.active(), "目标凝滞取消瞄准")
	target.control.hard.clear_family(&"stasis")
	source.auto_pull.try_start(source)
	_aim(source)
	id = source.auto_pull.projectile_id
	source.free()
	_flight()
	_expect(target.knockback.in_transit, "来源死亡移除后独立飞爪仍完成拉取")
	_main._projectile_system.clear_all()
	target.free()

	# 正式权威批次同时推进瞄准、弹体与移动，覆盖提交边界与通用施法锁。
	source = _spawn_ready_unit("blitzcrank", 0, Vector2(300,1000))
	target = _spawn_ready_unit("ashe", 1, Vector2(480,1000))
	target.can_attack = false
	source.attack_timeline.cooldown = 9.0
	_run_main_ticks(5)
	_expect(source.attack_timeline.cooldown == 0.0, "正式时钟沿用通用施法锁，不为机器人保留冷却特例")
	source.attack_timeline.cooldown = 1.0
	_run_main_ticks(32)
	_expect(not source.auto_pull.active() and source._target_gap(target) <= source.attack_range and source._attacking, "真实批次拉回后开始普攻，无额外落地刷新")
	_expect(source.get_visual_action_serial() == 1, "瞄准不播放飞爪，出钩只发布一次动作")
	source.free()
	target.free()

	for failure in ["death", "stasis", "untargetable", "immune"]:
		source = _spawn_ready_unit("blitzcrank", 0, Vector2(300,1000))
		target = _spawn_ready_unit("garen", 1, Vector2(480,1000))
		source.auto_pull.try_start(source)
		_aim(source)
		match failure:
			"death": target.hp = 0.0
			"stasis": target.apply_stasis(1.0)
			"untargetable": target.control.hard.apply(&"untargetable", &"test", 1.0, {})
			"immune": target.structure_rush.phase = StructureRushState.Phase.DASHING
		_flight()
		_expect(_main._projectile_system.projectiles.is_empty() and not target.knockback.in_transit, "出钩目标失效：" + failure)
		source.free()
		target.free()

	# 强化拳保持原有消费者与真实命中语义。
	source = _spawn_ready_unit("blitzcrank", 0, Vector2(300,1000))
	target = _spawn_ready_unit("garen", 1, Vector2(370,1000))
	_main._active_skill_effect_system.apply(source, CardDB.active_skills_for("blitzcrank")[0])
	source._attack_visual_serial = 1
	var hp := target.hp
	_main.combat_service().resolve_attack_hit(0, source.position, target, 105.0, 0.0, 0.0, source, source.position, -1, source.empowered_attack_effects)
	_expect(target.hp == hp - 105.0 and target.control.stun_timer == 1.0, "E真实命中仍为105伤害及1秒眩晕")
	source.free()
	target.free()

	_check_buff_tail()
	_check_pull_across_tower()
	_check_pull_from_bridge()

func _check_pull_across_tower() -> void:
	for team in [0, 1]:
		var tower: Tower
		for candidate in _main.world.towers_snapshot():
			if candidate.team == team and not candidate.is_king: tower = candidate
		var side := Vector2.DOWN if team == 0 else Vector2.UP
		for enemy in ["hecarim", "garen"]:
			var source := _spawn_ready_unit("blitzcrank", team, tower.position + side * (tower.body_radius + 20.0))
			var target := _spawn_ready_unit(enemy, 1-team, tower.position - side * (tower.body_radius + 40.0))
			_expect(source._target_gap(target) >= 80.0 and source._target_gap(target) <= 180.0, "隔塔样本处于飞爪起手范围")
			_run_main_ticks(44)
			_expect((target.position-tower.position).dot(side) > tower.body_radius, "飞爪跨过防御塔拉到机器人所在侧：" + enemy + str(team))
			_expect(UnitLandingQuery.displacement_legal(target, target.position), "隔塔拉回完整身体停在合法位置")
			_expect(source._target_gap(target) <= source.attack_range, "隔塔落在机器人附近可接普攻")
			_expect(source.get_visual_action_serial() == 1 and not source.auto_pull.active(), "隔塔只出钩一次并完成回程")
			source.free()
			target.free()
			_main._projectile_system.clear_all()

func _check_pull_from_bridge() -> void:
	for team in [0, 1]:
		for bridge_x in [140.0, 580.0]:
			var source := _spawn_ready_unit("blitzcrank", team, Vector2(350 if bridge_x < 360.0 else 370, 698.01 if team == 0 else 581.99))
			var target := _spawn_ready_unit("hecarim", 1-team, Vector2(bridge_x, 695 if team == 0 else 585))
			target.can_attack = false
			target.root(5.0)
			_expect(UnitLandingQuery.pull_destination(target, Vector2(360,640), Vector2(360,640), 10.0).is_finite(), "邻域全在河内时仍回退到直线上的桥面合法点")
			var origin := source.position
			var spacing := source.body_radius + source.attack_range * 0.5 + target.body_radius
			var direction := target.position.direction_to(origin)
			var old_endpoint := UnitLandingQuery.displacement_endpoint(target, target.position, direction,
				target.position.distance_to(origin) - spacing, spacing + ArenaRules.TILE_SIZE + target.body_radius + 2.0)
			_expect(absf(old_endpoint.y - ArenaRules.RIVER_Y) < ArenaRules.RIVER_HALF + target.body_radius, "夹具确实触发旧直线策略退回桥面")
			_expect(UnitLandingQuery.displacement_legal(target, target.position), "贴河夹具目标完整身体在桥内")
			_expect(source.auto_pull.try_start(source), "贴河桥上目标进入瞄准")
			_run_main_ticks(44)
			var bank_distance := target.position.y - ArenaRules.RIVER_Y if team == 0 else ArenaRules.RIVER_Y - target.position.y
			_expect(bank_distance >= ArenaRules.RIVER_HALF + target.body_radius, "斜拉离开桥面并完整落在机器人一侧河岸")
			_expect(target.position.distance_to(origin) <= source.body_radius + source.attack_range * 0.5 + target.body_radius + ArenaRules.TILE_SIZE + 0.1, "修正落点限于出手位置附近")
			_expect(UnitLandingQuery.displacement_legal(target, target.position), "贴河拉回落点合法")
			_expect(source.get_visual_action_serial() == 1 and not source.auto_pull.active(), "贴河只出钩一次并完成回程")
			source.free()
			target.free()
			_main._projectile_system.clear_all()

func _check_buff_tail() -> void:
	var player = load("res://assets/effects/blitzcrank/player.gd").new()
	_main.add_child(player)
	player.load_kind("ebuf")
	player.setup_native(0.010625)
	player.seek(1.39)
	_expect(player.has_live_particles(), "E循环末段有活粒子")
	player.stop_emitting()
	var survivors: Dictionary = player._survivors.duplicate()
	player.advance(0.05)
	_expect(player.has_live_particles(), "E停发不立即切掉残留粒子")
	var only_survivors := true
	for i in player._pools.size():
		for item in player._pools[i]:
			if item.visible:
				var particle = item.material_override.get_shader_parameter("p")
				only_survivors = only_survivors and survivors.has(str(i) + ":" + str(particle[0]))
	_expect(only_survivors, "E停发后没有新出生粒子")
	player.advance(1.4)
	_expect(not player.has_live_particles(), "E残留按原生寿命全部消散")
	player.restart_emitting()
	player.seek(0.5)
	_expect(player.has_live_particles(), "再次强化可以重新发射电光")
	player.free()
