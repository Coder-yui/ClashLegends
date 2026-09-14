extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	for tower in main._towers: tower.can_attack = false
	for permutation in 16:
		_check_due_attack(permutation)
	_check_stale_acceptance()
	_check_lifecycle_edges()

func _building(team: int) -> Unit:
	var unit: Unit = _main._spawn_unit(team, "tombstone", Vector2(180, 700), 0)
	unit.spawn_interval = 0
	return unit

func _attacker(team: int) -> Unit:
	var unit: Unit = _main._spawn_unit(team, "masteryi", Vector2(180, 760), 0)
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
	_run_main_ticks(4)
	_expect(attacker._attack_hit_index == 0 and attacker._attacking, "到期夹具：正常索敌前摇，本 Tick 尚未出手")
	building._lifespan_left = 0.05
	var backup: Unit = _main._spawn_unit(1 - team, "garen", Vector2(290, 760), 0)
	backup.freeze(100)
	if permutation & 4: _main.move_child(building, attacker.get_index())
	if permutation & 8:
		attacker.remove_from_group("combatants")
		attacker.add_to_group("combatants")
	_main._sim_step(0.05)
	_expect(building.nav_cells.is_empty() and not building.is_in_group("combatants"), "到期提交解除导航与战斗集合")
	var state := [attacker._attack_hit_index, attacker.attack_timeline.cooldown, attacker.hp, attacker.skill_resource_value, attacker._target == backup]
	print("EXPIRY_BOUNDARY permutation=", permutation, " tick=", _main._sim_tick_id, " state=", state)
	_expect(building.hp == 0 and state == [0, 0.0, 100.0, 0.0, true], "自然到期在全体攻击资格之前：不出手、不消耗段/间隔、无收益且一致转火")
	for unit in [attacker, building, backup]: unit.free()

func _check_stale_acceptance() -> void:
	var source := _attacker(0)
	var target := _building(1)
	target._lifespan_left = 0.05
	_main._combat.begin_batch(100, "stale_natural_exit")
	var result: Dictionary = _main._combat.submit_damage(target, 10, source, 0, source.position)
	_main._combat.resolve_attack_hit(0, source.position, target, 10, 0, 0, source, source.position, 0)
	target._building_tick(0.05)
	_main._combat.commit_batch()
	_expect(result.get("accepted", false) and not result.landed and result.health_lost == 0, "接受请求不等于最终合法命中：自然退出不产生 landed")
	_expect(source.hp == 100 and source.skill_resource_value == 0, "最终非法目标不发放回血或命中资源")
	source.free()
	target.free()

func _check_lifecycle_edges() -> void:
	for mode in ["freeze", "stun", "deploy"]:
		var building := _building(1)
		building._lifespan_left = 0.1
		if mode == "freeze": building.freeze(0.05)
		elif mode == "stun": building.stun(0.05)
		else: building._deploy_timer = 0.1
		_main._sim_step(0.05)
		_expect(is_equal_approx(building._lifespan_left, 0.1), mode + " 阻止自然寿命推进，控制/部署本身仅推进一次")
		_main._sim_step(0.05)
		_expect(is_equal_approx(building._lifespan_left, 0.05), mode + " 解除后寿命只推进一个 Tick")
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
