extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	for team in [0, 1]:
		var source := _spawn("yorick", team, Vector2(260, 900))
		var primary := _spawn("garen", 1-team, Vector2(305, 900))
		var nearby := _spawn("garen", 1-team, Vector2(350, 900))
		var far := _spawn("garen", 1-team, Vector2(390, 900))
		var friend := _spawn("garen", team, Vector2(305, 920))
		var air := _spawn("anivia", 1-team, Vector2(305, 900))
		source.hp = 400
		_strike(source, primary)
		_expect(primary.hp == primary.max_hp-110 and nearby.hp == nearby.max_hp-110, "牧魂人双方普攻以目标而非自身为圆心，主次目标各一次110")
		_expect(far.hp == far.max_hp and friend.hp == friend.max_hp and air.hp == air.max_hp, "范围外友军空军均不受伤")
		_expect(source.hp == 400, "普通范围攻击不回血")
		var skill: Dictionary = CardDB.active_skills_for("yorick")[0]
		main._active_skill_effect_system.apply(source, skill)
		_expect(source.hp == 400 and source.empowered_attack_ready, "Q只武装下一击，不在按下时回血")
		_strike(source, primary)
		_expect(primary.hp == primary.max_hp-330 and nearby.hp == nearby.max_hp-330, "Q整个命中区域各220伤害")
		_expect(source.hp == 520 and not source.empowered_attack_ready, "多目标只回复一次120且强化被消费")
		_strike(source, primary)
		_expect(primary.hp == primary.max_hp-440 and source.hp == 520, "下一刀恢复普通110且不再治疗")
		source.hp = source.max_hp-10
		main._active_skill_effect_system.apply(source, skill)
		_strike(source, primary)
		_expect(source.hp == source.max_hp, "Q治疗不溢出")
		source.hp = 400
		main._active_skill_effect_system.apply(source, skill)
		source.apply_blind(1)
		var before := primary.hp
		_strike(source, primary)
		_expect(source.hp == 400 and primary.hp == before and not source.empowered_attack_ready, "致盲空挥消费强化但不伤害不回血")
		main._active_skill_effect_system.apply(source, skill)
		primary.apply_stasis(1.0)
		_expect(not source._deal_attack_damage_to(primary, 220, {"hit_heal":120}), "凝滞主目标拒绝命中及附带范围伤害")
		_expect(source.hp == 400, "无有效命中不回血")
		# 同批致死的来源不能靠已提交Q复活。
		primary.free()
		primary = _spawn("garen",1-team,Vector2(305,900))
		primary.add_shield(1000, 10.0)
		source._deal_attack_damage_to(primary,220,{"hit_heal":120,"ground_only":true})
		_expect(primary.hp == primary.max_hp and source.hp == 520, "纯护盾承伤属于有效命中，固定治疗不冒充吸血")
		source.hp = 400
		var resolver = source.battle_context.damage_batch()
		resolver.begin_batch(1, "yorick_mutual")
		source._deal_attack_damage_to(primary,220,{"hit_heal":120,"ground_only":true})
		source.hp = 0
		resolver.commit_batch()
		_expect(source.hp == 0, "同批致死来源无治疗收益")
		for unit in [source,primary,nearby,far,friend,air]:
			if is_instance_valid(unit): unit.free()
	var old_deck: Array = main._deck.duplicate()
	main._deck[0] = "yorick"
	var paid: Unit = main._spawn_card_units(0,"yorick",Vector2(250,1100),0.0,0)[0]
	var target := _spawn("target_dummy",1,Vector2(295,1100))
	target.hp = 10000
	target.max_hp = 10000
	var id := paid.active_ability_id
	for use in 3:
		main._elixir.elixir = 10.0
		_expect(main.use_active_skill(id,0) and main._elixir.elixir == 9.0, "Q正式请求消费1金币")
		_expect(not main.use_active_skill(id,0), "排队中不接受重复请求")
		_run_main_ticks(12)
		var payload: Array = main._snapshot_system._unit_snapshot_payload(paid.net_id,paid)
		_expect(payload.size() == NetworkSnapshotSystem.UNIT_PAYLOAD_SIZE and int(payload[NetworkSnapshotSystem.U_EMPOWERED_READY]) == int(paid.empowered_attack_ready), "Q武装状态使用现有快照字段")
		if paid.empowered_attack_ready: _strike(paid,target)
		_expect(not main.use_active_skill(id,0), "Q冷却期间拒绝再次施放")
		main._tick_active_skill_cooldowns(6.0)
	_expect(not main.use_active_skill(id,0), "三次耗尽后不可施放")
	paid.free()
	target.free()
	main._deck = old_deck
	for value in [-1, 0, NAN, "120"]:
		var stats: Dictionary = CardDB.get_card("yorick").duplicate(true)
		stats.active_skills[0].hit_heal = value
		_expect(not CardDB.VALIDATOR.validate_all({"yorick":stats},false).is_empty(), "拒绝非法强化命中回血")
	var voiced := _spawn("yorick",0,Vector2(250,1000))
	var audio: GameAudioManager = main._audio_manager
	voiced.prepare_empowered_attack(2.0)
	audio._process(0.0)
	var key := audio._sustain_key(voiced.get_instance_id(), &"empowered")
	_expect(audio._sustain_players.has(key), "Q武装开始原版持续声")
	var player = audio._sustain_players.get(key)
	audio._process(0.0)
	_expect(audio._sustain_players.get(key) == player, "重复帧不重启Q持续声")
	voiced.empowered_attack_ready = false
	audio._process(0.0)
	_expect(not audio._sustain_players.has(key), "Q消费停止持续声")
	voiced.prepare_empowered_attack(2.0)
	audio._process(0.0)
	voiced.take_damage(99999)
	audio._process(0.0)
	_expect(not audio._sustain_players.has(key), "死亡清理Q持续声")
	voiced.free()
	var model = load("res://assets/units/yorick/yorick_view.tscn").instantiate()
	main.add_child(model)
	_expect(model._cape_materials.size() == 2, "原版披风两层材质均接到蒙皮表面")
	model.advance_ambient_visual(0.5)
	_expect(model._cape_materials[0] != model._cape_materials[1] and model._age == 0.5, "披风两层独立实例并按表现时钟推进")
	model.free()
	var visuals = main._projectile_system._hit_visuals
	visuals.clear()
	visuals.play_hit({"card_id":"yorick"},Vector2(300,900))
	_expect(visuals._circles.size() == 1 and visuals._circles[0].radius == 35.0, "范围圈使用命中落点与35权威半径")
	visuals.advance(0.29)
	_expect(visuals._circles.size() == 1, "范围圈在0.29秒仍可见")
	visuals.advance(0.02)
	_expect(visuals._circles.is_empty(), "范围圈0.3秒后清除")
	visuals.play_hit({"card_id":"yorick"},Vector2(300,900))
	visuals.clear()
	_expect(visuals._circles.is_empty(), "清场取消尚未结束的范围圈")

func _spawn(id: String, team: int, at: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team,id,at,{"deploy_time_override":0.0}))

func _strike(source: Unit, target: Unit) -> void:
	source._target = target
	source.attack_timeline.cancel(true)
	source._attack_visual_pending = true
	source._attack(0.0)
