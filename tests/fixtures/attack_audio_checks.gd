extends RefCounted
## 正式20Hz攻击链路的序号合同；不使用直接命中夹具，也不手写攻击序号。
func run(harness: Object, main: Node2D) -> void:
	var tower_attack_flags: Array[bool] = []
	for tower in main.world.towers_snapshot():
		tower_attack_flags.append(tower.can_attack)
		tower.can_attack = false
	var audio: GameAudioManager = main._audio_manager
	for card_id in ["masteryi", "sett", "jax", "twisted_fate"]:
		audio.begin_battle()
		var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(0, card_id, Vector2(360, 1000), {"deploy_time_override": 0.0}))
		var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1, "target_dummy", Vector2(360, 940), {"deploy_time_override": 0.0}))
		target.hp = 100000.0
		target.max_hp = target.hp
		var hits: Array[Dictionary] = []
		var cues: Array[StringName] = []
		var capture := func(source: Dictionary, _position: Vector2, _first: bool):
			if source.get("card_id") == card_id: hits.append(source.duplicate(true))
		var capture_cue := func(id: String, cue: StringName, _position: Vector2):
			if id == card_id: cues.append(cue)
		main.combat_service().attack_hit.connect(capture)
		audio.cue_played.connect(capture_cue)
		for tick in 100:
			main._sim_step(main.SIM_DT)
			if hits.size() >= 3: break
		harness._expect(hits.size() >= 3 and hits.all(func(source): return int(source.get("serial", 0)) > 0), "%s 正式索敌、起手、结算全程携带有效攻击序号" % card_id)
		harness._expect(cues.has(&"attack_hit"), "%s 正式命中实际到达音频消费者" % card_id)
		if hits.size() >= 3:
			harness._expect(int(hits.back().serial) > int(hits.front().serial), "%s 后续攻击推进身份，分段附加命中可共用同一身份" % card_id)
		main.combat_service().attack_hit.disconnect(capture)
		audio.cue_played.disconnect(capture_cue)
		unit.free()
		target.free()
		main._projectile_system.clear_all()
	for index in tower_attack_flags.size(): main.world.towers_snapshot()[index].can_attack = tower_attack_flags[index]
	audio.begin_battle()
