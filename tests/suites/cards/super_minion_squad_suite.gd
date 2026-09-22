extends "res://tests/suites/battle_suite.gd"


func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var stats := CardDB.get_unit_stats("super_minion_squad")
	var skill: Dictionary = stats.active_skills[0]
	var member_ids: Array = stats.deployment_member_ids
	_expect(
		stats.cost == 6
		and member_ids == ["super_minion", "super_minion"]
		and stats.deployment_count == 2
		and is_equal_approx(float(stats.deployment_spacing), 100.0)
		and stats.deployment_formation == &"line",
		"攻城部队为6费、两只超级兵并排且间隔2.5格",
	)
	_expect(
		skill.name == &"男爵之力"
		and skill.cost == 2
		and skill.max_uses == 1
		and is_equal_approx(float(skill.cooldown), 7.0)
		and skill.target_scope == &"deployment_group"
		and bool(skill.copy_member_buff),
		"攻城部队消耗2金币、可用1次并复用超级兵男爵之力",
	)
	_expect(CardArt.texture_for("super_minion_squad") != null, "攻城部队已有3D摄影卡面")

	var old_deck: Array = main._deck.duplicate()
	var old_skill_choices: Dictionary = main._active_skill_choices.duplicate(true)
	main._deck = ["super_minion_squad", "garen", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	main._active_skill_choices["super_minion_squad"] = 0
	var group: Array[Unit] = main._spawn_card_units(0, "super_minion_squad", Vector2(360, 1020), 0.0, 0)
	var group_id := group[0].deployment_group_id if not group.is_empty() else -1
	var offsets: Array[Vector2] = main._deployment_formation_offsets(2, 100.0, 0, "line")
	var expected_positions := {}
	for offset in offsets:
		expected_positions[Vector2(360, 1020) + offset] = true
	var positions_match := group.size() == 2 and group.all(func(member): return expected_positions.has(member.position))
	var same_group := group.size() == 2 and group.all(func(member): return member.deployment_group_id == group_id)
	var parallel := offsets.size() == 2 and is_equal_approx(offsets[0].y, 0.0) and is_equal_approx(offsets[1].y, 0.0) and is_equal_approx(offsets[0].distance_to(offsets[1]), 100.0)
	_expect(positions_match and same_group and parallel, "两只超级兵横向并排、中心间隔100像素并共享编队身份")
	_expect(group.size() == 2 and group.all(func(member): return member.card_id == "super_minion"), "编队成员继续使用超级兵战斗数据")

	main._active_skill_effect_system.apply(group[0], skill)
	var copied_effects := group.all(func(member):
		return is_equal_approx(member.active_speed_multiplier, 1.35) \
			and is_equal_approx(member.active_damage_multiplier, 1.35) \
			and is_equal_approx(member.active_buff_timer, 5.0) \
			and is_equal_approx(member.shield_hp, 140.0)
	)
	_expect(copied_effects, "男爵之力为本次部署中两只仍存活的超级兵复用移速、伤害与护盾效果")

	var ability_id := group[0].active_ability_id
	group[0].take_damage(10000.0)
	var transferred: bool = main._active_skills.has(ability_id) and main._active_skills.entry(ability_id).unit != group[0]
	var replacement: Unit = main._active_skills.entry(ability_id).unit if transferred else null
	transferred = transferred and replacement.deployment_group_id == group_id and replacement.active_skill_card_id == "super_minion_squad"
	_expect(transferred, "主动资格在队长死亡后转交给同一编队的超级兵")
	var activated: bool = transferred and main._activate_active_skill(ability_id, 0)
	var exhausted: bool = activated and int(main._active_skills.entry(ability_id).uses_remaining) == 0 and not main._activate_active_skill(ability_id, 0)
	_expect(exhausted, "攻城部队男爵之力使用1次后耗尽")

	if main._active_skills.has(ability_id):
		main._active_skills.remove(ability_id)
		if main._active_skill_bar != null:
			main._active_skill_bar.remove_skill(ability_id)
	for member in group:
		if is_instance_valid(member):
			member.free()
	main._deck = old_deck
	main._active_skill_choices = old_skill_choices
