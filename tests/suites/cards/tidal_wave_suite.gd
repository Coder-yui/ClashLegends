extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var spells: SpellSystem = main.get("_spell_system")
	_check_native_motion()
	var stats := CardDB.get_card("tidal_wave")
	var audio_events: Array[String] = []
	var hit_positions: Array[Vector2] = []
	var on_event := func(kind: String, data: Dictionary):
		if kind == "card_event" and data.card_id == "tidal_wave":
			audio_events.append(String(data.cue))
			if data.cue == "spell:hit": hit_positions.append(data.pos)
	main.runtime.event.connect(on_event)
	var origin := Vector2(360, 900)
	var units: Array[Unit] = []
	for pair in [["garen", 1, Vector2(0, -100)], ["garen", 1, Vector2(120, -100)], ["anivia", 1, Vector2(0, -100)], ["garen", 0, Vector2(0, -100)], ["tombstone", 1, Vector2(40, -150)], ["garen", 1, Vector2(0, -500)]]:
		units.append(main._spawn_unit(UnitSpawnRequest.new(pair[1], pair[0], origin + pair[2], {"deploy_time_override": 0.0})))
	var hp: Array = units.map(func(u): return u.hp)
	spells.cast(0, stats, origin, true)
	var start := int(spells.tidal_waves[0].start_tick)
	_expect(start == main.get_authoritative_server_tick() + 10, "原版施法前奏为10Tick")
	_tick_wave(spells, start - 1)
	_expect(not spells.tidal_waves[0].launched and spells.tidal_effects.is_empty(), "前奏期间不生成浪潮")
	_tick_wave(spells, start)
	_expect(spells.tidal_waves[0].launched, "第10Tick生成浪潮")
	_expect(audio_events.count("spell:launch") == 1, "生成时播放一次发射音效")
	_expect(units[0].hp == hp[0], "浪潮不是瞬间全范围伤害")
	_tick_wave(spells, start + 10)
	_expect(units[0].hp == hp[0] - 120, "扫掠跨Tick命中地面目标")
	_expect(units[1].hp == hp[1] and units[2].hp == hp[2], "排除宽度外及空军")
	_expect(units[3].hp == hp[3] and units[3].buffs.remaining(&"buff") > 1.9, "友军获得2秒加速且不受伤")
	_expect(is_equal_approx(units[3].active_speed_multiplier, 1.3), "加速30%")
	_expect(units[0].knockback.velocity.y < 0, "蓝方浪潮向敌方击退")
	_expect(units[4].hp == hp[4] - 120 and units[4].knockback.remaining == 0, "建筑受伤但不被击退")
	units[0].knockback.cancel(&"test")
	units[0].position = origin + Vector2(0, -200)
	units[3].position = origin + Vector2(0, -200)
	units[3].buffs.advance(1.0)
	var hit_count := audio_events.count("spell:hit")
	_expect(hit_count == 2, "两个有效敌方命中各播放一次音效")
	var remaining := units[3].buffs.remaining(&"buff")
	_tick_wave(spells, start + 16)
	_expect(units[0].hp == hp[0] - 120, "单次浪潮不重复伤害")
	_expect(units[0].knockback.remaining == 0, "单次浪潮再次接触不重复击退")
	_expect(audio_events.count("spell:hit") == hit_count, "重复接触不重复播放命中声")
	_expect(is_equal_approx(remaining, units[3].buffs.remaining(&"buff")), "重复接触不刷新加速")
	_tick_wave(spells, start + 28)
	_expect(units[5].hp == hp[5] and spells.tidal_waves.is_empty(), "射程外不命中且到期清理")
	# Shield blocks the entire wave delivery, including knockback.
	units[0].position = origin - Vector2(0, 100)
	units[0].knockback.cancel(&"test")
	units[0].buffs.apply(&"effect_shield", &"wave_test", 1.5, {})
	var shield_hp := units[0].hp
	hit_positions.clear()
	spells.cast(0, stats, origin)
	_tick_wave(spells, int(spells.tidal_waves[0].start_tick) + 10)
	_expect(units[0].hp == shield_hp and units[0].knockback.remaining == 0, "法术盾抵挡伤害和击退")
	_expect(not hit_positions.has(units[0].position), "法术盾抵挡不播放命中声")
	spells.clear()
	# Red direction and normal-slot no friendly haste.
	units[3].buffs.clear_family(&"buff")
	units[3].position = Vector2(360, 400)
	units[0].position = Vector2(390, 400)
	spells.cast(1, stats, Vector2(360, 300))
	_tick_wave(spells, int(spells.tidal_waves[0].start_tick) + 10)
	_expect(units[3].knockback.velocity.y > 0, "红方浪潮向下击退")
	_expect(units[0].buffs.remaining(&"buff") == 0, "普通槽不为友军加速")
	spells.clear()
	for tower in main.get_tree().get_nodes_in_group("combatants"):
		if not tower is Tower or tower.is_king: continue
		var team := 1 - int(tower.team)
		var pos := Vector2(tower.position.x, 700 if team == 0 else 580)
		var before: float = tower.hp
		spells.cast(team, stats, pos)
		_tick_wave(spells, int(spells.tidal_waves[0].end_tick))
		_expect(tower.hp == before - 36, "最前方释放恰可触及敌方防御塔且伤害为36")
	for team in [0, 1]:
		for row in ArenaRules.ARENA_ROWS:
			for column in ArenaRules.ARENA_COLUMNS:
				var tile := Vector2i(column, row)
				var pos: Vector2 = main.runtime._deployment_rules.arena_tile_center(tile)
				var expected: bool = main.runtime._deployment_rules.tile_in_ground_deploy_zone(tile, team)
				_expect(main.runtime.is_card_deploy_position_valid(team, "tidal_wave", pos) == expected, "浪潮与初始兵种区域逐格一致并忽略建筑")
		for y in [620, 660]:
			for x in [140, 360]:
				_expect(not main.runtime.is_card_deploy_position_valid(team, "tidal_wave", Vector2(x,y)), "双方河道及桥面禁止释放")
	_expect(main.runtime.is_card_deploy_position_valid(0, "tidal_wave", Vector2(140,1020)), "己方塔占地允许释放")
	for tower in main.get_tree().get_nodes_in_group("combatants"):
		if tower is Tower and tower.team == 1 and not tower.is_king: tower.hp = 0
	_expect(not main.runtime.is_card_deploy_position_valid(0, "tidal_wave", Vector2(140,500)), "破塔仍不开放敌方半场")
	spells.clear()
	spells.show_flight(999, "tidal_wave", Vector2(140,660), Vector2(140,260), 80, 0, 25)
	_expect(spells.tidal_waves.is_empty() and spells.tidal_effects.size() == 1, "客户端事件只创建表现")
	spells.clear()
	_expect(spells.tidal_effects.is_empty(), "清场移除浪潮表现")
	spells.cast(0, stats, origin)
	var canceled_start := int(spells.tidal_waves[0].start_tick)
	var launches_before := audio_events.count("spell:launch")
	spells.clear()
	_tick_wave(spells, canceled_start + 1)
	_expect(audio_events.count("spell:launch") == launches_before and spells.tidal_waves.is_empty(), "清场取消前奏中的浪潮与发射音效")
	main.runtime.event.disconnect(on_event)
	for unit in units:
		unit.remove_from_group("combatants")
		unit.queue_free()
	var invalid := stats.duplicate(true)
	invalid.wave_width = -1
	_expect(not CardDB.VALIDATOR.validate_all({"bad_wave":invalid}, false).is_empty(), "拒绝非法宽度")

func _tick_wave(spells: SpellSystem, tick: int) -> void:
	_main.runtime.set("_sim_tick_id", tick)
	_main.combat_service().begin_batch(tick, "wave_test")
	spells.tick(FixedStepClock.STEP)
	_main.combat_service().commit_batch()

func _check_native_motion() -> void:
	var a = preload("res://assets/effects/tidal_wave/player.gd").new()
	var b = preload("res://assets/effects/tidal_wave/player.gd").new()
	_main.add_child(a)
	_main.add_child(b)
	for player in [a,b]:
		player.load_kind("wave")
		player.setup_native(0.01)
	var velocity := Vector3(0,0,-3)
	for frame in range(1,61):
		var age := frame / 60.0
		a.seek_motion(age, velocity * age, Basis.IDENTITY, velocity, age)
	b.seek_motion(1.0, velocity, Basis.IDENTITY, velocity, 1.0)
	var same := true
	for i in a._pools.size():
		for j in b._data.frames[b._frame][i].size():
			same = same and a._pools[i][j].position.is_equal_approx(b._pools[i][j].position)
	_expect(same, "原版bindWeight拖尾位置不依赖首次渲染帧")
	a.seek_motion(1.6, velocity * 1.4, Basis.IDENTITY, velocity, 1.4)
	_expect(a.has_live_particles(), "停止发射后保留原版粒子尾部而非0.25秒整体截断")
	a.seek_motion(3.7, velocity * 1.4, Basis.IDENTITY, velocity, 1.4)
	_expect(not a.has_live_particles(), "原版各层结束后无残留粒子")
	a.free()
	b.free()
