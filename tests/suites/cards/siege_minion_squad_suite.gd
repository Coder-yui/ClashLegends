extends "res://tests/suites/battle_suite.gd"


func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var stats := CardDB.get_unit_stats("siege_minion_squad")
	var skill: Dictionary = stats.active_skills[0]
	var member_ids: Array = stats.deployment_member_ids
	_expect(
		stats.cost == 7
		and member_ids == ["siege_minion", "siege_minion", "siege_minion"]
		and stats.deployment_count == 3
		and stats.deployment_formation == &"polygon",
		"炮车部队为7费、3只炮车兵的三角形编队",
	)
	_expect(
		skill.name == &"男爵之力"
		and skill.cost == 3
		and skill.max_uses == 1
		and is_equal_approx(float(skill.cooldown), 8.0)
		and skill.target_scope == &"deployment_group"
		and bool(skill.copy_member_buff),
		"炮车部队消耗3金币、可用1次并复用炮车兵男爵之力",
	)
	_expect(CardArt.texture_for("siege_minion_squad") != null, "炮车部队已有3D摄影卡面")

	var old_deck: Array = main._deck.duplicate()
	var old_skill_choices: Dictionary = main._active_skill_choices.duplicate(true)
	main._deck = ["siege_minion_squad", "garen", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	main._active_skill_choices["siege_minion_squad"] = 0
	var group: Array[Unit] = main._spawn_card_units(0, "siege_minion_squad", Vector2(360, 1020), 0.0, 0)
	var group_id := group[0].deployment_group_id if not group.is_empty() else -1
	var radius := float(stats.deployment_spacing)
	var offsets: Array[Vector2] = main._deployment_formation_offsets(3, radius, 0, "polygon")
	var expected_positions := {}
	for offset in offsets:
		expected_positions[Vector2(360, 1020) + offset] = true
	var positions_match := group.size() == 3 and group.all(func(member): return expected_positions.has(member.position))
	var same_group := group.size() == 3 and group.all(func(member): return member.deployment_group_id == group_id)
	var edge_lengths := []
	for first in offsets.size():
		for second in range(first + 1, offsets.size()):
			edge_lengths.append(offsets[first].distance_to(offsets[second]))
	var triangle := edge_lengths.size() == 3 and edge_lengths.all(func(length): return absf(length - 60.0) <= 0.01)
	_expect(positions_match and same_group and triangle, "三只炮车兵位于三角形顶点，三条边均为60像素并共享编队身份")
	_expect(group.size() == 3 and group.all(func(member): return member.card_id == "siege_minion"), "编队成员继续使用炮车兵战斗数据")

	var dead_before_cast := group[2]
	dead_before_cast.take_damage(10000.0)
	main._active_skill_effect_system.apply(group[0], skill)
	var copied_effects := group.all(func(member):
		return member.hp <= 0.0 or (
			is_equal_approx(member.active_damage_multiplier, 1.5)
			and is_equal_approx(member.active_buff_timer, 5.0)
		)
	)
	_expect(copied_effects and is_equal_approx(dead_before_cast.active_buff_timer, 0.0), "男爵之力只作用于本次部署中仍存活的炮车兵")

	var ability_id := group[0].active_ability_id
	group[0].take_damage(10000.0)
	var transferred: bool = main._active_skills.has(ability_id) and main._active_skills.entry(ability_id).unit != group[0]
	var replacement: Unit = main._active_skills.entry(ability_id).unit if transferred else null
	transferred = transferred and replacement.deployment_group_id == group_id and replacement.active_skill_card_id == "siege_minion_squad"
	_expect(transferred, "主动资格在队长死亡后转交给同一编队的炮车兵")
	var activated: bool = transferred and main._activate_active_skill(ability_id, 0)
	var exhausted: bool = activated and int(main._active_skills.entry(ability_id).uses_remaining) == 0 and not main._activate_active_skill(ability_id, 0)
	_expect(exhausted, "炮车部队男爵之力使用1次后耗尽")

	if main._active_skills.has(ability_id):
		main._active_skills.remove(ability_id)
		if main._active_skill_bar != null:
			main._active_skill_bar.remove_skill(ability_id)
	for member in group:
		if is_instance_valid(member):
			member.free()
	main._deck = old_deck
	main._active_skill_choices = old_skill_choices
