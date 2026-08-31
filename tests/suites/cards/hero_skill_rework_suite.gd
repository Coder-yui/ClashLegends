class_name HeroSkillReworkSuite
extends RefCounted
## 腕豪/寒冰/盖伦/提莫技能重做：定向命中、资源、强化普攻、致盲与专用动画链。

var _harness: Object
var _main: Node2D

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_sett_resource_and_frontal_damage()
	_check_ashe_volley()
	_check_empowered_attacks_and_blind()
	_check_masteryi_double_strike_and_highlander()
	_check_animation_routes()

func _dummy_stats() -> Dictionary:
	var stats := SuiteUtils.sweep_dummy_stats(CardDB.get_card("garen"))
	stats["deploy_time"] = 0.0
	stats["hp"] = 3000.0
	return stats

func _spawn_test_unit(card_id: String, p_team: int, pos: Vector2) -> Unit:
	var stats := CardDB.get_card(card_id).duplicate(true)
	stats["deploy_time"] = 0.0
	var unit := Unit.new()
	unit.position = pos
	unit.setup(p_team, stats, stats.name)
	_main.add_child(unit)
	return unit

func _spawn_dummy(pos: Vector2, p_team: int = 1) -> Unit:
	var unit := Unit.new()
	var stats := _dummy_stats()
	unit.position = pos
	unit.setup(p_team, stats, "技能木桩")
	_main.add_child(unit)
	return unit

func _check_sett_resource_and_frontal_damage() -> void:
	var sett := _spawn_test_unit("sett", 0, Vector2(100.0, 1120.0))
	sett.take_damage(20.0)
	var hidden_without_loadout := not sett.is_skill_resource_visible() and is_zero_approx(sett.skill_resource_value)
	sett.configure_carried_active_skill(CardDB.get_card("sett").active_skill)
	sett.take_damage(80.0)
	sett.add_skill_resource(sett.skill_resource_attack_gain)
	var resource_from_combat := is_equal_approx(sett.skill_resource_value, 100.0)
	sett.add_skill_resource(100.0)
	var skill: Dictionary = CardDB.get_card("sett").active_skill
	var prepared: Dictionary = _main._active_skill_effect_system.prepare_cast(sett, skill)
	var prepared_full := (
		is_equal_approx(float(prepared.damage), float(skill.damage) * 2.0)
		and String(prepared.visual_action) == "active_strong"
		and is_zero_approx(sett.skill_resource_value)
	)
	var center := _spawn_dummy(Vector2(100.0, 1000.0))
	var edge := _spawn_dummy(Vector2(152.0, 1000.0))
	var behind := _spawn_dummy(Vector2(100.0, 1220.0))
	sett.begin_active_skill_cast(float(prepared.cast_duration), Vector2.UP, prepared.cast_locks)
	var center_before := center.hp
	var edge_before := edge.hp
	var behind_before := behind.hp
	_main._active_skill_effect_system.apply(sett, prepared)
	var center_damage := center_before - center.hp
	var edge_damage := edge_before - edge.hp
	_expect(hidden_without_loadout and resource_from_combat and prepared_full, "腕豪只有主动槽实际携带蓄意轰拳时才显示并积攒豪意；满豪意锁定 2 倍伤害并选择 Spell2 Strong 后清空旧豪意")
	_expect(
		is_equal_approx(center_damage, float(skill.damage) * 2.0 * 1.5)
		and is_equal_approx(edge_damage, float(skill.damage) * 2.0)
		and is_equal_approx(behind.hp, behind_before),
		"蓄意轰拳只命中前方梯形，中央造成 1.5 倍伤害且满豪意总伤害最高达到基础值 3 倍",
	)
	_expect(sett.is_active_skill_movement_locked() and sett.is_active_skill_attack_locked() and sett.is_active_skill_facing_locked(), "蓄意轰拳施放期间锁定移动、攻击与朝向")
	for unit in [sett, center, edge, behind]:
		unit.free()

func _check_ashe_volley() -> void:
	var ashe := _spawn_test_unit("ashe", 0, Vector2(300.0, 1120.0))
	var front := _spawn_dummy(Vector2(300.0, 980.0))
	var behind := _spawn_dummy(Vector2(300.0, 1250.0))
	var skill: Dictionary = CardDB.get_card("ashe").active_skill
	ashe.begin_active_skill_cast(float(skill.cast_duration), Vector2.UP, skill.cast_locks)
	var front_before := front.hp
	var behind_before := behind.hp
	_main._active_skill_effect_system.apply(ashe, skill)
	_expect(
		int(skill.projectile_count) == 8 and String(skill.shape) == "fan" and String(skill.visual_action) == "active"
		and is_equal_approx(front_before - front.hp, float(skill.damage))
		and is_equal_approx(front.slow_timer, 1.0)
		and is_equal_approx(behind.hp, behind_before),
		"寒冰 Spell2 万箭齐发以 8 箭扇形命中前方目标一次、造成伤害并施加 1 秒减速，不命中身后",
	)
	for unit in [ashe, front, behind]:
		unit.free()

func _check_empowered_attacks_and_blind() -> void:
	var garen := _spawn_test_unit("garen", 0, Vector2(500.0, 1120.0))
	var target := _spawn_dummy(Vector2(500.0, 1070.0))
	var garen_skill: Dictionary = CardDB.get_card("garen").active_skill
	garen._target = target
	garen._attacking = true
	garen._attack_windup = 0.2
	garen._attack_cd = 0.6
	garen._attack_visual_pending = false
	var windup_before := garen._attack_windup
	var cooldown_before := garen._attack_cd
	_main._active_skill_effect_system.apply(garen, garen_skill)
	var cadence_preserved := is_equal_approx(garen._attack_windup, windup_before) and is_equal_approx(garen._attack_cd, cooldown_before)
	var no_mid_attack_speed_boost := is_equal_approx(garen.empowered_attack_speed_multiplier, 1.0)
	var target_before := target.hp
	garen._attack_windup = 0.0
	garen._attack_cd = 0.0
	garen._attack(_main.SIM_DT)
	var empowered_damage := target_before - target.hp
	_expect(
		cadence_preserved and no_mid_attack_speed_boost and is_equal_approx(empowered_damage, garen.damage * 2.0)
		and not garen.empowered_attack_ready,
		"盖伦致命打击不重置攻击节奏；攻击中使用时不获得移速，当前强化命中造成 2 倍伤害后立即移除效果",
	)
	garen._attacking = false
	garen._move_direction = Vector2.ZERO
	garen.prepare_empowered_attack(2.0, CardDB.SPEED_MEDIUM / CardDB.SPEED_SLOW)
	garen._prepare_movement(Vector2.UP, _main.SIM_DT)
	_expect(
		is_equal_approx(garen._move_intent.length(), CardDB.SPEED_MEDIUM),
		"盖伦不在攻击中施放致命打击时，强化待命期间移动速度从慢速提升两档至中速",
	)

	var teemo := _spawn_test_unit("teemo", 0, Vector2(600.0, 1120.0))
	var blinded := _spawn_test_unit("garen", 1, Vector2(600.0, 1070.0))
	_main._active_skill_effect_system.apply(teemo, CardDB.get_card("teemo").active_skill)
	teemo._target = blinded
	teemo._attacking = true
	teemo._attack_windup = 0.0
	teemo._attack_cd = 0.0
	teemo._attack_visual_pending = true
	teemo._attack(_main.SIM_DT)
	for _tick in range(10):
		_main._tick_projectiles(_main.SIM_DT)
		if _main._projectiles.is_empty():
			break
	var blind_applied := blinded.blind_attack_charges == 2
	var victim := _spawn_dummy(Vector2(600.0, 1020.0), 0)
	blinded._target = victim
	blinded._attacking = true
	_main._active_skill_effect_system.apply(blinded, garen_skill)
	var victim_before := victim.hp
	for _index in range(2):
		blinded._attack_windup = 0.0
		blinded._attack_cd = 0.0
		blinded._attack_visual_pending = true
		blinded._attack(_main.SIM_DT)
	var first_two_missed := is_equal_approx(victim.hp, victim_before) and blinded.blind_attack_charges == 0 and not blinded.empowered_attack_ready
	blinded._attack_windup = 0.0
	blinded._attack_cd = 0.0
	blinded._attack_visual_pending = true
	blinded._attack(_main.SIM_DT)
	_expect(
		blind_applied and first_two_missed and victim.hp < victim_before,
		"提莫强化普攻击中后致盲两次；强化普攻也会被致盲吞掉且两次结束后的第三次普攻恢复伤害（applied=%s, first_two=%s, charges=%d, hp=%.1f/%.1f）" % [blind_applied, first_two_missed, blinded.blind_attack_charges, victim.hp, victim_before],
	)
	for unit in [garen, target, teemo, blinded, victim]:
		unit.free()

func _check_masteryi_double_strike_and_highlander() -> void:
	var yi := _spawn_test_unit("masteryi", 0, Vector2(520.0, 900.0))
	var target := _spawn_dummy(Vector2(520.0, 850.0))
	yi._target = target
	yi._attacking = true
	yi._attack_hit_index = 2
	yi._attack_windup = 0.0
	yi._attack_cd = 0.0
	yi._attack_visual_pending = true
	var hp_before := target.hp
	yi._attack(_main.SIM_DT)
	var first_blade_damage := hp_before - target.hp
	yi._tick_pending_extra_attacks(0.12)
	var double_strike_damage := hp_before - target.hp
	_expect(
		is_equal_approx(first_blade_damage, yi.damage)
		and is_equal_approx(double_strike_damage, yi.damage * 1.5),
		"剑圣第三段 2013 Passive 算两次普通攻击，第二刀在固定延迟后造成普通攻击 50% 伤害",
	)
	var skill: Dictionary = CardDB.get_card("masteryi").active_skill
	yi._attack_windup = 0.18
	_main._active_skill_effect_system.apply(yi, skill)
	var haste_mechanics := (
		is_equal_approx(yi.active_speed_multiplier, 1.5)
		and is_equal_approx(yi.active_attack_speed_multiplier, 1.5)
		and is_equal_approx(yi._attack_windup, 0.12)
		and is_equal_approx(yi._next_attack_gap(), yi.attack_interval / 1.5)
	)
	_main._battle_presentation.attach_unit(yi, CardDB.get_card("masteryi"))
	var view := _view_for(yi)
	var haste_visual := false
	if view != null:
		yi._attacking = false
		yi._move_intent = Vector2.UP * yi.move_speed * yi.active_speed_multiplier
		view._sync_visual(false, 0.05)
		var haste_run := view._animation_player.current_animation == "2013_Run_Haste"
		yi._attacking = true
		yi._move_intent = Vector2.ZERO
		view._play_attack(3)
		view._sync_visual(false, 0.05)
		var passive_attack := view._animation_player.current_animation == "masteryi_2013_passive_anm"
		var shortened_attack := view._animation_player.get_playing_speed() > 4.1
		haste_visual = haste_run and passive_attack and shortened_attack
	_expect(haste_mechanics and haste_visual, "剑圣高原血统持续期间移速和攻速均为 1.5 倍，移动使用 2013 Run Haste，三段攻击动画同步缩短")
	yi._tick_active_statuses(5.0)
	_expect(is_equal_approx(yi.active_speed_multiplier, 1.0) and is_equal_approx(yi.active_attack_speed_multiplier, 1.0), "剑圣高原血统在 5 秒后恢复基础速度与攻速")
	for unit in [yi, target]:
		if is_instance_valid(unit):
			unit.free()

func _view_for(unit: Unit) -> UnitModel3D:
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			return child as UnitModel3D
	return null

func _check_animation_routes() -> void:
	var sett := _spawn_test_unit("sett", 0, Vector2(100.0, 900.0))
	_main._battle_presentation.attach_unit(sett, CardDB.get_card("sett"))
	var sett_view := _view_for(sett)
	var sett_routes := false
	var sett_skill_route := false
	if sett_view != null:
		sett_view._play_attack(1)
		sett_view._transition_to_basic_state(2, 0.0, &"attack")
		var first_to_passive_run := sett_view._animation_player.current_animation == "Run_Passive"
		sett_view._play_attack(2)
		sett_view._transition_to_basic_state(2, 0.0, &"attack")
		var second_transition := (
			sett_view._animation_player.current_animation == "Sett_Passive_INTO_Run_anm"
			and is_equal_approx(sett_view._last_clip_blend_time, sett_view._transition_blend(&"sequence"))
		)
		sett_view._on_animation_finished(&"Sett_Passive_INTO_Run_anm")
		sett_routes = (
			first_to_passive_run and second_transition
			and sett_view._animation_player.current_animation == "Run_Base"
			and is_equal_approx(sett_view._last_clip_blend_time, sett_view._transition_blend(&"sequence"))
		)

		sett.play_visual_action(&"active", 1.4)
		sett_view._sync_visual(false, 0.05)
		var skill_uses_global_action_in: bool = (
			is_equal_approx(sett_view._last_clip_blend_time, sett_view._transition_blend(&"action_in"))
			and not CardDB.get_card("sett").visual_animations.visual_actions.active.has("blend_in")
			and not CardDB.get_card("sett").visual_animations.visual_actions.active.has("blend_out")
		)
		sett._move_intent = Vector2.UP * sett.move_speed
		sett_view._on_animation_finished(&"Sett_spell2_anm")
		var skill_transition_short := (
			sett_view._animation_player.current_animation == "Sett_Spell2_INTO_Run_anm"
			and is_equal_approx(sett_view._last_clip_blend_time, sett_view._transition_blend(&"sequence"))
		)
		sett_view._on_animation_finished(&"Sett_Spell2_INTO_Run_anm")
		sett_skill_route = (
			skill_uses_global_action_in and skill_transition_short
			and sett_view._animation_player.current_animation == "Run_Base"
			and is_equal_approx(sett_view._last_clip_blend_time, sett_view._transition_blend(&"sequence"))
		)
	_expect(sett_routes, "腕豪第一拳丢失目标后接 Run Passive；第二拳先接 Sett Passive Into Run 再进入 Run Base")
	_expect(sett_skill_route, "腕豪蓄意轰拳移除角色混合覆盖：入口用全局 action_in，专用转跑首尾用 sequence")

	var garen := _spawn_test_unit("garen", 0, Vector2(260.0, 900.0))
	_main._battle_presentation.attach_unit(garen, CardDB.get_card("garen"))
	var garen_view := _view_for(garen)
	var garen_visuals := false
	if garen_view != null:
		garen._move_intent = Vector2.UP * garen.move_speed
		garen.prepare_empowered_attack(2.0, CardDB.SPEED_MEDIUM / CardDB.SPEED_SLOW)
		garen_view._sync_visual(false, 0.05)
		var spell_run := garen_view._animation_player.current_animation == "Run_Spell1"
		garen._attack_visual_pending = true
		garen._try_start_attack_visual(garen.first_hit_time)
		garen._attacking = true
		garen_view._sync_visual(false, 0.05)
		garen_visuals = spell_run and garen_view._animation_player.current_animation == "Spell1"
	_expect(garen_visuals, "盖伦强化待命移动使用 Spell1 Run，原攻击序号到点后使用 Spell1 强化普攻动作")

	var teemo := _spawn_test_unit("teemo", 0, Vector2(420.0, 900.0))
	_main._battle_presentation.attach_unit(teemo, CardDB.get_card("teemo"))
	var teemo_view := _view_for(teemo)
	var teemo_routes := false
	if teemo_view != null:
		teemo._move_intent = Vector2.UP * teemo.move_speed
		teemo_view._sync_visual(false, 0.05)
		var run_in := teemo_view._animation_player.current_animation == "Run_In_ASU_Teemo_anm"
		teemo._empowered_attack_visual_serial = 1
		teemo_view._play_attack(1)
		var spell1 := teemo_view._animation_player.current_animation == "Spell1"
		teemo_view._update_attack_stages(teemo.first_hit_time + 0.01)
		var long_recover := teemo_view._animation_player.current_animation == "Spell1_ToIdle"
		teemo_view._transition_to_basic_state(2, 0.0, &"attack")
		var empowered_transition_short := (
			teemo_view._animation_player.current_animation == "Spell1_ToRun"
			and is_equal_approx(teemo_view._last_clip_blend_time, teemo_view._transition_blend(&"sequence"))
		)
		teemo_view._on_animation_finished(&"Spell1_ToRun")
		var transition_to_run_short := (
			teemo_view._animation_player.current_animation == "Run_Base"
			and is_equal_approx(teemo_view._last_clip_blend_time, teemo_view._transition_blend(&"sequence"))
		)
		teemo_routes = run_in and spell1 and long_recover and empowered_transition_short and transition_to_run_short
	_expect(teemo_routes, "提莫进入移动使用 Run In；强化攻击 Spell1 后继续攻击接长 Spell1 ToIdle，改为移动则可中断并接 Spell1 ToRun")
	for unit in [sett, garen, teemo]:
		unit.free()
