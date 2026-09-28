extends "res://tests/suites/battle_suite.gd"

var _owned: Array[Unit] = []

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_definition()
	_check_model_and_art()
	_check_permanent_team_boost()
	_check_forge_controls_and_targets()
	_check_existing_death_transitions()
	_check_forge_audio()
	_check_attack_rounding()
	_check_charge_motion_and_impact()
	_clear_owned()

func _check_definition() -> void:
	var card := CardDB.get_unit_stats("ornn")
	var skill: Dictionary = card.active_skills[0]
	_expect(card.cost == 6 and card.hp == 1260 and card.damage == 104, "奥恩首版为6费1260血104点普攻")
	_expect(card.first_hit == 0.26, "奥恩普攻前摇取三段原生命中节点映射的公共近似值")
	_expect(skill.kind == "terrain_charge" and skill.cost == 2 and skill.max_uses == 2 and skill.cooldown == 10.0, "熔铸冲锋为2费、2次、10秒冷却")
	_expect(skill.trail_damage == 32 and skill.damage == 135 and skill.stun_duration == 1.5, "冲锋路径小伤害，障碍爆发造成135伤害与1.5秒眩晕")

func _check_permanent_team_boost() -> void:
	var source := _spawn("ornn", 0, Vector2(360, 1000))
	var near_garen := _spawn("garen", 0, Vector2(370, 1000))
	var far_garen := _spawn("garen", 0, Vector2(80, 1000))
	var kayn := _spawn("kayn", 0, Vector2(650, 1000))
	var cheap := _spawn("melee_minion", 0, Vector2(361, 1000))
	var building := _spawn("tombstone", 0, Vector2(360, 920))
	var system: TeamAttackBoostSystem = _main.get("_team_attack_boost_system")

	source._deploy_timer = 0.05
	system.tick(0.05)
	_expect(not source.team_attack_boost_started and source.team_attack_boost_multiplier == 1.0, "部署未完成时被动不开始计时")
	source._deploy_timer = 0.0
	system.tick(0.0)
	_advance_boost(system, 3.95)
	_expect(source.team_attack_boost_multiplier == 1.0, "首次增幅在部署完成后4秒前不触发")
	system.tick(0.05)
	_expect(source.team_attack_boost_multiplier == 1.0 and system.flights.size() == 1, "锤子发射时不提前增幅")
	_advance_boost(system, 0.30)
	_expect(source.team_attack_boost_multiplier == 1.0, "锤子飞行中不改变普攻伤害")
	_advance_boost(system, 0.05)
	_expect(is_equal_approx(source.team_attack_boost_multiplier, 1.2), "锤子抵达自己后才获得增幅")
	for target in [near_garen, far_garen, kayn, cheap]:
		source.team_attack_boost_clock = 0.05
		system.tick(0.05)
		_advance_boost(system, 3.6)
		_expect(target.team_attack_boost_multiplier == 1.0, "选定友军必须等待飞行抵达")
		_advance_boost(system, 3.0)
		_expect(is_equal_approx(target.team_attack_boost_multiplier, 1.2), "按费用和距离顺序给未增幅友军送达锤子")
	source._tick_active_statuses(120.0)
	_expect(is_equal_approx(source.team_attack_boost_multiplier, 1.2) and is_equal_approx(near_garen.team_attack_boost_multiplier, 1.2), "获得的普攻增幅永久保留且不会重复叠加")
	_expect(building.team_attack_boost_multiplier == 1.0, "周期增幅只选择友方单位，不选择建筑")
	var doomed := _spawn("sion", 0, Vector2(100, 900))
	source.team_attack_boost_clock = 0.05
	system.tick(0.05)
	_advance_boost(system, 3.6)
	system._grant_one(near_garen, [doomed])
	_expect(system.flights.size() == 1, "飞行中的友军已预留，多个奥恩不会重复发锤")
	doomed.hp = 0.0
	_advance_boost(system, 3.0)
	_expect(doomed.team_attack_boost_multiplier == 1.0 and system.flights.is_empty(), "目标死亡取消飞行且不增幅尸体")
	var moving := _spawn("sion", 0, Vector2(100, 1100))
	source.team_attack_boost_clock = 0.05
	system.tick(0.05)
	_advance_boost(system, 3.6)
	moving.position = Vector2(580, 950)
	source.hp = 0.0
	_advance_boost(system, 3.0)
	_expect(is_equal_approx(moving.team_attack_boost_multiplier, 1.2), "已发出的锤子跟随目标，来源死亡不撤回在途增幅")
	_clear_owned()

func _check_attack_rounding() -> void:
	var source := _spawn("ornn", 0, Vector2(360, 1000))
	var target := _spawn("tombstone", 1, Vector2(360, 935))
	source.team_attack_boost_multiplier = 1.2
	source._target = target
	source._attacking = true
	source.attack_timeline.windup = 0.0
	source.attack_timeline.cooldown = 0.0
	source.attack_timeline.recovery = 0.0
	var before := target.hp
	source._attack(_main.SIM_DT)
	_expect(before - target.hp == 125, "104点普攻乘1.2后按项目数值规则取整为125")
	_clear_owned()

func _check_charge_motion_and_impact() -> void:
	var skill: Dictionary = CardDB.get_unit_stats("ornn").active_skills[0]
	var slow := _spawn("ornn", 0, Vector2(180, 900))
	var fast := _spawn("ornn", 0, Vector2(540, 900))
	var trail_target := _spawn("garen", 1, Vector2(180, 800))
	slow.team_attack_boost_multiplier = 1.2
	slow.move_speed = 2.0
	fast.move_speed = 1000.0
	var slow_state := _start_charge(slow, skill)
	var fast_state := _start_charge(fast, skill)
	for _tick in 7:
		slow_state.tick(_main.SIM_DT)
		fast_state.tick(_main.SIM_DT)
	_expect(slow.position == Vector2(180, 900) and not slow.skill_dash_active, "Spell3蓄力期间保持原地，未提前进入冲锋")
	for _tick in 4:
		slow_state.tick(_main.SIM_DT)
		fast_state.tick(_main.SIM_DT)
	_expect(is_equal_approx(900.0 - slow.global_position.y, 56.0) and is_equal_approx(900.0 - fast.global_position.y, 56.0), "冲锋速度固定，完全不受基础移速影响")
	for _tick in 30:
		if not slow_state.finished: slow_state.tick(_main.SIM_DT)
		if not fast_state.finished: fast_state.tick(_main.SIM_DT)
	_expect(trail_target.hp == 1050 - 32 and trail_target.control.stun_timer == 0.0, "未撞障碍时路径只造成一次32点伤害，不触发范围爆发或眩晕")
	_expect(is_equal_approx(900.0 - slow.global_position.y, 140.0), "无障碍时严格走完固定冲锋距离")
	_expect(not slow_state.hit_obstacle and slow.get_visual_action_name() == &"ornn_charge_miss", "未碰撞使用短收势，不播放撞墙Hit")
	_clear_owned()

	var blocker_source := _spawn("ornn", 0, Vector2(360, 900))
	var blocker := _spawn("tombstone", 1, Vector2(360, 760))
	var blast_target := _spawn("garen", 1, Vector2(400, 820))
	var blocker_before := blocker.hp
	var blast_before := blast_target.hp
	blocker_source.team_attack_boost_multiplier = 1.2
	var blocker_state := _start_charge(blocker_source, skill)
	for _tick in 40:
		if not blocker_state.finished: blocker_state.tick(_main.SIM_DT)
	_expect(blocker_state.hit_obstacle and blocker_source.get_visual_action_name() == &"ornn_charge_hit", "碰撞切换原生Hit与hit_toIdle分支")
	var blocked_unit := int(blocker_before - blocker.hp)
	var blasted_unit := int(blast_before - blast_target.hp)
	_expect(blocked_unit == 135, "阻挡冲锋的建筑免受路径伤害，只承受停止点范围伤害")
	_expect(blasted_unit == 167 and is_equal_approx(blast_target.control.stun_timer, 1.5), "附近敌人承受一次路径伤害与135点技能爆发并眩晕1.5秒")
	_expect(not blocker_state.collided and blocker_state.finished, "爆发完成后及时结束固定施法窗口")
	_clear_owned()

func _start_charge(source: Unit, skill: Dictionary) -> OrnnChargeState:
	source.begin_active_skill_cast(float(skill.cast_duration), Vector2.UP, skill.get("cast_locks", []))
	return OrnnChargeState.new(source, skill)

func _spawn(card_id: String, team: int, position: Vector2) -> Unit:
	var unit: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, card_id, position, {"deploy_time_override": 0.0}))
	_owned.append(unit)
	return unit

func _clear_owned() -> void:
	_main.get("_team_attack_boost_system").clear()
	for unit in _owned:
		if is_instance_valid(unit): unit.free()
	_owned.clear()

func _advance_boost(system: TeamAttackBoostSystem, seconds: float) -> void:
	for _step in roundi(seconds / _main.SIM_DT): system.tick(_main.SIM_DT)

func _check_model_and_art() -> void:
	var card := CardDB.get_unit_stats("ornn")
	var packed := load(PresentationConfig.scene_path(card, 0)) as PackedScene
	var wrapper := packed.instantiate() as Node3D
	_main.add_child(wrapper)
	wrapper.prepare_visual_animations()
	var meshes := wrapper.find_children("*", "MeshInstance3D", true, false)
	_expect(meshes.size() == 1 and meshes[0].mesh.get_surface_count() == 3, "奥恩按原始皮肤定义只显示主体、砧和锤，隐藏剑桶魄罗")
	var size: Vector3 = meshes[0].get_aabb().size * meshes[0].global_basis.get_scale().abs()
	_expect(size.y > 1.8 and size.y < 4.0, "奥恩在固定世界尺度中可见，不能用展台自动取景掩盖百分之一缩放")
	_expect(wrapper.get_preview_focus(Vector3(8, 0, 0)).distance_to(Vector3(0, 1.202, 0.156)) < 0.001, "展台聚焦身体中心，不受隐藏道具包围盒偏移影响")
	wrapper.free()
	var art := load("res://assets/cards/ornn_loading.jpg") as Texture2D
	_expect(art.get_height() > art.get_width(), "奥恩卡面使用原生竖版loadscreen")
	var skill: Dictionary = card.active_skills[0]
	_expect(skill.length == 3.5 * ArenaRules.TILE_SIZE and skill.fixed_speed == 280.0, "冲锋固定3.5格，0.5秒完成冲刺")

func _check_forge_controls_and_targets() -> void:
	var source := _spawn("ornn", 0, Vector2(360, 1000))
	var ally := _spawn("garen", 0, Vector2(380, 1000))
	var egg := _spawn("anivia_egg", 0, Vector2(420, 1000))
	var building := _spawn("tombstone", 0, Vector2(480, 1000))
	var sion := _spawn("sion", 0, Vector2(520, 1000))
	var system: TeamAttackBoostSystem = _main.get("_team_attack_boost_system")
	system.tick(0.0)
	_advance_boost(system, 0.4)
	_expect(bool(system.forging[source.get_instance_id()].active) and is_equal_approx(source.team_attack_boost_clock, 3.6), "部署后0.4秒开始锻造，提前3.6秒播放音频")
	_advance_boost(system, 1.0)
	source.stun(0.5)
	_expect(not bool(system.forging[source.get_instance_id()].active), "眩晕施加当刻打断锻造，不等下一次轮询")
	system.tick(0.05)
	source.control.clear_on_death()
	system.tick(0.05)
	_expect(is_equal_approx(source.team_attack_boost_clock, 3.6), "解除控制从头锻造3.6秒")
	_advance_boost(system, 3.55)
	_expect(system.flights.is_empty(), "重新锻造3.6秒前不发锤")
	system.tick(0.05)
	_expect(system.flights.size() == 1 and is_equal_approx(source.team_attack_boost_clock, 8.0), "发锤后重置8秒周期")

	var in_flight := system.flights.size()
	source.freeze(0.5)
	_expect(system.flights.size() == in_flight and is_equal_approx(source.team_attack_boost_clock, 8.0), "发锤后冰冻只截断声音，不撤回锤子或重置周期")
	source.control.clear_on_death()
	system.clear()
	for family in [&"freeze", &"stasis"]:
		source.team_attack_boost_clock = 3.6
		system.tick(0.05)
		if family == &"freeze": source.freeze(0.5)
		else: source.control.hard.apply(family, &"fixture", 0.5, {})
		system.tick(0.05)
		_expect(not bool(system.forging[source.get_instance_id()].active), "%s打断本次锻造" % family)
		source.control.clear_on_death()
		source.control.hard.clear_family(family)
		system.tick(0.05)
		_expect(is_equal_approx(source.team_attack_boost_clock, 3.6), "%s解除后完整重锻3.6秒" % family)
		system.clear()
	source.team_attack_boost_clock = 3.6
	system.tick(0.05)
	source.apply_knockback(source.position + Vector2(50, 0), 20.0)
	system.tick(0.05)
	_expect(bool(system.forging[source.get_instance_id()].active) and is_equal_approx(source.team_attack_boost_clock, 3.55), "普通击退不打断锻造")
	system.clear()
	_expect(not system._eligible(egg, 0) and not system._eligible(building, 0), "增幅不选择冰鸟蛋或建筑")
	sion.death_form.waiting_ticks = 10
	_expect(not system._eligible(sion, 0), "复生等待即便临时有血量也不参与友方增幅")
	ally.control.hard.apply(&"stasis", &"fixture", 1.0, {})
	_expect(not system._eligible(ally, 0), "凝滞中的友军不可被选为增幅目标")
	ally.control.hard.clear_family(&"stasis")
	system._grant_one(source, [ally])
	ally.control.hard.apply(&"untargetable", &"fixture", 1.0, {})
	system._tick_flights(3.0)
	_expect(ally.team_attack_boost_multiplier == 1.0 and system.flights.is_empty(), "抵达时对友方也不可选中则无增幅且丢弃飞行")
	ally.control.hard.clear_family(&"untargetable")
	system._grant_one(source, [ally])
	ally.control.hard.apply(&"stasis", &"fixture", 1.0, {})
	system._tick_flights(3.0)
	_expect(ally.team_attack_boost_multiplier == 1.0, "抵达时处于凝滞不获得增幅")
	_clear_owned()

func _check_existing_death_transitions() -> void:
	var source := _spawn("ornn", 0, Vector2(360, 1100))
	var system: TeamAttackBoostSystem = _main.get("_team_attack_boost_system")
	for card_id in ["sion", "anivia", "garen"]:
		var target := _spawn(card_id, 0, Vector2(100, 900))
		system._grant_one(source, [target])
		_expect(system.flights.size() == 1, "存活的%s可接收锤子" % card_id)
		target.take_damage(100000.0)
		system._tick_flights(0.05)
		_expect(system.flights.is_empty() and target.team_attack_boost_multiplier == 1.0, "%s致死转换/死亡由已有生命状态自然取消锤子" % card_id)
		if card_id == "anivia":
			for candidate in _main.get_tree().get_nodes_in_group("combatants"):
				if candidate is Unit and candidate.card_id == "anivia_egg" and candidate not in _owned:
					_owned.append(candidate)
					_expect(candidate.team_attack_boost_multiplier == 1.0, "新生冰鸟蛋不继承旧实体的在途锤子")
	var gwen := _spawn("gwen", 0, Vector2(100, 900))
	gwen.target_protection.begin(gwen.global_position, 100.0, 4.0)
	_expect(system._eligible(gwen, 0), "格温的敌方隔离不拦截友方增幅")
	_clear_owned()

func _check_forge_audio() -> void:
	var source := _spawn("ornn", 0, Vector2(360, 1100))
	var target := _spawn("garen", 0, Vector2(100, 900))
	var audio: GameAudioManager = _main.get("_audio_manager")
	var system: TeamAttackBoostSystem = _main.get("_team_attack_boost_system")
	var heard: Array = []
	var listener := func(card: String, cue: StringName, position: Vector2):
		if card == "ornn": heard.append({"cue": cue, "position": position})
	audio.cue_played.connect(listener)
	for family in [&"stun", &"freeze"]:
		audio.play_event(source, &"forge:pulse", source.position)
		var player: AudioStreamPlayer2D
		for candidate in audio._world_players:
			if candidate.playing and candidate.get_meta("action_owner", {}).get("kind", "") == "forge": player = candidate
		_expect(is_instance_valid(player), "锻造音使用可取消的专属归属")
		if family == &"stun": source.stun(0.5)
		else: source.freeze(0.5)
		_expect(is_instance_valid(player) and not player.playing, "%s立即截断正在播放的锻造声" % family)
		source.control.clear_on_death()
	heard.clear()
	system._grant_one(source, [target])
	target.control.hard.apply(&"stasis", &"fixture", 1.0, {})
	system._tick_flights(3.0)
	_expect(heard.is_empty(), "抵达资格失败不播放购买成功声")
	target.control.hard.clear_family(&"stasis")
	system._grant_one(source, [target])
	source.hp = 0.0
	system._tick_flights(3.0)
	_expect(heard.size() == 1 and heard[0].cue == &"forge:arrive" and heard[0].position == target.global_position, "来源死亡后成功抵达仍在友军位置播放一次购买成功声")
	audio.cue_played.disconnect(listener)
	_clear_owned()
