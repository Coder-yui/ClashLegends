extends SceneTree
## 用正式出牌和主动入口验证双阵营动作、流血/血怒、付费与免费斩杀；只读截图和混音。
var output := preload("res://tools/lib/development_paths.gd").output("darius-review")
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
	if "--network" in OS.get_cmdline_user_args():
		await _network()
		return
	main._start_local()
	main._ai.enabled = false
	main._minion_waves_enabled = false
	for tower in main._towers: tower.can_attack = false
	for attempt in 100:
		if main._match_started: break
		await create_timer(0.1).timeout
	main._deck[0] = "darius"
	main._audio_manager.cue_played.connect(func(card: String, cue: StringName, _position: Vector2):
		if card == "darius": print("DARIUS_AUDIO ", cue))
	var record := AudioEffectRecord.new()
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, record)
	await create_timer(0.2).timeout
	record.set_recording_active(true)
	for team in [0, 1]:
		main._clear_art_dev_units()
		await process_frame
		var center := Vector2(320, 820 if team == 0 else 460)
		main.play_card(team, "darius", center, {"immediate": true, "validate_position": false})
		var unit: Unit = main._latest_unit_for_card("darius", team)
		unit.move_speed = 0.0
		if team == 0:
			unit.active_ability_id = 99010
			unit.active_ability_slot = 0
			main._register_active_skill(unit, "darius", 0)
		main.play_card(1-team, "garen", center + Vector2(60, -40 if team == 0 else 40), {"immediate": true, "validate_position": false})
		var target: Unit = main._latest_unit_for_card("garen", 1-team)
		target.move_speed = 0.0
		target.damage = 0.0
		target.hp = 10000
		target.max_hp = 10000
		await create_timer(1.7).timeout
		await shot("team%d_first_bleed" % team)
		await create_timer(3.7).timeout
		await shot("team%d_blood_rage" % team)
		target.hp = 300
		if team == 0:
			main._elixir.elixir = 5.0
			main.use_active_skill(unit.active_ability_id, 0)
			await create_timer(0.2).timeout
			await shot("team0_paid_pending")
		else: main.preview_active_skill(unit, CardDB.active_skills_for("darius")[0])
		await create_timer(0.55).timeout
		await shot("team%d_execute" % team)
		await create_timer(1.0).timeout
		await shot("team%d_free_recast" % team)
		if team == 0:
			print("DARIUS_RECAST ", main.get_active_skill_snapshot(unit.active_ability_id))
			main.play_card(1, "garen", center + Vector2(60, -40), {"immediate": true, "validate_position": false})
			var next: Unit = main._latest_unit_for_card("garen", 1)
			next.move_speed = 0.0
			next.damage = 0.0
			main.use_active_skill(unit.active_ability_id, 0)
			await create_timer(1.8).timeout
			await shot("team0_free_used")
		unit.freeze(1.0)
		await create_timer(0.4).timeout
		await shot("team%d_frozen" % team)
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
	main._deck_builder._open_card_info("darius")
	await create_timer(0.2).timeout
	await shot("darius_card_info")
	print("DARIUS_REVIEW_OUTPUT ", output)
	main._clear_art_dev_units()
	main._audio_manager.end_battle()
	main.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	quit()

func _network() -> void:
	for attempt in 300:
		if main._match_started: break
		await create_timer(0.1).timeout
	if not main._match_started:
		push_error("DARIUS_NETWORK match did not start")
		quit(1)
		return
	main._minion_waves_enabled = false
	for tower in main._towers: tower.can_attack = false
	var saw_bleed := false
	var saw_rage := false
	var saw_recast := false
	if main.mode == "host":
		main._deck[0] = "darius"
		main.play_card(0, "darius", Vector2(320, 850), {"immediate": true, "validate_position": false})
		var unit: Unit = main._latest_unit_for_card("darius", 0)
		unit.move_speed = 0.0
		# Source card chosen after lobby only for this deterministic test fixture.
		unit.active_ability_id = 99011
		unit.active_ability_slot = 0
		main._register_active_skill(unit, "darius", 0)
		main.play_card(1, "garen", Vector2(380, 810), {"immediate": true, "validate_position": false})
		var target: Unit = main._latest_unit_for_card("garen", 1)
		target.move_speed = 0.0
		target.damage = 0.0
		target.hp = 10000
		target.max_hp = 10000
		await create_timer(5.4).timeout
		target.hp = 400
		main._elixir.elixir = 5.0
		main.use_active_skill(99011, 0)
		await create_timer(9.0).timeout
		print("DARIUS_NETWORK host state ", main.get_active_skill_snapshot(99011))
	else:
		for sample in 140:
			for id in main.client_unit_ids():
				var unit: Unit = main.find_client_unit(id)
				saw_bleed = saw_bleed or unit.bleeding.total_stacks() > 0
				if unit.card_id == "darius":
					saw_rage = saw_rage or unit.blood_rage_time_left_visual() > 0.0
					saw_recast = saw_recast or bool(main.get_active_skill_snapshot(unit.active_ability_id).get("free_recast", false))
			await create_timer(0.1).timeout
		print("DARIUS_NETWORK client bleed=", saw_bleed, " rage=", saw_rage, " recast=", saw_recast)
	var success: bool = main.mode == "host" or (saw_bleed and saw_rage and saw_recast)
	if main._network_peer != null: main._network_peer.close()
	main.multiplayer.multiplayer_peer = null
	main._clear_art_dev_units()
	main.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	quit(0 if success else 1)
