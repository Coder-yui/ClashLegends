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
	_check_forge_snapshot_and_waiting()
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
	var near := _spawn("garen", 0, Vector2(390,1000))
	var far := _spawn("garen", 0, Vector2(80,1000))
	var cheap := _spawn("melee_minion", 0, Vector2(370,1000))
	var system: TeamAttackBoostSystem = _main._team_attack_boost_system
	source._deploy_timer = 0.05
	system.tick(0.05)
	_expect(not source.team_attack_boost_started, "部署锁结束前不推进首次冷却")
	source._deploy_timer = 0
	system.tick(0)
	_advance_boost(system,3.95)
	_expect(not source.team_attack_boost_forging, "首次4秒之前不锻造")
	system.tick(0.05)
	_expect(source.team_attack_boost_forging and is_equal_approx(source.team_attack_boost_clock,6), "4秒就绪并真正开始时消耗机会开始6秒CD")
	_expect(system.flights.is_empty(), "开始锻造不提前发锤")
	_advance_boost(system,0.60)
	_expect(system.flights.is_empty(), "0.65秒前无锤")
	system.tick(0.05)
	_expect(system.flights.size()==1 and source.team_attack_boost_multiplier==1, "0.65秒发锤不提前增幅")
	_advance_boost(system,0.35)
	_expect(is_equal_approx(source.team_attack_boost_multiplier,1.2) and not source.team_attack_boost_forging, "1秒锻造行动锁结束且自己的锤抵达后增幅")
	for target in [near,far,cheap]:
		source.team_attack_boost_clock=0
		system.tick(0)
		_expect(system.forging[source.get_instance_id()].target.get_ref()==target,"原费用/距离选择顺序保留")
		_advance_boost(system,0.65)
		_expect(target.team_attack_boost_multiplier==1,"发射节点目标尚未获得收益")
		_advance_boost(system,3)
		_expect(is_equal_approx(target.team_attack_boost_multiplier,1.2),"到达后永久增幅")
	source.team_attack_boost_clock=0
	_advance_boost(system,20)
	_expect(not source.team_attack_boost_forging and source.team_attack_boost_clock==0,"无目标不空敲、就绪最多保存一次")
	var next := _spawn("sion",0,Vector2(100,900))
	system.tick(0)
	_expect(source.team_attack_boost_forging and source.team_attack_boost_clock==6,"出现合法目标立即消费保存机会")
	_advance_boost(system,0.65)
	source.hp=0
	_advance_boost(system,3)
	_expect(is_equal_approx(next.team_attack_boost_multiplier,1.2),"已发锤不因来源死亡收回")
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

func _ready_forge(source: Unit) -> void:
	source.team_attack_boost_started=true
	source.team_attack_boost_clock=0
	_main._team_attack_boost_system.tick(0)

func _control(source: Unit, kind: String) -> void:
	match kind:
		"stun": source.stun(1)
		"freeze": source.freeze(1)
		"stasis": source.apply_stasis(1)
		"knockback": source.apply_knockback(source.position+Vector2(50,0),20)
		"forced": source.apply_forced_displacement(Vector2.RIGHT,20,0.5)

func _check_forge_controls_and_targets() -> void:
	var system: TeamAttackBoostSystem = _main._team_attack_boost_system
	for kind in ["stun","freeze","stasis","knockback","forced"]:
		for after_release in [false,true]:
			var source := _spawn("ornn",0,Vector2(360,1000))
			var ally := _spawn("sion",0,Vector2(100,900))
			_ready_forge(source)
			_expect(source.team_attack_boost_forging,"%s中断测试先起锻" % kind)
			_advance_boost(system,0.65 if after_release else 0.3)
			var clock := source.team_attack_boost_clock
			_control(source,kind)
			_expect(not source.team_attack_boost_forging and is_equal_approx(source.team_attack_boost_clock,clock),"%s立即打断且不退款/重置CD" % kind)
			_expect(system.flights.size()==(1 if after_release else 0),"%s以发锤节点为独立结果分界" % kind)
			_advance_boost(system,2)
			_expect(is_equal_approx(ally.team_attack_boost_multiplier,1.2 if after_release else 1.0),"%s打断前后命中收益正确" % kind)
			source.team_attack_boost_clock=0
			system.tick(0.05)
			_expect(not source.team_attack_boost_forging and source.team_attack_boost_clock==0,"%s受控期间保持就绪" % kind)
			source.control.clear_on_death(); source.knockback.cancel(&"fixture")
			system.tick(0)
			_expect(source.team_attack_boost_forging,"%s解除后消费就绪而非额外重置等待" % kind)
			_clear_owned()
	var source := _spawn("ornn",0,Vector2(360,1000))
	var ally := _spawn("sion",0,Vector2(100,900))
	source.control.hard.apply(&"root",&"fixture",3,{})
	_ready_forge(source)
	_expect(source.team_attack_boost_forging,"禁锢允许起锻")
	source.take_damage(10)
	source.control.hard.apply(&"root",&"fixture2",3,{})
	_advance_boost(system,0.1)
	_expect(source.team_attack_boost_forging,"普通受伤及新增禁锢不打断")
	var clock := source.team_attack_boost_clock
	source.begin_active_skill_cast(1,Vector2.UP)
	_expect(not source.team_attack_boost_forging and source.team_attack_boost_clock==clock,"玩家主动技能抢占但不退款")
	_clear_owned()
	for gate in ["attack","windup","recovery","skill"]:
		source=_spawn("ornn",0,Vector2(360,1000))
		match gate:
			"attack": source._attacking=true
			"windup": source.attack_timeline.windup=0.1
			"recovery": source.attack_timeline.recovery=0.1
			"skill": source.begin_active_skill_cast(1,Vector2.UP)
		_ready_forge(source)
		_expect(not source.team_attack_boost_forging and source.team_attack_boost_clock==0,"%s阻止起锻且不消费" % gate)
		_clear_owned()
	source=_spawn("ornn",0,Vector2(360,1000))
	_ready_forge(source)
	var enemy := _spawn("tombstone",1,Vector2(360,950))
	source._target=enemy
	source.sim_tick(0.05)
	_expect(source.team_attack_boost_forging and not source._attacking and source._move_intent==Vector2.ZERO,"起锻后敌人进入范围不抢占")
	_clear_owned()
	source=_spawn("ornn",0,Vector2(360,1000))
	enemy=_spawn("tombstone",1,Vector2(360,950))
	source._target=enemy
	source.sim_tick(0.05)
	_ready_forge(source)
	_expect(source._attacking and not source.team_attack_boost_forging,"同Tick普攻需求先于新锻造")
	_clear_owned()
	for kind in ["death","stasis","untargetable","boosted"]:
		source=_spawn("ornn",0,Vector2(360,1000))
		ally=_spawn("sion",0,Vector2(100,900))
		_ready_forge(source)
		match kind:
			"death": ally.hp=0
			"stasis": ally.apply_stasis(1)
			"untargetable": ally.control.hard.apply(&"untargetable",&"fixture",1,{})
			"boosted": ally.team_attack_boost_multiplier=1.2
		_advance_boost(system,0.65)
		_expect(system.flights.is_empty() and not source.team_attack_boost_forging and source.team_attack_boost_clock>5,"%s发射前复核失败，不重选不退款" % kind)
		_clear_owned()
	source=_spawn("ornn",0,Vector2(360,1000))
	var other := _spawn("ornn",0,Vector2(420,1000))
	ally=_spawn("sion",0,Vector2(100,900))
	_ready_forge(source); _ready_forge(other)
	_expect(system.forging[source.get_instance_id()].target.get_ref()!=system.forging[other.get_instance_id()].target.get_ref(),"多个奥恩在准备期即预留目标")
	_advance_boost(system,0.65)
	ally.apply_stasis(0.05)
	_expect(system.flights.size()==1,"凝滞当刻清除指向它的旧锤")
	ally.control.clear_on_death()
	_advance_boost(system,3)
	_expect(ally.team_attack_boost_multiplier==1,"目标恢复也不使被清除旧锤复活")
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
	_ready_forge(source)
	_advance_boost(system,0.6)
	_expect(heard.is_empty(), "准备阶段没有重复敲击声音")
	system.tick(0.05)
	_expect(heard.size()==1 and heard[0].cue==&"forge:strike" and system.flights.size()==1,"同一权威节点只派发一次敲击声和锤子")
	var playing_before := audio._world_players.filter(func(p): return p.playing).size()
	source.stun(0.5)
	_expect(audio._world_players.filter(func(p): return p.playing).size()==playing_before,"已响短敲击尾音不被控制截断")
	source.control.clear_on_death()
	system.clear()
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

func _check_forge_snapshot_and_waiting() -> void:
	var system: TeamAttackBoostSystem = _main._team_attack_boost_system
	var source := _spawn("ornn",0,Vector2(360,1000))
	source._move_intent=Vector2.UP*50
	source.apply_slow(2,0.5)
	_ready_forge(source)
	_expect(source.team_attack_boost_forging and source._move_intent==Vector2.ZERO,"移动/普通减速可停步起锻")
	var serial := source.get_visual_action_serial()
	_advance_boost(system,0.3)
	var snap: Array=bytes_to_var(var_to_bytes(_main._snapshot_system._unit_snapshot_payload(source.net_id,source)))
	_expect(snap[NetworkSnapshotSystem.U_ACTION_NAME]=="ornn_forge" and snap[NetworkSnapshotSystem.U_ACTION_SERIAL]==serial,"锻造名称与序号进入既有快照")
	var permissions := int(snap[NetworkSnapshotSystem.U_ACTION_PERMISSIONS])
	_expect((permissions & ControlState.MOVE)==0 and (permissions & ControlState.BASIC_ATTACK)==0 and (permissions & ControlState.START_SKILL)!=0,"锻造同步锁住行走普攻但允许主动抢占")
	source.team_attack_boost_clock=0
	system.tick(0)
	_expect(source.get_visual_action_serial()==serial,"同次动作未完即使CD人为就绪也不能重入")
	source.stun(0.2)
	_expect(source.cancelled_visual_serial==serial and source.get_visual_action_time_left()==0,"眩晕发布动作取消屏障，客户端不能续播")
	_clear_owned()
	source=_spawn("ornn",0,Vector2(360,1000))
	source.stun(10)
	source.team_attack_boost_started=true;source.team_attack_boost_clock=0.1
	_advance_boost(system,1)
	_expect(source.team_attack_boost_clock==0 and not source.team_attack_boost_forging,"受控仍推进独立CD，到零不累积")
	source.control.clear_on_death();system.tick(0)
	_expect(source.team_attack_boost_forging and source.team_attack_boost_clock==6,"控制解除时就绪直接起锻")
	source.hp=0;system.tick(0.05)
	_expect(not source.team_attack_boost_forging and system.flights.is_empty(),"来源发锤前死亡不留锤")
	_clear_owned()
