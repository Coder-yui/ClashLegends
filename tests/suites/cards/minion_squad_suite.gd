extends "res://tests/suites/battle_suite.gd"


func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var stats := CardDB.get_unit_stats("minion_squad")
	var skill: Dictionary = stats.active_skills[0]
	var member_ids: Array = stats.deployment_member_ids
	_expect(
		stats.cost == 3
		and member_ids.size() == 6
		and member_ids.count("melee_minion") == 3
		and member_ids.count("ranged_minion") == 3
		and stats.deployment_formation == &"polygon",
		"小兵分队为3费、3近战兵+3远程兵的六边形六顶点编队",
	)
	_expect(
		skill.name == &"男爵之力"
		and skill.cost == 2
		and skill.max_uses == 1
		and is_equal_approx(float(skill.cooldown), 6.0)
		and skill.target_scope == &"deployment_group"
		and bool(skill.copy_member_buff),
		"小兵分队男爵之力为2费、每次部署1次、冷却6秒并复用成员技能效果",
	)
	_expect(CardArt.texture_for("minion_squad") != null, "小兵分队已有3D摄影卡面")

	var old_deck: Array = main._deck.duplicate()
	var old_skill_choices: Dictionary = main._active_skill_choices.duplicate(true)
	main._deck = ["minion_squad", "garen", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	main._active_skill_choices["minion_squad"] = 0
	var group: Array[Unit] = main._spawn_card_units(0, "minion_squad", Vector2(360, 1020), 0.0, 0)
	var group_id := group[0].deployment_group_id if not group.is_empty() else -1
	var offsets: Array[Vector2] = main._deployment_formation_offsets(6, 44.0, 0, "polygon")
	var expected_positions := {}
	for offset in offsets:
		expected_positions[Vector2(360, 1020) + offset] = true
	var positions_match := group.size() == 6 and group.all(func(member): return expected_positions.has(member.position))
	var same_group := group.size() == 6 and group.all(func(member): return member.deployment_group_id == group_id)
	_expect(positions_match and same_group, "六名成员各自占据确定的六边形顶点并共享编队身份")

	var melee: Array[Unit] = group.filter(func(member): return member.card_id == "melee_minion")
	var ranged: Array[Unit] = group.filter(func(member): return member.card_id == "ranged_minion")
	_expect(melee.size() == 3 and ranged.size() == 3, "编队成员继续使用近战兵与远程兵各自的战斗数据")

	var dead_before_cast := ranged[0]
	dead_before_cast.take_damage(10000.0)
	main._active_skill_effect_system.apply(group[0], skill)
	var copied_effects := melee.all(func(member): return member.hp <= 0.0 or (is_equal_approx(member.active_speed_multiplier, 1.35) and is_equal_approx(member.active_damage_multiplier, 1.25) and is_equal_approx(member.active_attack_speed_multiplier, 1.0) and is_equal_approx(member.active_buff_timer, 4.0)))
	copied_effects = copied_effects and ranged.all(func(member): return member.hp <= 0.0 or (is_equal_approx(member.active_speed_multiplier, 1.0) and is_equal_approx(member.active_damage_multiplier, 1.25) and is_equal_approx(member.active_attack_speed_multiplier, 1.25) and is_equal_approx(member.active_buff_timer, 5.0)))
	_expect(copied_effects and is_equal_approx(dead_before_cast.active_buff_timer, 0.0), "男爵之力按成员类型复用效果且只作用于本次部署仍存活成员")

	var ability_id := group[0].active_ability_id
	group[0].take_damage(10000.0)
	var transferred: bool = main._active_skills.has(ability_id) and main._active_skills.entry(ability_id).unit != group[0]
	var replacement: Unit = main._active_skills.entry(ability_id).unit if transferred else null
	transferred = transferred and replacement.deployment_group_id == group_id and replacement.active_skill_card_id == "minion_squad"
	_expect(transferred, "主动资格在队长死亡后转交给同一编队成员")
	var activated: bool = transferred and main._activate_active_skill(ability_id, 0)
	_expect(activated, "转交后的男爵之力仍可正常施放")
	var exhausted: bool = activated and int(main._active_skills.entry(ability_id).uses_remaining) == 0 and float(main._active_skills.entry(ability_id).cooldown_left) == 6.0 and not main._activate_active_skill(ability_id, 0)
	_expect(exhausted, "本次部署的男爵之力只可使用一次并进入6秒冷却")

	if main._active_skills.has(ability_id):
		main._active_skills.remove(ability_id)
		if main._active_skill_bar != null:
			main._active_skill_bar.remove_skill(ability_id)
	for member in group:
		if is_instance_valid(member):
			member.free()
	main._deck = old_deck
	main._active_skill_choices = old_skill_choices
