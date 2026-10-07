extends "res://tests/suites/battle_suite.gd"

var _owned: Array[Unit] = []
var _spells: SpellSystem

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_spells = main.get("_spell_system")
	_check_zap()
	_check_selection()
	_check_skip_and_new_target()
	_check_tower_and_clear()
	_check_schema()
	_check_cost_and_replica()
	_clear()

func _spawn(card: String, pos: Vector2, team: int = 1) -> Unit:
	var unit: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, card, pos, {"deploy_time_override": 0.0}))
	_owned.append(unit)
	return unit

func _advance(count: int) -> void:
	for index in count:
		_main.set("_sim_tick_id", _main.get_authoritative_server_tick() + 1)
		var batch: CombatResolver = _main.combat_service()
		batch.begin_batch(_main.get_authoritative_server_tick(), "spell_test")
		_spells.tick(FixedStepClock.STEP)
		batch.commit_batch()

func _cast(card: String, pos: Vector2, enhanced: bool = false) -> void:
	var batch: CombatResolver = _main.combat_service()
	batch.begin_batch(_main.get_authoritative_server_tick(), "spell_test")
	_spells.cast(0, CardDB.get_card(card), pos, enhanced)
	batch.commit_batch()

func _check_zap() -> void:
	var center := Vector2(360, 640)
	var ground := _spawn("garen", center)
	var air := _spawn("anivia", center + Vector2(40, 0))
	var building := _spawn("tombstone", center + Vector2(-40, 0))
	var ally := _spawn("garen", center, 0)
	var outside := _spawn("garen", center + Vector2(180, 0))
	var initial := [ground.hp, air.hp, building.hp, ally.hp, outside.hp]
	_cast("zap", center, true)
	_expect(_spells.lightning_areas.size() == 1 and is_equal_approx(float(_spells.lightning_areas[0].duration), 1.2), "多重电击范围圈持续1.2秒")
	for i in 3:
		var unit: Unit = [ground, air, building][i]
		_expect(unit.hp == initial[i] - 55, "电击对地面/空军/建筑首击55")
		_expect(is_equal_approx(unit.control.stun_timer, 0.2), "电击施加0.2秒眩晕")
	_expect(ally.hp == initial[3] and outside.hp == initial[4], "电击不伤友军和圈外目标")
	_advance(19)
	_expect(ground.hp == initial[0] - 55, "追加电击在第19Tick尚未结算")
	outside.position = center
	ground.position = center + Vector2(200, 0)
	_advance(1)
	_expect(ground.hp == initial[0] - 55 and outside.hp == initial[4] - 55, "第20Tick按当前范围重新查询进出目标")
	_expect(air.hp == initial[1] - 110 and building.hp == initial[2] - 110, "多重电击第二次保持55伤害")
	_expect(_spells.lightning_casts.is_empty(), "两次电击后排程释放")
	_clear()

func _check_selection() -> void:
	var center := Vector2(360, 640)
	var a := _spawn("garen", center)
	var b := _spawn("garen", center + Vector2(40, 0))
	a.max_hp = 3000; a.hp = 2000
	b.max_hp = 2000; b.hp = 900
	_cast("lightning", center, true)
	_expect(_spells.lightning_areas.size() == 1 and _spells.lightning_areas[0].pos == center and is_equal_approx(float(_spells.lightning_areas[0].duration), 2.2), "大型电击范围圈固定中心并持续2.2秒")
	_expect(a.hp == 1540 and b.hp == 900, "大型电击只命中当前血量最高者")
	_advance(19)
	_expect(b.hp == 900, "大型电击第二次不提前")
	_advance(1)
	_expect(a.hp == 1540 and b.hp == 348, "第二次重新选血量最高者并造成552伤害")
	var c := _spawn("garen", center + Vector2(-40, 0))
	c.hp = 800
	a.hp = 2500
	_advance(20)
	_expect(a.hp == 2500 and b.hp == 348 and c.hp == 138, "第三次排除前两次目标，对新目标按144%造成662伤害")
	_expect(_spells.lightning_casts.is_empty(), "三击结束清理权威排程")
	_clear()
	a = _spawn("garen", center); b = _spawn("garen", center)
	a.hp = 1000; b.hp = 1000
	_cast("lightning", center)
	_expect(a.hp == 540 and b.hp == 1000, "同血量按出生身份稳定选取")
	_clear()
	_cast("lightning", center)
	_expect(_spells.lightning_effects.is_empty(), "空范围大型电击没有伪造命中表现")
	a = _spawn("garen", center); a.hp = 1000
	_advance(20)
	_expect(a.hp == 540, "首击无目标仍保留后续独立电击")
	_clear()

func _check_tower_and_clear() -> void:
	for target in _main.get_tree().get_nodes_in_group("combatants"):
		if not target is Tower or target.team != 1: continue
		var before := float(target.hp)
		_cast("zap", target.global_position)
		_expect(target.hp == before - 17, "塔与水晶电击伤害保留30%，最终四舍五入")
		target.hp = before
		_cast("lightning", target.global_position, true)
		_expect(target.hp == before - 138, "塔与水晶大型电击首击138")
		_advance(40)
		_expect(target.hp == before - 138, "同一座塔/水晶每次施法最多承受一次电击")
		target.hp = before
		_spells.clear()
	_cast("zap", Vector2(360, 640), true)
	_spells.tick_visuals(5.0)
	_expect(_spells.lightning_casts.size() == 1, "渲染时间不推进权威追加电击")
	_spells.clear()
	_advance(40)
	_expect(_spells.lightning_casts.is_empty() and _spells.lightning_effects.is_empty() and _spells.lightning_areas.is_empty(), "清场取消未来落雷与表现")

func _check_schema() -> void:
	for field in ["strike_count", "strike_interval", "stun_duration", "tower_damage_multiplier"]:
		var stats := CardDB.get_card("zap").duplicate(true)
		stats[field] = "bad"
		_expect(not CardDB.VALIDATOR.validate_all({"zap": stats}, false).is_empty(), "电击字段拒绝错误类型: " + field)
	var invalid := CardDB.get_card("lightning").duplicate(true)
	invalid.active_skills[0].strike_damage_multiplier = 0.5
	_expect(not CardDB.VALIDATOR.validate_all({"lightning": invalid}, false).is_empty(), "递增倍率拒绝小于1")

func _clear() -> void:
	_spells.clear()
	for unit in _owned:
		if is_instance_valid(unit): unit.free()
	_owned.clear()


func _check_cost_and_replica() -> void:
	var saved_deck: Array = _main._deck.duplicate()
	_main._deck = ["zap", "lightning", "garen", "ashe", "teemo", "xin", "heal", "freeze"]
	_expect(_main.card_cost_for_team(0, "zap") == 3 and _main.card_cost_for_team(0, "lightning") == 7, "主动槽两张法术各增加1金币")
	_main._deck = ["garen", "ashe", "zap", "lightning", "teemo", "xin", "heal", "freeze"]
	_expect(_main.card_cost_for_team(0, "zap") == 2 and _main.card_cost_for_team(0, "lightning") == 6, "普通槽法术保持2/6金币")
	_main._deck = saved_deck
	_spells.clear()
	var saved_mode: String = _main.mode
	var saved_mode_team: int = _main.local_team
	var saved_session: MatchSession = _main._session
	_main.mode = "client"
	_main.local_team = 1
	_main._session = MatchSession.new()
	_main._session.opponent_id = 1
	_main._session.session_id = "lightning-test"
	_main._session.phase = MatchSession.Phase.RUNNING
	var event_id: int = _main._last_card_event_id + 100
	_main._rpc_lightning_fx("old-session", event_id, "zap", Vector2(360, 640), 90, 0)
	_expect(_spells.lightning_effects.is_empty(), "旧会话电击表现拒绝")
	_main._rpc_lightning_fx("lightning-test", event_id, "zap", Vector2(360, 640), 90, 0)
	_main._rpc_lightning_fx("lightning-test", event_id, "zap", Vector2(360, 640), 90, 0)
	_expect(_spells.lightning_effects.size() == 1 and _spells.lightning_casts.is_empty(), "客户端落雷去重且不创建权威排程")
	_main._rpc_lightning_fx("lightning-test", event_id - 1, "lightning", Vector2(360, 640), 120, 1)
	_expect(_spells.lightning_effects.size() == 1, "晚到旧表现不会重新播放")
	_main.game_over = true
	_main._rpc_lightning_fx("lightning-test", event_id + 1, "lightning", Vector2(360, 640), 120, 1)
	_expect(_spells.lightning_effects.size() == 1, "终局拒绝电击表现")
	_main.game_over = false
	_main.mode = saved_mode
	_main.local_team = saved_mode_team
	_main._session = saved_session


func _check_skip_and_new_target() -> void:
	var center := Vector2(360, 640)
	var first := _spawn("garen", center)
	first.hp = 100
	_cast("lightning", center)
	_expect(first.hp <= 0, "首段可以击杀唯一目标")
	_advance(20)
	_expect(_spells.lightning_casts.size() == 1 and int(_spells.lightning_casts[0].index) == 2 and _spells.lightning_effects.size() == 1, "1秒无目标跳过且保留2秒电击，不播放假命中")
	var arrival := _spawn("garen", center)
	arrival.hp = 1000
	_advance(19)
	_expect(arrival.hp == 1000, "新进入目标在2秒前不提前受击")
	_advance(1)
	_expect(arrival.hp == 540 and _spells.lightning_casts.is_empty(), "2秒正常电击新进入目标并完成施法")
	_clear()
	first = _spawn("garen", center)
	first.hp = 100
	_cast("lightning", center, true)
	_advance(20)
	arrival = _spawn("garen", center)
	arrival.hp = 1000
	_advance(20)
	_expect(arrival.hp == 338, "强化中间段跳过后第三段仍按144%造成662伤害")
	_clear()
	var survivor := _spawn("garen", center)
	survivor.max_hp = 3000; survivor.hp = 3000
	_cast("lightning", center)
	_advance(40)
	_expect(survivor.hp == 2540, "只有一个存活目标时不重复电击")
	_cast("lightning", center)
	_expect(survivor.hp == 2080, "不同施法的已命中集合互不污染")
	_clear()
