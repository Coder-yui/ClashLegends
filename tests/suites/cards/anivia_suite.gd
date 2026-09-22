class_name AniviaSuite
extends "res://tests/suites/battle_suite.gd"
## 艾尼维亚领域回归：冰雪风暴固定落区、三秒持续伤害/减速、小冰锥弹体与蛋形态复生。

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_card_config_and_visuals()
	_check_frost_storm_zone()
	_check_rebirth_egg()

func _check_card_config_and_visuals() -> void:
	var stats := CardDB.get_unit_stats("anivia")
	var animations: Dictionary = stats.get("visual_animations", {})
	var actions: Dictionary = animations.get("visual_actions", {})
	var frost_storm: Dictionary = actions.get("frost_storm", {})
	var skill: Dictionary = stats.get("active_skills", [])[0]
	var visual_scene := load(String(stats.get("visual_scene_path", ""))) as PackedScene
	var visual_sample := visual_scene.instantiate() as Node3D if visual_scene != null else null
	var model_node := visual_sample.get_node_or_null("Model") as Node3D if visual_sample != null else null
	var player := SuiteUtils.find_anim_player(visual_sample) if visual_sample != null else null
	_expect(
		bool(stats.get("is_air", false))
		and bool(stats.get("can_attack_air", false))
		and is_equal_approx(float(stats.get("range", 0.0)), 190.0)
		and is_equal_approx(float(stats.get("interval", 0.0)), 1.7)
		and StringName(stats.get("projectile_visual", "")) == &"ice_cone"
		and CardArt.texture_for("anivia") != null,
		"冰晶凤凰是远程空军、攻速较慢，并使用小冰锥普通攻击弹体且已有卡面",
	)
	_expect(
		model_node != null
		and is_equal_approx(model_node.scale.x, 0.011385)
		and is_equal_approx(model_node.scale.y, 0.011385)
		and String(animations.get("deploy", "")) == "Idle1"
		and String(animations.get("idle", "")) == "Idle1"
		and String(animations.get("move", "")) == "Run"
		and animations.get("attack", []) == ["Attack1", "Attack2"]
		and String(frost_storm.get("animation", "")) == "Spell4"
		and player != null and player.has_animation("Spell4")
		and is_equal_approx(float(frost_storm.get("durations", [0.0])[0]), 1.166667),
		"冰晶凤凰模型使用 Idle1/Run/Attack1-2，冰雪风暴使用 Spell4",
	)
	_expect(
		StringName(skill.get("kind", "")) == &"forward_area"
		and int(skill.get("cost", 0)) == 2
		and int(skill.get("max_uses", 0)) == 1
		and skill.get("cast_locks", []) == ["movement", "attack", "facing"]
		and is_equal_approx(float(skill.get("impact_delay", 0.0)), 0.72)
		and is_equal_approx(float(skill.get("cast_duration", 0.0)), 1.17)
		and is_equal_approx(float(skill.get("zone_duration", 0.0)), 3.0)
		and is_equal_approx(float(skill.get("zone_tick_interval", 0.0)), 1.0)
		and int(stats.get("death_replacement_charges", 0)) == 1
		and String(stats.get("death_replacement_visual_transition", "")) == "drop",
		"冰雪风暴按 Spell4 合理时刻落地，施法锁定三项操作且区域独立持续 3 秒",
	)
	_expect(
		String(CardDB.get_unit_stats("anivia_egg").get("timed_revival_visual_transition", "")) == "rebirth",
		"凤凰替身使用通用落地过渡，凤凰蛋复生使用通用升起过渡",
	)
	if visual_sample != null:
		visual_sample.free()

func _check_frost_storm_zone() -> void:
	var skill: Dictionary = CardDB.active_skills_for("anivia")[0]
	var phoenix: Unit = _main._spawn_unit(0, "anivia", Vector2(360.0, 1000.0), 0.0)
	var target := _spawn_dummy(Vector2(360.0, 875.0), 1)
	var target_before := target.hp
	phoenix.begin_active_skill_cast(float(skill.cast_duration), Vector2.UP, skill.cast_locks)
	phoenix.play_visual_action(&"frost_storm", float(skill.cast_duration))
	var frontal_visual_count_before: int = _main._active_skill_effect_system.frontal_effects.size()
	_main._active_skill_effect_system.begin_forward_area_visual(phoenix, skill, Vector2.UP)
	var no_preimpact_star_visual: bool = _main._active_skill_effect_system.frontal_effects.size() == frontal_visual_count_before
	_main._active_skill_effect_system.apply_forward_area(phoenix, skill, Vector2.UP)
	var initial_damage := target_before - target.hp
	var locked: bool = phoenix.is_active_skill_movement_locked() and phoenix.is_active_skill_attack_locked() and phoenix.is_active_skill_facing_locked()
	var zone_created: bool = _main._active_skill_effect_system.continuous_area_effects.size() == 1
	var initial_slow: bool = target.control.slow_timer > 0.0 and is_equal_approx(target.control.slow_multiplier, 0.65)
	_expect(
		locked and no_preimpact_star_visual and zone_created and is_equal_approx(initial_damage, 90.0) and initial_slow
		and is_equal_approx(phoenix.get_visual_action_duration(), 1.17),
		"冰雪风暴不提前播放星体落点特效，在 Spell4 期间锁定三项操作并于 Impact 直接生成区域",
	)
	var after_initial := target.hp
	phoenix.stun(2.0)
	phoenix.freeze(2.0)
	phoenix.apply_knockback(phoenix.position + Vector2.DOWN, 45.0, 0.4)
	phoenix.position += Vector2.RIGHT * 300.0
	_main._active_skill_effect_system.tick_effects(1.0)
	var pulse_damage := after_initial - target.hp
	_main._active_skill_effect_system.tick_effects(1.0)
	_main._active_skill_effect_system.tick_effects(1.0)
	_expect(
		is_equal_approx(pulse_damage, 42.0)
		and _main._active_skill_effect_system.continuous_area_effects.is_empty(),
		"冰雪风暴创建后不受施法者眩晕、冰冻、击退与移动影响，固定落点每秒伤害并在 3 秒后消失",
	)

	# 区域是固定落点；凤凰死亡后，已经创造的冰雪风暴仍应完成剩余寿命。
	phoenix.position = Vector2(360.0, 1000.0)
	var second_target: Unit = _spawn_dummy(Vector2(360.0, 875.0), 1)
	_main._active_skill_effect_system.apply_forward_area(phoenix, skill, Vector2.UP)
	var phoenix_died_visual := false
	phoenix.died.connect(func(): phoenix_died_visual = true)
	phoenix.take_damage(phoenix.hp + 1.0)
	if is_instance_valid(phoenix) and phoenix.is_queued_for_deletion():
		phoenix.free()
	var phoenix_egg := _find_unit("anivia_egg", 0)
	var second_before := second_target.hp
	_main._active_skill_effect_system.tick_effects(1.0)
	_expect(
		second_before - second_target.hp > 0.0
		and _main._active_skill_effect_system.continuous_area_effects.size() == 1
		and not phoenix_died_visual,
		"冰雪风暴落地后与施法者解绑，凤凰死亡不播死亡动画且区域不会提前清除",
	)
	_cleanup([target, second_target, phoenix_egg])

func _check_rebirth_egg() -> void:
	var phoenix: Unit = _main._spawn_unit(0, "anivia", Vector2(260.0, 1000.0), 0.0)
	var max_hp: float = phoenix.max_hp
	phoenix.take_damage(max_hp + 1.0)
	var egg := _find_unit("anivia_egg", 0)
	var expected_egg_hp := float(CardDB.PRINCESS_TOWER_STATS.damage) * 3.0
	_expect(
		is_instance_valid(egg)
		and not egg.is_air
		and egg.visual_spawn_transition == &"drop"
		and is_equal_approx(egg.max_hp, expected_egg_hp)
		and is_equal_approx(egg.hp, expected_egg_hp),
		"冰晶凤凰第一条血耗尽后变为地面蛋，蛋血量等于防御塔三次攻击",
	)
	var egg_died_visual := false
	egg.died.connect(func(): egg_died_visual = true)
	for _tick in range(59):
		egg.sim_tick(_main.SIM_DT)
	var not_yet_reborn := _find_unit("anivia", 0) == null
	egg.sim_tick(_main.SIM_DT)
	var revived := _find_unit("anivia", 0)
	_expect(
		not_yet_reborn and is_instance_valid(revived) and is_equal_approx(revived.hp, revived.max_hp)
		and is_equal_approx(revived.max_hp, max_hp)
		and revived.visual_spawn_transition == &"rebirth"
		and revived.death_replacement_charges == 0
		and not egg_died_visual,
		"蛋连续 3 秒未被击破后不播蛋死亡动画，生成满血并升起且不再复活的冰晶凤凰",
	)
	if is_instance_valid(revived):
		revived.take_damage(revived.max_hp + 1.0)
	_expect(
		_find_unit("anivia_egg", 0) == null,
		"凤凰复活后再次死亡不会生成第二枚蛋",
	)
	if is_instance_valid(egg) and egg.is_queued_for_deletion():
		egg.free()
	if is_instance_valid(revived):
		revived.free()

	var killable_phoenix: Unit = _main._spawn_unit(0, "anivia", Vector2(460.0, 1000.0), 0.0)
	killable_phoenix.take_damage(killable_phoenix.max_hp + 1.0)
	var killable_egg := _find_unit("anivia_egg", 0)
	var egg_hp := killable_egg.hp
	killable_egg.take_damage(egg_hp + 1.0)
	_expect(
		_find_unit("anivia", 0) == null,
		"蛋在 3 秒内被击破时不会复活凤凰",
	)
	if is_instance_valid(killable_egg) and killable_egg.is_queued_for_deletion():
		killable_egg.free()

func _spawn_dummy(pos: Vector2, p_team: int) -> Unit:
	var dummy := Unit.new()
	var stats := SuiteUtils.sweep_dummy_stats(CardDB.get_card("garen"))
	stats["deploy_time"] = 0.0
	stats["hp"] = 1200.0
	dummy.position = pos
	dummy.setup(p_team, stats, "冰雪风暴木桩")
	_main.add_child(dummy)
	return dummy

func _find_unit(card_id: String, p_team: int) -> Unit:
	for combatant in _main.get_tree().get_nodes_in_group("combatants"):
		if combatant is Unit and combatant.card_id == card_id and combatant.team == p_team:
			return combatant as Unit
	return null

func _cleanup(units: Array) -> void:
	for unit in units:
		if is_instance_valid(unit):
			unit.free()
	_main._active_skill_effect_system.continuous_area_effects.clear()
