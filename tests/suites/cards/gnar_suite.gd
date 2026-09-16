class_name GnarSuite
extends "res://tests/suites/battle_suite.gd"
## 纳尔卡牌领域：循环双形态机制与双形态美术接入。

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_gnar_mechanic()
	_check_gnar_art_integration()

## 纳尔循环双形态：小形态第6次命中变大，大形态第4次命中变小；变形期间可移动但不能攻击。
func _check_gnar_mechanic() -> void:
	var stats: Dictionary = CardDB.get_card("gnar").duplicate(true)
	stats["deploy_time"] = 0.0
	var dummy_stats := SuiteUtils.sweep_dummy_stats(CardDB.get_card("garen"))
	var gnar := Unit.new()
	var dummy := Unit.new()
	gnar.position = Vector2(360.0, 900.0)
	dummy.position = Vector2(360.0, 780.0)
	gnar.setup(0, stats, stats.name)
	dummy.setup(1, dummy_stats, "纳尔被动木桩")
	_main.add_child(gnar)
	_main.add_child(dummy)
	var small_contract := (
		gnar.form_index == 0
		and gnar.can_attack_air
		and gnar.projectile_speed > 0.0
		and gnar.body_radius == CardDB.RADIUS_SMALL
	)
	dummy.hp = 5000.0
	dummy.max_hp = 5000.0
	var dummy_hp_before := dummy.hp
	_main.launch_attack(gnar, dummy, gnar.damage, gnar.projectile_speed, 0.0, 0.0, gnar.color)
	var delayed_projectile_ok: bool = dummy.hp == dummy_hp_before and gnar.transform_hit_count == 0 and not _main._projectile_system.projectiles.is_empty()
	for _tick in 10:
		_main._tick_projectiles(_main.SIM_DT)
	for _hit_index in range(4):
		gnar.on_attack_landed()
	var five_hits_still_small := gnar.form_index == 0 and gnar.transform_hit_count == 5
	gnar.hp = 300.0
	# 同一时刻在途的两枚小纳尔回旋镖只有第一枚完成第6层；第二枚不会误算为大纳尔命中。
	_main.launch_attack(gnar, dummy, gnar.damage, gnar.projectile_speed, 0.0, 0.0, gnar.color)
	_main.launch_attack(gnar, dummy, gnar.damage, gnar.projectile_speed, 0.0, 0.0, gnar.color)
	for _tick in 10:
		_main._tick_projectiles(_main.SIM_DT)
	var transformed_contract := (
		gnar.form_index == 1
		and not gnar.can_attack_air
		and is_zero_approx(gnar.projectile_speed)
		and gnar.body_radius == CardDB.RADIUS_EXTREMELY_LARGE
		and is_equal_approx(gnar.max_hp, float(stats.transformed_stats.hp))
		and is_equal_approx(gnar.hp, 300.0 + float(stats.transformed_stats.hp) - float(stats.hp))
		and gnar.transform_hit_count == 0
		and is_equal_approx(gnar.form_transition_timer, float(stats.transform_duration))
	)
	var largest_other_unit_radius := 0.0
	for card_id in CardDB.all():
		if card_id == "gnar":
			continue
		var other_stats: Dictionary = CardDB.get_card(card_id)
		if other_stats.get("type", "unit") == "unit":
			largest_other_unit_radius = maxf(largest_other_unit_radius, float(other_stats.get("radius", 0.0)))
	_expect(small_contract and delayed_projectile_ok and five_hits_still_small, "小纳尔为小体型远程单位，回旋镖抵达才造成伤害/计层且前5次命中不会提前变身")
	_expect(transformed_contract, "小纳尔第6次真实命中立即切换大形态数值，当前生命增加两形态上限差值且在途回旋镖不串层")
	_expect(gnar.body_radius >= largest_other_unit_radius, "大纳尔使用最大的极大体型档位，允许新单位共享该档位")

	# 变大演出期间先用大纳尔视野/射程决定追击或待攻；移动不被锁，攻击必须等固定演出结束。
	dummy.position = gnar.position + Vector2(0.0, -120.0)
	gnar.sim_tick(_main.SIM_DT)
	var transition_moves := gnar.form_transition_timer > 0.0 and not gnar._attacking and gnar._move_intent.length_squared() > 0.01
	dummy.position = gnar.position + Vector2(0.0, -65.0)
	gnar.sim_tick(_main.SIM_DT)
	var transition_waits_in_range := not gnar._attacking and gnar._move_intent.is_zero_approx()
	var attack_serial_before := gnar.get_attack_visual_serial()
	while gnar.form_transition_timer > 0.0:
		gnar.sim_tick(_main.SIM_DT)
	var attacks_immediately_after_transition := gnar._attacking and gnar.get_attack_visual_serial() > attack_serial_before
	_expect(transition_moves and transition_waits_in_range, "变形期间按新形态射程决定继续移动或原地待攻，但始终不发动攻击")
	_expect(attacks_immediately_after_transition, "变形动画锁结束后，射程内目标会立即衔接新形态攻击")

	gnar.hp = 200.0
	for _hit_index in range(3):
		gnar.on_attack_landed(1)
	var three_mega_hits_still_big := gnar.form_index == 1 and gnar.transform_hit_count == 3
	gnar.on_attack_landed(1)
	var reverted_contract := (
		gnar.form_index == 0
		and is_equal_approx(gnar.max_hp, float(stats.hp))
		and is_equal_approx(gnar.hp, 200.0)
		and gnar.transform_hit_count == 0
		and gnar.get_visual_action_name() == &"revert"
		and is_equal_approx(gnar.form_transition_timer, float(stats.revert_duration))
	)
	gnar.transform_to_mega()
	gnar.hp = 700.0
	gnar.transform_to_small()
	var revert_clamps_overflow := is_equal_approx(gnar.hp, float(stats.hp))
	_expect(three_mega_hits_still_big and reverted_contract, "大纳尔前3次命中保持大形态，第4次命中立即变小并保留未超上限的剩余生命")
	_expect(revert_clamps_overflow, "大纳尔变小时剩余生命会被小纳尔最大生命上限截断")

	# 小半径合法但大半径压入河岸的位置，变大后应被确定性修正到新体积合法点。
	var resize_gnar := Unit.new()
	resize_gnar.position = Vector2(360.0, ArenaRules.RIVER_Y + ArenaRules.RIVER_HALF + CardDB.RADIUS_SMALL)
	resize_gnar.setup(0, stats, stats.name)
	_main.add_child(resize_gnar)
	var resize_origin := resize_gnar.position
	resize_gnar.transform_to_mega()
	var resize_safe: bool = resize_gnar.position != resize_origin and _main.is_ground_position_walkable(resize_gnar.position, resize_gnar.body_radius, resize_gnar)
	_expect(resize_safe, "小纳尔在河岸/桥角变大时会按新半径移到最近安全点，不会因瞬时体积增大卡住")

	# 周围单位使用统一圆柱推挤处理，不做伤害或击退；即使纳尔贴场地边缘，另一侧单位也应被推出。
	var crowded_gnar := Unit.new()
	crowded_gnar.position = Vector2(540.0, 860.0)
	crowded_gnar.setup(0, stats, stats.name)
	_main.add_child(crowded_gnar)
	crowded_gnar._just_deployed = false
	var crowded_neighbors: Array[Unit] = []
	var old_contact_distance := CardDB.RADIUS_SMALL + float(dummy_stats.radius) - 0.5
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var neighbor := Unit.new()
		neighbor.position = crowded_gnar.position + direction * old_contact_distance
		neighbor.setup(1, dummy_stats, "纳尔变大推挤木桩")
		_main.add_child(neighbor)
		neighbor._just_deployed = false
		crowded_neighbors.append(neighbor)
	var crowded_origins: Array[Vector2] = []
	for neighbor in crowded_neighbors:
		crowded_origins.append(neighbor.position)
	crowded_gnar.transform_to_mega()
	_main._movement._resolve_unit_collisions(_main.SIM_DT, _main._movement._active_mobile_units())
	var pushed_on_resize_tick := false
	for neighbor_index in crowded_neighbors.size():
		pushed_on_resize_tick = pushed_on_resize_tick or crowded_neighbors[neighbor_index].position != crowded_origins[neighbor_index]
	for _tick in 40:
		_main._movement._resolve_unit_collisions(_main.SIM_DT, _main._movement._active_mobile_units())
	var crowd_separated := true
	for neighbor in crowded_neighbors:
		var required_gap: float = crowded_gnar.body_radius + neighbor.body_radius - ArenaRules.COLLISION_SLOP - 0.1
		crowd_separated = (
			crowd_separated
			and crowded_gnar.position.distance_to(neighbor.position) >= required_gap
			and _main.is_ground_position_walkable(neighbor.position, neighbor.body_radius, neighbor)
		)
	var edge_gnar := Unit.new()
	var edge_neighbor := Unit.new()
	edge_gnar.position = Vector2(CardDB.RADIUS_EXTREMELY_LARGE, 760.0)
	edge_neighbor.position = edge_gnar.position + Vector2.RIGHT * old_contact_distance
	edge_gnar.setup(0, stats, stats.name)
	edge_neighbor.setup(1, dummy_stats, "贴边推挤木桩")
	_main.add_child(edge_gnar)
	_main.add_child(edge_neighbor)
	edge_gnar._just_deployed = false
	edge_neighbor._just_deployed = false
	edge_gnar.transform_to_mega()
	for _tick in 40:
		_main._movement._resolve_unit_collisions(_main.SIM_DT, _main._movement._active_mobile_units())
	var edge_separated: bool = (
		edge_gnar.position.distance_to(edge_neighbor.position) >= edge_gnar.body_radius + edge_neighbor.body_radius - ArenaRules.COLLISION_SLOP - 0.1
		and _main.is_ground_position_walkable(edge_gnar.position, edge_gnar.body_radius, edge_gnar)
		and _main.is_ground_position_walkable(edge_neighbor.position, edge_neighbor.body_radius, edge_neighbor)
	)
	_expect(pushed_on_resize_tick and crowd_separated and edge_separated, "纳尔变大当帧开始按质量挤开周围单位，密集包围与贴边场景最终都无重叠、无单位被卡进地形")

	var active_small := Unit.new()
	active_small.card_id = "gnar"
	active_small.position = Vector2(200.0, 900.0)
	active_small.setup(0, stats, stats.name)
	_main.add_child(active_small)
	var skill: Dictionary = stats.active_skills[0]
	# team0 默认朝上。前方目标在 -Y，后方目标在 +Y，空中目标即使在前方也应免疫。
	var front := Unit.new()
	var back := Unit.new()
	var air := Unit.new()
	front.position = active_small.position + Vector2(20.0, -100.0)
	back.position = active_small.position + Vector2(0.0, 100.0)
	air.position = active_small.position + Vector2(-20.0, -90.0)
	front.setup(1, dummy_stats, "前方木桩")
	back.setup(1, dummy_stats, "后方木桩")
	var air_stats := dummy_stats.duplicate(true)
	air_stats["is_air"] = true
	air.setup(1, air_stats, "空中木桩")
	_main.add_child(front)
	_main.add_child(back)
	_main.add_child(air)
	var front_hp := front.hp
	var back_hp := back.hp
	var air_hp := air.hp
	var cast_facing := active_small.get_visual_facing_direction()
	_main.preview_active_skill(active_small, skill)
	var active_small_contract := (
		active_small.form_index == 1
		and active_small.get_visual_action_name() == &"transform_active"
		and is_equal_approx(active_small.form_transition_timer, float(stats.active_transform_duration))
		and is_equal_approx(active_small.active_skill_cast_timer, float(skill.transform_cast_duration))
	)
	var attack_serial_before_cast_tick := active_small.get_attack_visual_serial()
	active_small._target = back
	active_small._attacking = true
	active_small.sim_tick(_main.SIM_DT)
	var cast_lock_ok := (
		not active_small._attacking
		and active_small._move_intent.is_zero_approx()
		and active_small.get_attack_visual_serial() == attack_serial_before_cast_tick
		and active_small.get_visual_facing_direction().is_equal_approx(cast_facing)
	)
	var telegraph_queued: bool = (
		front.hp == front_hp
		and is_zero_approx(front.control.stun_timer)
		and _main._commands.impacts.size() == 1
		and _main._active_skill_effect_system.frontal_effects.size() == 1
	)
	_main._commands.tick_impacts(float(skill.transform_impact_delay) - 0.05)
	var waits_for_hand_impact := front.hp == front_hp and is_zero_approx(front.control.stun_timer)
	_main._commands.tick_impacts(0.05)
	var frontal_hit_ok := front.hp == front_hp - float(skill.damage) and is_equal_approx(front.control.stun_timer, 1.0)
	var filtering_ok := back.hp == back_hp and is_zero_approx(back.control.stun_timer) and air.hp == air_hp and is_zero_approx(air.control.stun_timer)
	var frozen_position := front.position
	front._move_intent = Vector2.DOWN * front.move_speed
	front.sim_tick(_main.SIM_DT)
	_expect(active_small_contract and cast_lock_ok and telegraph_queued and waits_for_hand_impact and frontal_hit_ok, "小纳尔主动锁定发动方向且不能移动/普攻，合成变身 Spell2 手掌触地才造成伤害和 1 秒眩晕")
	_expect(filtering_ok and front.position == frozen_position, "大纳尔 Spell2 不命中后方或空中单位，眩晕期间目标不能自主行动")
	active_small.form_transition_timer = 0.0
	active_small.active_skill_cast_timer = 0.0
	active_small.active_skill_cast_facing = Vector2.ZERO
	_main.preview_active_skill(active_small, skill)
	var mega_waits_for_impact: bool = (
		active_small.get_visual_action_name() == &"active"
		and _main._commands.impacts.size() == 1
		and is_equal_approx(active_small.active_skill_cast_timer, float(skill.cast_duration))
	)
	_expect(mega_waits_for_impact, "大纳尔主动固定方向并锁定行动，直接播放 Spell2 后延迟到 0.8 秒手掌触地时结算")
	_main._commands.impacts.clear()
	_main._active_skill_effect_system.frontal_effects.clear()
	active_small.active_skill_cast_timer = 0.0
	active_small.active_skill_cast_facing = Vector2.ZERO
	for unit in [gnar, dummy, resize_gnar, crowded_gnar, edge_gnar, edge_neighbor, active_small, front, back, air] + crowded_neighbors:
		if is_instance_valid(unit):
			unit.free()

func _check_gnar_art_integration() -> void:
	var stats: Dictionary = CardDB.get_card("gnar").duplicate(true)
	var mega_stats: Dictionary = stats.transformed_stats
	var small_packed := load(stats.visual_scene_path) as PackedScene
	var mega_packed := load(mega_stats.visual_scene_path) as PackedScene
	if small_packed == null or mega_packed == null:
		return
	_expect(stats.visual_animations.attack == ["Gnar_Attack1_anm", "Gnar_Attack2_anm"], "小纳尔普通攻击使用非 Fast 版 Attack1/Attack2")
	var art_panel := DevelopmentWorkbench.new()
	_main.add_child(art_panel)
	art_panel.setup(CardDB.all())
	art_panel._select_item("gnar")
	_expect(
		art_panel._skill_option.item_count == 1 and art_panel.selected_skill_index() == 0
		and art_panel._skill_button.disabled,
		"开发工作台选择纳尔后列出主动技能，并在放置单位前保持播放按钮禁用",
	)
	art_panel.free()
	var mega_attributes: Array[Dictionary] = CardDetails.attributes(mega_stats)
	var mega_hp_shown := false
	var mega_damage_shown := false
	for attribute in mega_attributes:
		if String(attribute.get("name", "")) == "生命" and String(attribute.get("value", "")) == "820":
			mega_hp_shown = true
		if String(attribute.get("name", "")) == "单次伤害" and String(attribute.get("value", "")) == "85":
			mega_damage_shown = true
	_expect(mega_hp_shown and mega_damage_shown, "纳尔信息面板可读取大纳尔变形后的生命与伤害")
	var small_sample := small_packed.instantiate() as Node3D
	var mega_sample := mega_packed.instantiate() as Node3D
	var small_model := small_sample.get_node_or_null("Model") as Node3D
	var mega_model := mega_sample.get_node_or_null("Model") as Node3D
	_expect(
		small_model != null and mega_model != null
		and is_equal_approx(small_model.scale.x, 0.0105)
		and is_equal_approx(mega_model.scale.x, 0.00825)
		and is_equal_approx(small_model.position.y, 0.5)
		and mega_model.position.y < small_model.position.y,
		"纳尔双模型分别按小/极大体型校准缩放与脚底偏移",
	)
	small_sample.free()
	mega_sample.free()

	stats["deploy_time"] = 0.0
	var unit := Unit.new()
	unit.position = Vector2(360.0, 900.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var attached: bool = _main._battle_presentation.attach_unit(unit, stats)
	var view: UnitModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			view = child as UnitModel3D
			break
	var small_standard_attack_playing := false
	if view != null:
		unit._target = unit
		unit._attacking = true
		view._play_attack(1)
		small_standard_attack_playing = view._animation_player.current_animation == "Gnar_Attack1_anm"
		unit._attacking = false
	unit.transform_to_mega()
	if view != null:
		view._sync_visual(false, 0.05)
	var swapped_and_playing := (
		view != null
		and view._model_root.name == "GnarMegaView"
		and view._animation_player.current_animation == "gnar_runtime/Rage_Transform"
	)
	var rage_transform_filtered := false
	var rage_transform_duration_ok := false
	var rage_transform_has_body_motion := false
	var rage_endpoint_scale_ok := false
	var attack_waited_for_transform := false
	var mega_run_in_then_loop := false
	var mega_run_in_filtered := false
	var revert_transform_started := false
	var revert_transform_filtered := false
	var revert_transform_duration_ok := false
	var revert_transform_has_body_motion := false
	var revert_endpoint_scale_ok := false
	var small_run_in_then_loop := false
	var small_run_in_filtered := false
	var active_transform_chain := false
	var turret_attack_playing := false
	var unit_attack_playing := false
	if view != null:
		var rage_transform_animation := view._animation_player.get_animation(&"gnar_runtime/Rage_Transform")
		rage_transform_filtered = (
			view._model_root.call("is_filtered_clip_active")
			and int(view._model_root.call("get_filtered_triangle_count")) < int(view._model_root.call("get_original_triangle_count"))
		)
		rage_transform_duration_ok = absf(rage_transform_animation.length - 1.5) < 0.001
		for track_index in rage_transform_animation.get_track_count():
			if rage_transform_animation.track_get_type(track_index) == Animation.TYPE_ROTATION_3D and rage_transform_animation.track_get_key_count(track_index) > 1:
				rage_transform_has_body_motion = true
			if (
				rage_transform_animation.track_get_type(track_index) == Animation.TYPE_SCALE_3D
				and String(rage_transform_animation.track_get_path(track_index)) == "Skeleton/Skeleton3D:Root"
			):
				var first_scale: Vector3 = rage_transform_animation.track_get_key_value(track_index, 0)
				var last_scale: Vector3 = rage_transform_animation.track_get_key_value(track_index, rage_transform_animation.track_get_key_count(track_index) - 1)
				rage_endpoint_scale_ok = absf(first_scale.x - 0.68) < 0.001 and last_scale.is_equal_approx(Vector3.ONE)
		unit._target = unit
		unit._attacking = true
		unit._attack_visual_serial += 1
		view._sync_visual(false, 0.05)
		var transform_not_interrupted := view._animation_player.current_animation == "gnar_runtime/Rage_Transform"
		view._on_animation_finished(&"gnar_runtime/Rage_Transform")
		attack_waited_for_transform = transform_not_interrupted and view._animation_player.current_animation == "GnarBig_Attack1_anm"
		unit._move_intent = Vector2.UP * unit.move_speed
		unit._attacking = false
		view._sync_visual(false, 0.05)
		var entered_run := view._animation_player.current_animation == "Run_In"
		mega_run_in_filtered = view._model_root.call("is_filtered_clip_active")
		view._on_animation_finished(&"Run_In")
		mega_run_in_then_loop = entered_run and view._animation_player.current_animation == "Run_Base" and not view._model_root.call("is_filtered_clip_active")
		unit._move_intent = Vector2.ZERO
		unit.transform_to_small()
		view._sync_visual(false, 0.05)
		revert_transform_started = view._animation_player.current_animation == "gnar_runtime/Revert_Transform"
		var revert_transform_animation := view._animation_player.get_animation(&"gnar_runtime/Revert_Transform")
		revert_transform_filtered = (
			view._model_root.call("is_filtered_clip_active")
			and int(view._model_root.call("get_filtered_triangle_count")) < int(view._model_root.call("get_original_triangle_count"))
		)
		revert_transform_duration_ok = absf(revert_transform_animation.length - 1.333333) < 0.001
		for track_index in revert_transform_animation.get_track_count():
			if revert_transform_animation.track_get_type(track_index) == Animation.TYPE_ROTATION_3D and revert_transform_animation.track_get_key_count(track_index) > 1:
				revert_transform_has_body_motion = true
			if (
				revert_transform_animation.track_get_type(track_index) == Animation.TYPE_SCALE_3D
				and String(revert_transform_animation.track_get_path(track_index)) == "Skeleton/Skeleton3D:Root_Upper"
			):
				var first_scale: Vector3 = revert_transform_animation.track_get_key_value(track_index, 0)
				var last_scale: Vector3 = revert_transform_animation.track_get_key_value(track_index, revert_transform_animation.track_get_key_count(track_index) - 1)
				revert_endpoint_scale_ok = absf(first_scale.x - 2.45) < 0.001 and last_scale.is_equal_approx(Vector3.ONE)
		view._on_animation_finished(&"gnar_runtime/Revert_Transform")
		unit._move_intent = Vector2.UP * unit.move_speed
		view._sync_visual(false, 0.05)
		var small_entered_run := view._animation_player.current_animation == "Run1_In"
		small_run_in_filtered = view._model_root.call("is_filtered_clip_active")
		view._on_animation_finished(&"Run1_In")
		small_run_in_then_loop = small_entered_run and view._animation_player.current_animation == "Run_Base" and not view._model_root.call("is_filtered_clip_active")
		unit._move_intent = Vector2.ZERO
		unit.transform_to_mega(true)
		view._sync_visual(false, 0.05)
		var active_rage_started := view._animation_player.current_animation == "gnar_runtime/Rage_Spell2_Transform"
		var active_transform_animation := view._animation_player.get_animation(&"gnar_runtime/Rage_Spell2_Transform")
		active_transform_chain = (
			active_rage_started
			and view._model_root.call("is_filtered_clip_active")
			and absf(active_transform_animation.length - 1.2) < 0.001
		)
		view._on_animation_finished(&"gnar_runtime/Rage_Spell2_Transform")
		unit._move_intent = Vector2.ZERO
		unit._target = _main._towers[0]
		unit._attacking = true
		view._play_attack(1)
		turret_attack_playing = view._animation_player.current_animation == "GnarBig_Turret_Attack01_anm"
		unit._target = unit
		view._play_attack(2)
		unit_attack_playing = view._animation_player.current_animation == "GnarBig_Attack2_anm"
	_main.preview_active_skill(unit, stats.active_skills[0])
	if view != null:
		view._sync_visual(false, 0.05)
	var spell2_playing := view != null and view._animation_player.current_animation == "GnarBig_Spell2_anm"
	var death_chain := false
	if view != null:
		view._on_animation_finished(&"GnarBig_Spell2_anm")
		var mega_death_root := view._model_root
		unit.notify_visual_death()
		var big_death_started := view._animation_player.current_animation == "GnarBig_Death_anm"
		view._on_animation_finished(&"GnarBig_Death_anm")
		death_chain = big_death_started and view._model_root != mega_death_root and view._animation_player.current_animation == "Death"
	var transform_death_safe := false
	var transform_death_unit := Unit.new()
	transform_death_unit.position = Vector2(300.0, 900.0)
	transform_death_unit.setup(0, stats, stats.name)
	_main.add_child(transform_death_unit)
	_main._battle_presentation.attach_unit(transform_death_unit, stats)
	var transform_death_view: UnitModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == transform_death_unit:
			transform_death_view = child as UnitModel3D
			break
	if transform_death_view != null:
		transform_death_unit.transform_to_mega(true)
		transform_death_view._sync_visual(false, 0.05)
		var was_transforming := transform_death_view._animation_player.current_animation == "gnar_runtime/Rage_Spell2_Transform"
		transform_death_unit.hp = 0.0
		transform_death_unit.notify_visual_death()
		transform_death_safe = was_transforming and transform_death_view._animation_player.current_animation == "GnarBig_Death_anm"
	var postmortem_projectile_safe := false
	var death_race_unit := Unit.new()
	death_race_unit.position = Vector2(420.0, 900.0)
	death_race_unit.setup(0, stats, stats.name)
	_main.add_child(death_race_unit)
	_main._battle_presentation.attach_unit(death_race_unit, stats)
	var death_race_view: UnitModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == death_race_unit:
			death_race_view = child as UnitModel3D
			break
	if death_race_view != null:
		death_race_unit.transform_hit_count = int(stats.transform_after_hits) - 1
		death_race_unit.hp = 0.0
		death_race_unit.notify_visual_death()
		var death_model: Node3D = death_race_view._model_root
		# 模拟小纳尔死亡后，同一渲染帧内最后一枚在途回旋镖抵达。
		death_race_unit.on_attack_landed(0, death_race_unit.damage)
		var late_visual_swap_rejected := not death_race_view.replace_visual(
			mega_packed,
			mega_stats.visual_animations,
			float(mega_stats.visual_forward_yaw),
		)
		death_race_view._animation_player.advance(0.1)
		postmortem_projectile_safe = (
			death_race_unit.form_index == 0
			and late_visual_swap_rejected
			and death_race_view._model_root == death_model
			and death_race_view._animation_player.current_animation == "Death"
			and death_race_view._animation_player.current_animation_position > 0.0
		)
	_expect(attached and swapped_and_playing, "普通变大使用 Rage_Scale 相对 Base 叠加到 Rage_Move 的单段合成动画，权威形态已先切换")
	_expect(small_standard_attack_playing, "小纳尔实战表现代理播放非 Fast 版 Gnar_Attack1")
	_expect(rage_transform_filtered and rage_transform_duration_ok and rage_transform_has_body_motion, "变大合成动画保留 1.5 秒完整动作与多帧身体旋转，并隐藏石头")
	_expect(rage_endpoint_scale_ok and revert_endpoint_scale_ok, "变大/变小合成动画重映射根缩放首值并在末帧回到各自包装尺寸")
	_expect(attack_waited_for_transform, "变形期间已经决定攻击时不打断变形，序列结束后立即播放攻击动画")
	_expect(mega_run_in_then_loop and small_run_in_then_loop and mega_run_in_filtered and small_run_in_filtered, "大、小纳尔 Run_In 隐藏石头/额外回旋镖，完成后衔接完整模型 Run")
	_expect(revert_transform_started and revert_transform_filtered and revert_transform_duration_ok and revert_transform_has_body_motion, "变小使用 Revert_Scale 相对 Base 叠加到 Gnar_Revert 的 1.33 秒完整合成动画，并隐藏额外回旋镖")
	_expect(active_transform_chain, "小纳尔主动使用 Rage_Scale 与 Spell2_Tran 同步合成的 1.2 秒变身施法动画")
	_expect(turret_attack_playing and unit_attack_playing, "大纳尔攻击建筑使用 Turret_Attack，攻击单位仍使用普通 Attack")
	_expect(spell2_playing, "大纳尔前方主动使用源模型 Spell2 动画，效果时刻仍由固定模拟决定")
	_expect(death_chain, "大纳尔死亡先播放极短 BigGnar Death，再换小纳尔模型播放 Death")
	_expect(transform_death_safe, "纳尔在主动变身动画中死亡时立即打断变身并播放大形态死亡动画")
	_expect(postmortem_projectile_safe, "小纳尔死亡后同帧抵达的回旋镖不再触发变身，Death 持续播放且模型不会定格")
	if transform_death_view != null:
		transform_death_view.free()
	if is_instance_valid(transform_death_unit):
		transform_death_unit.free()
	if death_race_view != null:
		death_race_view.free()
	if is_instance_valid(death_race_unit):
		death_race_unit.free()
	if view != null:
		view.free()
	if is_instance_valid(unit):
		unit.free()
	# 清理待结算主动技能现场，避免污染后续领域 suite。
	_main._commands.impacts.clear()
	_main._active_skill_effect_system.frontal_effects.clear()
