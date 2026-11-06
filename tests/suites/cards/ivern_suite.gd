extends "res://tests/suites/battle_suite.gd"
func run(harness: Object) -> void:
	_harness = harness
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	_expect(CardDB.validate_all(false).is_empty(), "翠神定义有效：" + str(CardDB.validate_all(false)))
	for team in 2:
		var actor := _spawn_ready_unit("daisy", team, Vector2(300, 900))
		var target := _spawn_ready_unit("target_dummy", 1-team, Vector2(340, 900))
		target.hp = 10000
		actor._target = target
		for strike in 6:
			actor.attack_timeline.cooldown = 0.0
			actor.attack_timeline.windup = 0.0
			actor._attack_visual_pending = true
			target.control.tick_hard_controls(2.0)
			var before := target.hp
			actor._attack(0.05)
			_expect(is_equal_approx(before-target.hp, 160.0 if strike % 3 == 2 else 100.0), "双方小菊三击伤害循环")
			_expect(target.is_stunned() == (strike % 3 == 2), "只有第三击真实命中眩晕")
			if strike % 3 == 2: _expect(is_equal_approx(target.control.stun_timer, 1.0), "眩晕持续1秒")
		var ivern := _spawn_ready_unit("ivern", team, Vector2(400, 900))
		ivern._body_facing_direction = Vector2(0.6, -0.8) if team == 0 else Vector2(-0.6, 0.8)
		var expected_spawn := ivern.global_position + ivern.get_visual_facing_direction() * 40.0
		var before_count := _main.get_tree().get_nodes_in_group("combatants").size()
		_main._active_skill_effect_system.activate_summon(ivern, CardDB.active_skills_for("ivern")[0])
		_expect(_main.get_tree().get_nodes_in_group("combatants").size() == before_count+1, "召唤恰好一只小菊")
		var daisy: Unit
		for unit in _main.get_tree().get_nodes_in_group("combatants"):
			if unit is Unit and unit != actor and unit.card_id == "daisy": daisy = unit
		_expect(daisy != null and daisy.team == team and is_equal_approx(daisy.max_hp, 1100), "召唤物阵营与独立属性正确")
		_expect(daisy.global_position.distance_to(expected_spawn) < 0.01, "双方小菊生成在翠神朝向前方1格")
		ivern.take_damage(99999)
		_expect(daisy.hp > 0.0, "翠神死亡不清除已召唤小菊")
		for unit in _main.get_tree().get_nodes_in_group("combatants"):
			if unit is Unit: unit.free()
	_check_building_stun()
	_check_boundaries()
	_check_paid_skill()
	_check_spawn_visual_timing()
	_main.free()

func _clear() -> void:
	_main._projectile_system.clear_all()
	for unit in _main.get_tree().get_nodes_in_group("combatants"):
		if unit is Unit: unit.free()

func _check_boundaries() -> void:
	var actor := _spawn_ready_unit("daisy", 0, Vector2(300, 900))
	var target := _spawn_ready_unit("target_dummy", 1, Vector2(340, 900))
	actor._target = target
	actor._attack_hit_index = 2
	actor._attack_swing_count = 2
	actor.attack_timeline.windup = 0.0
	actor.attack_timeline.cooldown = 0.0
	actor.blind_attack_charges = 1
	var before := target.hp
	actor._attack(0.05)
	_expect(target.hp == before and not target.is_stunned() and actor.blind_attack_charges == 0, "致盲第三击无伤害无眩晕但消费攻击")
	actor._attack_hit_index = 2
	actor._attack_swing_count = 2
	actor._attack_visual_pending = true
	actor.attack_timeline.windup = 0.0
	actor.attack_timeline.cooldown = 0.0
	target.apply_stasis(1.0)
	actor._attack(0.05)
	_expect(target.hp == before and not target.is_stunned() and actor._attack_hit_index == 2, "凝滞拒绝命中时不触发并退回第三段")
	target.control.tick_hard_controls(1.0)
	actor.attack_timeline.windup = 0.0
	actor.attack_timeline.cooldown = 0.0
	actor._attack(0.05)
	_expect(target.hp == before-160 and is_equal_approx(target.control.stun_timer, 1.0), "恢复后仍为第三击")
	_clear()
	var cards := CardDB.all().duplicate(true)
	for invalid in [-1.0, INF, "40"]:
		cards.ivern.active_skills[0].spawn_forward_distance = invalid
		_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "拒绝非法前方召唤距离")
	cards.ivern.active_skills[0].spawn_forward_distance = 40.0
	cards.ivern.active_skills[0].spawn_count = 2
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "前方定距召唤仅允许单体")
	cards.ivern.active_skills[0].spawn_count = 1
	cards.daisy.attack_stun_durations = [0.0, -1.0, 1.0]
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "拒绝负眩晕时长")
	cards.daisy.attack_stun_durations = [1.0]
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "拒绝攻击循环长度不一致")

func _check_paid_skill() -> void:
	var wallet := ElixirManager.new()
	_main.add_child(wallet)
	_main.runtime.bind_account(0, wallet)
	_main.runtime._deck = ["ivern", "garen", "ashe", "teemo", "xin", "freeze", "heal", "pix"]
	var actor: Unit = _main.runtime._spawn_card_units(0, "ivern", Vector2(300, 1000), 0.0, 0)[0]
	actor._deploy_timer = 0.0
	var id := actor.active_ability_id
	wallet.elixir = 10.0
	_expect(_main.use_active_skill(id, 0), "正式小菊技能请求接受")
	_expect(wallet.elixir == 7.0 and not _main.use_active_skill(id, 0), "扣3金币且拒绝重复请求")
	_main.runtime._sim_tick_id += 10
	_main.runtime._tick_pending_active_skills(0.05)
	var entry: Dictionary = _main.runtime._active_skills.entry(id)
	_expect(entry.uses_remaining == 0 and entry.cooldown_left == 20.0, "起手消费唯一次数并启动20秒冷却")
	_clear()

func _check_spawn_visual_timing() -> void:
	var view = preload("res://assets/units/daisy/daisy_view.gd").new()
	_main.add_child(view)
	view.set_process(false)
	view.advance_deployment_visual(0.9, 1.3, true)
	_expect(not view._started and view._effect == null, "落地前不播放GroundSlam")
	view.advance_deployment_visual(0.95, 1.3, true)
	_expect(view._started and is_equal_approx(view._age, 0.0075), "第29帧映射部署时长后触发落地粒子")
	view.advance_deployment_visual(0.95, 1.3, true)
	_expect(is_equal_approx(view._age, 0.0075), "部署时钟暂停不推进落地特效")
	view.advance_deployment_visual(1.0, 1.3, false)
	_expect(view._effect == null, "取消部署清除落地特效")
	view.reset_pool_visual()
	view.advance_deployment_visual(1.3, 1.3, true)
	_expect(not view._started, "已完成部署重连不补播落地")
	view.free()

func _check_building_stun() -> void:
	for team in 2:
		var targets: Array[Node2D] = []
		for tower in _main.world.towers_snapshot():
			if tower.team != team: targets.append(tower)
		var building := _spawn_ready_unit("tombstone", 1-team, Vector2(300, 900))
		targets.append(building)
		for target in targets:
			var actor := _spawn_ready_unit("daisy", team, target.global_position + Vector2(30, 0))
			actor._target = target
			target.hp = target.max_hp
			for strike in 3:
				actor.attack_timeline.cooldown = 0.0
				actor.attack_timeline.windup = 0.0
				actor._attack_visual_pending = true
				actor._attack(0.05)
				var expected := 1.0 if strike == 2 and not (target is Tower and target.is_king) else 0.0
				_expect(is_equal_approx(target.control.stun_timer, expected), "第三击眩晕建筑和公主塔，国王塔保留统一免控")
			actor.free()
		building.free()
