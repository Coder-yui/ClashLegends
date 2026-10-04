extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_decay_hit_animation()
	var skill: Dictionary = CardDB.active_skills_for("target_dummy")[0]
	var dummy := _spawn(0, Vector2(300, 900))
	var enemy := _spawn(1, Vector2(380, 900))
	var ally := _spawn(0, Vector2(300, 980))
	var far := _spawn(1, Vector2(520, 900))
	_expect(dummy.body_radius == CardDB.RADIUS_SLIGHTLY_LARGE and CardDB.get_card("target_dummy").footprint_tiles == Vector2i(2, 2), "木桩稍大碰撞半径独立于2×2占地")
	var start := dummy.global_position
	for tick in 20: dummy.sim_tick(0.05)
	_expect(dummy.global_position == start and dummy.get_attack_visual_serial() == 0 and not dummy._attacking, "木桩不移动、不启动普攻")
	dummy.hp = 750.0
	_expect(main.preview_active_skill(dummy, skill), "正式技能生命周期建立余震")
	dummy.add_shield(30.0, 4.0)
	dummy.take_damage(100.0, enemy)
	_expect(dummy.hp == 740.0 and dummy.shield_hp == 0.0, "100伤害减为40，再消耗30护盾、10生命")
	dummy.buffs.apply(&"damage_reduction", &"weaker", 1.0, {"reduction": 0.2})
	dummy.take_damage(100.0, enemy)
	_expect(dummy.hp == 700.0, "多个普通减伤取最强，不叠加")
	var before_enemy := enemy.hp
	var before_ally := ally.hp
	var before_far := far.hp
	for tick in 49:
		dummy._tick_active_statuses(0.05)
		main._active_skill_effect_system.tick_effects(0.05)
	_expect(enemy.hp == before_enemy and dummy.buffs.remaining(&"damage_reduction") > 0.0, "49Tick不提前爆炸")
	dummy._tick_active_statuses(0.05)
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(enemy.hp == before_enemy - 80.0 and ally.hp == before_ally and far.hp == before_far, "50Tick仅伤害范围内敌方")
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(enemy.hp == before_enemy - 80.0, "到期爆炸不重复")
	dummy.take_damage(100.0, enemy)
	_expect(dummy.hp == 600.0, "到期恢复全额承伤")
	var frozen := _spawn(0, Vector2(380, 980))
	main.preview_active_skill(frozen, skill)
	frozen.freeze(3.0)
	for tick in 50: frozen._tick_active_statuses(0.05)
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(enemy.hp == before_enemy - 160.0, "冰冻不取消已经建立的余震")
	var stasis := _spawn(0, Vector2(380, 820))
	main.preview_active_skill(stasis, skill)
	stasis.apply_stasis(3.0)
	for tick in 50: stasis._tick_active_statuses(0.05)
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(enemy.hp == before_enemy - 160.0, "凝滞期间到期抑制爆炸，不补发")
	var dead := _spawn(0, Vector2(380, 840))
	main.preview_active_skill(dead, skill)
	dead._tick_active_statuses(2.5)
	dead.take_damage(99999.0, enemy)
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(enemy.hp == before_enemy - 160.0, "排队后来源死亡取消爆炸")
	var decaying := _spawn(0, Vector2(200, 900))
	main.preview_active_skill(decaying, skill)
	_expect(decaying.lifespan_hp_decay, "正式木桩配置启用自然生命衰减")
	decaying.add_shield(30.0, 4.0)
	decaying._tick_building_lifetime(1.0)
	_expect(decaying.hp == 700.0 and decaying.shield_hp == 30.0, "减伤与护盾不减少每秒50的自然生命衰减")
	var lifetime := _spawn(0, Vector2(180, 1000))
	for tick in 299: lifetime._tick_building_lifetime(0.05)
	_expect(lifetime.hp == 2.0, "299个固定Tick累计自然衰血，末Tick前仍存活")
	lifetime._tick_building_lifetime(0.05)
	_expect(lifetime.hp <= 0.0, "寿命第300Tick自然退出")
	for team in [0, 1]:
		var aged := _spawn(team, Vector2(540, 820 + team * 120))
		for tick in 100: aged.sim_tick(0.05)
		_expect(aged.hp == 500.0 and is_equal_approx(aged.presentation_state().health_ratio, 2.0 / 3.0), "双方木桩5秒未受击已衰至500生命，血条读取真实剩余比例")
		aged.take_damage(100.0)
		_expect(aged.hp == 400.0, "木桩首次受击从自然衰减后的500继续扣血")
		aged.free()
	var resume := _spawn(0, Vector2(180, 1100))
	main.preview_active_skill(resume, skill)
	resume.apply_stasis(1.0)
	_run_main_ticks(20)
	_expect(not CombatInteraction.in_stasis(resume), "凝滞自然解除")
	var resume_hp := resume.hp
	resume.take_damage(100.0)
	_expect(resume.hp == resume_hp - 40.0, "凝滞解除恢复剩余减伤，不重新建立窗口")
	_run_main_ticks(30)
	_expect(resume.buffs.remaining(&"damage_reduction") == 0.0, "完整模拟50Tick状态到期")
	var old_deck: Array = main._deck.duplicate()
	main._deck[0] = "target_dummy"
	var paid: Unit = main._spawn_card_units(0, "target_dummy", Vector2(500, 1100), 0.0, 0)[0]
	main._elixir.elixir = 8.0
	_expect(main.use_active_skill(paid.active_ability_id, 0) and main._elixir.elixir == 6.0, "正式技能请求扣2费")
	main._sim_tick_id += 10
	main._tick_pending_active_skills(0.05)
	var entry: Dictionary = main._active_skills.entry(paid.active_ability_id)
	_expect(entry.uses_remaining == 0 and entry.cooldown_left == 10.0 and not main.use_active_skill(paid.active_ability_id, 0), "一次资格及10秒冷却")
	var snap: Array = main._snapshot_system._unit_snapshot_payload(4444, paid)
	_expect(snap[NetworkSnapshotSystem.U_ACTIVE_BUFF_ACTIVE], "快照同步余震增益表现")
	main._deck = old_deck
	for invalid in [-0.1, 1.1, INF, "bad"]:
		var cards := CardDB.all().duplicate(true)
		cards.target_dummy.active_skills[0].damage_reduction = invalid
		_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "拒绝非法减伤比例")

	var wrong_kind := CardDB.all().duplicate(true)
	wrong_kind.target_dummy.active_skills[0].kind = "nova"
	_expect(not CardDB.VALIDATOR.validate_all(wrong_kind, false).is_empty(), "拒绝没有减伤读取方的技能配置")

func _check_decay_hit_animation() -> void:
	for team in [0, 1]:
		var dummy := _spawn(team, Vector2(500, 800 + team * 120))
		var view := _view_for(dummy)
		var hit_events := [0]
		dummy.visual_hit.connect(func(): hit_events[0] += 1)
		_expect(view != null, "双方木桩具有正式3D表现代理")
		if view == null:
			dummy.free()
			continue
		for tick in 100:
			dummy.sim_tick(0.05)
			view._process(0.05)
		_expect(dummy.hp == 500.0 and hit_events[0] == 0 and not view._playing_visual_action and view._hit_flash_timer == 0.0, "木桩5秒自然衰血只刷新生命，持续待机、不播放Hit或闪白")
		dummy.take_damage(10.0)
		_expect(hit_events[0] == 1 and view._playing_visual_action and view._active_action_name == &"hit" and view._animation_player.current_animation == "Hit", "实际攻击木桩从500扣至490，触发原生Hit动画")
		dummy._tick_building_lifetime(10.0)
		_expect(dummy.hp == 0.0 and hit_events[0] == 1 and view._dying and view._animation_player.current_animation == "Death", "自然衰血归零播放Death，不追加Hit")
		view.free()
		dummy.free()

func _spawn(team: int, pos: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, "target_dummy", pos, {"deploy_time_override": 0.0}))
