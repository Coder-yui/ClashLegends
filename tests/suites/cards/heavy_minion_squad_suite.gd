extends "res://tests/suites/battle_suite.gd"


func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var stats := CardDB.get_unit_stats("heavy_minion_squad")
	var skill: Dictionary = stats.active_skills[0]
	var member_ids: Array = stats.deployment_member_ids
	_expect(
		stats.cost == 5
		and member_ids == ["super_minion", "siege_minion"]
		and stats.deployment_count == 2
		and is_equal_approx(float(stats.deployment_spacing), 100.0)
		and stats.deployment_formation == &"depth_line",
		"重装部队为5费、超级兵前置与炮车兵后置的2.5格纵列",
	)
	_expect(
		skill.name == &"男爵之力"
		and skill.cost == 2
		and skill.max_uses == 1
		and is_equal_approx(float(skill.cooldown), 7.0)
		and skill.target_scope == &"deployment_group"
		and bool(skill.copy_member_buff),
		"重装部队共用超级兵男爵之力的施放门槛并按成员复用效果",
	)
	_expect(CardArt.texture_for("heavy_minion_squad") != null, "重装部队已有3D摄影卡面")

	var old_deck: Array = main._deck.duplicate()
	var old_skill_choices: Dictionary = main._active_skill_choices.duplicate(true)
	main._deck = ["heavy_minion_squad", "garen", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	main._active_skill_choices["heavy_minion_squad"] = 0
	# 远离己方水晶；中体型炮车在旧后排点1070会触发合法出生避让。
	var group: Array[Unit] = main._spawn_card_units(0, "heavy_minion_squad", Vector2(360, 940), 0.0, 0)
	var group_id := group[0].deployment_group_id if not group.is_empty() else -1
	var offsets: Array[Vector2] = main._deployment_formation_offsets(2, 100.0, 0, "depth_line")
	var expected_positions := {}
	for offset in offsets:
		expected_positions[Vector2(360, 940) + offset] = true
	var positions_match := group.size() == 2 and group.all(func(member): return expected_positions.has(member.position))
	var same_group := group.size() == 2 and group.all(func(member): return member.deployment_group_id == group_id)
	var front_back := offsets.size() == 2 and is_equal_approx(offsets[0].x, 0.0) and is_equal_approx(offsets[1].x, 0.0) and offsets[0].y < offsets[1].y
	_expect(positions_match and same_group and front_back, "超级兵在前、炮车兵在后，沿纵向间隔2.5格并共享编队身份")
	_expect(group.size() == 2 and group[0].card_id == "super_minion" and group[1].card_id == "siege_minion" and is_equal_approx(group[0].body_radius, CardDB.RADIUS_SLIGHTLY_LARGE) and is_equal_approx(group[1].body_radius, CardDB.RADIUS_MEDIUM), "重装编队超级兵使用稍大半径21，炮车使用中体型半径18")

	main._active_skill_effect_system.apply(group[0], skill)
	var copied_effects := (
		is_equal_approx(group[0].active_speed_multiplier, 1.35)
		and is_equal_approx(group[0].active_damage_multiplier, 1.35)
		and is_equal_approx(group[0].active_buff_timer, 5.0)
		and is_equal_approx(group[0].shield_hp, 140.0)
		and is_equal_approx(group[1].active_speed_multiplier, 1.0)
		and is_equal_approx(group[1].active_damage_multiplier, 1.5)
		and is_equal_approx(group[1].active_attack_speed_multiplier, 1.0)
		and is_equal_approx(group[1].active_buff_timer, 5.0)
	)
	_expect(copied_effects, "男爵之力按成员分别复用超级兵护盾增益与炮车兵伤害增益")

	var ability_id := group[0].active_ability_id
	group[0].take_damage(10000.0)
	var transferred: bool = main._active_skills.has(ability_id) and main._active_skills.entry(ability_id).unit != group[0]
	var replacement: Unit = main._active_skills.entry(ability_id).unit if transferred else null
	transferred = transferred and replacement.card_id == "siege_minion" and replacement.active_skill_card_id == "heavy_minion_squad"
	_expect(transferred, "主动资格在超级兵阵亡后转交给炮车兵")
	var activated: bool = transferred and main._activate_active_skill(ability_id, 0)
	var exhausted: bool = activated and int(main._active_skills.entry(ability_id).uses_remaining) == 0 and is_equal_approx(float(main._active_skills.entry(ability_id).cooldown_left), 7.0) and not main._activate_active_skill(ability_id, 0)
	_expect(exhausted, "重装部队男爵之力使用1次后进入7秒冷却并耗尽次数")

	if main._active_skills.has(ability_id):
		main._active_skills.remove(ability_id)
		if main._active_skill_bar != null:
			main._active_skill_bar.remove_skill(ability_id)
	for member in group:
		if is_instance_valid(member):
			member.free()
	main._deck = old_deck
	main._active_skill_choices = old_skill_choices
