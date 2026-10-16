extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var old_tick: int = main._sim_tick_id
	_check_birth_tick()
	var stats := CardDB.get_card("void_summoning")
	for team in [0, 1]:
		_clean()
		main._sim_tick_id = 100
		_expect(main._spell_system.cast(team, stats, Vector2(360, 640)), "双方均可施放")
		_expect(_fish().is_empty(), "起始不提前生成")
		for tick in range(101, 261):
			main._sim_tick_id = tick
			main._spell_system.tick(0.05)
			_expect(_fish().size() == (0 if tick < 110 else mini(10, 1 + (tick - 110) / 16)), "首次0.5秒，此后每0.8秒准确增加一只")
		_expect(_fish().size() == 10, "8秒内精确生成10只")
		var positions := {}
		for fish in _fish():
			positions[fish.position] = true
			_expect(fish.team == team and is_equal_approx(fish.deploy_time, 0.8), "归属施法方且出生仅0.8秒")
			_expect(fish.position.distance_to(Vector2(360, 640)) <= 160.001, "出生中心在范围内")
			_expect(not fish.is_deployed(), "出生阶段不行动")
			main._sim_tick_id += 1
			for i in 15: fish.sim_tick(0.05)
			_expect(not fish.is_deployed(), "0.75秒仍未结束出生")
			fish.sim_tick(0.05)
			_expect(fish.is_deployed(), "0.8秒允许行动，不再等1秒")
		_expect(positions.size() == 10, "10个落点分散且不重合")
		main._sim_tick_id = 261
		main._spell_system.tick(0.05)
		_expect(main._spell_system.summon_zones.is_empty(), "到期清理区域")
		_check_conversion(team, stats)
	_check_edges(stats)
	_check_constrained_landing()
	_check_spell_audio()
	main._sim_tick_id = old_tick
	_clean()

func _check_conversion(team: int, stats: Dictionary) -> void:
	_clean()
	_main._sim_tick_id = 200
	_main._spell_system.cast(team, stats, Vector2(360, 640), true)
	for victim_team in [team, 1 - team]:
		var victim: Unit = _main.spawn_summoned(victim_team, "melee_minion", Vector2(360, 640), 0.0)
		var before := _fish().size()
		victim.take_damage(99999)
		_expect(_fish().size() == before + 1, "双方普通单位死亡均转化")
		_main._spell_system.on_unit_death(victim)
		_expect(_fish().size() == before + 1, "同一次死亡不能重复转化")
	for id in ["voidfish", "tombstone"]:
		var victim: Unit = _main.spawn_summoned(team, id, Vector2(360, 640), 0.0)
		var before := _fish().size()
		victim.take_damage(99999)
		_expect(_fish().size() == before - (1 if id == "voidfish" else 0), "排除建筑及近战虚空鱼：" + id)
	for id in ["voidfish_ranged", "voidfish_ranged_single", "voidfish_ranged_army"]:
		var victim: Unit = _main.spawn_summoned(team, id, Vector2(360, 640), 0.0)
		var before := _fish().size()
		victim.take_damage(99999)
		_expect(_fish().size() == before + 1, "远程虚空鱼允许转化：" + id)
	var outside: Unit = _main.spawn_summoned(team, "melee_minion", Vector2(550, 640), 0.0)
	var count := _fish().size()
	outside.take_damage(99999)
	_expect(_fish().size() == count, "圈外死亡不转化")
	_main._sim_tick_id = 360
	var expired: Unit = _main.spawn_summoned(team, "melee_minion", Vector2(360, 640), 0.0)
	expired.take_damage(99999)
	_expect(_fish().size() == count, "结束Tick即使区域尚未清扫也不转化")
	_clean()
	_main._spell_system.cast(team, stats, Vector2(360, 640), false)
	var plain: Unit = _main.spawn_summoned(team, "melee_minion", Vector2(360, 640), 0.0)
	plain.take_damage(99999)
	_expect(_fish().is_empty(), "未强化不转化")
	_main._spell_system.clear()
	_main._sim_tick_id += 100
	_main._spell_system.tick(0.05)
	_expect(_fish().is_empty(), "清场取消后续召唤")

func _fish() -> Array:
	return _main.get_tree().get_nodes_in_group("combatants").filter(func(u): return is_instance_valid(u) and u is Unit and u.card_id == "voidfish" and u.hp > 0)

func _clean() -> void:
	_main._spell_system.clear()
	for node in _main.get_tree().get_nodes_in_group("combatants"):
		if node is Unit: node.free()

func _check_birth_tick() -> void:
	_clean()
	var active: bool = _main._sim_step_active
	_main._sim_step_active = true
	_expect(_main.play_card(0, "void_summoning", Vector2(360, 640), {"immediate": true, "validate_position": false}), "正式play_card入口可召唤")
	_main._sim_tick_id += 10
	_main._spell_system.tick(0.05)
	var fish: Unit = _fish()[0]
	fish.sim_tick(0.05)
	_expect(is_equal_approx(fish._deploy_timer, 0.8), "生成当Tick不提前扣出生时间")
	for i in 15:
		_main._sim_tick_id += 1
		fish.sim_tick(0.05)
	_expect(not fish.is_deployed(), "真实权威时钟0.75秒不能行动")
	_main._sim_tick_id += 1
	fish.sim_tick(0.05)
	_expect(fish.is_deployed(), "真实权威时钟0.8秒即可行动")
	_main._sim_step_active = active
	_clean()

func _check_edges(stats: Dictionary) -> void:
	_expect(float(stats.radius) == 160.0 and float(stats.duration) == 8.0 and int(stats.active_cost_bonus) == 1 and int(stats.active_skills[0].cost) == 1, "4格半径/8秒/强化1金币")
	var offsets: Array = _main._spell_system._summoning_offsets(10, 160.0)
	seed(1234)
	var expected_random := randi()
	seed(1234)
	_expect(offsets == _main._spell_system._summoning_offsets(10, 160.0), "固定种子重复生成相同不规则形状")
	_expect(randi() == expected_random, "不消耗全局随机流")
	for center in [Vector2(0, 0), Vector2(720, 0), Vector2(0, 1280), Vector2(720, 1280), Vector2(0, 640), Vector2(720, 640), Vector2(360, 0), Vector2(360, 1280), Vector2(360, 640), Vector2(360, 900)]:
		var first: Array[Vector2] = []
		for repeat in 2:
			_clean()
			_main._sim_tick_id = 500
			_main._spell_system.cast(repeat, stats, center)
			for tick in range(501, 661):
				_main._sim_tick_id = tick
				_main._spell_system.tick(0.05)
			_expect(_fish().size() == 10, "边界仍完整召唤10只：" + str(center))
			var actual: Array[Vector2] = []
			for fish in _fish():
				actual.append(fish.position)
				_expect(fish.position.distance_to(center) <= 160.001, "最终合法修正后仍在法术圈内")
				_expect(fish.position.x >= fish.body_radius and fish.position.x <= 720.0 - fish.body_radius and fish.position.y >= fish.body_radius and fish.position.y <= 1280.0 - fish.body_radius, "整个碰撞体在地图内")
				_expect(fish.is_air or _main.is_ground_position_walkable(fish.position, fish.body_radius), "按空中/地面类型检查地形")
			var distinct := {}
			for point in actual: distinct[point] = true
			_expect(distinct.size() == 10, "边界修正不把多个落点挤在同一点")
			if repeat == 0: first = actual
			else: _expect(first == actual, "两阵营重复施放的无障碍落点相同")

func _check_constrained_landing() -> void:
	var regions: Array[Rect2] = [Rect2(10, 10, 700, 1260)]
	var obstacles: Array[Vector3] = [Vector3(450, 900, 70)]
	var point := UnitLandingQuery._nearest(Vector2(450, 900), 0, obstacles, regions, 0.02, Vector2(360, 900), 100.0)
	_expect(point.is_finite() and point.distance_to(Vector2(360, 900)) <= 100.001, "占位修正使用圆周交点，不能挤出法术圈")
	_expect(point.distance_to(Vector2(450, 900)) >= 69.999, "约束圈内同时避开不可推动占位")
	obstacles = [Vector3(360, 900, 120)]
	point = UnitLandingQuery._nearest(Vector2(360, 900), 0, obstacles, regions, 0.02, Vector2(360, 900), 100.0)
	_expect(not point.is_finite(), "范围被完全封堵时拒绝圈外生成")

func _check_spell_audio() -> void:
	var audio: GameAudioManager = _main._audio_manager
	var was_processing := audio.is_processing()
	audio.set_process(false)
	audio.set_battle_paused(false)
	var config: Dictionary = CardDB.get_card("void_summoning").audio.events["spell:zone_sustain"]
	_expect(config.pool.size() == 3 and config.natural_tail, "3个原版激活变体，完整开始段不得重复循环")
	for path in config.pool:
		var stream := load(path) as AudioStreamWAV
		_expect(stream != null and is_equal_approx(stream.get_length(), 8.0), "声音序列精确8秒，不延长区域音频")
		_expect(not "zone.wav" in path, "不再引用装备虚空献祭声音")
	var cues: Array[StringName] = []
	var capture := func(card_id: String, cue: StringName, _pos: Vector2):
		if card_id == "void_summoning": cues.append(cue)
	audio.cue_played.connect(capture)
	for team in [0, 1]:
		audio.begin_battle()
		cues.clear()
		audio.start_zone_audio(1, "void_summoning", 0, "spell", Vector2(100, 900), 8.0, team)
		var player: AudioStreamPlayer2D = audio._zone_players[1].player
		audio.start_zone_audio(1, "void_summoning", 0, "spell", Vector2.ZERO, 8.0, team)
		_expect(cues.size() == 1 and player.global_position == Vector2(100, 900), "区域事件去重，不重播开始段")
		audio._process(0.5)
		audio.set_battle_paused(true)
		audio._process(2.0)
		_expect(audio._battle_paused and audio._paused_players.has(player.get_instance_id()) and is_equal_approx(float(audio._zone_players[1].time_left), 7.5), "暂停同时冻结声音与剩余时间")
		audio.set_battle_paused(false)
		audio._process(7.49)
		_expect(audio._zone_players.has(1) and not player.stream_paused, "恢复后继续到接近8秒")
		audio._process(0.01)
		_expect(audio._zone_players.is_empty() and not player.playing, "8秒停止整个序列，无尾音遗留")
		audio.start_zone_audio(2, "void_summoning", 0, "spell", Vector2.ZERO, 8.0, team)
		var finished: AudioStreamPlayer2D = audio._zone_players[2].player
		finished.finished.emit()
		_expect(audio._zone_players.is_empty() and not finished.playing, "文件结束不能循环回大招开始声")
		audio.start_zone_audio(3, "void_summoning", 0, "spell", Vector2.ZERO, 8.0, team)
		audio.clear_zone_audio()
		_expect(audio._zone_players.is_empty(), "清场中止开始段及循环")
		audio.start_zone_audio(4, "void_summoning", 0, "spell", Vector2.ZERO, 8.0, team)
		audio.end_battle()
		_expect(audio._zone_players.is_empty(), "终局中止开始段及循环")
	audio.cue_played.disconnect(capture)
	audio.begin_battle()
	audio.set_process(was_processing)
