extends "res://tests/suites/battle_suite.gd"
func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_growth()
	_terrain()
	_dash()
	_control_and_growth_deployment()
	_dash_edges()
	_queued_form()
	_schema()
	var invalid := CardDB.all().duplicate(true)
	invalid.kayn_slayer.heal_on_hit_name = 12
	_expect(not CardDB.VALIDATOR.validate_all(invalid,false).is_empty(), "命中回复显示名拒绝非文本类型")

func _make(id: String, team: int, point: Vector2) -> Unit:
	return _main._spawn_unit(team, id, point, 0.0)

func _growth() -> void:
	_main._card_growth.clear()
	var a := _make("kayn", 0, Vector2(300,900))
	var b := _make("kayn", 0, Vector2(350,900))
	var ranged := _make("ashe", 1, Vector2(400,900))
	ranged.hp = 10000
	for hit in 3: _main._combat.resolve_attack_hit(0,a.position,ranged,1,0,0,a,a.position,0)
	_expect(_main._card_growth.resolved_id(0,"kayn") == "kayn", "远程3次尚未解锁")
	_main._combat.begin_batch(0,"growth")
	_main._combat.resolve_attack_hit(0,b.position,ranged,1,0,0,b,b.position,0)
	_main._combat.commit_batch()
	_expect(_main._card_growth.resolved_id(0,"kayn") == "kayn_assassin", "同队第二凯隐共享第四次命中解锁蓝凯")
	_expect(a.card_id == "kayn" and a.damage == 80, "场上旧凯隐保持普通")
	_expect(_main._card_growth.resolved_id(1,"kayn") == "kayn", "双方成长隔离")
	for hit in 6: _main._card_growth.record_hit(a,b) # 队友不计
	_expect(_main._card_growth.resolved_id(0,"kayn") == "kayn_assassin", "解锁不反转")
	a.free();b.free();ranged.free()
	_main._card_growth.clear()

func _terrain() -> void:
	var a := _make("kayn",0,Vector2(360,850))
	a.hp = 300
	a.position = Vector2(360,ArenaRules.RIVER_Y)
	a.terrain_traversal.update(a)
	_expect(a.hp == 370 and a.terrain_traversal.inside, "首次入河回复70")
	for tick in 5: a.terrain_traversal.update(a)
	_expect(a.hp == 370, "留在地形不重复回血")
	_expect(not a.terrain_traversal.leave_for_attack(a), "地形中攻击先离开且不当步出手")
	_expect(not a.terrain_traversal.inside and a.is_walkable_at(a.position), "出地形落点完整合法")
	a.position = Vector2(360,ArenaRules.RIVER_Y)
	a.terrain_traversal.update(a)
	_expect(a.hp == 440, "完整离开再入河可再次回复")
	var blocker := _make("garen",1,a.position)
	var point: Vector2 = UnitLandingQuery.find_position(a,a.position,true)
	_expect(point.distance_to(blocker.position) >= a.body_radius+blocker.body_radius-0.001, "Q落点允许河道但避开单位")
	a.free();blocker.free()

func _dash() -> void:
	var a := _make("kayn_slayer",0,Vector2(360,950))
	var enemy := _make("garen",1,Vector2(360,865))
	enemy.max_hp = 1000;enemy.hp = 1000
	a.hp = 400
	a.active_skill_cast_facing = Vector2.UP
	var skill: Dictionary = CardDB.active_skills_for("kayn_slayer")[0]
	var dash := DashStrikeState.new(a,skill)
	for tick in 10:
		_main._combat.begin_batch(tick,"dash_test")
		dash.tick(0.05)
		_main._combat.commit_batch()
	_expect(enemy.hp == 760, "突进与旋转各90+最大生命3%，沿途不重复")
	_expect(a.hp == 500, "红凯两段各回复50")
	_expect(not a.skill_dash_active and a.position.distance_to(enemy.position) >= a.body_radius+enemy.body_radius-0.001, "末端解除穿单位且无重叠")
	a.free();enemy.free()

func _control_and_growth_deployment() -> void:
	_main._card_growth.clear()
	var source := _make("kayn",0,Vector2(360,950))
	var target := _make("garen",1,Vector2(360,850))
	for hit in 6: _main._card_growth.record_hit(source,target)
	_expect(_main._card_growth.resolved_id(0,"kayn") == "kayn_slayer", "六次近战解锁红凯")
	var old_deck: Array = _main._deck.duplicate()
	_main._deck[0] = "kayn"
	_expect(_main.play_card(0,"kayn",Vector2(250,950),{"immediate":true,"validate_position":false}), "正式出牌入口接受已成长来源卡")
	var grown: Unit = _main._latest_unit_for_card("kayn",0)
	_expect(grown != null and grown.card_id == "kayn_slayer" and grown.max_hp == 950 and grown.active_skill_card_id == "kayn", "后续部署红凯且保留原牌主动归属")
	if grown != null: grown.free()
	_main._card_growth.clear()
	for hit in 4: _main._card_growth.record_hit(source, _make("ashe",1,Vector2(650,1100)))
	_main.play_card(0,"kayn",Vector2(250,950),{"immediate":true,"validate_position":false})
	grown = _main._latest_unit_for_card("kayn",0)
	if grown != null:
		grown.active_ability_id = 99030
		grown.active_ability_slot = 0
		_main._register_active_skill(grown,"kayn",0)
	_expect(grown != null and grown.card_id == "kayn_assassin" and _main._active_skills.cost(grown.active_ability_id) == 1, "蓝凯从普通来源卡部署后主动实际费用为1")
	if grown != null: grown.free()
	_main._deck = old_deck
	var skill: Dictionary = CardDB.active_skills_for("kayn")[0]
	source.active_skill_cast_facing = Vector2.UP
	var dash := DashStrikeState.new(source,skill)
	source.freeze(1.0)
	var before := source.position
	_expect(not dash.tick(0.05) and not source.skill_dash_active and source.position == before, "冰冻取消突进和后段且解除穿单位")
	source.control.tick_hard_controls(2.0)
	source.active_skill_cast_serial += 1
	dash = DashStrikeState.new(source,skill)
	source.stun(1.0)
	dash.tick(0.05)
	_expect(source.position != before and source.skill_dash_active, "眩晕不取消已开始Q")
	source.take_damage(30)
	_expect(source.hp == 620, "突进仍可被伤害命中")
	source.free();target.free()
	for unit in _main.get_tree().get_nodes_in_group("combatants"):
		if unit is Unit and unit.card_id == "ashe" and unit.position == Vector2(650,1100): unit.free()
	_main._card_growth.clear()

func _schema() -> void:
	for field in ["growth_ranged_hits","growth_melee_hits","terrain_entry_heal"]:
		var cards := CardDB.all().duplicate(true)
		cards.kayn[field] = -1
		_expect(not CardDB.VALIDATOR.validate_all(cards,false).is_empty(), "非法新增字段被拒绝："+field)
	var cards := CardDB.all().duplicate(true)
	cards.kayn.terrain_traversal = "yes"
	_expect(not CardDB.VALIDATOR.validate_all(cards,false).is_empty(), "穿地形布尔字段类型校验")

func _queued_form() -> void:
	_main._card_growth.clear()
	_main._commands.clear()
	_main._deck = ["kayn","garen","ashe","teemo","xin","freeze","heal","pix"]
	preload("res://tests/suites/network_fixture.gd").fixed_cycle(_main,0,_main._deck)
	_main._elixir.elixir = 10.0
	_expect(_main.play_card(0,"kayn",Vector2(300,900),{"elixir":_main._elixir}), "未成长时成功付款入队")
	var source := _make("kayn",0,Vector2(600,1100))
	var target := _make("ashe",1,Vector2(650,1100))
	for hit in 4: _main._card_growth.record_hit(source,target)
	var command: Dictionary = _main._commands.inspect_cards()[0]
	_main._sim_tick_id = int(command.execute_tick)
	_main._tick_pending_card_deployments(0.05)
	var result: Unit = _main._latest_unit_for_card("kayn",0)
	_expect(result.card_id == "kayn", "等待期间解锁不追溯改变已接受的普通部署")
	_expect(_main._elixir.elixir == 6.0 and "kayn" in _main.get_authoritative_queue(0), "成长不额外扣费且来源牌正常进入递补")
	result.free();source.free();target.free()
	_main._card_growth.clear()

func _dash_edges() -> void:
	var a := _make("kayn_slayer",0,Vector2(360,1000))
	a.hp = 300
	a.active_skill_cast_facing = Vector2.UP
	var skill: Dictionary = CardDB.active_skills_for("kayn_slayer")[0]
	var dash := DashStrikeState.new(a,skill)
	for tick in 10: dash.tick(0.05)
	_expect(a.hp == 300, "红凯空Q不回血")
	a.position = Vector2(360,1000)
	var targets: Array[Unit] = []
	for x in [340,360,380]: targets.append(_make("garen",1,Vector2(x,920)))
	dash = DashStrikeState.new(a,skill)
	for tick in 10:
		_main._combat.begin_batch(tick,"multi_dash")
		dash.tick(0.05)
		_main._combat.commit_batch()
	_expect(a.hp == 400, "多目标命中仍只按两段各回复50")
	for target in targets: target.free()
	a.position = Vector2(360,1000)
	dash = DashStrikeState.new(a,skill)
	dash.tick(0.05)
	var position_before := a.position
	a.apply_knockback(a.position+Vector2.RIGHT*10.0,40.0)
	dash.tick(0.05)
	_expect(not a.skill_dash_active and a.position == position_before, "击退接管后停止剩余自主突进")
	for tick in 8: dash.tick(0.05)
	_expect(dash.stopped and not dash.cancelled, "击退保留旋转阶段，区别于冰冻取消")
	a.free()
