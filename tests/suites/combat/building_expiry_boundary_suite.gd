extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	for tower in main._towers: tower.can_attack = false
	for permutation in 16:
		_check_due_attack(permutation)
	_check_stale_acceptance()
	_check_lifecycle_edges()
	_check_tombstone_death_summons()

func _building(team: int) -> Unit:
	var unit: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, "tombstone", Vector2(180, 700), {"deploy_time_override": 0}))
	unit.spawn_interval = 0
	# 通用寿命/攻击边界夹具隔离产出，真实墓碑死亡召唤由专用用例验证。
	unit.death_spawn_count = 0
	return unit

func _attacker(team: int) -> Unit:
	var unit: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, "masteryi", Vector2(180, 760), {"deploy_time_override": 0}))
	unit.hp = 100
	unit.heal_every_hits = 1
	unit.heal_amount = 10
	unit.skill_resource_max = 100
	unit.skill_resource_hit_gain = 2
	unit.skill_resource_kill_gain = 3
	return unit

func _check_due_attack(permutation: int) -> void:
	var team := permutation & 1
	var attacker: Unit
	var building: Unit
	if permutation & 2:
		building = _building(1 - team)
		attacker = _attacker(team)
	else:
		attacker = _attacker(team)
		building = _building(1 - team)
	# 0.20秒前摇第4Tick命中；在第3Tick后布置同帧自然到期，不依赖浮点尾差。
	_run_main_ticks(3)
	_expect(attacker._attack_hit_index == 0 and attacker._attacking and is_equal_approx(attacker.attack_timeline.windup, 0.05), "到期夹具：正常索敌前摇，本 Tick 尚未出手")
	building._lifespan_left = 0.05
	var backup: Unit = _main._spawn_unit(UnitSpawnRequest.new(1 - team, "garen", Vector2(290, 760), {"deploy_time_override": 0}))
	backup.freeze(100)
	if permutation & 4: _main.move_child(building, attacker.get_index())
	if permutation & 8:
		attacker.remove_from_group("combatants")
		attacker.add_to_group("combatants")
	_main._sim_step(0.05)
	_expect(building.nav_cells.is_empty() and not building.is_in_group("combatants"), "到期提交解除导航与战斗集合")
	var state := [attacker._attack_hit_index, attacker.attack_timeline.cooldown, attacker.hp, attacker.skill_resource_value, attacker._target == backup]
	if "--verbose-checks" in OS.get_cmdline_user_args(): print("EXPIRY_BOUNDARY permutation=", permutation, " tick=", _main._sim_tick_id, " state=", state)
	_expect(building.hp == 0 and state == [0, 0.0, 100.0, 0.0, true], "自然到期在全体攻击资格之前：不出手、不消耗段/间隔、无收益且一致转火")
	for unit in [attacker, building, backup]: unit.free()

func _check_stale_acceptance() -> void:
	var source := _attacker(0)
	var target := _building(1)
	target._lifespan_left = 0.05
	_main._combat.begin_batch(100, "stale_natural_exit")
	var result: Dictionary = _main._combat.submit_damage(target, 10, source, 0, source.position)
	source.position = target.position + Vector2(0, 30)
	source._target = target
	source._attacking = true
	source.attack_timeline.windup = 0.0
	source.attack_timeline.cooldown = 0.0
	source._attack_hit_index = 2
	source._attack_swing_count = 2
	source._attack(0.05)
	# 故障注入：非生命周期边界的强制对象销毁，仍需失效回执；正式自然退休已在上面的固定边界验证。
	target.queue_free()
	_main._combat.commit_batch()
	_expect(result.get("accepted", false) and not result.landed and result.health_lost == 0, "接受请求不等于最终合法命中：已销毁引用不产生 landed")
	_expect(source.hp == 100 and source.skill_resource_value == 0, "最终非法目标不发放回血或命中资源")
	_expect(source._attack_swing_count == 2 and source._attack_hit_index == 2 and source._pending_extra_attacks.is_empty(), "实际未命中时回收近战段推进及依附追加刀，致盲例外不走此分支")
	source.free()

func _check_lifecycle_edges() -> void:
	for mode in ["freeze", "stun", "deploy"]:
		var building := _building(1)
		building._lifespan_left = 0.1
		if mode == "freeze": building.freeze(0.05)
		elif mode == "stun": building.stun(0.05)
		else: building._deploy_timer = 0.1
		_main._sim_step(0.05)
		_expect(is_equal_approx(building._lifespan_left, 0.1 if mode == "deploy" else 0.05), mode + " 部署前不计寿命，受控生命周期正常推进")
		_main._sim_step(0.05)
		_expect(is_equal_approx(building._lifespan_left, 0.05 if mode == "deploy" else 0.0), mode + " 生命周期只推进一次，受控不延寿")
		building.free()
	var building := _building(1)
	building.lifespan_hp_decay = true
	building.hp = 1
	building.add_shield(100, 10)
	building._lifespan_left = 1
	var deaths := [0]
	building.died.connect(func(): deaths[0] += 1)
	_main._sim_step(0.05)
	_expect(building.hp == 0 and building.shield_hp == 100 and deaths[0] == 1, "自然衰减归零只退出一次且不消耗盾")
	building.free()
	for deploying in [false, true]:
		building = _building(1)
		building.spawn_interval = 1
		building._spawn_timer = 0.05
		building._initial_summons_spawned = not deploying
		building._lifespan_left = 0.05
		if deploying: building._deploy_timer = 0.05
		var before := _main.get_tree().get_nodes_in_group("combatants").size()
		_main._sim_step(0.05)
		_expect(building.hp == 0 and _main.get_tree().get_nodes_in_group("combatants").size() <= before, "自然到期与周期/部署召唤重合时不生成单位")
		building.free()
	var source := _attacker(0)
	building = _building(1)
	building.lifespan_hp_decay = false
	building.add_shield(100, 10)
	_main._combat.begin_batch(200, "shield_landed")
	var result: Dictionary = _main._combat.submit_damage(building, 10, source, 0, source.position)
	_main._combat.resolve_attack_hit(0, source.position, building, 10, 0, 0, source, source.position, 0)
	_main._combat.commit_batch()
	_expect(result.landed and result.health_lost == 0 and source.hp == 110 and source.skill_resource_value == 2, "存活建筑全盾吸收仍是合法命中，回血和资源正常发放")
	var healed := source.hp
	building._lifespan_left = 0.05
	_main._sim_step(0.05)
	_expect(source.hp == healed, "随后自然到期不追溯撤销先前阶段收益")
	source.free()
	building.free()

func _check_tombstone_death_summons() -> void:
	for team in [0, 1]:
		for cause in ["expiry", "healed_expiry", "decay", "damage"]:
			var building: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, "tombstone", Vector2(300, 900), {"deploy_time_override": 0}))
			# 隔离周期产出，直接观察死亡召唤；到期前恢复首批/周期到点冲突。
			building.spawn_interval = 0
			if cause in ["expiry", "healed_expiry"]:
				_run_main_ticks(399)
				_expect(building.hp == 1 and is_equal_approx(building._lifespan_left, Unit.SIM_DT), "墓碑19.95秒仍存活，按20秒寿命自然衰血")
				if cause == "healed_expiry": building.heal(100)
				building.spawn_interval = 5.0
				building._spawn_timer = Unit.SIM_DT
				building._initial_summons_spawned = team == 0
			elif cause == "decay":
				building.hp = 1
				building.freeze(10.0)
			building.add_shield(100, 30)
			var before := _main.get_tree().get_nodes_in_group("combatants").filter(func(c): return c is Unit and c.card_id == "imp")
			if cause == "damage":
				_main._combat.begin_batch(_main._sim_tick_id, "tombstone_death_test")
				building.take_damage(1000)
				building.take_damage(1000)
				_main._combat.commit_batch()
			else:
				_main._sim_step(Unit.SIM_DT)
			var summons := _main.get_tree().get_nodes_in_group("combatants").filter(func(c): return c is Unit and c.card_id == "imp" and not before.has(c))
			_expect(building.hp == 0 and not building.is_in_group("combatants") and building.nav_cells.is_empty() and summons.size() == 2, "墓碑%s死亡仅释放两只雾行者并解除占位，阵营%d" % [cause, team])
			_expect(summons.all(func(c): return c.team == team and c.hp == c.max_hp and c.is_walkable_at(c.position) and c._move_intent == Vector2.ZERO and c._attack_hit_index == 0), "墓碑死亡召唤阵营与落点合法，生成当Tick不行动")
			if cause != "damage":
				_expect(building.shield_hp == 100, "墓碑自然死亡不消耗护盾")
			building._die(true)
			_expect(_main.get_tree().get_nodes_in_group("combatants").filter(func(c): return c is Unit and c.card_id == "imp" and not before.has(c)).size() == 2, "墓碑重复死亡通知不重复生成")
			building.free()
			for summoned in summons: summoned.free()
