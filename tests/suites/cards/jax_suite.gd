extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_animation_transitions()
	var source := _unit("jax", 0, Vector2(300, 900))
	var enemy := _unit("jax", 1, Vector2(360, 900))
	var skill: Dictionary = CardDB.active_skills_for("jax")[0]
	var deployed: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "jax", Vector2(200,1100)))
	_expect(deployed.deploy_time == 2.0 and deployed._deploy_timer == 2.0, "部署窗口为2秒")
	_expect(CardDB.get_card("jax").visual_animations.deploy == "Respawn", "部署继续使用Respawn")
	deployed.free()
	var resolver: CombatResolver = main.combat_service()
	_expect(main.preview_active_skill(source, skill), "反击风暴正式生命周期开始")
	source.add_shield(100.0, 4.0)
	for hit in 8:
		var result := resolver.resolve_attack_hit(1, enemy.position, source, 60.0, 0.0, 0.0, enemy, enemy.position)
		_expect(not result.landed, "免疫普攻不形成有效命中")
	_expect(enemy.buffs.stack_count(&"hit_haste") == 0, "被免疫攻击不发攻击者命中收益")
	var snap: Array = preload("res://tests/fixtures/network_fixture.gd").snapshot_payload(main._snapshot_system, 4444, source)
	_expect(snap[NetworkSnapshotSystem.U_ACTIVE_BUFF_ACTIVE], "快照同步反击风暴活动状态")
	_expect(source.active_buff_clock_visual().y == 2.0, "快照表现时钟使用2秒窗口")
	_expect(source.hp == 1100.0 and source.shield_hp == 100.0, "免疫普攻不消耗生命或护盾")
	_expect(source.buffs.strongest(&"counter_strike", &"dodges", 0.0) == 5, "免疫次数增长封顶五次")
	resolver.resolve_damage_hit(source, 120.0, enemy, 1, enemy.position)
	_expect(source.hp == 1080.0 and source.shield_hp == 0.0, "技能仍可消耗护盾并造成伤害")
	resolver.resolve_attack_hit(1, enemy.position, source, 20.0, 0.0, 0.0, enemy, enemy.position, -1, {"strike_type": "skill"})
	_expect(source.hp == 1060.0, "技能型强化攻击不被普攻免疫")
	var before := enemy.hp
	for tick in 39:
		source._tick_active_statuses(0.05)
		main._active_skill_effect_system.tick_effects(0.05)
	_expect(enemy.hp == before, "39Tick尚未爆发")
	source._tick_active_statuses(0.05)
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(enemy.hp == before - 300.0, "40Tick结算200%范围伤害")
	_expect(enemy.is_stunned(), "结束施加眩晕")
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(enemy.hp == before - 300.0, "结束伤害只触发一次")
	resolver.resolve_attack_hit(1, enemy.position, source, 20.0, 0.0, 0.0, enemy, enemy.position)
	_expect(source.hp == 1040.0, "窗口结束正常承受普攻")
	for i in 10:
		source.on_attack_landed(-1, 0.0, i + 10)
	_expect(source.buffs.stack_count(&"hit_haste") == 5 and is_equal_approx(source.active_attack_speed_multiplier, 1.5), "被动五层50%攻速封顶")
	source._tick_active_statuses(3.95)
	_expect(source.buffs.stack_count(&"hit_haste") == 5, "79Tick被动仍在")
	source._tick_active_statuses(0.05)
	_expect(source.buffs.stack_count(&"hit_haste") == 0, "80Tick被动自然结束")
	source.begin_counter_strike(skill)
	source.apply_stasis(3.0)
	source._tick_active_statuses(2.0)
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(enemy.hp == before - 300.0, "凝滞中到期不爆发")
	var dead := _unit("jax", 0, Vector2(360, 960))
	dead.begin_counter_strike(skill)
	dead._tick_active_statuses(2.0)
	dead.take_damage(99999.0)
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(enemy.hp == before - 300.0, "排队后死亡取消反击")
	var fresh := _unit("jax", 0, Vector2(500, 1000))
	var first := _unit("jax", 1, Vector2(550, 1000))
	var second := _unit("jax", 1, Vector2(550, 1020))
	resolver.resolve_attack_hit(0, fresh.position, first, 125.0, 35.0, 0.0, fresh, fresh.position)
	_expect(first.hp == 975.0 and second.hp == 975.0 and fresh.buffs.stack_count(&"hit_haste") == 1, "范围伤害命中两人只叠一层")
	fresh._tick_active_statuses(3.0)
	fresh.on_attack_landed(-1, 0.0, 12)
	fresh._tick_active_statuses(1.05)
	_expect(fresh.buffs.stack_count(&"hit_haste") == 2, "命中刷新全部层数而非首层单独到期")
	fresh.begin_counter_strike(skill)
	fresh.freeze(3.0)
	fresh._tick_active_statuses(2.0)
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(first.hp == 825.0 and first.is_stunned(), "冰冻中自然到期仍造成基础伤害和眩晕")
	# 半径159.38的2D圆形边界；纵向不随原生特效的镜头椭圆压缩。
	var ring_source := _unit("jax", 0, Vector2(350,750))
	var boundary_targets: Array[Unit] = []
	for direction in [Vector2.RIGHT, Vector2.UP]:
		for distance in [179.38,181.38]:
			var target := _unit("jax", 1, ring_source.position + direction * distance)
			target.position = ring_source.position + direction * distance
			boundary_targets.append(target)
	main._active_skill_effect_system.activate_nova(ring_source, skill)
	for index in boundary_targets.size():
		var target := boundary_targets[index]
		_expect(target.hp == (950.0 if index % 2 == 0 else 1100.0) and target.is_stunned() == (index % 2 == 0), "水平与纵向共用圆形范围伤害和眩晕边界")
		target.free()
	ring_source.free()
	var old_deck: Array = main.runtime._deck.duplicate()
	main.runtime._deck[0] = "jax"
	var paid: Unit = main.runtime._spawn_card_units(0, "jax", Vector2(500, 1100), 0.0, 0)[0]
	var account = main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team)
	account.elixir = 8.0
	_expect(main.use_active_skill(paid.active_ability_id, 0) and account.elixir == 6.0, "正式技能请求扣2金币")
	main.runtime._sim_tick_id += 10
	main.runtime._tick_pending_active_skills(0.05)
	var entry: Dictionary = main.runtime._active_skills.entry(paid.active_ability_id)
	_expect(entry.uses_remaining == 1 and entry.cooldown_left == 8.0 and not main.use_active_skill(paid.active_ability_id, 0), "一次施放后剩1次，8秒冷却禁止重复请求")
	main.runtime._deck = old_deck
	paid.free()
	for bad in [0, -1, 1.5]:
		var cards := CardDB.all().duplicate(true)
		cards.jax.active_skills[0].max_dodges = bad
		_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "免疫计数上限拒绝非法值")
	for unit in [source, enemy, dead, fresh, first, second]:
		if is_instance_valid(unit): unit.free()

func _unit(id: String, team: int, point: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, id, point, {"deploy_time_override": 0.0}))

func _check_animation_transitions() -> void:
	for moving in [false, true]:
		var unit := _unit("jax", 0, Vector2(300, 1050))
		var view := _view_for(unit)
		_expect(view != null, "武器大师动画代理存在")
		if view == null:
			unit.free()
			continue
		unit._move_intent = Vector2.UP * unit.move_speed if moving else Vector2.ZERO
		view._sync_visual(false, 0.0)
		var player := view._animation_player
		if moving:
			_expect(player.current_animation == "Run_In", "待机进入移动使用原版Run_In")
		unit.begin_counter_strike(CardDB.active_skills_for("jax")[0])
		view._sync_visual(false, 0.0)
		_expect(player.current_animation == "Spell3_Run_Intro_anm", "E先播放原版起手而非直入循环")
		player.advance(player.current_animation_length + 0.01)
		view._sync_visual(false, 0.0)
		_expect(player.current_animation == ("Spell3_Run" if moving else "Spell3_Idle"), "E起手完成按移动状态接持续循环")
		unit._tick_active_statuses(2.0)
		_main._active_skill_effect_system.tick_effects(0.05)
		view._sync_visual(false, 0.0)
		var ending := "Spell3b_run" if moving else "Spell3_B_Idle_anm"
		_expect(player.current_animation == ending and not view._playing_visual_action, "实际到期事件播放可打断Spell3B，不进入技能动作锁")
		view._last_buff_pose = true
		view._sync_visual(false, 0.0)
		_expect(player.current_animation == ending, "晚到的buff下降沿不覆盖已收到的结束动画")
		_expect(unit.active_skill_cast_timer == 0.0 and unit.get_visual_action_duration() == 0.0, "结束动画不延长权威技能或动作窗口")
		player.advance(player.current_animation_length + 0.01)
		view._sync_visual(false, 0.0)
		_expect(player.current_animation == ("Run_Base" if moving else "Idle1_Base"), "结束片段自然播完恢复基础循环")
		unit.presentation_cue.emit(&"counter_strike:explode")
		unit._move_intent = Vector2.ZERO if moving else Vector2.UP * unit.move_speed
		view._sync_visual(false, 0.0)
		_expect(player.current_animation != ending, "移动/停止立即打断E结束表现")
		unit._move_intent = Vector2.ZERO
		view._sync_visual(false, 0.0)
		unit.presentation_cue.emit(&"counter_strike:explode")
		unit._attacking = true
		unit._attack_visual_serial += 1
		view._sync_visual(false, 0.0)
		_expect(player.current_animation == "Attack_1_anm", "新普攻立即打断E结束表现")
		unit.presentation_cue.emit(&"counter_strike:explode")
		_expect(player.current_animation == "Attack_1_anm", "正在攻击时不抢播或排队结束动画")
		unit._attacking = false
		view._sync_visual(false, 0.0)
		_expect(player.current_animation == "Attack1_To_Idle", "第一击退出攻击接原版待机收势")
		unit._attacking = true
		unit._attack_visual_serial += 1
		view._sync_visual(false, 0.0)
		unit._attacking = false
		unit._move_intent = Vector2.UP * unit.move_speed
		view._sync_visual(false, 0.0)
		_expect(player.current_animation == "Attack2_To_Run", "第二击退出攻击接原版转跑收势")
		unit.presentation_cue.emit(&"counter_strike:explode")
		unit.stun(0.5)
		view._process(0.0)
		_expect(player.current_animation not in ["Spell3_B_Idle_anm", "Spell3b_run"], "眩晕立即打断结束表现")
		view.free()
		unit.free()
	var cards := CardDB.all().duplicate(true)
	cards.jax.visual_animations.transitions["unknown:event>idle"] = "Idle_In"
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "未知事件衔接被配置校验拒绝")
