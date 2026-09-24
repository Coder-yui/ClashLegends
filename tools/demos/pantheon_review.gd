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
		main.play_card(team, "pantheon", center, {"immediate": true, "validate_position": false})
		await create_timer(0.7).timeout
		await shot("team%d_landing" % team)
		var unit: Unit = main._latest_unit_for_card("pantheon", team)
		unit.move_speed = 0.0
		unit.configure_carried_active_skill(CardDB.active_skills_for("pantheon")[0])
		main.play_card(1-team, "garen", center + Vector2(0, -65 if team == 0 else 65), {"immediate": true, "validate_position": false})
		var target: Unit = main._latest_unit_for_card("garen", 1-team)
		target.move_speed = 0.0
		target.damage = 0.0
		target.hp = 10000
		target.max_hp = 10000
		await create_timer(2.0).timeout
		await shot("team%d_attack" % team)
		unit.skill_resource_value = 1
		main.preview_active_skill(unit, CardDB.active_skills_for("pantheon")[0])
		await create_timer(0.2).timeout
		await shot("team%d_q" % team)
		await create_timer(1.0).timeout
		unit.skill_resource_value = 4
		main.preview_active_skill(unit, CardDB.active_skills_for("pantheon")[0])
		await create_timer(0.2).timeout
		await shot("team%d_empowered_q" % team)
		await create_timer(1.0).timeout
		unit.take_damage(10000)
		await create_timer(0.3).timeout
		await shot("team%d_death" % team)
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
