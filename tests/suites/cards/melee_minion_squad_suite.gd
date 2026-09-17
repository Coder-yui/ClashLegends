extends "res://tests/suites/battle_suite.gd"


func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var stats := CardDB.get_unit_stats("melee_minion_squad")
	var skill: Dictionary = stats.active_skills[0]
	var member_ids: Array = stats.deployment_member_ids
	_expect(
		stats.cost == 2
		and member_ids.size() == 4
		and member_ids.all(func(member_id): return member_id == "melee_minion")
		and stats.deployment_formation == &"square",
		"近战兵小队为2费、4只近战兵的正方形编队",
	)
	_expect(
		skill.name == &"男爵之力"
		and skill.cost == 1
		and skill.max_uses == 2
		and is_equal_approx(float(skill.cooldown), 5.0)
		and skill.target_scope == &"deployment_group"
		and bool(skill.copy_member_buff),
		"近战兵小队男爵之力消耗1金币并复用近战兵技能配置",
	)
	_expect(CardArt.texture_for("melee_minion_squad") != null, "近战兵小队已有3D摄影卡面")

	var old_deck: Array = main._deck.duplicate()
	var old_skill_choices: Dictionary = main._active_skill_choices.duplicate(true)
	main._deck = ["melee_minion_squad", "garen", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	main._active_skill_choices["melee_minion_squad"] = 0
	var group: Array[Unit] = main._spawn_card_units(0, "melee_minion_squad", Vector2(360, 1020), 0.0, 0)
	var group_id := group[0].deployment_group_id if not group.is_empty() else -1
	var offsets: Array[Vector2] = main._deployment_formation_offsets(4, 28.0, 0, "square")
	var expected_positions := {}
	for offset in offsets:
		expected_positions[Vector2(360, 1020) + offset] = true
	var positions_match := group.size() == 4 and group.all(func(member): return expected_positions.has(member.position))
	var same_group := group.size() == 4 and group.all(func(member): return member.deployment_group_id == group_id)
	var edge_parallel_to_river := offsets.size() == 4 and (is_equal_approx(offsets[0].y, offsets[3].y) or is_equal_approx(offsets[1].y, offsets[2].y))
	_expect(positions_match and same_group and edge_parallel_to_river, "四名近战兵紧凑占据正方形四个顶点，且正方形边平行于河道")
	_expect(group.size() == 4 and group.all(func(member): return member.card_id == "melee_minion"), "编队成员继续使用近战兵战斗数据")

	var dead_before_cast := group[3]
	dead_before_cast.take_damage(10000.0)
	main._active_skill_effect_system.apply(group[0], skill)
	var copied_effects := group.all(func(member):
		return member.hp <= 0.0 or (
			is_equal_approx(member.active_speed_multiplier, 1.35)
			and is_equal_approx(member.active_damage_multiplier, 1.25)
			and is_equal_approx(member.active_buff_timer, 4.0)
		)
	)
	_expect(copied_effects and is_equal_approx(dead_before_cast.active_buff_timer, 0.0), "男爵之力只作用于本次下牌中仍存活的近战兵")

	var ability_id := group[0].active_ability_id
	group[0].take_damage(10000.0)
	var transferred: bool = main._active_skills.has(ability_id) and main._active_skills[ability_id].unit != group[0]
	var replacement: Unit = main._active_skills[ability_id].unit if transferred else null
	transferred = transferred and replacement.deployment_group_id == group_id and replacement.active_skill_card_id == "melee_minion_squad"
	_expect(transferred, "主动资格在队长死亡后转交给同一编队成员")
	var activated: bool = transferred and main._activate_active_skill(ability_id, 0)
	_expect(activated, "转交后的男爵之力仍可正常施放")

	if main._active_skills.has(ability_id):
		main._active_skills.erase(ability_id)
		if main._active_skill_bar != null:
			main._active_skill_bar.remove_skill(ability_id)
	for member in group:
		if is_instance_valid(member):
			member.free()
	main._deck = old_deck
	main._active_skill_choices = old_skill_choices
