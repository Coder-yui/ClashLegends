extends SceneTree
var output := preload("res://tools/lib/development_paths.gd").output("pantheon-review")
var main: Node2D
func _initialize() -> void:
	_run.call_deferred()
func shot(label: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output + "/" + label + ".png")
func _run() -> void:
	root.audio_listener_enable_2d = true
	DirAccess.make_dir_recursive_absolute(output)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_local()
	main._ai.enabled = false
	main._minion_waves_enabled = false
	for tower in main._towers: tower.can_attack = false
	for attempt in 100:
		if main._match_started: break
		await create_timer(0.1).timeout
	if "--movement-range" in OS.get_cmdline_user_args():
		await _movement_range()
		quit()
		return
	if "--arrival-materials" in OS.get_cmdline_user_args():
		await _arrival_materials()
		quit()
		return
	if "--size-comparison" in OS.get_cmdline_user_args():
		await _size_comparison()
		quit()
		return
	main._audio_manager.cue_played.connect(func(card: String, cue: StringName, _position: Vector2):
		if card == "pantheon": print("PANTHEON_AUDIO ", cue))
	var record := AudioEffectRecord.new()
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	for team in [0, 1]:
		main._clear_art_dev_units()
		await process_frame
		var center := Vector2(320, 820 if team == 0 else 460)
		var direction := Vector2.UP if team == 0 else Vector2.DOWN
		var victims: Array[Unit] = []
		for point in ([] if "--clean-arrival" in OS.get_cmdline_user_args() else [center - direction * 120.0 + Vector2(60, 0), center + direction * 80.0]):
			var victim: Unit = main._spawn_unit(1-team, "garen", point, 0.0)
			victim.move_speed = 0.0
			victim._deploy_timer = 99.0
			victims.append(victim)
		main.play_card(team, "pantheon", center, {"immediate": true, "validate_position": false})
		await create_timer(0.1).timeout
		await shot("team%d_pre_spear" % team)
		await create_timer(0.25).timeout
		await shot("team%d_pre_air" % team)
		await create_timer(0.35).timeout
		await shot("team%d_pre_slide" % team)
		await create_timer(0.4).timeout
		await shot("team%d_pre_arrive" % team)
		while main._latest_unit_for_card("pantheon", team) == null:
			await process_frame
		await create_timer(0.08).timeout
		await shot("team%d_landing" % team)
		await create_timer(0.35).timeout
		await shot("team%d_landing_recovery" % team)
		for victim in victims: victim.free()
		var unit: Unit = main._latest_unit_for_card("pantheon", team)
		unit.move_speed = 0.0
		unit.configure_carried_active_skill(CardDB.active_skills_for("pantheon")[0])
		main.play_card(1-team, "garen", center + Vector2(0, -65 if team == 0 else 65), {"immediate": true, "validate_position": false})
		var target: Unit = main._latest_unit_for_card("garen", 1-team)
		target.move_speed = 0.0
		target.damage = 0.0
		target.hp = 10000
		target.max_hp = 10000
		await create_timer(4.5).timeout
		await shot("team%d_attack" % team)
		unit.skill_resource_value = 1
		main.preview_active_skill(unit, CardDB.active_skills_for("pantheon")[0])
		await create_timer(0.3).timeout
		await shot("team%d_q" % team)
		await create_timer(1.0).timeout
		unit.skill_resource_value = 4
		await create_timer(0.1).timeout
		await shot("team%d_full_rage" % team)
		main.preview_active_skill(unit, CardDB.active_skills_for("pantheon")[0])
		await create_timer(0.3).timeout
		await shot("team%d_empowered_q" % team)
		await create_timer(1.0).timeout
		unit.take_damage(10000)
		await create_timer(0.3).timeout
		await shot("team%d_death" % team)
		await create_timer(0.22).timeout
		await shot("team%d_death_head" % team)
	record.set_recording_active(false)
	await create_timer(0.2).timeout
	var wav := record.get_recording()
	if wav != null: wav.save_to_wav(output + "/battle_mix.wav")
	AudioServer.remove_bus_effect(0, slot)
	main._deck_builder = DeckBuilder.new()
	main.add_child(main._deck_builder)
	main._deck_builder.open(main._deck, main._active_skill_choices, main._skin_choices, func(_deck, _skills, _skins): pass)
	main._deck_builder._open_card_info("pantheon")
	await create_timer(0.2).timeout
	await shot("pantheon_card_info")
	print("PANTHEON_REVIEW_OUTPUT ", output)
	main._audio_manager.end_battle()
	main.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	quit()

func _size_comparison() -> void:
	var cards := ["twisted_fate", "pantheon", "kayn"]
	var actors: Array[Unit] = []
	for index in cards.size():
		var point := Vector2(160 + index * 190, 860)
		var unit: Unit = main._spawn_unit(0, cards[index], point, 0.0)
		unit.move_speed = 0.0
		actors.append(unit)
		var label := Label.new()
		label.text = String(CardDB.get_card(cards[index]).name) + "（中）"
		label.position = point + Vector2(-45, -120)
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		main.add_child(label)
	await create_timer(0.2).timeout
	await shot("medium_comparison")
	actors[1].configure_carried_active_skill(CardDB.active_skills_for("pantheon")[0])
	actors[1].add_skill_resource(4)
	await create_timer(0.1).timeout
	await shot("medium_comparison_rage")
	print("PANTHEON_REVIEW_OUTPUT ", output)

## Isolated native-system inspection using the existing battle review camera.
func _arrival_materials() -> void:
	var presentation = main._battle_presentation
	var reference = preload("res://assets/units/pantheon/pantheon_arrival.tscn").instantiate()
	presentation._world_root.add_child(reference)
	for team in [0, 1]:
		# A temporary mapping helper; no units, damage or sounds are emitted.
		var map := preload("res://scripts/presentation/pre_deployment_visual_3d.gd").new()
		presentation._world_root.add_child(map)
		map.setup(presentation._camera, Vector2(350, 760), team)
		var origin: Vector3 = map.ground(Vector2(350, 760))
		var forward: Vector3 = (map.ground(Vector2(350, 740 if team == 0 else 780)) - origin).normalized()
		var motion := Basis(forward.cross(Vector3.UP), forward, Vector3.UP)
		for system in ["Spear_Impact", "update_missile", "Update_Impact", "Sliding_Comet", "Damage_Mis", "Ending_Shockwave"]:
			var particles := preload("res://assets/units/pantheon/r_original/particles.gd").new()
			presentation._world_root.add_child(particles)
			var moving: bool = system in ["update_missile", "Sliding_Comet", "Damage_Mis"]
			var basis := motion if moving else Basis(Vector3.UP, atan2(forward.x, forward.z))
			if system == "Ending_Shockwave": basis = Basis(forward, Vector3.UP, forward.cross(Vector3.UP))
			particles.global_transform = Transform3D(basis, origin)
			particles.setup(system, preload("res://assets/units/pantheon/visual_metrics.gd").PARTICLE_SCALE, moving)
			var previous := 0.0
			for time in [0.12, 0.35, 0.60]:
				while previous < time - 0.001:
					var dt: float = minf(0.02, time - previous)
					previous += dt
					if moving: particles.global_position = origin + forward * previous * 4.0
					particles.advance(dt)
				await shot("material_team%d_%s_%03d" % [team, system, roundi(time * 100)])
			particles.free()
		map.free()
	reference.free()
	print("PANTHEON_REVIEW_OUTPUT ", output)

func _movement_range() -> void:
	for team in [0, 1]:
		main._clear_art_dev_units()
		var unit: Unit = main._spawn_unit(team, "pantheon", Vector2(320, 850 if team == 0 else 430), 0.0)
		unit.configure_carried_active_skill(CardDB.active_skills_for("pantheon")[0])
		for stacks in [0, 3, 4, 0]:
			unit.skill_resource_value = stacks
			await create_timer(0.2).timeout
			await shot("team%d_move_%d_%d" % [team, stacks, Time.get_ticks_msec()])
			for child in main._battle_presentation._world_root.get_children():
				if child is UnitModel3D and child._source == unit:
					print("MOVE_REVIEW team=", team, " stacks=", stacks, " clip=", child._animation_player.current_animation)
		unit.move_speed = 0.0
		main.preview_active_skill(unit, CardDB.active_skills_for("pantheon")[0])
		await create_timer(0.3).timeout
		await shot("team%d_short_q_range" % team)
	print("PANTHEON_REVIEW_OUTPUT ", output)
