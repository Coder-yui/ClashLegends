extends "res://tests/suites/battle_suite.gd"
## 用正式弹体/批次命中证明结构死亡收益幂等，不直接调用助攻或发奖回调。
func run(harness: Object) -> void:
	_harness = harness
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	for kind in ["repeat", "two", "first", "ally", "expired", "expired_last_hit", "dead_source", "stasis", "building"]:
		_check_case(kind)
	_main.free()
	_main = null

func _hit(source: Unit, target: Node2D, amount: float) -> void:
	_expect(_main._projectile_system.launch(source, target, amount, 1000.0, 0.0, 0.0, Color.WHITE), "正式弹体发射")
	# 只推进弹体阶段，避免额外单位自主普攻影响本次致死批次。
	for tick in 4:
		_main.runtime._sim_tick_id += 1
		_main._combat.begin_batch(_main.runtime._sim_tick_id, "reward_projectile")
		_main._projectile_system.tick(0.05)
		_main._combat.commit_batch()

func _check_case(kind: String) -> void:
	var target: Node2D = _main.world.towers_snapshot()[2]
	target.hp = 1000.0
	var source := _spawn_ready_unit("jinx", 0, target.position + Vector2(100, 0))
	var ally := _spawn_ready_unit("ashe", 0, target.position + Vector2(100, 30))
	if kind == "building": target = _spawn_ready_unit("tombstone", 1, Vector2(360, 400))
	if kind != "first":
		_hit(source, target, 10.0)
		_expect(target.hp > 0.0 and source.buffs.stack_count(&"structure_haste") == 0, "非致死命中只登记窗口:" + kind)
	if kind in ["expired", "expired_last_hit"]: _main.runtime._sim_tick_id += 61
	if kind == "stasis": source.apply_stasis(1.0)
	if kind in ["dead_source", "two"]:
		# 两枚真实弹体在同一正式批次结算，来源资格必须看全批最终生命。
		_main._projectile_system.launch(source, target, 100000, 100000, 0, 0, Color.WHITE)
		if kind == "dead_source":
			_main._projectile_system.launch(target, source, 100000, 100000, 0, 0, Color.WHITE)
		else:
			var second: Tower = _main.world.towers_snapshot()[3]
			second.hp = 1000
			_main._projectile_system.launch(source, second, 100000, 100000, 0, 0, Color.WHITE)
		_main._combat.begin_batch(_main.runtime._sim_tick_id, "reward_mutual")
		_main._projectile_system.tick(0.05)
		_main._combat.commit_batch()
	else:
		_hit(ally if kind in ["ally", "expired", "stasis"] else source, target, 100000)
	var expected := 0 if kind in ["expired", "dead_source", "stasis"] else (2 if kind == "two" else 1)
	_expect(target.hp == 0.0 and source.buffs.stack_count(&"structure_haste") == expected, "每次真实结构死亡只消费一次收益:" + kind)
	if kind == "repeat":
		_expect(not _main._combat.resolve_attack_hit(0, source.position, target, 100000, 0, 0, source).accepted and source.buffs.stack_count(&"structure_haste") == 1, "已死亡结构拒绝后续命中且不重复收益")
	if kind == "stasis":
		source.control.hard.clear_family(&"stasis")
		_expect(source.buffs.stack_count(&"structure_haste") == 0, "凝滞结束不补发该次死亡奖励")
	if kind == "building":
		var summons := _main.get_tree().get_nodes_in_group("combatants").filter(func(u): return u is Unit and u.card_id == "imp")
		_expect(summons.size() == 2, "建筑真实死亡保留亡语两只雾行者")
	_main._projectile_system.clear_all()
	_main.runtime._commands.clear()
	for actor in _main.get_tree().get_nodes_in_group("combatants"):
		if actor is Unit: actor.free()
