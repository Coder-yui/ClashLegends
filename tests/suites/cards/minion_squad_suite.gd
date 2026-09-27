extends "res://tests/suites/battle_suite.gd"
## 六种编队的内容差异；共享资格生命周期在 deployment/ 中验证。

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_minion_squad(main)
	_check_melee_minion_squad(main)
	_check_ranged_minion_squad(main)
	_check_heavy_minion_squad(main)
	_check_super_minion_squad(main)
	_check_siege_minion_squad(main)

func _check_minion_squad(main: Node2D) -> void:
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

	# 转交、付款与次数由 DeploymentSkillSuite 统一覆盖。
	var ability_id := group[0].active_ability_id
	if main._active_skills.has(ability_id):
		main._active_skills.remove(ability_id)
		if main._active_skill_bar != null:
			main._active_skill_bar.remove_skill(ability_id)
	for member in group:
		if is_instance_valid(member):
			member.free()
	main._deck = old_deck
	main._active_skill_choices = old_skill_choices

func _check_melee_minion_squad(main: Node2D) -> void:
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

	# 转交、付款与次数由 DeploymentSkillSuite 统一覆盖。
	var ability_id := group[0].active_ability_id
	if main._active_skills.has(ability_id):
		main._active_skills.remove(ability_id)
		if main._active_skill_bar != null:
			main._active_skill_bar.remove_skill(ability_id)
	for member in group:
		if is_instance_valid(member):
			member.free()
	main._deck = old_deck
	main._active_skill_choices = old_skill_choices

func _check_ranged_minion_squad(main: Node2D) -> void:
	var stats := CardDB.get_unit_stats("ranged_minion_squad")
	var skill: Dictionary = stats.active_skills[0]
	var member_ids: Array = stats.deployment_member_ids
	_expect(
		stats.cost == 2
		and member_ids.size() == 3
		and member_ids.all(func(member_id): return member_id == "ranged_minion")
		and stats.deployment_formation == &"polygon",
		"远程兵小队为2费、3只远程兵的三角形编队",
	)
	_expect(
		skill.name == &"男爵之力"
		and skill.cost == 1
		and skill.max_uses == 2
		and is_equal_approx(float(skill.cooldown), 5.0)
		and skill.target_scope == &"deployment_group"
		and bool(skill.copy_member_buff),
		"远程兵小队男爵之力消耗1金币并复用远程兵技能配置",
	)

	var old_deck: Array = main._deck.duplicate()
	var old_skill_choices: Dictionary = main._active_skill_choices.duplicate(true)
	main._deck = ["ranged_minion_squad", "garen", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	main._active_skill_choices["ranged_minion_squad"] = 0
	var group: Array[Unit] = main._spawn_card_units(0, "ranged_minion_squad", Vector2(360, 1020), 0.0, 0)
	var group_id := group[0].deployment_group_id if not group.is_empty() else -1
	var offsets: Array[Vector2] = main._deployment_formation_offsets(3, 24.0, 0, "polygon")
	var expected_positions := {}
	for offset in offsets:
		expected_positions[Vector2(360, 1020) + offset] = true
	var positions_match := group.size() == 3 and group.all(func(member): return expected_positions.has(member.position))
	var same_group := group.size() == 3 and group.all(func(member): return member.deployment_group_id == group_id)
	var triangle_orientation := offsets.size() == 3 and is_equal_approx(offsets[0].x, 0.0) and is_equal_approx(offsets[1].y, offsets[2].y) and offsets[0].y < offsets[1].y
	_expect(positions_match and same_group and triangle_orientation, "三名远程兵紧凑占据三角形顶点，前1后2并共享编队身份")
	_expect(group.size() == 3 and group.all(func(member): return member.card_id == "ranged_minion"), "编队成员继续使用远程兵战斗数据")

	var dead_before_cast := group[2]
	dead_before_cast.take_damage(10000.0)
	main._active_skill_effect_system.apply(group[0], skill)
	var copied_effects := group.all(func(member):
		return member.hp <= 0.0 or (
			is_equal_approx(member.active_speed_multiplier, 1.0)
			and is_equal_approx(member.active_damage_multiplier, 1.25)
			and is_equal_approx(member.active_attack_speed_multiplier, 1.25)
			and is_equal_approx(member.active_buff_timer, 5.0)
		)
	)
	_expect(copied_effects and is_equal_approx(dead_before_cast.active_buff_timer, 0.0), "男爵之力只作用于本次下牌中仍存活的远程兵")

	# 转交、付款与次数由 DeploymentSkillSuite 统一覆盖。
	var ability_id := group[0].active_ability_id
	if main._active_skills.has(ability_id):
		main._active_skills.remove(ability_id)
		if main._active_skill_bar != null:
			main._active_skill_bar.remove_skill(ability_id)
	for member in group:
		if is_instance_valid(member):
			member.free()
	main._deck = old_deck
	main._active_skill_choices = old_skill_choices

func _check_heavy_minion_squad(main: Node2D) -> void:
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

	# 转交、付款与次数由 DeploymentSkillSuite 统一覆盖。
	var ability_id := group[0].active_ability_id
	if main._active_skills.has(ability_id):
		main._active_skills.remove(ability_id)
		if main._active_skill_bar != null:
			main._active_skill_bar.remove_skill(ability_id)
	for member in group:
		if is_instance_valid(member):
			member.free()
	main._deck = old_deck
	main._active_skill_choices = old_skill_choices

func _check_super_minion_squad(main: Node2D) -> void:
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
	_expect(group.size() == 2 and group.all(func(member): return member.card_id == "super_minion" and is_equal_approx(member.body_radius, CardDB.RADIUS_SLIGHTLY_LARGE)), "编队成员使用超级兵战斗数据和稍大碰撞半径21")

	main._active_skill_effect_system.apply(group[0], skill)
	var copied_effects := group.all(func(member):
		return is_equal_approx(member.active_speed_multiplier, 1.35) \
			and is_equal_approx(member.active_damage_multiplier, 1.35) \
			and is_equal_approx(member.active_buff_timer, 5.0) \
			and is_equal_approx(member.shield_hp, 140.0)
	)
	_expect(copied_effects, "男爵之力为本次部署中两只仍存活的超级兵复用移速、伤害与护盾效果")

	# 转交、付款与次数由 DeploymentSkillSuite 统一覆盖。
	var ability_id := group[0].active_ability_id
	if main._active_skills.has(ability_id):
		main._active_skills.remove(ability_id)
		if main._active_skill_bar != null:
			main._active_skill_bar.remove_skill(ability_id)
	for member in group:
		if is_instance_valid(member):
			member.free()
	main._deck = old_deck
	main._active_skill_choices = old_skill_choices

func _check_siege_minion_squad(main: Node2D) -> void:
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

	# 转交、付款与次数由 DeploymentSkillSuite 统一覆盖。
	var ability_id := group[0].active_ability_id
	if main._active_skills.has(ability_id):
		main._active_skills.remove(ability_id)
		if main._active_skill_bar != null:
			main._active_skill_bar.remove_skill(ability_id)
	for member in group:
		if is_instance_valid(member):
			member.free()
	main._deck = old_deck
	main._active_skill_choices = old_skill_choices
