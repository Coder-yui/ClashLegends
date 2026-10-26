extends "res://tests/suites/battle_suite.gd"
var _owned: Array[Unit] = []
var _spells: SpellSystem

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_spells = main.get("_spell_system")
	_check_timing()
	_check_targets(false)
	_check_targets(true)
	_check_towers()
	_check_immunity()
	_check_contract()
	_check_native_palette()
	_check_owned_audio()
	_check_replica()
	_clear()

func _spawn(card: String, pos: Vector2, team: int = 1) -> Unit:
	var unit: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, card, pos, {"deploy_time_override": 0.0}))
	_owned.append(unit)
	return unit

func _cast(pos: Vector2, enhanced: bool = false) -> void:
	var batch: CombatResolver = _main.combat_service()
	batch.begin_batch(_main.get_authoritative_server_tick(), "medium_lightning_test")
	_spells.cast(0, CardDB.get_card("medium_lightning"), pos, enhanced)
	_spells._tick_medium_lightning(_main.get_authoritative_server_tick() + 40)
	batch.commit_batch()

func _check_targets(enhanced: bool) -> void:
	var center := Vector2(360, 640)
	var ground := _spawn("garen", center)
	var air := _spawn("anivia", center + Vector2(30, 0))
	var building := _spawn("tombstone", center + Vector2(-40, 0))
	var ally := _spawn("garen", center, 0)
	var ally_air := _spawn("anivia", center + Vector2(0, 40), 0)
	var ally_building := _spawn("tombstone", center, 0)
	var outside := _spawn("garen", center + Vector2(200, 0))
	var edge := _spawn("garen", center + Vector2(100 + ground.body_radius, 0))
	edge.position = center + Vector2(100 + edge.body_radius, 0)
	var initial := [ground.hp, air.hp, building.hp, ally.hp, outside.hp, edge.hp]
	_cast(center, enhanced)
	for i in 3:
		var target: Unit = [ground, air, building][i]
		_expect(target.hp == initial[i] - 240, "中型落雷对地空及建筑造成240伤害")
		_expect(target.control.stun_timer == 0, "中型落雷不眩晕单位或建筑卡")
	_expect(ally.hp == initial[3] and outside.hp == initial[4], "中型落雷不误伤友军或圈外目标")
	_expect(edge.hp == initial[5] - 240, "范围含目标权威半径接触边界")
	_expect(ally.shield_hp == (180 if enhanced else 0) and ally_air.shield_hp == (180 if enhanced else 0), "仅强化给地空友军180点盾")
	_expect(ally_building.shield_hp == 0 and ground.shield_hp == 0, "建筑友军及敌军不获盾")
	_expect(is_equal_approx(ground.control.slow_multiplier, 0.7 if enhanced else 1.0), "仅强化使敌军减速30%")
	_expect(building.control.slow_multiplier == 1.0, "建筑卡不施加移动减速")
	_expect(_spells.lightning_casts.is_empty(), "中型落雷不创建多段权威排程")
	if enhanced:
		for i in 39: ground.control.tick_slows(0.05)
		_expect(ground.control.slow_multiplier < 1.0, "减速第39Tick仍有效")
		ground.control.tick_slows(0.05)
		_expect(ground.control.slow_multiplier == 1.0, "减速第40Tick到期")
		for i in 60: ally.shields.tick(0.05)
		_expect(ally.shield_hp == 0, "护盾3秒自然到期")
	_clear()

func _check_towers() -> void:
	for tower in _main.get_tree().get_nodes_in_group("combatants"):
		if not tower is Tower or tower.team != 1: continue
		var hp := float(tower.hp)
		tower.control.hard.clear_family(&"stun")
		_cast(tower.global_position, true)
		_expect(tower.hp == hp - 72, "防御塔和水晶承受72伤害")
		_expect(is_equal_approx(tower.control.stun_timer, 0.0 if tower.is_king else 2.0), "仅防御塔失效2秒，水晶免疫")
		if not tower.is_king:
			_expect(not tower.has_visible_stun(), "失效本身无眩晕标识")
			_expect(_main._snapshot_system._tower_snapshot_payload(tower)[NetworkSnapshotSystem.T_STUNNED] == 0, "客户端失效不投影眩晕标识")
			tower.stun(0.5, &"test_other_stun")
			_expect(tower.has_visible_stun(), "失效期间其他眩晕正常显示")
			_expect(_main._snapshot_system._tower_snapshot_payload(tower)[NetworkSnapshotSystem.T_STUNNED] == 1, "叠加眩晕同步客户端标识")
			for i in 10: tower.control.tick_hard_controls(0.05)
			_expect(not tower.has_visible_stun() and tower.control.stun_timer > 0.0, "普通眩晕先结束时隐藏标识但保留失效")
			for i in 29: tower.control.tick_hard_controls(0.05)
			_expect(tower.control.stun_timer > 0.0, "防御塔失效第39Tick仍有效")
			tower.control.tick_hard_controls(0.05)
			_expect(tower.control.stun_timer == 0.0, "防御塔失效第40Tick到期")
			tower.apply_stasis(3.0)
			_cast(tower.global_position)
			_expect(tower.hp == hp - 72 and tower.control.stun_timer == 0, "凝滞防御塔拒绝伤害与失效")
			tower.control.hard.clear_family(&"stasis")
		tower.hp = hp
		_spells.clear()

func _check_immunity() -> void:
	var center := Vector2(360,640)
	var enemy := _spawn("garen",center)
	var ally := _spawn("garen",center,0)
	enemy.apply_stasis(2.0)
	ally.apply_stasis(2.0)
	var hp := enemy.hp
	_cast(center,true)
	_expect(enemy.hp == hp and enemy.control.slow_multiplier == 1.0, "凝滞敌军不受伤害和减速")
	_expect(ally.shield_hp == 0, "凝滞友军不获盾")
	_clear()

func _check_contract() -> void:
	var saved_deck: Array = _main.runtime._deck.duplicate()
	_main.runtime._deck = ["medium_lightning", "garen", "ashe", "teemo", "xin", "heal", "freeze", "zap"]
	_expect(_main.runtime.card_cost_for_team(0, "medium_lightning") == 5, "主动槽费用4+1")
	_main.runtime._deck = ["garen", "ashe", "medium_lightning", "teemo", "xin", "heal", "freeze", "zap"]
	_expect(_main.runtime.card_cost_for_team(0, "medium_lightning") == 4, "普通槽费用4")
	_main.runtime._deck = saved_deck
	for field in ["shield", "shield_duration", "slow_duration", "slow_multiplier"]:
		var invalid := CardDB.get_card("medium_lightning").duplicate(true)
		invalid.active_skills[0][field] = -1
		_expect(not CardDB.VALIDATOR.validate_all({"medium_lightning":invalid},false).is_empty(), "拒绝非法强化字段：" + field)
	for curve in ["unsupported", 6]:
		var invalid_curve := CardDB.get_card("medium_lightning").duplicate(true)
		invalid_curve.audio.events["spell:zone_sustain"].fade_out_curve = curve
		_expect(not CardDB.VALIDATOR.validate_all({"medium_lightning":invalid_curve},false).is_empty(), "拒绝未知区域停止淡出曲线")
	var invalid_windup := CardDB.get_card("medium_lightning").duplicate(true)
	invalid_windup.spell_windup = 0.0
	_expect(not CardDB.VALIDATOR.validate_all({"medium_lightning":invalid_windup},false).is_empty(), "拒绝无法覆盖敌方预警的落雷前摇")
	_spells.show_lightning("medium_lightning_disabled", Vector2(180,300),54)
	_spells.show_lightning("medium_lightning_disabled", Vector2(180,300),54)
	_expect(_spells.lightning_effects.size() == 1, "同塔失效刷新不叠加附着层")
	_spells.tick_visuals(2.4)
	_expect(_spells.lightning_effects.is_empty(), "失效表现到期清理")

func _clear() -> void:
	_spells.clear()
	for unit in _owned:
		if is_instance_valid(unit): unit.free()
	_owned.clear()

func _check_replica() -> void:
	_spells.clear()
	var saved_mode: String = _main.runtime.mode
	var saved_team: int = _main.runtime.local_team
	var saved_session: MatchSession = _main.runtime.session
	_main.runtime.mode = "client"
	_main.runtime.local_team = 1
	_main.runtime.session = MatchSession.new()
	_main.runtime.session.opponent_id = 1
	_main.runtime.session.session_id = "medium-test"
	_main.runtime.session.phase = MatchSession.Phase.RUNNING
	var event_id: int = _main._last_card_event_id + 100
	_main._rpc_lightning_fx("old-session", event_id, "medium_lightning", Vector2(360,640),100,0)
	_expect(_spells.lightning_effects.is_empty(), "旧会话中型落雷被拒绝")
	_main._rpc_lightning_fx("medium-test", event_id, "medium_lightning", Vector2(360,640),100,0)
	_main._rpc_lightning_fx("medium-test", event_id, "medium_lightning", Vector2(360,640),100,0)
	_expect(_spells.lightning_effects.size() == 1 and _spells.lightning_casts.is_empty(), "客户端落雷事件去重且不创建权威结果")
	_main._rpc_lightning_fx("medium-test", event_id+1, "medium_lightning_disabled", Vector2(180,300),54,0)
	_expect(_spells.lightning_effects.size() == 2, "客户端接收塔失效表现")
	_main.runtime.game_over = true
	_main._rpc_lightning_fx("medium-test", event_id+2, "medium_lightning", Vector2(360,640),100,0)
	_expect(_spells.lightning_effects.size() == 2, "终局后拒绝中型落雷")
	_main.runtime.game_over = false
	_main.runtime.mode = saved_mode
	_main.runtime.local_team = saved_team
	_main.runtime.session = saved_session

func _check_timing() -> void:
	var pos := Vector2(360, 640)
	var target := _spawn("garen", pos)
	var entering := _spawn("garen", pos + Vector2(200, 0))
	var hp := target.hp
	var entering_hp := entering.hp
	var start: int = _main.get_authoritative_server_tick()
	_spells.cast(0, CardDB.get_card("medium_lightning"), pos, true)
	_expect(target.hp == hp and target.control.slow_multiplier == 1.0, "E施法时无提前伤害或减速")
	_expect(_spells.medium_lightning_casts.size() == 1, "E建立独立权威延迟排程")
	_spells._tick_medium_lightning(start + 39)
	_expect(target.hp == hp, "E第39Tick仍不结算")
	target.position += Vector2(200, 0)
	entering.position = pos
	_spells._tick_medium_lightning(start + 40)
	_expect(target.hp == hp and entering.hp == entering_hp - 240, "E第40Tick按落雷瞬间位置结算")
	_spells._tick_medium_lightning(start + 41)
	_expect(entering.hp == entering_hp - 240 and _spells.medium_lightning_casts.is_empty(), "E只结算一次并释放排程")
	_spells.cast(0, CardDB.get_card("medium_lightning"), pos)
	_spells.clear()
	_spells._tick_medium_lightning(start + 80)
	_expect(entering.hp == entering_hp - 240, "清场取消在途落雷")
	_clear()

func _check_owned_audio() -> void:
	var audio: GameAudioManager = _main._audio_manager
	var tower: Tower
	for target in _main.world.towers_snapshot():
		if not target.is_king: tower = target; break
	var hp := tower.hp
	var event_id := maxi(_main._presentation_event_id, audio._last_zone_event_id) + 100
	audio.start_zone_audio(event_id, "medium_lightning", 0, "spell", tower.position, 2.0, 0, tower)
	_expect(audio._zone_players.has(event_id), "R失效持续声独立启动")
	audio.start_zone_audio(event_id + 1, "medium_lightning", 0, "spell", tower.position, 2.0, 0, tower)
	_expect(not audio._zone_players.has(event_id) and audio._zone_players.has(event_id + 1), "同塔刷新替换持续声，不叠加")
	audio._tick_zone_audio(1.95)
	_expect(audio._zone_players.has(event_id + 1), "R持续声到期前保留")
	audio._tick_zone_audio(0.05)
	_expect(audio._zone_players.has(event_id + 1) and audio._zone_players[event_id + 1].fading, "R持续声2秒开始原版停止淡出")
	audio._tick_zone_audio(0.5)
	_expect(is_equal_approx(audio._zone_players[event_id + 1].player.volume_linear, db_to_linear(-12.0) * 0.625), "R停止事件Exp1曲线半程保持衰减后起始振幅的0.625")
	audio._tick_zone_audio(0.5)
	_expect(not audio._zone_players.has(event_id + 1), "R停止事件1秒淡出后释放")
	audio.start_zone_audio(event_id + 2, "medium_lightning", 0, "spell", tower.position, 2.0, 0, tower)
	tower.hp = 0
	audio._tick_zone_audio(0.01)
	_expect(audio._zone_players.has(event_id + 2) and audio._zone_players[event_id + 2].fading, "塔死亡触发R原版停止淡出")
	audio._tick_zone_audio(1.0)
	_expect(not audio._zone_players.has(event_id + 2), "塔死亡尾音不重启")
	tower.hp = hp
	audio.start_zone_audio(event_id + 3, "medium_lightning", 0, "spell", tower.position, 2.0, 0, tower)
	audio.clear_zone_audio()
	_expect(audio._zone_players.is_empty(), "清场停止R持续声")
	_main._presentation_event_id = event_id + 3

func _check_native_palette() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/medium_lightning/warning_enemy/sampled.json"))
	var matched := 0
	for emitter in data.emitters:
		if not bool(emitter.get("palette_enabled", false)): continue
		matched += 1
		var material: ShaderMaterial = preload("res://assets/effects/medium_lightning/player.gd")._material(emitter)
		_expect(bool(material.get_shader_parameter("has_palette")) and is_equal_approx(float(material.get_shader_parameter("palette_row")), 15.5 / 16.0), "敌方预警材质实际启用原版第15索引色表")
		var texture: Texture2D = material.get_shader_parameter("palette_texture")
		_expect(texture != null and texture.resource_path == emitter.palette_path, "敌方色表进入材质绑定与预加载依赖")
	_expect(matched == 3, "敌方范围圈三个原版色表层接入")

	for kind in ["warning", "strike", "disabled", "tower_hit", "tower_crack"]:
		var unchanged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/medium_lightning/" + kind + "/sampled.json"))
		for emitter in unchanged.emitters:
			var material: ShaderMaterial = preload("res://assets/effects/medium_lightning/player.gd")._material(emitter)
			_expect(not bool(material.get_shader_parameter("has_palette")), "红圈修正不再改变其他阶段的色表表现：" + kind + "/" + emitter.name)
