extends "res://tests/suites/battle_suite.gd"
var _owned: Array[Unit] = []
var _spells: SpellSystem
func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_spells = main._spell_system
	var center := Vector2(360, 640)
	var ground := _spawn("garen", center)
	var air := _spawn("anivia", center + Vector2(30, 0))
	var ally := _spawn("garen", center, 0)
	var building := _spawn("tombstone", center)
	var outside := _spawn("garen", center + Vector2(300, 0))
	var hp := [ground.hp, air.hp, ally.hp, building.hp, outside.hp]
	_spells.cast(0, CardDB.get_card("corrosion"), center)
	_expect(ground.hp == hp[0], "腐蚀施放当Tick不预扣未来伤害")
	_advance(20)
	_expect(ground.hp == hp[0] - 120 and air.hp == hp[1] - 120, "腐蚀首秒对地对空各120")
	_expect(ally.hp == hp[2] and outside.hp == hp[4], "腐蚀不伤友军和圈外单位")
	_expect(building.hp == hp[3] - 120, "腐蚀对建筑卡首秒造成120伤害")
	_expect(is_equal_approx(ground.control.slow_multiplier, 1.0), "普通腐蚀没有减速")
	ground.position += Vector2(300, 0)
	outside.position = center
	_advance(20)
	_expect(ground.hp == hp[0] - 120 and outside.hp == hp[4] - 120, "每Tick重新查询进出区域")
	_advance(60)
	_expect(air.hp == hp[1] - 600 and _spells.corrosion_zones.is_empty(), "100Tick总伤害600且区域到期")
	_advance(10)
	_expect(air.hp == hp[1] - 600, "到期不多伤害")
	_spells.clear()
	_spells.cast(0, CardDB.get_card("corrosion"), center, true)
	_advance(1)
	_expect(is_equal_approx(outside.control.slow_multiplier, 0.8), "强化腐蚀移速降低20%")
	outside.position += Vector2(400, 0)
	outside.control.tick_slows(0.1)
	_expect(is_equal_approx(outside.control.slow_multiplier, 1.0), "停止续期后最多0.1秒恢复移速")
	outside.position = center
	var before := outside.hp
	_spells.tick_visuals(9.0)
	_expect(outside.hp == before and _spells.corrosion_zones.size() == 1, "表现时间不能结算伤害或删除权威区域")
	_spells.clear()
	_advance(100)
	_expect(outside.hp == before and _spells.corrosion_effects.is_empty(), "清场取消后续伤害与表现")
	_spells.cast(0, CardDB.get_card("corrosion"), center)
	_spells.cast(0, CardDB.get_card("corrosion"), center)
	before = outside.hp
	_advance(20)
	_expect(outside.hp == before - 240, "独立施法区域各自结算")
	_spells.clear()
	outside.apply_stasis(2.0, &"corrosion_test")
	before = outside.hp
	_spells.cast(0, CardDB.get_card("corrosion"), center, true)
	_advance(20)
	_expect(outside.hp == before, "凝滞拒绝腐蚀伤害")
	for field in ["damage", "interval"]:
		var bad := CardDB.get_card("corrosion").duplicate(true)
		bad[field] = 0.0
		_expect(not CardDB.VALIDATOR.validate_all({"corrosion": bad}, false).is_empty(), "腐蚀拒绝非法" + field)
	for multiplier in [-0.1, 1.1, INF]:
		var invalid := CardDB.get_card("corrosion").duplicate(true)
		invalid.tower_damage_multiplier = multiplier
		_expect(not CardDB.VALIDATOR.validate_all({"corrosion": invalid}, false).is_empty(), "腐蚀拒绝非法塔伤倍率")
	var bad := CardDB.get_card("corrosion").duplicate(true)
	bad.active_skills[0].slow_multiplier = 1.0
	_expect(not CardDB.VALIDATOR.validate_all({"corrosion": bad}, false).is_empty(), "强化腐蚀拒绝无效减速倍率")
	var deck: Array = _main._deck.duplicate()
	_main._deck = ["corrosion", "garen", "ashe", "teemo", "xin", "heal", "freeze", "zap"]
	_expect(_main.card_cost_for_team(0, "corrosion") == 4, "强化腐蚀额外费用0，总费用4")
	_main._deck = deck
	_check_half_second_schedule()
	_check_structures()
	_check_backline_and_audio()
	_check_replica()
	_spells.clear()
	for unit in _owned:
		if is_instance_valid(unit): unit.free()
	_owned.clear()

func _spawn(card: String, pos: Vector2, team: int = 1) -> Unit:
	var unit: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, card, pos, {"deploy_time_override": 0.0}))
	unit.max_hp = 5000; unit.hp = 5000
	_owned.append(unit)
	return unit
func _advance(count: int) -> void:
	for index in count:
		_main.set("_sim_tick_id", _main.get_authoritative_server_tick() + 1)
		var batch: CombatResolver = _main.combat_service()
		batch.begin_batch(_main.get_authoritative_server_tick(), "corrosion_test")
		_spells.tick(FixedStepClock.STEP)
		batch.commit_batch()

func _check_replica() -> void:
	_spells.clear()
	var mode: String = _main.mode
	var session: MatchSession = _main._session
	_main.mode = "client"
	_main._session = MatchSession.new()
	_main._session.opponent_id = 1
	_main._session.session_id = "corrosion-test"
	_main._session.phase = MatchSession.Phase.RUNNING
	var id: int = _main._last_card_event_id + 100
	_main._rpc_corrosion_fx("old", id, Vector2(360, 640), 110, 4, 0)
	_expect(_spells.corrosion_effects.is_empty(), "腐蚀拒绝旧会话")
	_main._rpc_corrosion_fx("corrosion-test", id, Vector2(360, 640), 110, 4, 0)
	_main._rpc_corrosion_fx("corrosion-test", id, Vector2(360, 640), 110, 4, 0)
	_expect(_spells.corrosion_effects.size() == 1 and _spells.corrosion_zones.is_empty(), "副本去重且只创建表现")
	_main._rpc_corrosion_fx("corrosion-test", id + 1, Vector2(360, 640), 110, 4, 7)
	_expect(_spells.corrosion_effects.size() == 1, "腐蚀拒绝非法阵营")
	_main.game_over = true
	_main._rpc_corrosion_fx("corrosion-test", id + 2, Vector2(360, 640), 110, 4, 1)
	_expect(_spells.corrosion_effects.size() == 1, "终局不恢复腐蚀表现")
	_main.game_over = false
	_main.mode = mode
	_main._session = session

func _check_structures() -> void:
	_spells.clear()
	for target in _main.get_tree().get_nodes_in_group("combatants"):
		if not target is Tower: continue
		var before := float(target.hp)
		_spells.cast(0, CardDB.get_card("corrosion"), target.global_position, true)
		_advance(10)
		_expect(target.hp == before - (18.0 if target.team == 1 else 0.0), "腐蚀对敌方防御塔/水晶每跳18伤害，不伤友军")
		_advance(90)
		_expect(target.hp == before - (180.0 if target.team == 1 else 0.0), "腐蚀对敌方防御塔/水晶共180伤害，不伤友方建筑")
		target.hp = before
		_spells.clear()
	var center := Vector2(360, 640)
	var building := _spawn("tombstone", center)
	var before := building.hp
	_spells.cast(0, CardDB.get_card("corrosion"), center, true)
	_advance(100)
	_expect(building.hp == before - 600, "强化腐蚀对建筑卡完整造成600伤害")
	_expect(is_equal_approx(building.control.slow_multiplier, 1.0), "不向静止建筑施加无意义移速状态")
	building.position = center + Vector2(110.0 + building.body_radius + 1.0, 0)
	before = building.hp
	_spells.cast(0, CardDB.get_card("corrosion"), center)
	_advance(1)
	_expect(building.hp == before, "建筑身体边缘在圈外不受伤")
	building.position.x -= 1.0
	_advance(9)
	_expect(building.hp == before - 60, "建筑身体边缘接触110半径在下个伤害节点受伤")
	_spells.clear()

func _check_half_second_schedule() -> void:
	_spells.clear()
	var center := Vector2(360, 640)
	var target := _spawn("garen", center)
	var entrant := _spawn("garen", center + Vector2(300, 0))
	var before := target.hp
	_spells.cast(0, CardDB.get_card("corrosion"), center, true)
	_expect(target.hp == before and is_equal_approx(target.control.slow_multiplier, 0.8), "施法当刻立即减速但不造成伤害")
	for pulse in range(1, 11):
		_advance(9)
		_expect(target.hp == before - (pulse - 1) * 60, "第%d个半秒节点前不提前伤害" % pulse)
		_advance(1)
		_expect(target.hp == before - pulse * 60, "第%d个半秒节点恰好造成60伤害" % pulse)
	_expect(_spells.corrosion_zones.is_empty(), "第10次伤害结算后移除区域")
	_advance(20)
	_expect(target.hp == before - 600, "5秒后不出现第11次伤害")
	_spells.cast(0, CardDB.get_card("corrosion"), center, true)
	_advance(3)
	entrant.position = center
	_advance(1)
	_expect(entrant.hp == 5000 and is_equal_approx(entrant.control.slow_multiplier, 0.8), "节点之间入圈立即减速、不提前伤害")
	_advance(5)
	_expect(entrant.hp == 5000, "入圈不重设区域伤害节拍")
	_advance(1)
	_expect(entrant.hp == 4940, "入圈目标在区域统一0.5秒节点受伤")
	entrant.position += Vector2(300, 0)
	_advance(10)
	_expect(entrant.hp == 4940, "节点前离圈不再受伤")
	entrant.position = center
	_advance(10)
	_expect(entrant.hp == 4880, "再次入圈不补离圈时错过的伤害")
	_spells.clear()

func _check_backline_and_audio() -> void:
	_spells.clear()
	var targets: Array[Unit] = []
	for card in ["twisted_fate", "twitch", "tristana", "lulu", "aurelionsol"]:
		var target := _spawn(card, Vector2(360, 640))
		target.max_hp = float(CardDB.get_card(card).hp)
		target.hp = target.max_hp
		targets.append(target)
	_spells.cast(0, CardDB.get_card("corrosion"), Vector2(360, 640))
	_advance(100)
	for target in targets:
		_expect(not is_instance_valid(target) or target.hp <= 0, "腐蚀全程600伤害可击杀4费后排")
	var audio = _main._audio_manager
	audio.clear_zone_audio()
	_main._presentation_event_id += 1
	var id: int = _main._presentation_event_id
	audio.start_zone_audio(id, "corrosion", 0, "spell", Vector2.ZERO, 5.0)
	_expect(is_equal_approx(audio._zone_players[id].time_left, 6.547188), "原版W音轨完整6.547188秒")
	audio._tick_zone_audio(5.0)
	_expect(audio._zone_players.has(id), "区域5秒结束后仍保留原版尾音")
	audio._tick_zone_audio(1.55)
	_expect(not audio._zone_players.has(id), "原版尾音自然结束后清理")
	audio.start_zone_audio(id + 1, "corrosion", 0, "spell", Vector2.ZERO, 5.0)
	audio.clear_zone_audio()
	_expect(audio._zone_players.is_empty(), "清场立即取消原版尾音")
	var bad := CardDB.get_card("corrosion").duplicate(true)
	bad.audio.events["spell:zone_sustain"].natural_tail = "true"
	_expect(not CardDB.VALIDATOR.validate_all({"corrosion": bad}, false).is_empty(), "原音尾声配置必须是布尔值")
