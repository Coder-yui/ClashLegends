extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var skill: Dictionary = CardDB.active_skills_for("corki")[0]
	var source := _spawn("corki", 0, Vector2(200, 900))
	var first := _spawn("target_dummy", 1, Vector2(310, 900))
	var air := _spawn("corki", 1, Vector2(310, 930))
	var behind := _spawn("target_dummy", 1, Vector2(400, 900))
	var ally := _spawn("target_dummy", 0, Vector2(310, 880))
	var first_hp := first.hp
	var air_hp := air.hp
	var behind_hp := behind.hp
	var ally_hp := ally.hp
	var system: ProjectileSystem = main._projectile_system
	system.clear_all()
	system.launch_skill_fan(source, skill, Vector2.RIGHT)
	_expect(first.hp == first_hp, "库奇发射不提前伤害")
	for i in 12: main._tick_projectiles(0.05)
	_expect(first.hp == first_hp - 100 and air.hp == air_hp - 100, "首个地面碰撞爆炸同时命中空军，主目标只扣一次")
	_expect(behind.hp == behind_hp and ally.hp == ally_hp, "碰撞点外后排及友军不受伤")
	_expect(system.projectiles.is_empty() and system.impact_effects.size() == 1, "首个碰撞停止并只生成一次爆炸")
	system.clear_all()
	system.launch_skill_fan(source, skill, Vector2.LEFT)
	for i in 12: main._tick_projectiles(0.05)
	_expect(system.projectiles.is_empty() and system.impact_effects.is_empty(), "最大射程落空消失，不爆炸")
	first.position = Vector2(600, 1100)
	air.position = Vector2(300, 900)
	behind.position = Vector2(320, 925)
	system.launch_skill_fan(source, skill, Vector2.RIGHT)
	for i in 12: main._tick_projectiles(0.05)
	_expect(air.hp == air_hp - 200 and behind.hp == behind_hp - 100, "空军可以成为首个碰撞体，并炸伤地面")
	system.clear_all()
	air.apply_stasis(2.0)
	behind.position = Vector2(420, 900)
	system.launch_skill_fan(source, skill, Vector2.RIGHT)
	for i in 12: main._tick_projectiles(0.05)
	_expect(air.hp == air_hp - 200 and behind.hp == behind_hp - 200, "凝滞不阻挡弹体且不受爆炸伤害")
	system.clear_all()
	system.launch_skill_fan(source, skill, Vector2.RIGHT)
	source.take_damage(99999.0)
	for i in 12: main._tick_projectiles(0.05)
	_expect(behind.hp == behind_hp - 300, "来源死亡后已发导弹独立命中")
	for unit in [source, first, air, behind, ally]:
		if is_instance_valid(unit): unit.free()
	system.clear_all()

	var old_deck: Array = main._deck.duplicate()
	main._deck[0] = "corki"
	var paid: Unit = main._spawn_card_units(0, "corki", Vector2(250, 1100), 0.0, 0)[0]
	var id := paid.active_ability_id
	main._elixir.elixir = 9.0
	for use in 3:
		var prepared: Dictionary = main._active_skills.skill_for_cast(id)
		_expect(prepared.projectile_impact_visual == ("corki_explosion_big" if use == 2 else "corki_explosion"), "超级导弹独立红色爆炸表现")
		_expect(prepared.damage == [100, 100, 180][use], "按实际消费次数选择普通/超级伤害")
		_expect(prepared.visual_action == ("active_big" if use == 2 else "active"), "第三枚使用独立动作与声音")
		main._elixir.elixir = 9.0 - use
		_expect(main.use_active_skill(id, 0), "正式入口接受第%d枚" % (use + 1))
		_expect(not main.use_active_skill(id, 0), "排队期间拒绝重复请求")
		main._sim_tick_id += 10
		main._tick_pending_active_skills(0.05)
		var entry: Dictionary = main._active_skills.entry(id)
		_expect(entry.uses_remaining == 2 - use and entry.cooldown_left == 3.0, "开始时消费一次并启动3秒冷却")
		_expect(not main.use_active_skill(id, 0), "冷却或耗尽期间拒绝")
		_expect(main._elixir.elixir == 8.0 - use, "每次仅扣一金币")
		_run_main_ticks(3)
		var missile: Dictionary = system.projectiles.values()[0]
		_expect(missile.damage == [100, 100, 180][use], "正式排程实际发出的弹体固化次数伤害")
		var payload: Array = main._snapshot_system._projectile_snapshot_payload(700 + use, missile)
		main._snapshot_system._apply_projectiles([payload])
		var replica: Dictionary = system.client_snapshot()[700 + use]
		_expect(replica.visual == (&"corki_missile_big" if use == 2 else &"corki_missile"), "弹体快照往返保留普通/超级表现")
		_expect(replica.pos == missile.pos and replica.direction == missile.direction, "客户端只接收权威位置与方向")
		_run_main_ticks(57)
		system.clear_all()
	_expect(not main.use_active_skill(id, 0), "第三枚后永远耗尽本次部署资格")
	_expect(CardDB.active_skills_for("corki")[0].damage == 100, "逐次副本不修改共享定义")
	main._deck = old_deck
	for change in [{"projectile_impact_visuals_by_use": ["bad", "bad", "bad"]}, {"projectile_impact_visuals_by_use": ["corki_explosion"]}, {"projectile_impact_visuals_by_use": "bad"}, {"damage_by_use": [100, 180]}, {"damage_by_use": [100, INF, 180]}, {"damage_by_use": "bad"}, {"projectile_explosion_radius": -1}, {"projectile_explosion_radius": "bad"}, {"projectile_stop_on_hit": false}, {"visual_actions_by_use": ["bad", "bad", "bad"]}, {"projectile_visuals_by_use": ["bad", "bad", "bad"]}]:
		var cards := CardDB.all().duplicate(true)
		cards.corki.active_skills[0].merge(change, true)
		_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "非法序列、爆炸配置和类型被拒绝")

func _spawn(card: String, team: int, pos: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, card, pos, {"deploy_time_override": 0.0}))
