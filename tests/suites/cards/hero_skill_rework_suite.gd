class_name HeroSkillReworkSuite
extends "res://tests/suites/battle_suite.gd"
## 腕豪/寒冰/盖伦/提莫技能重做：定向命中、资源、强化普攻、致盲与专用动画链。

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_sett_resource_and_frontal_damage()
	_check_sett_shield_and_combat_decay()
	_check_ashe_volley()
	_check_ashe_arrow_collision()
	_check_piercing_cards()
	_check_empowered_attacks_and_blind()
	_check_garen_judgment()
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
	sett.configure_carried_active_skill(CardDB.active_skills_for("sett")[0])
	sett.take_damage(80.0)
	sett.add_skill_resource(sett.skill_resource_attack_gain)
	var resource_from_combat := is_equal_approx(sett.skill_resource_value, 100.0)
	sett.add_skill_resource(100.0)
	var skill: Dictionary = CardDB.active_skills_for("sett")[0]
	var prepared: Dictionary = _main._active_skill_effect_system.prepare_cast(sett, skill)
	_main._active_skill_effect_system.apply_cast_start(sett, prepared)
	var prepared_full := (
		is_equal_approx(float(prepared.damage), float(skill.damage) * 2.0)
		and String(prepared.visual_action) == "active_strong"
		and is_equal_approx(sett.shield_hp, 300.0)
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

func _check_sett_shield_and_combat_decay() -> void:
	var skill: Dictionary = CardDB.active_skills_for("sett")[0]
	var zero_sett := _spawn_test_unit("sett", 0, Vector2(100.0, 1120.0))
	zero_sett.configure_carried_active_skill(skill)
	var zero_prepared: Dictionary = _main._active_skill_effect_system.prepare_cast(zero_sett, skill)
	_main._active_skill_effect_system.apply_cast_start(zero_sett, zero_prepared)
	var zero_grit_no_shield := is_zero_approx(zero_sett.shield_hp)

	var sett := _spawn_test_unit("sett", 0, Vector2(180.0, 1120.0))
	sett.configure_carried_active_skill(skill)
	sett.add_skill_resource(180.0)
	var resource_from_attack := false
	var dummy := _spawn_dummy(Vector2(180.0, 1060.0))
	sett._target = dummy
	sett._attacking = true
	sett.attack_timeline.windup = 0.0
	sett.attack_timeline.cooldown = 0.0
	sett._attack_visual_pending = true
	sett._attack(_main.SIM_DT)
	resource_from_attack = is_equal_approx(sett.skill_resource_value, 200.0)

	var full_prepared: Dictionary = _main._active_skill_effect_system.prepare_cast(sett, skill)
	_expect(is_equal_approx(float(zero_prepared.impact_delay), 0.8) and is_equal_approx(float(full_prepared.impact_delay), float(zero_prepared.impact_delay)), "腕豪普通与满豪意 W 使用相同的 0.8 秒权威命中延迟")
	_main._active_skill_effect_system.apply_cast_start(sett, full_prepared)
	var cast_start_shield := is_equal_approx(sett.shield_hp, 300.0) and is_zero_approx(sett.skill_resource_value)
	sett._tick_active_statuses(1.0)
	var halfway_shield := (
		is_equal_approx(sett.shield_hp, 150.0)
		and is_equal_approx(sett.get_shield_ratio(), 0.5)
		and is_equal_approx(sett.get_shield_health_ratio(), 150.0 / sett.max_hp)
	)
	sett._tick_active_statuses(1.0)
	var shield_expired := is_zero_approx(sett.shield_hp) and is_zero_approx(sett.shield_timer)

	sett.add_skill_resource(100.0)
	sett._tick_active_statuses(0.75)
	var combat_delay_holds := is_equal_approx(sett.skill_resource_value, 100.0)
	sett.take_damage(1.0)
	var damage_refreshes_decay := is_equal_approx(sett.skill_resource_value, 101.0)
	sett._tick_active_statuses(0.5)
	var reentered_combat_holds := is_equal_approx(sett.skill_resource_value, 101.0)
	sett._tick_active_statuses(0.5)
	var exact_delay_boundary_holds := is_equal_approx(sett.skill_resource_value, 101.0)
	sett._tick_active_statuses(0.1)
	var out_of_combat_decay := sett.skill_resource_value < 101.0

	sett.add_shield(100.0, 2.0, true)
	var hp_before_shielded_hit := sett.hp
	sett.take_damage(60.0)
	var shield_absorbs_first := is_equal_approx(sett.hp, hp_before_shielded_hit) and is_equal_approx(sett.shield_hp, 40.0)
	sett.take_damage(60.0)
	var damage_overflow_reaches_hp := is_equal_approx(sett.shield_hp, 0.0) and is_equal_approx(sett.hp, hp_before_shielded_hit - 20.0)
	_expect(
		zero_grit_no_shield and resource_from_attack and cast_start_shield and halfway_shield and shield_expired
		and shield_absorbs_first and damage_overflow_reaches_hp,
		"腕豪 0 豪意不生成护盾，攻击可积攒豪意，技能释放瞬间按满豪意获得 300 护盾并在 2 秒线性衰减至 0",
	)
	_expect(
		combat_delay_holds and damage_refreshes_decay and reentered_combat_holds and exact_delay_boundary_holds and out_of_combat_decay,
		"腕豪受伤/攻击后的豪意会刷新脱战计时，1 秒内重新进入战斗不衰减，脱战满 1 秒后才开始衰减",
	)
	for unit in [zero_sett, sett, dummy]:
		if is_instance_valid(unit):
			unit.free()

func _check_ashe_volley() -> void:
	var ashe := _spawn_test_unit("ashe", 0, Vector2(300.0, 1120.0))
	var front := _spawn_dummy(Vector2(300.0, 980.0))
	var behind := _spawn_dummy(Vector2(300.0, 1250.0))
	var skill: Dictionary = CardDB.active_skills_for("ashe")[0]
	var active_visual: Dictionary = CardDB.get_card("ashe").visual_animations.visual_actions.active
	var animation_duration_ok: bool = active_visual.get("durations", []) == [1.0] and is_equal_approx(float(skill.cast_duration), 1.0) and is_equal_approx(ashe.attack_interval, 1.0) and is_equal_approx(float(skill.impact_delay), 0.16)
	ashe.begin_active_skill_cast(float(skill.cast_duration), Vector2.UP, skill.cast_locks)
	var front_before := front.hp
	var behind_before := behind.hp
	_main._active_skill_effect_system.begin_frontal_visual(ashe, skill, Vector2.UP)
	var range_effect: Dictionary = _main._active_skill_effect_system.frontal_effects.back()
	var ring_sector_shape := (
		bool(skill.fan_inner_arc)
		and bool(range_effect.fan_inner_arc)
		and is_equal_approx(float(range_effect.source_radius), ashe.body_radius)
		and is_equal_approx(float(range_effect.length), 210.0)
		and is_equal_approx(float(range_effect.arc_degrees), 72.0)
		and is_equal_approx(float(range_effect.projectile_launch_delay), float(skill.impact_delay))
		and is_equal_approx(float(range_effect.projectile_flight_duration), 0.2)
		and is_equal_approx(ashe.first_hit_time, 0.14)
	)
	_main._active_skill_effect_system.apply(ashe, skill)
	var waits_for_flight := is_equal_approx(front.hp, front_before)
	_main._tick_projectiles(0.25)
	_expect(
			int(skill.projectile_count) == 8 and String(skill.shape) == "fan" and String(skill.visual_action) == "active"
			and waits_for_flight and animation_duration_ok
			and ring_sector_shape
			and is_equal_approx(front_before - front.hp, float(skill.damage))
		and is_equal_approx(front.control.slow_timer, 1.0)
		and is_equal_approx(behind.hp, behind_before),
		"寒冰 Spell2 万箭齐发压至 1 秒，普攻/W 均按源 0.30 秒换算离弦节点，使用贴合人物体型内圆弧的 8 箭环形扇区，命中前方目标一次并减速，不命中身后",
	)
	_main._active_skill_effect_system.frontal_effects.clear()
	for unit in [ashe, front, behind]:
		unit.free()

func _check_empowered_attacks_and_blind() -> void:
	var garen := _spawn_test_unit("garen", 0, Vector2(500.0, 1120.0))
	var target := _spawn_dummy(Vector2(500.0, 1070.0))
	var garen_skill: Dictionary = CardDB.active_skills_for("garen")[0]
	garen._target = target
	garen._attacking = true
	garen.attack_timeline.windup = 0.2
	garen.attack_timeline.cooldown = 0.6
	garen._attack_visual_pending = false
	var windup_before := garen.attack_timeline.windup
	var cooldown_before := garen.attack_timeline.cooldown
	_main._active_skill_effect_system.apply(garen, garen_skill)
	var cadence_preserved := is_equal_approx(garen.attack_timeline.windup, windup_before) and is_equal_approx(garen.attack_timeline.cooldown, cooldown_before)
	var no_mid_attack_speed_boost := is_equal_approx(garen.empowered_attack_speed_multiplier, 1.0)
	var target_before := target.hp
	garen.attack_timeline.windup = 0.0
	garen.attack_timeline.cooldown = 0.0
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
	_main._active_skill_effect_system.apply(teemo, CardDB.active_skills_for("teemo")[0])
	teemo._target = blinded
	teemo._attacking = true
	teemo.attack_timeline.windup = 0.0
	teemo.attack_timeline.cooldown = 0.0
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
		blinded.attack_timeline.windup = 0.0
		blinded.attack_timeline.cooldown = 0.0
		blinded._attack_visual_pending = true
		blinded._attack(_main.SIM_DT)
	var first_two_missed := is_equal_approx(victim.hp, victim_before) and blinded.blind_attack_charges == 0 and not blinded.empowered_attack_ready
	blinded.attack_timeline.windup = 0.0
	blinded.attack_timeline.cooldown = 0.0
	blinded._attack_visual_pending = true
	blinded._attack(_main.SIM_DT)
	_expect(
		blind_applied and first_two_missed and victim.hp < victim_before,
		"提莫强化普攻击中后致盲两次；强化普攻也会被致盲吞掉且两次结束后的第三次普攻恢复伤害（applied=%s, first_two=%s, charges=%d, hp=%.1f/%.1f）" % [blind_applied, first_two_missed, blinded.blind_attack_charges, victim.hp, victim_before],
	)
	for unit in [garen, target, teemo, blinded, victim]:
		unit.free()

func _check_garen_judgment() -> void:
	var skills := CardDB.active_skills_for("garen")
	var skill: Dictionary = skills[1] if skills.size() > 1 else {}
	var garen := _spawn_test_unit("garen", 0, Vector2(360.0, 500.0))
	var target := _spawn_dummy(Vector2(410.0, 500.0))
	var outside := _spawn_dummy(Vector2(550.0, 500.0))
	var air := _spawn_dummy(Vector2(360.0, 420.0))
	air.is_air = true
	# 盖伦的规则是攻城行军；放一个不入树的同阵营 Tower 锚点，避免测试脉冲时被场景塔的
	# 固定推进目标带走，移动能力单独用统一移动应用验证。
	var movement_anchor := Tower.new()
	movement_anchor.team = 0
	movement_anchor.hp = 100000.0
	movement_anchor.body_radius = 54.0
	movement_anchor.position = garen.position
	garen._target = movement_anchor
	_main._battle_presentation.attach_unit(garen, CardDB.get_card("garen"))
	var garen_view := _view_for(garen)
	_main._begin_configured_active_skill_cast(garen, skill)
	_main._active_skill_effect_system.apply(garen, skill)
	if garen_view != null:
		garen_view._sync_visual(false, 0.0)
	var animation_ok := garen_view != null and garen_view._animation_player.current_animation == "Spell3_0"
	var cast_locks_ok := (
		garen.is_active_skill_attack_locked()
		and not garen.is_active_skill_movement_locked()
		and not garen.is_active_skill_facing_locked()
		and is_equal_approx(garen.active_skill_cast_timer, 3.0)
	)
	# 主动施法锁定攻击但不锁移动：实际走一次统一移动应用，确认窗口内仍可位移。
	var position_before_move := garen.position
	garen._move_intent = Vector2.RIGHT * garen.move_speed
	_main._movement._apply_unit_movement(_main.SIM_DT, _main._movement._active_mobile_units())
	var moved_during_cast := garen.position.distance_to(position_before_move) > 0.001
	var target_before := target.hp
	var outside_before := outside.hp
	var air_before := air.hp
	var no_immediate_damage: bool = is_equal_approx(target.hp, target_before) and _main._active_skill_effect_system.continuous_area_effects.size() == 1
	_run_main_ticks(19)
	var no_early_pulse := is_equal_approx(target.hp, target_before) and is_equal_approx(outside.hp, outside_before)
	_run_main_ticks(1)
	var first_pulse := (
		is_equal_approx(target_before - target.hp, float(skill.damage))
		and is_equal_approx(outside.hp, outside_before)
		and is_equal_approx(air.hp, air_before)
	)
	# 把施法者移到原本圈外的目标附近；下一次脉冲必须读取新位置，而不是固定 Cast Start 坐标。
	garen.position = Vector2(470.0, 500.0)
	movement_anchor.position = garen.position
	_run_main_ticks(20)
	var follows_caster := is_equal_approx(outside_before - outside.hp, float(skill.damage))
	_run_main_ticks(20)
	var three_second_timeline: bool = (
		is_equal_approx(target_before - target.hp, float(skill.damage) * 3.0)
		and is_equal_approx(outside_before - outside.hp, float(skill.damage) * 2.0)
		and is_equal_approx(air.hp, air_before)
		and _main._active_skill_effect_system.continuous_area_effects.is_empty()
		and is_zero_approx(garen.active_skill_cast_timer)
	)
	_expect(
		StringName(skill.get("kind", "")) == &"continuous_area"
		and is_equal_approx(float(skill.get("duration", 0.0)), 3.0)
		and is_equal_approx(float(skill.get("tick_interval", 0.0)), 1.0)
		and animation_ok and cast_locks_ok and moved_during_cast and no_immediate_damage
		and no_early_pulse and first_pulse and follows_caster and three_second_timeline,
		"盖伦审判播放 Spell3_0 3 秒；每秒按施法者当前位置造成环形伤害，只锁攻击并允许移动，地面目标可被跟随命中而空中目标不受影响",
	)
	_main._active_skill_effect_system.continuous_area_effects.clear()
	_main._active_skill_effect_system.frontal_effects.clear()
	movement_anchor.free()
	for unit in [garen, target, outside, air]:
		if is_instance_valid(unit):
			unit.free()

func _check_masteryi_double_strike_and_highlander() -> void:
	var yi := _spawn_test_unit("masteryi", 0, Vector2(520.0, 900.0))
	var target := _spawn_dummy(Vector2(520.0, 850.0))
	yi._target = target
	yi._attacking = true
	yi._attack_hit_index = 2
	yi.attack_timeline.windup = 0.0
	yi.attack_timeline.cooldown = 0.0
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
	var skill: Dictionary = CardDB.active_skills_for("masteryi")[0]
	yi.attack_timeline.cooldown = 0.7
	yi.attack_timeline.windup = 0.18
	yi.apply_slow(2.0, 0.5)
	yi.apply_attack_speed_slow(2.0, 0.5)
	var slow_preexisting := yi.control.slow_timer > 0.0 and yi.control.attack_speed_slow_timer > 0.0
	_main._active_skill_effect_system.apply(yi, skill)
	var haste_mechanics := (
		is_equal_approx(yi.attack_interval, 0.7)
		and is_equal_approx(yi.active_speed_multiplier, 1.5)
		and is_equal_approx(yi.active_attack_speed_multiplier, 1.4)
		and is_equal_approx(yi.attack_timeline.cooldown, 0.7 / 1.4)
		and is_equal_approx(yi.attack_timeline.windup, 0.18 / 1.4)
		and is_equal_approx(yi._next_attack_gap(), 0.5)
	)
	var slow_timer_before_refresh := yi.control.slow_timer
	var attack_speed_slow_timer_before_refresh := yi.control.attack_speed_slow_timer
	yi.apply_slow(2.0, 0.5)
	yi.apply_attack_speed_slow(2.0, 0.5)
	var slow_ignored := (
		slow_preexisting
		and is_equal_approx(yi.control.slow_timer, slow_timer_before_refresh)
		and is_equal_approx(yi.control.attack_speed_slow_timer, attack_speed_slow_timer_before_refresh)
	)
	yi._prepare_movement(Vector2.UP, 0.05)
	slow_ignored = slow_ignored and is_equal_approx(yi._move_intent.length(), yi.move_speed * 1.5)
	_main._battle_presentation.attach_unit(yi, CardDB.get_card("masteryi"))
	var view := _view_for(yi)
	var haste_visual := false
	var haste_run := false
	var passive_attack := false
	var shortened_attack := false
	var visual_speed := -1.0
	var expected_visual_speed := -1.0
	if view != null:
		yi._attacking = false
		yi._move_intent = Vector2.UP * yi.move_speed * yi.active_speed_multiplier
		view._sync_visual(false, 0.05)
		haste_run = view._animation_player.current_animation == "2013_Run_Haste"
		yi._attacking = true
		yi._move_intent = Vector2.ZERO
		view._play_attack(3)
		view._sync_visual(false, 0.05)
		passive_attack = view._animation_player.current_animation == "masteryi_2013_passive_anm"
		var attack_animation := view._animation_player.get_animation("masteryi_2013_passive_anm")
		visual_speed = view._animation_player.get_playing_speed()
		expected_visual_speed = attack_animation.length / yi.attack_interval * yi.active_attack_speed_multiplier if attack_animation != null else -1.0
		shortened_attack = attack_animation != null and is_equal_approx(visual_speed, expected_visual_speed)
		haste_visual = haste_run and passive_attack and shortened_attack
	_expect(haste_mechanics and slow_ignored and haste_visual, "剑圣基础攻击间隔为 0.7 秒，高原血统将间隔缩短为 0.5 秒并免疫减速/减攻速，移动使用 2013 Run Haste，三段攻击动画同步缩短")
	yi._tick_active_statuses(5.0)
	_expect(is_equal_approx(yi.active_speed_multiplier, 1.0) and is_equal_approx(yi.active_attack_speed_multiplier, 1.0) and not yi.active_buff_ignores_movement_slow and not yi.active_buff_ignores_attack_speed_slow, "剑圣高原血统在 5 秒后恢复基础速度与攻速及控制抗性")
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
		sett_view._transition_to_basic_state(2, -1.0, &"attack")
		var first_to_passive_run := (
			sett_view._animation_player.current_animation == "Run_Passive"
			and is_equal_approx(sett_view._last_clip_blend_time, sett_view._transition_blend(&"action_out"))
		)
		sett._attacking = true
		sett_view._play_attack(2)
		sett_view._update_attack_stages(sett.first_hit_time)
		sett._attacking = false
		sett_view._transition_to_basic_state(2, -1.0, &"attack")
		var second_transition := (
			sett_view._animation_player.current_animation == "Sett_Passive_INTO_Run_anm"
			and is_equal_approx(sett_view._last_clip_blend_time, sett_view._transition_blend(&"sequence"))
		)
		sett_view._on_animation_finished(&"Sett_Passive_INTO_Run_anm")
		var second_to_base_run := (
			sett_view._animation_player.current_animation == "Run_Base"
			and is_equal_approx(sett_view._last_clip_blend_time, sett_view._transition_blend(&"sequence"))
		)
		sett_routes = (
			first_to_passive_run and second_transition and second_to_base_run
		)

		sett.play_visual_action(&"active", 1.4)
		sett_view._sync_visual(false, 0.05)
		var skill_entry_ok: bool = is_equal_approx(sett_view._last_clip_blend_time, 0.1)
		sett._move_intent = Vector2.UP * sett.move_speed
		sett_view._on_animation_finished(&"Sett_spell2_anm")
		sett_view._on_animation_finished(&"Sett_spell2_anm")
		sett_skill_route = (
			skill_entry_ok
			and sett_view._animation_player.current_animation == "Sett_Spell2_INTO_Run_anm"
			and is_equal_approx(sett_view._animation_player.current_animation_position, 0.4)
		)
		sett_view._on_animation_finished(&"Sett_Spell2_INTO_Run_anm")
		sett_skill_route = sett_skill_route and sett_view._animation_player.current_animation == "Run_Base"
	_expect(sett_routes, "腕豪第二拳无下一目标时先接 Sett Passive Into Run 再进入 Run Base，第一拳直接接 Run Passive")
	_expect(sett_skill_route, "腕豪普通 W 结束从匹配站姿的 ToRun 起点衔接，然后进入 Run Base")

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

func _check_ashe_arrow_collision() -> void:
	var skill: Dictionary = CardDB.active_skills_for("ashe")[0]
	for team in [0, 1]:
		var forward := Vector2.UP if team == 0 else Vector2.DOWN
		var source := _spawn_test_unit("ashe", team, Vector2(360, 850 if team == 0 else 430))
		var front := _spawn_dummy(source.position + forward * 80.0, 1 - team)
		var rear := _spawn_dummy(source.position + forward * 150.0, 1 - team)
		var side := _spawn_dummy(source.position + forward.rotated(deg_to_rad(23.65)) * 150.0, 1 - team)
		front.body_radius = 24.0
		rear.body_radius = 10.0
		side.body_radius = 10.0
		var hp := front.hp
		var hit_count := source._attack_swing_count
		_main._active_skill_effect_system.apply_frontal(source, skill, forward)
		var no_instant_hit := front.hp == hp and rear.hp == hp and side.hp == hp
		# 单 Tick 跨过所有对象仍必须取沿路径最近碰撞，不能穿透前排。
		_main._tick_projectiles(0.25)
		_expect(no_instant_hit and front.hp == hp - 70.0 and rear.hp == hp and side.hp == hp - 70.0 and source._attack_swing_count == hit_count, "阵营 %d：W 飞行后前排挡住后排，多箭命中仅伤害一次，未受阻侧箭仍可命中且不计普攻" % team)
		_main._active_skill_effect_system.apply_frontal(source, skill, forward)
		_main._tick_projectiles(0.25)
		_expect(front.hp == hp - 140.0 and rear.hp == hp, "下一次 W 有独立命中记录，前排仍持续阻挡")
		front.free()
		rear.free()
		side.free()
		# 单箭精确检查新增射程和到达上限后的清理。
		var single := skill.duplicate(true)
		single.projectile_count = 1
		var far := _spawn_dummy(source.position + forward * (source.body_radius + 205.0), 1 - team)
		far.body_radius = 2.0
		_main._active_skill_effect_system.apply_frontal(source, single, forward)
		source.free() # 已飞出的技能仍能碰撞、伤害和按固化来源发声。
		_main._tick_projectiles(0.25)
		_expect(far.hp == hp - 70.0, "阵营 %d：210 射程能命中旧 190 射程外目标，施法者销毁不取消在途箭" % team)
		far.free()
	var invalid := CardDB.get_card("ashe").duplicate(true)
	invalid.active_skills[0].projectile_flight_duration = 0.0
	var errors := PackedStringArray()
	CardDB.VALIDATOR._validate_active_skills("arrow_probe", invalid, errors)
	_expect("projectile_stop_on_hit" in "\n".join(errors), "非穿透扇形弹体要求有效飞行时长，非法配置由 validator 拒绝")

func _check_piercing_cards() -> void:
	var skill: Dictionary = CardDB.active_skills_for("twisted_fate")[0]
	for team in [0, 1]:
		_main._projectile_system.clear_all()
		var forward := Vector2.UP if team == 0 else Vector2.DOWN
		var source := _spawn_test_unit("twisted_fate", team, Vector2(360, 850 if team == 0 else 430))
		var front := _spawn_dummy(source.position + forward * 75.0, 1 - team)
		var rear := _spawn_dummy(source.position + forward * 160.0, 1 - team)
		var gap := _spawn_dummy(source.position + forward.rotated(deg_to_rad(12.0)) * 150.0, 1 - team)
		var friend := _spawn_dummy(source.position + forward * 50.0, team)
		front.body_radius = 30.0 # 三张牌可能重叠，整次施法仍只伤害一次。
		rear.body_radius = 5.0
		gap.body_radius = 2.0
		friend.body_radius = 5.0
		var hp := front.hp
		var hits: Array = []
		var on_hit := func(_source, action, position):
			if action == "wild_cards": hits.append(position)
		_main._projectile_system.skill_hit.connect(on_hit)
		_main._active_skill_effect_system.apply_frontal(source, skill, forward)
		var launched: bool = _main._projectiles.size() == 3 and front.hp == hp and hits.is_empty()
		for projectile in _main._projectiles.values():
			launched = launched and projectile.visual == &"card"
		_main._tick_projectiles(0.2)
		_expect(launched and front.hp == hp - 100.0 and rear.hp == hp and hits.size() == 1, "阵营 %d：卡牌 Q 发射不扣血，飞到前排才伤害并发声，重叠三牌不重复伤害" % team)
		source.free()
		_main._tick_projectiles(1.0) # 跨过后排和射程末端，验证扫掠与来源独立。
		_expect(rear.hp == hp - 100.0 and front.hp == hp - 100.0 and gap.hp == hp and friend.hp == hp and hits.size() == 2 and _main._projectiles.is_empty(), "阵营 %d：穿透前排继续命中后排，空隙/友军不受伤，死后在途仍有效且到射程清理" % team)
		_main._projectile_system.skill_hit.disconnect(on_hit)
		for unit in [front, rear, gap, friend]: unit.free()
	var invalid := CardDB.get_card("twisted_fate").duplicate(true)
	invalid.active_skills[0].projectile_stop_on_hit = true
	var errors := PackedStringArray()
	CardDB.VALIDATOR._validate_active_skills("pierce_probe", invalid, errors)
	_expect(not errors.is_empty(), "穿透与命中停止互斥，validator 拒绝冲突配置")
