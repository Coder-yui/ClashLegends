extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var center := Vector2(180, 800)
	var ally: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "garen", center, {"deploy_time_override": 0.0}))
	var enemy: Unit = main._spawn_unit(UnitSpawnRequest.new(1, "garen", center + Vector2(50, 0), {"deploy_time_override": 0.0}))
	var outside: Unit = main._spawn_unit(UnitSpawnRequest.new(1, "anivia", center + Vector2(200, 0), {"deploy_time_override": 0.0}))
	var spells: SpellSystem = main.get("_spell_system")
	ally.apply_active_buff(4.0, 2.0, 2.0, 2.0)
	spells.cast(0, CardDB.get_card("stasis"), center, true)
	_expect(not CombatInteraction.in_stasis(ally), "凝滞弹体抵达前不生效")
	var impact := int(spells.spell_flights[0].impact_tick)
	main.set("_sim_tick_id", impact - 1)
	spells.tick(FixedStepClock.STEP)
	_expect(not CombatInteraction.in_stasis(enemy), "凝滞不提前一Tick命中")
	main.set("_sim_tick_id", impact)
	spells.tick(FixedStepClock.STEP)
	_expect(ally.control.stasis_timer == 2.0 and enemy.control.stasis_timer == 3.0, "免费强化友方2秒敌方3秒")
	_expect(not CombatInteraction.in_stasis(outside), "凝滞不影响范围外单位")
	_expect(ally.action_permissions() == 0 and ally.active_speed_multiplier == 1.0, "凝滞禁用行动并抑制增益")
	var snapshot: Array = main.get("_snapshot_system")._unit_snapshot_payload(9001, ally)
	_expect(snapshot[NetworkSnapshotSystem.U_STASIS] == true and snapshot[NetworkSnapshotSystem.U_ACTION_PERMISSIONS] == 0, "快照同步凝滞与禁用权限")
	var hp := ally.hp
	_expect(not ally.take_damage(100, enemy) and ally.hp == hp, "凝滞免疫直接伤害")
	_expect(not ally.take_damage(100, enemy, 1, enemy.position, true), "凝滞免疫已附着伤害")
	ally.hp -= 100
	ally.heal(50)
	_expect(ally.hp == hp - 100, "凝滞拒绝自身治疗")
	ally.apply_stasis(8.0)
	_expect(ally.control.stasis_timer == 2.0, "凝滞拒绝重复刷新")
	var origin := ally.position
	ally.apply_knockback(origin + Vector2(1, 0), 100.0)
	main.get("_movement").tick(FixedStepClock.STEP)
	_expect(ally.position == origin and ally.knockback.remaining == 0.0, "凝滞保留占位且不可推动")
	var newcomer: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "garen", origin, {"deploy_time_override": 0.0}))
	_expect(newcomer.position.distance_to(origin) >= newcomer.body_radius + ally.body_radius, "新单位部署避开凝滞占位")
	for i in 39: ally._tick_active_statuses(FixedStepClock.STEP)
	_expect(CombatInteraction.in_stasis(ally), "2秒凝滞第39Tick仍有效")
	ally._tick_active_statuses(FixedStepClock.STEP)
	_expect(not CombatInteraction.in_stasis(ally) and ally.active_speed_multiplier == 2.0, "第40Tick解除并恢复尚未到期增益")
	for i in 60: enemy._tick_active_statuses(FixedStepClock.STEP)
	_expect(not CombatInteraction.in_stasis(enemy), "普通3秒凝滞第60Tick解除")
	spells.cast(0, CardDB.get_card("stasis"), center, false)
	main.set("_sim_tick_id", int(spells.spell_flights[0].impact_tick))
	spells.tick(FixedStepClock.STEP)
	_expect(ally.control.stasis_timer == 3.0, "未强化友方同样凝滞3秒")
	_expect(int(CardDB.get_card("stasis").cost) == 3 and int(CardDB.active_skills_for("stasis")[0].cost) == 0, "凝滞费用3金币强化0金币")
	spells.clear()
	for unit in [ally, enemy, outside, newcomer]:
		unit.remove_from_group("combatants")
		unit.queue_free()

	var saved_deck: Array = main._deck.duplicate()
	main._deck = ["stasis", "garen", "ashe", "teemo", "xin", "heal", "freeze", "zap"]
	_expect(main.card_cost_for_team(0, "stasis") == 3, "主动槽凝滞仍只收3金币")
	main._deck = saved_deck
	var saved_session: MatchSession = main._session
	main.mode = "client"
	main._session = MatchSession.new()
	main._session.opponent_id = 1
	main._session.session_id = "stasis-test"
	main._session.phase = MatchSession.Phase.RUNNING
	var saved_event_id: int = main._last_card_event_id
	var event_id: int = main._last_card_event_id + 10
	main._rpc_spell_flight("old-session", event_id, 1, "stasis", Vector2(360,1160), center, 110, 0, 10, 0)
	_expect(spells.stasis_effects.is_empty(), "凝滞拒绝旧会话表现")
	main._rpc_spell_flight("stasis-test", event_id, 1, "stasis", Vector2(360,1160), center, 110, 0, 10, 0)
	main._rpc_spell_flight("stasis-test", event_id, 1, "stasis", Vector2(360,1160), center, 110, 0, 10, 0)
	_expect(spells.stasis_effects.size() == 1 and spells.spell_flights.is_empty(), "凝滞副本去重且不创建权威施法")
	spells.tick_visuals(2.0)
	_expect(not spells.stasis_effects[0].impacted, "副本不按本地计时提前爆炸")
	main._rpc_spell_arrival("old-session", event_id + 1, 1, "stasis", center, 0)
	_expect(not spells.stasis_effects[0].impacted, "旧会话抵达无效")
	main._rpc_spell_arrival("stasis-test", event_id + 1, 1, "stasis", center, 0)
	spells.tick_visuals(0.2)
	var tail: float = spells.stasis_effects[0].timer
	main._rpc_spell_arrival("stasis-test", event_id + 1, 1, "stasis", center, 0)
	_expect(spells.stasis_effects[0].impacted and spells.stasis_effects[0].timer == tail, "抵达驱动爆炸且重复事件不重启尾段")
	main.game_over = true
	main._rpc_spell_flight("stasis-test", event_id + 2, 2, "stasis", Vector2.ZERO, center, 110, 0, 10, 0)
	_expect(spells.stasis_effects.size() == 1, "终局拒绝新在途表现")
	main.game_over = false
	main._last_card_event_id = saved_event_id
	main._session = saved_session
	main.mode = "local"
	spells.clear()
	_check_exceptions(main)
	_check_placement(main)
	_check_towers(main)
	_check_indicators_and_grit(main)
	_check_flights(main)

func _unit(main: Node2D, id: String, team: int, pos: Vector2) -> Unit:
	return main._spawn_unit(UnitSpawnRequest.new(team, id, pos, {"deploy_time_override": 0.0}))

func _retire(units: Array) -> void:
	for unit in units:
		unit.remove_from_group("combatants")
		unit.remove_from_group("combat_structures")
		unit.queue_free()

func _check_exceptions(main: Node2D) -> void:
	var herald := _unit(main, "rift_herald", 0, Vector2(180,800))
	herald.structure_rush.phase = StructureRushState.Phase.DASHING
	for source_team in [0, 1]:
		herald.apply_stasis(3, &"probe", CombatInteraction.effect_context(null, source_team))
		_expect(not CombatInteraction.in_stasis(herald) and herald.structure_rush.phase == StructureRushState.Phase.DASHING, "先锋冲撞免疫双方凝滞且不中止轨迹")
	herald.structure_rush.phase = StructureRushState.Phase.RECOVERY
	herald.apply_stasis(3, &"probe", CombatInteraction.effect_context(null, 0))
	_expect(CombatInteraction.in_stasis(herald), "冲撞免疫不扩展到恢复阶段")
	var guard := _unit(main, "shurima_guard", 0, Vector2(460,800))
	guard.hp = 100
	guard.add_restoration_shield(180, 2)
	guard.apply_stasis(3)
	guard.heal(100)
	_expect(guard.hp == 100, "恢复盾特例不开放普通治疗")
	for tick in 40: guard._tick_active_statuses(0.05)
	_expect(guard.hp == guard.max_hp and CombatInteraction.in_stasis(guard) and guard.shield_hp == 0, "已有黄沙庇护凝滞中到期回满并移除盾层")
	guard.hp = 100
	guard._tick_active_statuses(0.05)
	_expect(guard.hp == 100, "恢复盾到期收益不重复")
	var sion := _unit(main, "sion", 0, Vector2(180,960))
	var target := _unit(main, "garen", 1, Vector2(260,960))
	var skill: Dictionary = CardDB.active_skills_for("sion")[0]
	sion.shields.add(400, 2, false, false, &"probe", skill)
	sion.apply_stasis(3)
	var hp := target.hp
	for tick in 40: sion._tick_active_statuses(0.05)
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(target.hp == hp - 240 and CombatInteraction.in_stasis(sion), "既有赛恩护盾凝滞中仍按时爆炸")
	var grown := _unit(main, "garen", 0, Vector2(520,1000))
	grown.apply_permanent_growth(0.3, 1.3)
	grown.team_attack_boost_multiplier = 1.2
	var maximum := grown.max_hp
	var body := grown.body_radius
	grown.apply_stasis(3)
	_expect(grown.max_hp == maximum and grown.body_radius == body and grown.active_damage_multiplier == 1.2, "永久成长与锻造增伤在凝滞中保留")
	var batch: CombatResolver = main.combat_service()
	grown.control.hard.clear_family(&"stasis")
	batch.begin_batch(1, "chosen_order")
	grown.apply_stasis(3)
	grown.apply_active_buff(4, 2, 2, 2)
	batch.commit_batch()
	_expect(grown.buffs.remaining(&"buff") == 0, "同批先凝滞则后提交普通Buff被拒绝")
	grown.control.hard.clear_family(&"stasis")
	batch.begin_batch(2, "chosen_order")
	grown.apply_active_buff(4, 2, 2, 2)
	grown.apply_stasis(3)
	batch.commit_batch()
	_expect(grown.buffs.remaining(&"buff") == 4 and grown.active_speed_multiplier == 1, "同批先Buff则实例保留且被凝滞抑制")
	_retire([herald, guard, sion, target, grown])

func _check_placement(main: Node2D) -> void:
	var positions: Array[Vector2] = []
	for team in [0, 1]:
		var pos := Vector2(180,700) if team == 0 else Vector2(540,580)
		var blocker := _unit(main, "garen", team, pos)
		blocker.apply_stasis(3)
		var before := blocker.position
		var spawned: Array = main._spawn_card_units(team, "garen", pos, 0.0)
		_expect(spawned.size() == 1, "凝滞桥边部署找到合法落点")
		if not spawned.is_empty():
			var unit: Unit = spawned[0]
			positions.append(unit.position)
			_expect(main.is_card_deploy_position_valid(team, "garen", unit.position) and main.is_ground_position_walkable(unit.position, unit.body_radius), "避让仍在玩家部署范围和完整地形内")
			_expect(unit.position.distance_to(blocker.position) >= unit.body_radius + blocker.body_radius - 0.001 and blocker.position == before, "新下单位避让且凝滞占位不动")
		_retire(spawned + [blocker])
	_expect(positions.size() == 2 and positions[0].distance_to(Vector2(720,1280) - positions[1]) < 0.01, "镜像阵营落点对称：%s" % [positions])
	var frozen := _unit(main, "garen", 0, Vector2(180,800))
	frozen.freeze(3)
	var normal: Array = main._spawn_card_units(0, "garen", frozen.position, 0.0)
	_expect(normal.size() == 1 and normal[0].position == frozen.position, "冰冻不触发特殊出生避让，保留自然碰撞")
	_retire(normal + [frozen])
	var anchor := _unit(main, "garen", 0, Vector2(500,800))
	anchor.apply_stasis(3)
	var before := anchor.position
	var building: Array = main._spawn_card_units(0, "tombstone", anchor.position, 0.0)
	_expect(building.size() == 1 and anchor.position == before and building[0].position.distance_to(before) >= building[0].body_radius + anchor.body_radius, "建筑先选合法避让点，不能先推动凝滞单位")
	_retire(building + [anchor])
	anchor = _unit(main, "garen", 0, Vector2(180,400))
	anchor.apply_stasis(3)
	var summon: Unit = main.spawn_summoned(0, "imp", anchor.position, 0.0)
	_expect(summon.position.y < 640 and summon.position.distance_to(anchor.position) >= summon.body_radius + anchor.body_radius - 0.001, "召唤物按全场几何避让，不被送回己方部署区")
	_retire([anchor, summon])
	anchor = _unit(main, "garen", 0, Vector2(180,800))
	anchor.body_radius = 2000
	anchor.apply_stasis(3)
	var waiting: Array = main._spawn_card_units(0, "garen", Vector2(180,800), 0.0)
	_expect(waiting.is_empty(), "无合法落点不生成越界或重叠玩家单位")
	_expect(main._commands.inspect_deployments().size() == 1, "无落点沿用已付费等待队列")
	_retire([anchor])
	main._tick_pending_card_pre_deployments(0.05)
	var resumed: Array = main.get_tree().get_nodes_in_group("combatants").filter(func(c): return c is Unit)
	_expect(resumed.size() == 1 and main._commands.inspect_deployments().is_empty(), "空间恢复后只生成一次，不重复付费或留队列")
	_retire(resumed)

func _check_flights(main: Node2D) -> void:
	var spells: SpellSystem = main._spell_system
	spells.clear()
	spells.cast(0, CardDB.get_card("stasis"), Vector2(360,1000))
	var impact := int(spells.spell_flights[0].impact_tick)
	var before_tick: int = main._sim_tick_id
	main._process(0.8)
	_expect(main._sim_tick_id - before_tick <= 4, "掉帧仍保留固定步赶步预算")
	_expect(not spells.stasis_effects[0].impacted and not spells.spell_flights.is_empty(), "渲染掉帧不能使权威在途法术提前落地")
	main._sim_tick_id = impact
	spells.tick(0.05)
	_expect(spells.stasis_effects[0].impacted and spells.spell_flights.is_empty(), "权威抵达同时切换落地表现")
	spells.clear()
	var slow := CardDB.get_card("freeze").duplicate(true)
	slow.flight_speed = 450.0
	slow.flight_min_duration = 0.0
	var target := _unit(main, "garen", 1, Vector2(180,800))
	spells.cast(0, slow, target.position)
	var expected := ceili(Vector2(360,1160).distance_to(target.position) / 450.0 / 0.05)
	_expect(int(spells.spell_flights[0].impact_tick) - main._sim_tick_id == expected and not target.is_frozen(), "另一法术按不同配置速度复用在途调度")
	main._sim_tick_id = int(spells.spell_flights[0].impact_tick)
	spells.tick(0.05)
	_expect(target.is_frozen(), "通用在途法术抵达后才执行自身效果")
	_retire([target])
	spells.clear()
	for value in [0.0, -1.0, INF]:
		var bad := CardDB.get_card("stasis").duplicate(true)
		bad.flight_speed = value
		_expect(not CardDB.VALIDATOR.validate_all({"stasis": bad}, false).is_empty(), "拒绝无效飞行速度")
	_check_card_timing(main)

func _check_card_timing(main: Node2D) -> void:
	var deck: Array = main._deck.duplicate()
	var cycles: Dictionary = main._authoritative_card_cycles.duplicate()
	main._deck = ["stasis", "garen", "ashe", "teemo", "xin", "heal", "freeze", "zap"]
	for team in [0, 1]:
		main._authoritative_card_cycles[team] = CardCycle.new(main._deck, false)
		var pos := Vector2(180,820) if team == 0 else Vector2(540,460)
		var unit := _unit(main, "garen", team, pos)
		unit.move_speed = 0
		var start: int = main._sim_tick_id
		_expect(main.play_card(team, "stasis", pos), "双方通过真实play_card提交凝滞")
		for tick in 9: main._sim_step(0.05)
		_expect(main._spell_system.spell_flights.is_empty() and not unit.is_frozen(), "公用0.5秒延迟未结束时不发射不生效")
		main._sim_step(0.05)
		var impact: int = main._spell_system.spell_flights[0].impact_tick
		_expect(main._sim_tick_id == start + 10 and impact == start + 19, "双方镜像距离均在10Tick发射19Tick抵达")
		for tick in 8: main._sim_step(0.05)
		_expect(not unit.is_frozen(), "抵达前一Tick仍不凝滞")
		main._sim_step(0.05)
		_expect(CombatInteraction.in_stasis(unit), "抵达边界才凝滞")
		_retire([unit])
		main._spell_system.clear()
	main._deck = deck
	main._authoritative_card_cycles = cycles
	main._spell_system.cast(0, CardDB.get_card("stasis"), Vector2(180,800))
	var tick: int = main._sim_tick_id
	main._end_game(0, "time")
	for step in 30: main._sim_step(0.05)
	_expect(main._sim_tick_id == tick and main._spell_system.spell_flights.is_empty() and main._spell_system.stasis_effects.is_empty(), "终局清理在途/表现且不再抵达")

func _check_towers(main: Node2D) -> void:
	var spells: SpellSystem = main._spell_system
	for source_team in [0, 1]:
		var stats := CardDB.get_card("stasis").duplicate(true)
		stats.radius = 5000.0
		spells._apply_stasis(source_team, stats, Vector2(360,640), true, 0)
		for tower: Tower in main._towers:
			if tower.is_king:
				_expect(not CombatInteraction.in_stasis(tower), "双方水晶均免疫凝滞")
			else:
				_expect(tower.control.stasis_timer == (2.0 if tower.team == source_team else 3.0), "双方防御塔按友方强化2秒/敌方3秒凝滞")
		for tower: Tower in main._towers: tower.control.hard.clear_family(&"stasis")
	for team in [0, 1]:
		var tower: Tower = main._towers[0 if team == 0 else 2]
		var enemy := _unit(main, "garen", 1-team, tower.position + Vector2(90,0))
		tower._target = enemy
		tower._lock_windup = 0.15
		tower._cooldown = 0.4
		tower.add_shield(100, 0.5)
		tower.battle_context.launch_attack(enemy, tower, 10, 400, 0, 0, Color.WHITE)
		_expect(main._projectile_system.projectiles.values().any(func(p): return p.get("target") == tower), "已发弹体先锁定防御塔")
		tower.apply_stasis(2)
		_expect(tower._target == null and tower._lock_windup == 0 and tower._cooldown == 0, "塔凝滞取消旧目标/前摇/冷却，解除重新起手")
		_expect(not main._projectile_system.projectiles.values().any(func(p): return p.get("target") == tower), "塔凝滞立即断开已有追踪弹体")
		var herald := _unit(main, "rift_herald", 1-team, tower.position + Vector2(180,0))
		herald.structure_rush.target = tower
		herald.structure_rush.phase = StructureRushState.Phase.PREPARING
		herald.structure_rush.tick(herald, 0.05)
		_expect(herald.structure_rush.phase == StructureRushState.Phase.READY, "防御塔凝滞使先锋旧冲撞目标失效，取消准备")
		herald.structure_rush.target = tower
		herald.structure_rush.phase = StructureRushState.Phase.DASHING
		herald.structure_rush.tick(herald, 0.05)
		_expect(herald.structure_rush.phase == StructureRushState.Phase.RECOVERY, "防御塔凝滞使已开始冲撞结束且不命中")
		_retire([herald])
		var hp := tower.hp
		_expect(not tower.take_damage(100) and not tower.take_damage(100, null, -1, Vector2.ZERO, true) and tower.hp == hp and tower.shield_hp == 100, "凝滞塔拒绝直接/附着伤害且不消耗旧护盾")
		_expect(not CombatInteraction.can_acquire(tower, 1-team) and not CombatInteraction.allows(tower, enemy), "凝滞塔不被索敌和效果命中")
		tower.freeze(9)
		tower.stun(9)
		tower.add_shield(200,9)
		tower.apply_stasis(9)
		_expect(tower.frozen_timer == 0 and tower.control.stun_timer == 0 and tower.shield_hp == 100 and tower.control.stasis_timer == 2, "凝滞塔拒绝新控制/护盾与重复凝滞")
		for i in 39: tower.sim_tick(0.05)
		_expect(CombatInteraction.in_stasis(tower) and tower._target == null and tower.shield_hp == 0, "防御塔第39Tick仍停手，已有盾按时到期")
		tower.sim_tick(0.05)
		_expect(not CombatInteraction.in_stasis(tower) and tower._target == enemy and tower._lock_windup > 0, "第40Tick解除后重新选敌并开始完整前摇")
		for i in 5: tower.sim_tick(0.05)
		_expect(tower._cooldown > 0, "防御塔解除后能够重新发射")
		main._projectile_system.projectiles.clear()
		tower._target = null
		tower._lock_windup = 0
		tower._cooldown = 0
		_retire([enemy])
	var building := _unit(main, "tombstone", 0, Vector2(180,800))
	building.apply_stasis(3)
	_expect(CombatInteraction.in_stasis(building) and not building.take_damage(100), "建筑卡保留凝滞与无敌语义")
	_retire([building])

func _check_indicators_and_grit(main: Node2D) -> void:
	var retired := Node2D.new()
	retired.free()
	_expect(not PresentationConfig.status_indicators_visible(retired), "模型晚于来源释放时安全隐藏标识，不访问失效对象")
	var sett := _unit(main, "sett", 0, Vector2(300,900))
	sett.configure_carried_active_skill(CardDB.get_card("sett").active_skills[0])
	sett.skill_resource_value = 200
	sett.hp = 500
	sett.team_attack_boost_multiplier = 1.2
	sett.mark_skill_resource_combat_activity()
	sett._attacking = true
	_expect(PresentationConfig.status_indicators_visible(sett), "普通状态显示实体附属标识")
	sett.apply_stasis(3)
	_expect(not sett._attacking and sett.active_skill_cast_timer == 0, "凝滞取消瑟提攻击和施法，实际处于非攻击状态")
	_expect(not PresentationConfig.status_indicators_visible(sett) and sett.skill_resource_value == 200 and sett.team_attack_boost_multiplier == 1.2, "隐藏血量/资源/增幅标识不清空真实数值")
	for i in 20:
		sett._tick_active_statuses(0.05)
		sett.prepare_action_clocks(0.05)
	_expect(is_equal_approx(sett.skill_resource_value, 200), "凝滞中豪意仍遵守原有1秒衰减等待")
	for i in 10:
		sett._tick_active_statuses(0.05)
		sett.prepare_action_clocks(0.05)
	_expect(is_equal_approx(sett.skill_resource_value, 150), "非攻击凝滞状态豪意按每秒100正常衰减")
	sett.control.hard.clear_family(&"stasis")
	_expect(PresentationConfig.status_indicators_visible(sett) and is_equal_approx(sett.skill_resource_value, 150) and sett.hp == 500, "解除标识按实时150豪意和500生命恢复，不回滚旧值")
	var original_mode: String = main.mode
	main.mode = "client"
	sett.control.hard.apply(&"stasis", &"replica", 1, {})
	_expect(not PresentationConfig.status_indicators_visible(sett), "客户端凝滞标志同样隐藏附属标识")
	sett.control.hard.clear_family(&"stasis")
	_expect(PresentationConfig.status_indicators_visible(sett), "客户端解除按当前状态恢复附属标识")
	main.mode = original_mode
	_retire([sett])
	for card in ["tombstone", "garen"]:
		var unit := _unit(main, card, 0, Vector2(300,900))
		unit.apply_stasis(3)
		_expect(not PresentationConfig.status_indicators_visible(unit), "建筑与普通单位统一使用凝滞标识门禁")
		_retire([unit])
	var tower: Tower = main._towers[0]
	tower.apply_stasis(3)
	_expect(not PresentationConfig.status_indicators_visible(tower), "防御塔金身隐藏血条等标识")
	tower.control.hard.clear_family(&"stasis")
	_expect(PresentationConfig.status_indicators_visible(tower), "防御塔解除恢复实时血条")
