extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	for team in [0, 1]:
		var source := _spawn("azir", team, Vector2(300, 900))
		for delay in [39, 40, 41]:
			var target := _spawn("ashe", 1 - team, Vector2(400, 900))
			var before := _count("sand_soldier", team)
			_hit(source, target, 1)
			main._sim_tick_id += delay
			target.take_damage(99999)
			_expect(_count("sand_soldier", team) == before + (1 if delay <= 40 else 0), "转化40Tick包含边界，41Tick排除；阵营%d 延迟%d" % [team, delay])
		var refreshed := _spawn("ashe", 1 - team, Vector2(450, 1000))
		_hit(source, refreshed, 1)
		main._sim_tick_id += 39
		_hit(source, refreshed, 1)
		main._sim_tick_id += 40
		var before := _count("sand_soldier", team)
		refreshed.take_damage(99999)
		_expect(_count("sand_soldier", team) == before + 1, "再次真实命中刷新窗口")
		var air := _spawn("corki", 1 - team, Vector2(450, 1050))
		before = _count("sand_soldier", team)
		_hit(source, air, 99999)
		_expect(_count("sand_soldier", team) == before + 1, "直接击杀空军也生成地面士兵")
		var second := _spawn("azir", team, Vector2(330, 900))
		var victim := _spawn("ashe", 1 - team, Vector2(440, 950))
		before = _count("sand_soldier", team)
		main._combat.begin_batch(main._sim_tick_id, "azir_shared_kill")
		_hit(source, victim, 99999)
		_hit(second, victim, 99999)
		main._combat.commit_batch()
		_expect(_count("sand_soldier", team) == before + 1, "双沙皇同批击杀只转化一次")
		var shielded := _spawn("ashe", 1 - team, Vector2(440, 1000))
		shielded.add_shield(500, 10)
		_hit(source, shielded, 1)
		before = _count("sand_soldier", team)
		shielded.take_damage(99999)
		_expect(_count("sand_soldier", team) == before + 1, "护盾承受的真实命中计入参与")
		var blocked := _spawn("ashe", 1 - team, Vector2(500, 1000))
		blocked.apply_stasis(2.0, &"azir_test")
		_hit(source, blocked, 99)
		blocked.control.clear_on_death()
		before = _count("sand_soldier", team)
		blocked.take_damage(99999)
		_expect(_count("sand_soldier", team) == before, "凝滞拒绝命中不登记资格")
		before = _count("sand_soldier", team)
		main._active_skill_effect_system.activate_summon(source, CardDB.active_skills_for("azir")[0])
		_expect(_count("sand_soldier", team) == before + 4, "主动四周独立生成4名士兵")
		var unqualified := true
		for actor in main.get_tree().get_nodes_in_group("combatants"):
			if actor is Unit and actor.card_id == "sand_soldier": unqualified = unqualified and actor.active_ability_id < 0 and AssistConversionState.source_definition(actor).is_empty()
		_expect(unqualified, "士兵不继承主动资格和转化被动")
		var building := _spawn("target_dummy", 1 - team, Vector2(500, 1100))
		before = _count("sun_disc", team)
		_hit(source, building, 1)
		building.hp = 1
		building._lifespan_left = 0.05
		building._tick_building_lifetime(0.05)
		_expect(_count("sun_disc", team) == before + 1, "窗口内建筑自然到期也转化")
		var tower: Tower
		for candidate in main._towers:
			if candidate.team != team and not candidate.is_king:
				tower = candidate
				break
		before = _count("sun_disc", team)
		_hit(source, tower, 99999)
		var disc: Unit
		for actor in main.get_tree().get_nodes_in_group("combatants"):
			if actor is Unit and actor.card_id == "sun_disc" and actor.team == team and actor.position.is_equal_approx(tower.position): disc = actor
		_expect(_count("sun_disc", team) == before + 1 and is_instance_valid(disc), "塔位原地生成圆盘")
		if is_instance_valid(disc):
			var hp := disc.hp
			disc._tick_building_lifetime(0.05)
			_expect(not disc.built_on_tower_ruin and disc.hp < hp, "被动塔位圆盘持续自然衰减")
		var marked := _spawn("ashe", 1 - team, Vector2(420, 1050))
		_hit(source, marked, 1)
		source.take_damage(99999)
		before = _count("sand_soldier", team)
		marked.take_damage(99999)
		_expect(_count("sand_soldier", team) == before + 1, "来源先死亡不撤回已命中的窗口")
		_clear()
	_check_true_death_rewards()
	_check_instant_attack()
	_check_definition_contracts()
	await _check_beam_warmup()
	_check_client_beam()
	var plan := preload("res://scripts/presentation/match_resource_plan.gd").for_match([["ashe", "teemo", "azir"], ["azir"]], [{}, {}])
	_expect(plan.cards.has("sand_soldier") and plan.cards.has("sun_disc"), "普通槽被动和主动槽都展开两种召唤资源")
	_expect(not plan.allows("sun_disc") and not plan.allows("sand_soldier"), "资源召唤链不继承主动技能")

func _check_instant_attack() -> void:
	for team in [0, 1]:
		for distance in [90.0, 230.0]:
			var source := _spawn("azir", team, Vector2(320, 900))
			var target := _spawn("ashe", 1-team, Vector2(320+distance, 900))
			source._target = target
			source.attack_timeline.begin_windup(source.first_hit_time, 1.0)
			var hp := target.hp
			var count: int = _main._projectile_system.projectiles.size()
			for tick in 4: source._attack(0.05)
			_expect(target.hp == hp, "命中节点前不提前扣血")
			source._attack(0.05)
			_expect(target.hp == hp-130, "近远距离均在第5Tick直接扣130生命")
			_expect(_main._projectile_system.projectiles.size() == count, "沙皇普攻不创建飞行弹体")
			var views = _main._projectile_system._hit_visuals
			_expect(views._views.size() == 1, "真实命中生成单层原版光束")
			views.advance(0.24)
			_expect(views._views.size() == 1, "0.24秒仍有光束")
			views.advance(0.02)
			_expect(views._views.is_empty(), "光束0.25秒后释放且不重复扣血")
			_expect(target.hp == hp-130, "表现推进不再次结算伤害")
			_clear()
	var source := _spawn("azir", 0, Vector2(320, 900))
	var target := _spawn("ashe", 1, Vector2(500, 900))
	target.apply_stasis(1.0, &"azir_test")
	var hp := target.hp
	source._target = target
	source._attack(0.05)
	_expect(target.hp == hp and _main._projectile_system._hit_visuals._views.is_empty(), "凝滞拒绝的攻击既无伤害也无光束")
	_clear()

func _spawn(id: String, team: int, pos: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, id, pos, {"deploy_time_override": 0.0}))

func _hit(source: Unit, target: Node2D, damage: float) -> void:
	_main.combat_service().resolve_attack_hit(source.team, source.position, target, damage, 0, 0, source, source.position, 0)

func _count(id: String, team: int) -> int:
	var count := 0
	for actor in _main.get_tree().get_nodes_in_group("combatants"):
		if actor is Unit and actor.card_id == id and actor.team == team and actor.hp > 0: count += 1
	return count

func _clear() -> void:
	for actor in _main.get_tree().get_nodes_in_group("combatants"):
		if actor is Unit:
			if not actor.nav_cells.is_empty(): _main.unblock_nav_cells(actor.nav_cells)
			actor.free()

func _check_definition_contracts() -> void:
	var cards := CardDB.all().duplicate(true)
	for value in [0, -1, "2秒"]:
		cards.azir.assist_conversion_window = value
		_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "非法助攻窗口拒绝: %s" % value)
	cards = CardDB.all().duplicate(true)
	cards.azir.attack_hit_visual = "unknown"
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "未知直接命中表现被拒绝")
	cards = CardDB.all().duplicate(true)
	cards.azir.projectile_speed = 650
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "命中光束不得误配置为飞行弹体")
	cards = CardDB.all().duplicate(true)
	cards.azir.assist_conversion_unit_id = "missing"
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "未知转化目标拒绝")


func _check_beam_warmup() -> void:
	var warm = preload("res://scripts/presentation/spell_effect_warmup.gd").new()
	var presentation = _main._battle_presentation
	await warm.prepare({"azir": true}, presentation._world_root, presentation._camera)
	_expect(warm.prepared.has("azir") and int(warm.sampled_layers.get("azir/basic_attack", 0)) == 1, "普通槽沙皇原版beamflow完成绘制预热")
	var resources := MatchResources.new()
	resources.prepare(["azir"])
	_expect(resources.errors.is_empty() and resources.resources.has("res://assets/effects/azir/beam.gdshader"), "普攻光束Shader及召唤资源完整闭包")

func _check_client_beam() -> void:
	var source := _spawn("azir", 0, Vector2(300, 900))
	var target := _spawn("ashe", 1, Vector2(460, 900))
	source.net_id = 991
	target.net_id = 992
	source.set_meta("projectile_model_offset", Vector2(25,-80))
	target.set_meta("projectile_model_offset", Vector2(0,-45))
	var old_mode: String = _main.mode
	_main.mode = "client"
	var hp := target.hp
	var descriptor := PresentationConfig.attack_source(source)
	descriptor.hit_origin = source.position
	descriptor.hit_target = {"id": target.net_id}
	_main._play_attack_hit_visual(descriptor, target.position)
	var views = _main._projectile_system._hit_visuals
	_expect(views._views.size() == 1 and views._views[0].start == source.position+Vector2(25,-80) and views._views[0].end == target.position+Vector2(0,-45), "客户端通过网络ID恢复武器与目标挂点")
	_expect(target.hp == hp and _main._projectile_system.projectiles.is_empty(), "客户端光束只呈现不生成伤害或弹体")
	var soldiers := _count("sand_soldier", 0)
	target.assist_conversion.record(target, AssistConversionState.source_definition(source))
	target.assist_conversion.consume(target)
	_expect(_count("sand_soldier", 0) == soldiers, "客户端不独立生成转化产物")
	_main._projectile_system.clear_client()
	_expect(views._views.is_empty(), "客户端清场清除未播完的光束")
	_expect(_main.BUFFERED_BATTLE_EVENTS.has(&"_rpc_attack_hit_visual"), "光束纳入可靠战斗时间轴事件")
	_main.mode = old_mode
	_clear()

func _check_true_death_rewards() -> void:
	for reverse in [false, true]:
		for card in ["sion", "anivia", "anivia_egg", "ashe"]:
			var azir := _spawn("azir", 0, Vector2(250, 900))
			var dragon := _spawn("aurelionsol", 0, Vector2(250, 1000))
			dragon.configure_carried_active_skill(CardDB.active_skills_for("aurelionsol")[0])
			var victim := _spawn(card, 1, Vector2(400, 900))
			_main._combat.begin_batch(_main._sim_tick_id, "true_death")
			if reverse: _hit(azir, victim, 99999)
			_hit(dragon, victim, 99999)
			_hit(dragon, victim, 99999)
			if not reverse: _hit(azir, victim, 99999)
			_main._combat.commit_batch()
			var expected := 0 if card == "anivia" else 1
			_expect(dragon.skill_resource_value == expected and _count("sand_soldier", 0) == expected, "%s正反批次：统一真正死亡决定龙王收益与沙皇转化，重复致死只给一次" % card)
			for actor in _main.get_tree().get_nodes_in_group("combatants"):
				if actor is Unit and actor.card_id in ["sand_soldier", "anivia_egg"] and actor != victim:
					_expect(actor.hp == actor.max_hp, "本批新生蛋/沙兵不参与已锁定伤害")
			if card == "sion":
				_expect(victim.death_form.waiting() and victim.is_true_death(), "本体真死发收益后照常等待亡语狂暴")
				victim.death_form.created_tick = -1
				for tick in 40: victim.death_form.advance(victim, 0.05)
				_hit(azir, victim, 1)
				_hit(dragon, victim, 99999)
				_expect(not victim.is_true_death() and dragon.skill_resource_value == 1 and _count("sand_soldier", 0) == 1, "狂暴被杀不再次充能或转化")
			_clear()
	# 狂暴第一条命未登记沙皇资格，第二条命有新命中也不能转化。
	for natural in [false, true]:
		var azir := _spawn("azir", 0, Vector2(250, 900))
		var victim := _spawn("sion", 1, Vector2(400, 900))
		victim.take_damage(99999)
		victim.death_form.created_tick = -1
		for tick in 40: victim.death_form.advance(victim, 0.05)
		_hit(azir, victim, 1)
		if natural: victim.apply_death_form_decay(99999)
		else: _hit(azir, victim, 99999)
		_expect(_count("sand_soldier", 0) == 0 and not victim.is_true_death(), "狂暴自然结束/被杀均拒绝新转化资格")
		_clear()
	var azir := _spawn("azir", 0, Vector2(250, 900))
	var dragon := _spawn("aurelionsol", 0, Vector2(250, 1000))
	dragon.configure_carried_active_skill(CardDB.active_skills_for("aurelionsol")[0])
	var egg := _spawn("anivia_egg", 1, Vector2(400, 900))
	_hit(azir, egg, 1)
	egg._tick_timed_revival(3.0)
	_expect(not egg.is_true_death() and _count("sand_soldier", 0) == 0 and dragon.skill_resource_value == 0, "带助攻标记蛋正常孵化不转化、不计击杀")
	var revived: Unit
	for actor in _main.get_tree().get_nodes_in_group("combatants"):
		if actor is Unit and actor.card_id == "anivia": revived = actor
	_expect(is_instance_valid(revived) and revived.death_replacement_charges == 0, "孵化生成无蛋机会的新冰鸟")
	if is_instance_valid(revived):
		_hit(azir, revived, 1)
		_hit(dragon, revived, 99999)
		_expect(revived.is_true_death() and dragon.skill_resource_value == 1 and _count("sand_soldier", 0) == 1, "无蛋机会冰鸟死亡正常充能与转化")
	_clear()

	# 同批死亡来源不得因亡语/孵化或收益顺序恢复资格。
	for reverse in [false, true]:
		azir = _spawn("azir", 0, Vector2(250, 900))
		dragon = _spawn("aurelionsol", 0, Vector2(250, 1000))
		dragon.configure_carried_active_skill(CardDB.active_skills_for("aurelionsol")[0])
		var victim := _spawn("sion", 1, Vector2(400, 900))
		_main._combat.begin_batch(_main._sim_tick_id, "dead_source")
		if reverse: dragon.take_damage(99999)
		_hit(azir, victim, 1)
		_hit(dragon, victim, 99999)
		if not reverse: dragon.take_damage(99999)
		_main._combat.commit_batch()
		_expect(dragon.skill_resource_value == 0 and _count("sand_soldier", 0) == 1, "同批来源死亡正反顺序均无龙王收益，沙皇已成立窗口仍转化赛恩本体")
		_clear()
