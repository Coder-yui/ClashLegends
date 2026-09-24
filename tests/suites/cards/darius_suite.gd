extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_bleeding()
	_check_execution()
	_check_payment()
	_check_schema()
	_check_lifecycle()
	_check_tower_cleanup()
	_check_hit_timing()

func _unit(card: String, team: int) -> Unit:
	var unit: Unit = _main._spawn_unit(team, card, Vector2(300 + team * 45, 900), 0.0)
	unit.move_speed = 0.0
	return unit

func _strike(source: Unit, target: Node2D, execute: bool = false) -> void:
	source._target = target
	# 测试直接结算一击；此前主场景Tick可能因拥挤推开来源，先确保命中距离。
	target.global_position = source.global_position + Vector2(45, 0)
	source.attack_timeline.cancel(true)
	source.blind_attack_charges = 0
	if execute: _main._active_skill_effect_system.apply(source, CardDB.active_skills_for("darius")[0])
	_main._combat.begin_batch(0, "darius_test")
	source._attack(0.05)
	_main._combat.commit_batch()

func _check_bleeding() -> void:
	var source := _unit("darius", 0)
	var target := _unit("sion", 1)
	target.hp = 10000
	target.max_hp = 10000
	_strike(source, target)
	_expect(target.bleeding.stacks(source) == 1, "首击施加1层流血")
	for tick in 30: target.bleeding.advance(target, 0.05)
	_expect(target.hp == 9867, "1.5秒流血按累计余量结算23点")
	_strike(source, target)
	_expect(target.bleeding.stacks(source) == 2, "1.5秒再命中变为2层")
	for tick in 59: target.bleeding.advance(target, 0.05)
	_expect(target.bleeding.stacks(source) == 2, "刷新后59Tick保留全层")
	target.bleeding.advance(target, 0.05)
	_expect(target.bleeding.stacks(source) == 0 and target.hp == 9667, "第60Tick完成最后伤害后全层到期，总流血113点")
	for hit in 4: _strike(source, target)
	_expect(target.bleeding.stacks(source) == 4 and source.active_damage_multiplier == 2.0, "第4次命中叠满获得血怒")
	var other := _unit("garen", 1)
	_strike(source, other)
	_expect(other.bleeding.stacks(source) == 4 and other.hp == 830, "血怒首击新目标直接4层且攻击翻倍")
	for tick in 79: source._tick_active_statuses(0.05)
	_expect(source.active_damage_multiplier == 2.0, "血怒第79Tick仍有效")
	_strike(source, other)
	source._tick_active_statuses(0.05)
	_expect(source.buffs.remaining(&"blood_rage") > 3.9, "血怒末端命中重新计时4秒")
	for tick in 79: source._tick_active_statuses(0.05)
	_expect(source.active_damage_multiplier == 1.0, "血怒第80Tick恢复普通伤害")
	var second := _unit("darius", 0)
	_strike(second, target)
	_expect(target.bleeding.stacks(second) == 1 and target.bleeding.stacks(source) == 4, "不同德莱厄斯独立叠层")
	source.queue_free()
	var hp_before := target.hp
	target.bleeding.advance(target, 0.05)
	_expect(target.hp < hp_before, "来源退出后已附着流血继续")
	second.queue_free()
	target.queue_free()
	other.queue_free()

func _check_execution() -> void:
	var source := _unit("darius", 0)
	var target := _unit("garen", 1)
	_strike(source, target)
	var hp_before := target.hp
	_strike(source, target, true)
	_expect(hp_before - target.hp == 225 and target.bleeding.stacks(source) == 2, "断头台按原1层结算225，再施加第2层")
	source.active_ability_id = 99001
	source.active_ability_slot = 0
	_main._active_skills.register(source, "darius", 0, CardDB.active_skills_for("darius")[0])
	target.hp = 1
	_strike(source, target, true)
	_expect(source.active_damage_multiplier == 2.0 and _main.get_active_skill_snapshot(99001).free_recast, "劈砍击杀立刻获得血怒与免费追斩")
	var fresh := _unit("garen", 1)
	_strike(source, fresh, true)
	_expect(fresh.hp == 690 and fresh.bleeding.stacks(source) == 4, "血怒断头台无层造成360并直接叠满")
	source.queue_free()
	fresh.queue_free()

func _check_payment() -> void:
	var deck: Array = _main._deck.duplicate()
	_main._deck[0] = "darius"
	var source := _unit("darius", 0)
	source.active_ability_id = 99002
	source.active_ability_slot = 0
	_main._register_active_skill(source, "darius", 0)
	_main._elixir.elixir = 5.0
	_expect(_main.use_active_skill(99002, 0) and _main._elixir.elixir == 3.0, "付费断头台请求扣2金币")
	_run_main_ticks(10)
	var state: Dictionary = _main.get_active_skill_snapshot(99002)
	_expect(state.uses_remaining == 1 and is_equal_approx(state.cooldown_left, 16.0) and source.empowered_attack_ready, "开始时扣次数启动16秒且武装下一击")
	_expect(not _main.use_active_skill(99002, 0), "已武装技能不能重复提交")
	var target := _unit("garen", 1)
	target.hp = 1
	_strike(source, target)
	_expect(_main.get_active_skill_snapshot(99002).free_recast, "已武装的真实劈砍击杀赠送免费资格")
	_main._elixir.elixir = 0.0
	_expect(_main.use_active_skill(99002, 0) and _main._elixir.elixir == 0.0, "付费冷却中零金币可提交免费追斩")
	_run_main_ticks(10)
	state = _main.get_active_skill_snapshot(99002)
	_expect(state.uses_remaining == 1 and not state.free_recast and is_equal_approx(state.cooldown_left, 15.5), "免费使用不占次数且冷却继续从16走到15.5")
	target = _unit("garen", 1)
	_strike(source, target)
	_expect(not _main.use_active_skill(99002, 0), "免费追斩未击杀回到原付费冷却")
	_main._active_skills.grant_recast(99002)
	_main._active_skills.tick(20.0)
	state = _main.get_active_skill_snapshot(99002)
	_expect(state.free_recast and state.cooldown_left == 0.0 and _main._active_skills.cost(99002) == 0.0, "付费CD完成不会覆盖未消费免费资格")
	_main._active_skills.consume(99002)
	_expect(_main._active_skills.cost(99002) == 2.0, "免费用尽后才恢复2金币技能")
	_main._active_skills.consume(99002)
	_main._active_skills.grant_recast(99002)
	_expect(_main.get_active_skill_snapshot(99002).uses_remaining == 0 and _main._can_submit_active_skill(99002, 0), "付费2次耗尽仍能使用击杀赠送资格")
	target.queue_free()
	source.queue_free()
	_main._deck = deck

func _check_schema() -> void:
	for field in ["bleed_damage_per_second", "bleed_duration", "bleed_max_stacks", "blood_rage_duration", "blood_rage_damage_multiplier", "empowered_first_hit"]:
		for value in ["bad", -1.0, NAN]:
			var stats := CardDB.get_card("darius").duplicate(true)
			stats[field] = value
			_expect(not CardDB.VALIDATOR.validate_all({"darius": stats}, false).is_empty(), "流血字段拒绝非法类型/数值 " + field)

func _check_lifecycle() -> void:
	var source := _unit("darius", 0)
	var target := _unit("garen", 1)
	source.hp = 1
	source._target = target
	source.attack_timeline.cancel(true)
	_main._combat.begin_batch(0, "darius_simultaneous")
	source._attack(0.05)
	source.take_damage(10, target)
	_main._combat.commit_batch()
	_expect(source.hp == 0.0 and target.bleeding.stacks(source) == 1, "来源同批死亡不撤销已提交普攻的流血")
	var hp_before := target.hp
	for tick in 60: target.bleeding.advance(target, 0.05)
	_expect(hp_before - target.hp == 45 and target.bleeding.total_stacks() == 0, "来源死亡后流血持续完整3秒，共45伤害")
	target.queue_free()
	source = _unit("darius", 0)
	target = _unit("garen", 1)
	source._target = target
	source.blind_attack_charges = 1
	source.attack_timeline.cancel(true)
	source._attack(0.05)
	_expect(target.hp == target.max_hp and target.bleeding.total_stacks() == 0, "致盲挥空不造成流血或血怒")
	_strike(source, target)
	target.freeze(4.0)
	target.target_protection.begin(target.global_position, 10.0, 4.0)
	source.position += Vector2(200, 0)
	hp_before = target.hp
	for tick in 60: target.bleeding.advance(target, 0.05)
	_expect(hp_before - target.hp == 45, "冰冻及后获圈外不可选取不停止已附着流血")
	source.refresh_blood_rage()
	var manager: GameAudioManager = _main._audio_manager
	manager._process(0.05)
	var key := manager._sustain_key(source.get_instance_id(), &"blood_rage")
	_expect(manager._sustain_players.has(key), "血怒启动原版持续音")
	source.freeze(1.0)
	manager._process(0.05)
	_expect(manager._sustain_players.has(key), "血怒持续音不被硬控打断")
	for tick in 80: source._tick_active_statuses(0.05)
	manager._process(0.05)
	_expect(not manager._sustain_players.has(key), "血怒自然到期停止持续音")
	source.queue_free()
	target.queue_free()

func _check_tower_cleanup() -> void:
	var source := _unit("darius", 0)
	var tower: Tower = _main._towers[2]
	tower.bleeding.apply(tower, source, source.bleed_definition, false)
	_expect(tower.bleeding.stacks(source) == 1, "防御塔接受流血")
	_main.clear_preview_battle()
	_expect(tower.bleeding.total_stacks() == 0, "工作台清场同时清除塔上的流血，不能残留伤害")

func _check_hit_timing() -> void:
	var source := _unit("darius", 0)
	_expect(is_equal_approx(source.body_radius, 21.0), "德莱厄斯稍大体型半径21")
	_expect(is_equal_approx(source._attack_first_hit_for_segment(0), 0.3) and is_equal_approx(source._attack_first_hit_for_segment(1), 0.3), "普通攻击不同动作统一0.30秒前摇")
	source.prepare_empowered_attack(1.0)
	_expect(is_equal_approx(source._next_attack_first_hit_time(), 0.33), "断头台映射原生11/40节点")
	source.attack_timeline.begin_windup(source._next_attack_first_hit_time(), 2.0)
	_expect(is_equal_approx(source.attack_timeline.windup, 0.165), "双倍攻速同步缩放劈砍前摇")
	source.empowered_attack_ready = false
	source._attacking = true
	source._attack_visual_pending = false
	source.attack_timeline.windup = 0.1
	source.attack_timeline.cooldown = 0.1
	source.prepare_empowered_attack(1.0)
	_expect(source.attack_timeline.windup == 0.0 and source.attack_timeline.cooldown == 0.0 and source.attack_timeline.visual_elapsed == 0.0 and source._attack_visual_pending, "强化刷新旧攻击周期和进度，等待完整强化前摇")

	var target := _unit("garen", 1)
	source._target = target
	source.empowered_attack_ready = false
	source.attack_timeline.cancel(true)
	source.attack_timeline.begin_windup(0.3, 1.0)
	for tick in 5: source._attack(0.05)
	_expect(target.hp == target.max_hp, "统一普攻前摇第5Tick不提前命中")
	source._attack(0.05)
	_expect(target.hp == target.max_hp - 110, "0.30秒前摇第6Tick真实命中，无浮点尾差多等一Tick")
	source.attack_timeline.cancel(true)
	source.empowered_execute = CardDB.active_skills_for("darius")[0]
	source.prepare_empowered_attack(1.0)
	source.attack_timeline.begin_windup(source._next_attack_first_hit_time(), 1.0)
	var hp_before := target.hp
	for tick in 6: source._attack(0.05)
	_expect(target.hp == hp_before, "劈砍0.33秒节点第6Tick不提前命中")
	source._attack(0.05)
	_expect(target.hp == hp_before - 225, "劈砍第7Tick按已有1层结算")
	target.queue_free()
	var effect: ActiveBuffVisual3D = load("res://assets/effects/darius/blood_rage.tscn").instantiate()
	_expect(effect.status_source == "blood_rage", "自身特效只订阅血怒状态")
	effect.configure(source.visual_radius, source.team)
	effect.advance(true, 0.2)
	_expect(effect.visible and effect.active, "血怒自身特效可启动")
	effect.advance(false, 0.2)
	_expect(not effect.visible and not effect.active, "血怒结束后清理自身特效")
	effect.free()
	source.queue_free()
