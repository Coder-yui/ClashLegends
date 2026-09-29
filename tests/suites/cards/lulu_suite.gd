extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var source := _spawn("lulu", 0, Vector2(360, 1000))
	source._deploy_timer = 0.1
	source.sim_tick(0.05)
	_expect(_pix().is_empty(), "部署完成前不召唤皮克斯")
	source.sim_tick(0.05)
	_expect(_pix().is_empty() and main._commands.inspect_summons().size() == 2, "部署结束只发出两道紫光")
	main._tick_summon_flights(0.20)
	_expect(_pix().is_empty(), "飞行0.20秒尚未生成实体")
	main._tick_summon_flights(0.05)
	_expect(_pix().size() == 2, "飞行0.25秒到达瞬间生成两只")
	var first := _pix()
	_expect(first[0].position.is_equal_approx(source.position + Vector2(-60, 0)) and first[1].position.is_equal_approx(source.position + Vector2(60, 0)), "首批左右1.5格生成")
	_expect(first.all(func(pix): return pix._deploy_timer == 0.0 and pix.deploy_time == 0.0), "璐璐召唤皮克斯无需部署")
	for i in 139: source.sim_tick(0.05)
	_expect(_pix().size() == 2, "7秒前不提前召唤")
	source.sim_tick(0.05)
	main._tick_summon_flights(0.25)
	_expect(_pix().size() == 4, "7秒再次发出并到达生成两只")
	var skill: Dictionary = CardDB.get_card("lulu").active_skills[0]
	var near := _spawn("garen", 0, Vector2(390, 1000))
	var far := _spawn("garen", 0, Vector2(460, 1000))
	var outside := _spawn("ornn", 0, Vector2(600, 1000))
	var egg := _spawn("anivia_egg", 0, Vector2(360, 1005))
	var tower := _spawn("tombstone", 0, Vector2(360, 1040))
	var air_enemy := _spawn("pix", 1, Vector2(400, 1010))
	var enemy := _spawn("melee_minion", 1, Vector2(400, 1000))
	_expect(ActiveSkillEffectSystem.growth_target(source, skill) == near, "同费选近者，高费圈外和建筑蛋排除")
	near.hp = 100.0
	var before := near.max_hp
	var radius := near.body_radius
	var effects: ActiveSkillEffectSystem = _main.get("_active_skill_effect_system")
	_expect(effects.apply(source, skill), "狂野生长生效")
	_expect(near.max_hp == before + BattleNumbers.quantity(before * 0.3) and near.hp == 100.0 + BattleNumbers.quantity(before * 0.3), "最大和当前生命增加相同差额")
	_expect(is_equal_approx(near.body_radius, radius * 1.3) and near.growth_body_scale == 1.3, "身体碰撞和模型倍率同步增大30%")
	_expect(enemy._knockback_timer > 0.0, "受益单位周围敌军被击退")
	_expect(air_enemy._knockback_timer == 0.0, "地面变大不击退空军")
	_expect(not near.apply_permanent_growth(0.3, 1.3), "已增益单位不能重复获益")
	_expect(ActiveSkillEffectSystem.growth_target(source, skill) == far, "第二次跳过已增益目标")
	effects.apply(source, skill)
	_expect(ActiveSkillEffectSystem.growth_target(source, skill) == source, "包含璐璐自身")
	outside.free()
	egg.free()
	tower.free()
	for pix in _pix(): pix.free()
	effects.apply(source, skill)
	_expect(ActiveSkillEffectSystem.growth_target(source, skill) == null, "全员已增益时无合法目标")
	var receipt := ActiveSkillEffectSystem.RefundReceipt.new()
	var calls := [0]
	receipt.rollback = func(): calls[0] += 1
	var pending := skill.duplicate(true)
	pending.refund_receipt = receipt
	_expect(not effects.apply(source, pending), "空目标释放返回失败")
	effects.apply(source, pending)
	_expect(calls[0] == 1, "失败回退收据只执行一次")
	var air_friend := _spawn("pix", 0, Vector2(365, 1000))
	enemy.knockback.advance(1.0)
	effects.apply(source, skill)
	_expect(air_friend.growth_body_scale == 1.3 and air_enemy._knockback_timer > 0.0 and enemy._knockback_timer == 0.0, "空军变大仅击退空军")
	var gnar := _spawn("gnar", 0, Vector2(100, 1000))
	gnar.apply_permanent_growth(0.3, 1.3)
	var bonus := gnar.growth_health_bonus
	gnar.transform_to_mega(true)
	_expect(gnar.max_hp == BattleNumbers.quantity(float(gnar.transformed_stats.hp)) + bonus and is_equal_approx(gnar.body_radius, float(gnar.transformed_stats.radius) * 1.3), "换形保留一次性生命加成和身体倍率")
	var cards := CardDB.all().duplicate(true)
	cards.lulu.spawn_deploy_time = -0.1
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "召唤部署时间拒绝负值")
	cards = CardDB.all().duplicate(true)
	cards.lulu.spawn_distance = "bad"
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "召唤距离拒绝字符串")
	cards = CardDB.all().duplicate(true)
	cards.lulu.active_skills[0].body_scale_multiplier = 0.0
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "成长倍率拒绝零值")
	for unit in main.get_tree().get_nodes_in_group("combatants"):
		if unit is Unit: unit.free()
	var old_deck: Array = main._deck.duplicate()
	main._deck[0] = "lulu"
	var units: Array[Unit] = main._spawn_card_units(0, "lulu", Vector2(360, 1000), 0.0, 0)
	var paid := units[0]
	paid.apply_permanent_growth(0.3, 1.3)
	var ability := paid.active_ability_id
	main._elixir.elixir = 8.0
	_expect(main.use_active_skill(ability, 0), "空目标仍允许请求释放")
	_expect(main._elixir.elixir == 6.0, "空目标请求先预扣2金币")
	main._sim_tick_id += 10
	main._tick_pending_active_skills(0.05)
	_expect(main._active_skills.entry(ability).uses_remaining == 1, "起手先消耗次数")
	main._commands.tick_impacts(0.25)
	_expect(main._elixir.elixir == 8.0 and main._active_skills.entry(ability).uses_remaining == 2 and main._active_skills.entry(ability).cooldown_left == 0.0, "生效时空目标回退金币次数和冷却")
	main._commands.tick_impacts(1.0)
	_expect(main._elixir.elixir == 8.0, "后续Tick不重复退费")
	var valid := _spawn("garen", 0, Vector2(380, 1000))
	_expect(main.use_active_skill(ability, 0), "有目标可请求")
	main._sim_tick_id += 10
	main._tick_pending_active_skills(0.05)
	valid.free()
	main._commands.tick_impacts(0.25)
	_expect(main._elixir.elixir == 8.0 and main._active_skills.entry(ability).uses_remaining == 2, "施法期间目标消失也回退")
	paid._spawn_batch()
	paid.take_damage(10000)
	main._tick_summon_flights(0.25)
	var survivors := _pix()
	_expect(survivors.size() == 2 and survivors.all(func(pix): return is_instance_valid(pix) and pix.hp > 0.0), "璐璐死亡后已召唤皮克斯独立存活")
	var sion := _spawn("sion", 0, Vector2(100, 1000))
	var base_max := sion.max_hp
	sion.apply_permanent_growth(0.3, 1.3)
	sion.take_damage(100000)
	_expect(sion.growth_body_scale == 1.0 and sion.growth_health_bonus == 0.0 and sion.max_hp == base_max, "致死复生入口清理成长倍率和生命增量")
	# 独立起手测试：20Hz生效节点及起手后控制，不借动画推进效果。
	for control_kind in ["none", "stun", "freeze", "knockback"]:
		var caster := _spawn("lulu", 0, Vector2(650, 1150))
		_expect(main._start_active_skill_cast(caster, skill), "控制用例可正式起手:" + control_kind)
		if control_kind == "stun": caster.stun(1.0)
		if control_kind == "freeze": caster.freeze(1.0)
		if control_kind == "knockback": caster.apply_knockback(Vector2(640, 1150), 40.0)
		for tick in 4: main._commands.tick_impacts(0.05)
		_expect(caster.growth_body_scale == 1.0, "起手0.20秒未结算:" + control_kind)
		main._commands.tick_impacts(0.05)
		_expect(caster.growth_body_scale == (1.0 if control_kind == "freeze" else 1.3), "起手0.25秒控制结算:" + control_kind)
		caster.free()
		main._commands.tick_impacts(1.0)
	for pix in _pix(): pix.free()
	for family in [&"stun", &"freeze", &"stasis"]:
		var summoner := _spawn("lulu", 0, Vector2(300, 1100))
		summoner.control.hard.apply(family, &"fixture", 20.0, {})
		summoner._spawn_initial_summons()
		_expect(not summoner._initial_summons_spawned and main._commands.inspect_summons().is_empty(), "首次召唤受控等待:" + String(family))
		summoner.control.hard.clear_family(family)
		summoner._spawn_initial_summons()
		_expect(main._commands.inspect_summons().size() == 2, "首次召唤解除后发出:" + String(family))
		summoner.control.hard.apply(family, &"fixture", 20.0, {})
		main._tick_summon_flights(0.25)
		_expect(_pix().size() == 2, "已发出召唤不受后续控制打断:" + String(family))
		for pix in _pix(): pix.free()
		summoner._spawn_timer = 0.05
		summoner._tick_periodic_summons(14.0)
		_expect(main._commands.inspect_summons().is_empty() and summoner._spawn_timer == 0.0, "受控跨多个周期只保留待发批次:" + String(family))
		summoner.control.hard.clear_family(family)
		summoner._tick_periodic_summons(0.05)
		_expect(main._commands.inspect_summons().size() == 2 and summoner._spawn_timer == 7.0, "解除立即发出且重启周期:" + String(family))
		summoner.free()
		main._tick_summon_flights(0.25)
		_expect(_pix().size() == 2, "来源释放不取消在途召唤:" + String(family))
		for pix in _pix(): pix.free()
	var edge := _spawn("lulu", 0, Vector2(20, 1000))
	edge._spawn_batch()
	var queued: Array = main._commands.inspect_summons()
	_expect(float(queued[0].pos.x) == float(CardDB.get_unit_stats("pix").radius), "靠边落点在特效发出前夹紧")
	var fx: Dictionary = main._skill_presentation.frontal_effects.back().duplicate(true)
	var present_before: int = main._skill_presentation.frontal_effects.size()
	main._skill_presentation.show_skill_effect(98765, fx)
	main._skill_presentation.show_skill_effect(98765, fx)
	_expect(main._skill_presentation.frontal_effects.size() == present_before + 1 and _pix().is_empty(), "客户端表现事件去重且不生成实体")
	main._commands.clear()
	main._tick_summon_flights(1.0)
	_expect(_pix().is_empty(), "清场取消所有在途召唤")
	cards = CardDB.all().duplicate(true)
	cards.lulu.spawn_flight_duration = 0.0
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "飞行召唤拒绝零时长")
	cards = CardDB.all().duplicate(true)
	cards.lulu.spawn_defer_while_controlled = 1
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "控制延后字段必须为布尔")
	main._deck = old_deck
	for unit in main.get_tree().get_nodes_in_group("combatants"):
		if unit is Unit: unit.free()

func _spawn(id: String, team: int, pos: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, id, pos, {"deploy_time_override": 0.0}))

func _pix() -> Array:
	return _main.get_tree().get_nodes_in_group("combatants").filter(func(u): return u is Unit and u.card_id == "pix" and u.team == 0)
