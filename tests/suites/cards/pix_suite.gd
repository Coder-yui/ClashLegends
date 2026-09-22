class_name PixSuite
extends "res://tests/suites/battle_suite.gd"


func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_card_data_and_art()
	_check_group_deployment_and_shared_skill()



func _check_card_data_and_art() -> void:
	var stats := CardDB.get_unit_stats("pix")
	var animations: Dictionary = stats.get("visual_animations", {})
	var skill: Dictionary = stats.get("active_skills", [])[0]
	var visual_scene := load(String(stats.get("visual_scene_path", ""))) as PackedScene
	var visual_sample := visual_scene.instantiate() as Node3D if visual_scene != null else null
	var model_node := visual_sample.get_node_or_null("Model") as Node3D if visual_sample != null else null
	_expect(
		int(stats.get("cost", 0)) == 2
		and int(stats.get("deployment_count", 0)) == 5
		and bool(stats.get("is_air", false))
		and StringName(stats.get("size_tier", "")) == CardDB.SIZE_EXTREMELY_SMALL
		and is_equal_approx(float(stats.get("hp", 0.0)), float(CardDB.PRINCESS_TOWER_STATS.damage))
		and is_equal_approx(float(stats.get("damage", 0.0)), float(CardDB.PRINCESS_TOWER_STATS.damage))
		and is_equal_approx(float(stats.get("range", 0.0)), 48.0)
		and is_equal_approx(float(stats.get("interval", 0.0)), 1.0)
		and is_equal_approx(float(stats.get("first_hit", 0.0)), 0.4),
		"皮克斯为2费五单位极小空军，生命/伤害等于塔的一击，攻击距离1.2格且攻速1秒",
	)
	_expect(
		animations.get("attack", []) == ["Attack1", "Attack2"]
		and StringName(stats.get("projectile_visual", "")) == &"orb"
		and (stats.get("projectile_colors", []) as Array).all(func(color): return color is Color and (color as Color).b > (color as Color).g)
		and CardArt.texture_for("pix") != null,
		"皮克斯循环 Attack1/Attack2，并在动作约40%处发射小型紫色光弹且已有多单位卡面",
	)
	_expect(
		model_node != null
		and is_equal_approx(model_node.scale.x, 0.022)
		and is_equal_approx(model_node.scale.y, 0.022)
		and is_equal_approx(float(stats.get("deployment_spacing", 0.0)), 36.0)
		and is_equal_approx(float(stats.get("projectile_visual_height", 0.0)), 84.0),
		"皮克斯保持极小权威体积和原始模型比例，战场中按统一空军高度抬升且编队不会挤作一团",
	)
	if visual_sample != null:
		visual_sample.free()
	_expect(
		int(skill.get("cost", 0)) == 1
		and int(skill.get("max_uses", 0)) == 1
		and StringName(skill.get("kind", "")) == &"attack_lifesteal"
		and StringName(skill.get("target_scope", "")) == &"deployment_group"
		and is_equal_approx(float(skill.get("heal_ratio", 0.0)), 0.25)
		and is_equal_approx(float(skill.get("max_health_ratio", 0.0)), 1.5),
		"皮克斯编队技能为1费1次，给存活编队成员永久附加25%逐次攻击吸血并封顶150%生命",
	)


func _check_group_deployment_and_shared_skill() -> void:
	var old_deck: Array = _main._deck.duplicate()
	_main._deck = ["pix", "garen", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	var pending_before: int = _main._commands.inspect_cards().size()
	var scheduled_tick: int = _main._deploy_card(0, "pix", Vector2(360.0, 1050.0), _main._sim_tick_id)
	var one_pending_circle: bool = scheduled_tick >= 0 and _main._commands.inspect_cards().size() == pending_before + 1
	_main._commands.cancel_last_card()
	var group: Array[Unit] = _main._spawn_card_units(0, "pix", Vector2(360.0, 1050.0), 0.0, 0)
	var other_group: Array[Unit] = _main._spawn_card_units(0, "pix", Vector2(500.0, 1050.0), 0.0)
	var positions := {}
	var group_id := group[0].deployment_group_id
	for member in group:
		positions[member.global_position] = true
	for team in [0, 1]:
		var offsets: Array[Vector2] = _main._deployment_formation_offsets(5, 36.0, team, "polygon")
		var centroid := Vector2.ZERO
		for index in range(5):
			centroid += offsets[index]
			_expect(is_equal_approx(offsets[index].length(), 36.0), "五个顶点到中心等距，无中心成员")
			_expect(is_equal_approx(offsets[index].distance_to(offsets[(index + 1) % 5]), 72.0 * sin(PI / 5.0)), "五边形相邻边等长")
		_expect(centroid.length() < 0.001, "双方五边形重心保持部署中心")
	var lead: Unit = group[0]
	var ability_id := lead.active_ability_id
	_expect(
		one_pending_circle and group.size() == 5 and positions.size() == 5 and group.all(func(member): return member.deployment_group_id == group_id),
		"一次格心部署只排入一个读条圈，并按确定性正五边形阵型生成5个独立皮克斯",
	)

	# 主动持有者死亡后，编队资格必须交给存活成员，而不是让整队技能随第一只消失。
	lead.take_damage(lead.hp + 1.0)
	var transferred: bool = _main._active_skills.has(ability_id)
	var replacement: Unit = _main._active_skills.entry(ability_id).unit if transferred else null
	transferred = transferred and replacement != null and replacement != lead and replacement.deployment_group_id == group_id
	var activated: bool = transferred and _main._activate_active_skill(ability_id, 0)
	var survivors: Array[Unit] = []
	for member in group:
		if member.hp > 0.0:
			survivors.append(member)
	var armed_only_this_group := survivors.all(func(member): return is_equal_approx(member.attack_lifesteal_ratio, 0.25))
	armed_only_this_group = armed_only_this_group and other_group.all(func(member): return is_zero_approx(member.attack_lifesteal_ratio))
	_expect(
		transferred and activated and int(_main._active_skills.entry(ability_id).uses_remaining) == 0 and armed_only_this_group,
		"编队主动在首成员死亡后仍由存活成员持有，释放时只强化本次部署中仍存活的皮克斯",
	)

	for member in survivors:
		member.hp = member.max_hp
		member.on_attack_landed(-1, member.damage)
		member.on_attack_landed(-1, member.damage)
	var healed_repeatedly: bool = survivors.all(func(member):
		return is_equal_approx(member.hp, roundf(member.max_hp * 1.5)) and is_equal_approx(member.attack_lifesteal_ratio, 0.25)
	)
	var cap_probe := survivors[0]
	cap_probe.hp = cap_probe.max_hp * 1.45
	cap_probe.on_attack_landed(-1, cap_probe.damage)
	_expect(
		healed_repeatedly
		and is_equal_approx(cap_probe.hp, roundf(cap_probe.max_hp * 1.5))
		and is_equal_approx(cap_probe.attack_lifesteal_ratio, 0.25),
		"每名存活皮克斯的每次真实攻击命中都会回复该击伤害25%（四舍五入），效果不消耗且溢出上限按150%四舍五入",
	)

	# 同一卡槽再次部署只替换主动资格；旧编队已经获得的持续吸血不得被清除或转移。
	var new_group: Array[Unit] = _main._spawn_card_units(0, "pix", Vector2(240.0, 1050.0), 0.0, 0)
	var new_lead: Unit = new_group[0]
	var new_ability_id: int = new_lead.active_ability_id
	var old_effect_survives_redeploy: bool = not _main._active_skills.has(ability_id)
	old_effect_survives_redeploy = old_effect_survives_redeploy and survivors.all(func(member):
		return is_equal_approx(member.attack_lifesteal_ratio, 0.25)
	)
	var new_group_starts_clean: bool = new_group.all(func(member): return is_zero_approx(member.attack_lifesteal_ratio))
	cap_probe.hp = cap_probe.max_hp
	cap_probe.on_attack_landed(-1, cap_probe.damage)
	old_effect_survives_redeploy = old_effect_survives_redeploy and is_equal_approx(cap_probe.hp, cap_probe.max_hp + roundf(cap_probe.damage * 0.25))
	var new_activated: bool = new_ability_id != ability_id and _main._activate_active_skill(new_ability_id, 0)
	var isolated_new_activation: bool = new_group.all(func(member): return is_equal_approx(member.attack_lifesteal_ratio, 0.25))
	isolated_new_activation = isolated_new_activation and survivors.all(func(member): return is_equal_approx(member.attack_lifesteal_ratio, 0.25))
	_expect(
		old_effect_survives_redeploy
		and new_group_starts_clean
		and new_activated
		and int(_main._active_skills.entry(new_ability_id).uses_remaining) == 0
		and isolated_new_activation,
		"再次部署只把主动按钮交给新编队：旧编队永久吸血保留，新编队不会继承且新技能只作用于新编队",
	)

	_main._active_skills.remove(new_ability_id)
	_main._active_skill_bar.remove_skill(new_ability_id)
	for member in group + other_group + new_group:
		if is_instance_valid(member):
			member.free()
	_main._deck = old_deck
