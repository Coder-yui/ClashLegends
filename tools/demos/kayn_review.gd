extends SceneTree
var output := preload("res://tools/lib/development_paths.gd").output("kayn-review")
var main: Node2D
func _initialize() -> void:
	_run.call_deferred()
func shot(label: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output+"/"+label+".png")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.audio_listener_enable_2d = true
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_local()
	main._ai.enabled = false
	main._minion_waves_enabled = false
	for tower in main._towers: tower.can_attack = false
	for attempt in 150:
		if main._match_started: break
		await create_timer(0.1).timeout
	if "--deploy-voice" in OS.get_cmdline_user_args():
		await _review_deploy_voice()
		return
	if "--terrain-audio" in OS.get_cmdline_user_args():
		await _review_terrain_audio()
		return
	if "--terrain-exit" in OS.get_cmdline_user_args():
		await _review_terrain_exit()
		return
	if "--ui-only" in OS.get_cmdline_user_args():
		await _review_ui()
		return
	main._audio_manager.cue_played.connect(func(card: String,cue: StringName,_point: Vector2):
		if card.begins_with("kayn"): print("KAYN_AUDIO ",card," ",cue))
	var record := AudioEffectRecord.new()
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,record)
	record.set_recording_active(true)
	for card in ["kayn","kayn_assassin","kayn_slayer"]:
		for team in [0,1]:
			main._clear_art_dev_units()
			await process_frame
			var center := Vector2(360,800 if team == 0 else 480)
			main.play_card(team,card,center,{"immediate":true,"validate_position":false})
			var unit: Unit = main._latest_unit_for_card(card,team)
			unit.hp = 300
			main.play_card(1-team,"garen",center+Vector2(0,-115 if team == 0 else 115),{"immediate":true,"validate_position":false})
			var target: Unit = main._latest_unit_for_card("garen",1-team)
			target.move_speed = 0.0;target.damage = 0.0;target.hp = 10000;target.max_hp = 10000
			await create_timer(2.0).timeout
			await shot(card+"_team"+str(team)+"_attack")
			main.preview_active_skill(unit,CardDB.active_skills_for(card)[0])
			await create_timer(0.2).timeout
			await shot(card+"_team"+str(team)+"_dash")
			await create_timer(0.3).timeout
			await shot(card+"_team"+str(team)+"_spin")
			await create_timer(0.8).timeout
			unit.freeze(0.5)
			await create_timer(0.2).timeout
			await shot(card+"_team"+str(team)+"_frozen")
			await create_timer(0.6).timeout
			unit.take_damage(10000)
			await create_timer(0.4).timeout
			await shot(card+"_team"+str(team)+"_death")
	await create_timer(0.8).timeout
	record.set_recording_active(false)
	var wav := record.get_recording()
	if wav != null: wav.save_to_wav(output+"/battle_mix.wav")
	AudioServer.remove_bus_effect(0,slot)
	print("KAYN_REVIEW_OUTPUT ",output)
	main._clear_art_dev_units()
	main._audio_manager.end_battle()
	main.queue_free()
	await process_frame
	quit()

func _review_ui() -> void:
	main._deck[0] = "kayn"
	for card in ["kayn","kayn_assassin","kayn_slayer"]:
		main._clear_art_dev_units()
		main.play_card(0,card,Vector2(360,950),{"immediate":true,"validate_position":false})
		var unit: Unit = main._latest_unit_for_card(card,0)
		unit.move_speed = 0.0
		unit.active_skill_card_id = "kayn"
		unit.active_ability_id = 99031
		unit.active_ability_slot = 0
		main._register_active_skill(unit,"kayn",0)
		await create_timer(1.2).timeout
		main._elixir.elixir = 5.0
		await shot(card+"_skill_ready")
		main.use_active_skill(unit.active_ability_id,0)
		await create_timer(0.2).timeout
		await shot(card+"_skill_pending")
		await create_timer(1.0).timeout
		await shot(card+"_skill_cooldown")
		main._deck_builder = DeckBuilder.new()
		main.add_child(main._deck_builder)
		main._deck_builder.open(main._deck,main._active_skill_choices,main._skin_choices,func(_deck,_skills,_skins): pass)
		main._deck_builder._open_card_info(card)
		await create_timer(0.2).timeout
		await shot(card+"_card_info")
		main._deck_builder.queue_free()
		main._deck_builder = null
	print("KAYN_UI_OUTPUT ",output)
	main._clear_art_dev_units()
	main.queue_free()
	await process_frame
	quit()

func _review_terrain_exit() -> void:
	var failures := 0
	for card in ["kayn", "kayn_assassin", "kayn_slayer"]:
		for team in [0, 1]:
			main._clear_art_dev_units()
			await process_frame
			var forward := -1.0 if team == 0 else 1.0
			main._workbench.selection = "training_dummy"
			main._workbench.team = 1-team
			main._place_art_dev_item(Vector2(360, ArenaRules.RIVER_Y + forward * 60))
			var target: Unit
			for node in get_nodes_in_group("combatants"):
				if node is Unit and node.card_id == "training_dummy": target = node
			main.play_card(team, card, Vector2(360, ArenaRules.RIVER_Y - forward * 120), {"immediate": true, "validate_position": false})
			var unit: Unit = main._latest_unit_for_card(card, team)
			await create_timer(6.0).timeout
			await shot(card + "_team" + str(team) + "_terrain_exit")
			var good: bool = target.hp < target.max_hp and not unit.terrain_traversal.inside and (unit.position.y - ArenaRules.RIVER_Y) * forward > 0
			print("TERRAIN_EXIT ", card, " team=", team, " passed=", good, " position=", unit.position, " target_hp=", target.hp)
			if not good: failures += 1
	print("KAYN_REVIEW_OUTPUT ", output)
	quit(1 if failures else 0)

func _review_terrain_audio() -> void:
	main.set_process(false)
	var counts := {}
	main._audio_manager.cue_played.connect(func(card: String, cue: StringName, _point: Vector2):
		if String(cue).begins_with("terrain:"):
			var key := card + ":" + String(cue)
			counts[key] = int(counts.get(key, 0)) + 1)
	var record := AudioEffectRecord.new()
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	var failed := 0
	for card in ["kayn", "kayn_assassin", "kayn_slayer"]:
		for team in [0, 1]:
			main._clear_art_dev_units()
			await process_frame
			main.play_card(team, card, Vector2(360, 850), {"immediate": true, "validate_position": false})
			var unit: Unit = main._latest_unit_for_card(card, team)
			var before := counts.duplicate()
			for entry in 2:
				unit.position = Vector2(360, ArenaRules.RIVER_Y)
				for repeat in 10: unit.terrain_traversal.update(unit)
				await create_timer(4.4).timeout
				unit.position = Vector2(360, 850)
				unit.terrain_traversal.update(unit)
				await create_timer(0.1).timeout
			await process_frame
			var good := true
			for cue in ["terrain:enter", "terrain:sustain", "terrain:exit"]:
				var key: String = card + ":" + cue
				good = good and int(counts.get(key, 0)) - int(before.get(key, 0)) == 2
			if not good: failed += 1
			print("TERRAIN_AUDIO ", card, " team=", team, " enter_loop_exit_twice_only=", good)
	record.set_recording_active(false)
	var wav := record.get_recording()
	if wav != null: wav.save_to_wav(output + "/terrain_mix.wav")
	AudioServer.remove_bus_effect(0, slot)
	main._clear_art_dev_units()
	main._audio_manager.end_battle()
	print("KAYN_REVIEW_OUTPUT ", output)
	quit(1 if failed else 0)

func _review_deploy_voice() -> void:
	main.set_process(false)
	main._audio_manager.cue_played.connect(func(id: String, cue: StringName, _point: Vector2):
		if cue == &"deploy:voice": print("DEPLOY_VOICE ", id))
	var record := AudioEffectRecord.new()
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	for card in ["kayn", "kayn_assassin", "kayn_slayer"]:
		for team in [0, 1]:
			main._clear_art_dev_units()
			await process_frame
			main.play_card(team, card, Vector2(360, 850), {"immediate": true, "validate_position": false})
			await create_timer(6.2).timeout
	record.set_recording_active(false)
	var wav := record.get_recording()
	if wav != null: wav.save_to_wav(output + "/deploy_voice_mix.wav")
	AudioServer.remove_bus_effect(0, slot)
	main._clear_art_dev_units()
	main._audio_manager.end_battle()
	print("KAYN_REVIEW_OUTPUT ", output)
	quit()
