extends "res://tests/suites/battle_suite.gd"
func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var crab := spawn("scuttle_crab",0,Vector2(250,900))
	var building := spawn("target_dummy",1,Vector2(250,850))
	var enemy := spawn("garen",1,Vector2(280,900))
	crab.hp = 300
	var building_hp := building.hp
	for i in 20: crab.sim_tick(0.05)
	_expect(crab.structure_mending and crab.get_visual_state_code() == 3, "建筑射程内进入跳舞状态")
	_expect(crab.hp == 330 and building.hp == building_hp, "跳舞每秒回血30而不伤建筑")
	_expect(crab._target == building and not crab._attacking, "忽略旁边敌军且不启动攻击时间线")
	var payload: Array = main._snapshot_system._unit_snapshot_payload(crab.net_id, crab)
	_expect(int(payload[NetworkSnapshotSystem.U_VISUAL_STATE]) == 3, "客户端通过既有行为快照播放舞蹈")
	crab.hp = crab.max_hp
	crab.sim_tick(0.05)
	_expect(crab.hp == crab.max_hp, "满血跳舞不超过最大生命")
	crab.hp = 330
	crab.stun(1.0)
	crab.sim_tick(0.05)
	_expect(not crab.structure_mending and crab.hp == 330, "眩晕中停止跳舞回血")
	crab.control.clear_on_death()
	building.free()
	crab.sim_tick(0.05)
	_expect(not crab.structure_mending and crab._move_intent.length() > 0.0, "建筑销毁后继续寻找建筑")
	var skill: Dictionary = main._active_skill_effect_system.prepare_cast(crab, CardDB.active_skills_for("scuttle_crab")[0])
	var air := spawn("nocturne",1,Vector2(250,920))
	var ally := spawn("garen",0,Vector2(250,930))
	var far := spawn("garen",1,Vector2(600,900))
	var blocked := spawn("nocturne",1,Vector2(230,900))
	blocked.buffs.apply(&"effect_shield", &"test", 2.0, {})
	var stasis := spawn("garen",1,Vector2(220,900))
	stasis.apply_stasis(2.0)
	var before := enemy.hp
	main._active_skill_effect_system.apply(crab,skill)
	_expect(enemy.hp == before and enemy.movement_slow_visual(), "谦卑无伤害并施加移动减速")
	_expect(enemy.attack_speed_slow_visual() and air.attack_speed_slow_visual(), "谦卑同时降低地面与空军攻速")
	_expect(not ally.movement_slow_visual() and not far.movement_slow_visual(), "友军与圈外敌人不受影响")
	_expect(not blocked.movement_slow_visual() and not blocked.attack_speed_slow_visual() and blocked.buffs.remaining(&"effect_shield") == 0.0, "一次抵挡同时阻止两种减速")
	_expect(not stasis.movement_slow_visual() and not stasis.attack_speed_slow_visual(), "凝滞免疫谦卑")
	blocked.free()
	stasis.free()
	ally.hp = 200
	air.hp = 100
	crab.take_damage(9999)
	_expect(main._active_skill_effect_system.death_heal_zones.size() == 1, "真实死亡创建一次独立治疗区")
	var phase_cues: Array[StringName] = []
	var on_cue := func(card: String, cue: StringName, _point: Vector2):
		if card == "scuttle_crab": phase_cues.append(cue)
	main._audio_manager.cue_played.connect(on_cue)
	crab.free() # 延迟阶段不得读取已释放来源。
	for i in 39: main._active_skill_effect_system.tick_effects(0.05)
	_expect(ally.hp == 200 and not main._active_skill_effect_system.death_heal_zones[0].activated, "触角入地未结束时不回血")
	_expect(phase_cues.count(&"shrine:leap") == 1 and phase_cues.count(&"shrine:start") == 0, "1秒衔接声音只发一次，2秒前不播放形成声")
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(ally.hp == 200 and main._active_skill_effect_system.death_heal_zones[0].presented and not main._active_skill_effect_system.death_heal_zones[0].activated, "第40tick开始祭坛展开但不回血")
	for i in 55: main._active_skill_effect_system.tick_effects(0.05)
	_expect(ally.hp == 200 and not main._active_skill_effect_system.death_heal_zones[0].activated, "祭坛展开期间不提前治疗")
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(ally.hp == 200 and main._active_skill_effect_system.death_heal_zones[0].activated, "第96tick完成展开后开始完整6秒治疗")
	for i in 20: main._active_skill_effect_system.tick_effects(0.05)
	_expect(ally.hp == 225 and air.hp == 100, "来源死亡后仍每秒治疗友军25且不治疗敌军")
	ally.position = Vector2(600,1000)
	for i in 20: main._active_skill_effect_system.tick_effects(0.05)
	_expect(ally.hp == 225, "离开区域立即停止获得治疗")
	ally.position = Vector2(250,930)
	for i in 80: main._active_skill_effect_system.tick_effects(0.05)
	_expect(ally.hp == 325 and main._active_skill_effect_system.death_heal_zones.is_empty(), "6秒边界准确结束治疗区")
	_expect(phase_cues.count(&"shrine:start") == 1 and phase_cues.count(&"shrine:leap") == 1, "形成与衔接声音独立一次派发")
	main._audio_manager.cue_played.disconnect(on_cue)
	var cleanup := spawn("scuttle_crab",0,Vector2(250,900))
	cleanup.take_damage(9999)
	main._active_skill_effect_system.clear()
	_expect(main._active_skill_effect_system.death_heal_zones.is_empty(), "清场删除死亡治疗区")
	var test_crab := spawn("scuttle_crab",0,Vector2(200,1100))
	var audio: GameAudioManager = main._audio_manager
	test_crab.structure_mending = true
	audio._process(0.05)
	var key: String = audio._sustain_key(test_crab.get_instance_id(), &"mend")
	_expect(audio._sustain_players.has(key), "舞蹈状态启动持续音")
	if audio._sustain_players.has(key):
		var stream: AudioStreamRandomizer = audio._sustain_players[key].stream
		_expect((stream.get_stream(0) as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "舞蹈音轨实际循环")
	test_crab.structure_mending = false
	audio._process(0.05)
	_expect(not audio._sustain_players.has(key), "离开舞蹈状态释放音轨")
	test_crab.structure_mending = true
	audio._process(0.05)
	_expect(audio._sustain_players.has(key), "再次跳舞重新启动持续音")
	test_crab.take_damage(99999)
	_expect(not audio._sustain_players.has(key), "舞蹈中死亡立即释放持续音，不留循环音轨")
	test_crab.free()
	for unit in [enemy,air,ally,far]:
		if is_instance_valid(unit): unit.free()
func spawn(card: String, team: int, point: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team,card,point,{"deploy_time_override":0.0}))
