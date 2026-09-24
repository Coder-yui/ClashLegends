extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_payment()
	var skill: Dictionary = CardDB.active_skills_for("pantheon")[0]
	for team in [0, 1]:
		_expect(_main.is_card_deploy_position_valid(team, "pantheon", Vector2(360, 400 if team == 0 else 880)), "敌方半场合法地面允许部署")
		_expect(not _main.is_card_deploy_position_valid(team, "pantheon", Vector2(360, 640)), "全图部署仍拒绝河道")
		var source: Unit = _main._spawn_unit(team, "pantheon", Vector2(360, 900), 0.0)
		source.add_skill_resource(4)
		_expect(source.skill_resource_value == 0, "未携带主动时不获得红怒")
		source.configure_carried_active_skill(skill)
		for stacks in range(5):
			source.skill_resource_value = stacks
			var prepared: Dictionary = _main._active_skill_effect_system.prepare_cast(source, skill)
			_expect(source.skill_resource_value == (0 if stacks == 4 else stacks + 1), "仅满四层消费，未满保留并加一层")
			_expect(prepared.damage == (240 if stacks == 4 else 120), "按释放前层数判定强化，三层释放仍为普通伤害")
			_expect(String(prepared.visual_action) == ("spear_tap_empowered" if stacks == 4 else "spear_tap"), "红怒强弱音画与本次伤害使用同一快照")
		source.add_skill_resource(9)
		_expect(source.skill_resource_value == 4, "红怒不能超过四层")
		source.clear_carried_active_skill_resource()
		_expect(not source.skill_resource_enabled and source.skill_resource_value == 0, "主动资格替换清理红怒")
		var enemy: Unit = _main._spawn_unit(1-team, "garen", source.position + Vector2(0, -60), 0.0)
		var ally: Unit = _main._spawn_unit(team, "garen", source.position + Vector2(0, -60), 0.0)
		var air: Unit = _main._spawn_unit(1-team, "anivia", source.position + Vector2(0, -60), 0.0)
		var behind: Unit = _main._spawn_unit(1-team, "garen", source.position + Vector2(0, 80), 0.0)
		var before: Array = [enemy.hp, ally.hp, air.hp, behind.hp]
		_main._active_skill_effect_system.apply_frontal(source, skill, Vector2.UP)
		_expect(enemy.hp == before[0] - 120 and ally.hp == before[1] and air.hp == before[2] and behind.hp == before[3], "短Q仅刺中前方地面敌人")
		before = [enemy.hp, ally.hp, air.hp, behind.hp]
		source._perform_deploy_sweep()
		_expect(enemy.hp == before[0] - 100 and behind.hp == before[3] - 100 and ally.hp == before[1] and air.hp == before[2], "落地范围伤害地面敌人，不伤友军与空军")
		for unit in [source, enemy, ally, air, behind]: unit.free()
	var invalid: Dictionary = CardDB.get_card("pantheon").duplicate(true)
	invalid.active_skills[0].resource_consume_only_full = "true"
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all({"pantheon": invalid}, false).is_empty(), "拒绝错误类型的满层消费开关")
	invalid = CardDB.get_card("pantheon").duplicate(true)
	invalid.active_skills[0].resource_nonfull_cast_gain = -1
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all({"pantheon": invalid}, false).is_empty(), "拒绝负数施法增怒")

func _check_payment() -> void:
	var deck: Array = _main._deck.duplicate()
	_main._deck[0] = "pantheon"
	var source: Unit = _main._spawn_unit(0, "pantheon", Vector2(360, 1000), 0.0, 0)
	var ability := source.active_ability_id
	source.move_speed = 0.0
	_main._elixir.elixir = 10
	source.skill_resource_value = 3
	_expect(_main.use_active_skill(ability, 0) and _main._elixir.elixir == 9.0 and source.skill_resource_value == 3, "请求扣1金币，排队不提前改变红怒")
	_main._sim_tick_id += 10
	_main._tick_pending_active_skills(0.05)
	_expect(source.skill_resource_value == 4 and _main._active_skills.entry(ability).uses_remaining == 1 and _main._active_skills.entry(ability).cooldown_left == 5.0, "开始时增加红怒、扣次数并启动5秒冷却")
	_expect(not _main.use_active_skill(ability, 0), "冷却中不可重复请求")
	source.prepare_action_clocks(5.0)
	_main._tick_active_skill_cooldowns(5.0)
	_expect(_main.use_active_skill(ability, 0) and _main._elixir.elixir == 8.0, "5秒后允许第二次释放")
	_main._sim_tick_id += 10
	_main._tick_pending_active_skills(0.05)
	_expect(source.skill_resource_value == 0 and _main._active_skills.entry(ability).uses_remaining == 0, "第二次满怒释放清空红怒和剩余次数")
	source.prepare_action_clocks(5.0)
	_main._tick_active_skill_cooldowns(5.0)
	_expect(not _main.use_active_skill(ability, 0) and _main._elixir.elixir == 8.0, "次数耗尽拒绝且不再扣费")
	source.free()
	_main._deck = deck
