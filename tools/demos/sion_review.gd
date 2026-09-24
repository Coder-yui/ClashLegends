extends SceneTree
## 正式出牌/技能入口的赛恩双阵营实战验收，包含复生、护盾与混音录音。
var output := preload("res://tools/lib/development_paths.gd").output("sion-review")
var main: Node2D
func _initialize() -> void:
	_run.call_deferred()
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/" + label + ".png")
	for node in main.find_children("*", "Node3D", true, false):
		if node is UnitModel3D and node._animation_player != null and node._model_root != null and "Sion" in node._model_root.name:
			print("SION_CLIP ", label, " ", node._animation_player.current_animation, " source_time=", node._animation_player.current_animation_position, " speed=", node._current_clip_speed, " blend=", node._last_clip_blend_time)
func _run() -> void:
	root.audio_listener_enable_2d = true
	DirAccess.make_dir_recursive_absolute(output)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	if "--network" in OS.get_cmdline_user_args():
		await _run_network()
		return
	main._start_local()
	main._ai.enabled = false
	main._minion_waves_enabled = false
	for tower in main._towers: tower.can_attack = false
	for attempt in 100:
		if main._match_started: break
		await create_timer(0.1).timeout
	if "--frozen-revival" in OS.get_cmdline_user_args():
		await _run_frozen_revival()
		return
	if "--attack-order" in OS.get_cmdline_user_args():
		await _run_attack_order()
		return
	main._deck[0] = "sion"
	main._audio_manager.cue_played.connect(func(card: String, cue: StringName, _position: Vector2):
		if card == "sion": print("SION_AUDIO ", cue, " tick=", main._sim_tick_id, " ms=", Time.get_ticks_msec()))
	var record := AudioEffectRecord.new()
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, record)
	await create_timer(0.2).timeout
	record.set_recording_active(true)
	for team in [0, 1]:
		main._clear_art_dev_units()
		await process_frame
		var center := Vector2(350, 870 if team == 0 else 410)
		main.play_card(team, "sion", center, {"immediate": true, "validate_position": false})
		var unit: Unit = main._latest_unit_for_card("sion", team)
		unit.move_speed = 0.0
		if team == 0:
			unit.active_ability_id = 9000
			unit.active_ability_slot = 0
			main._register_active_skill(unit, "sion", 0)
		main.play_card(1-team, "anivia", center + Vector2(70, 0), {"immediate": true, "validate_position": false})
		var air: Unit = main._latest_unit_for_card("anivia", 1-team)
		air.move_speed = 0.0
		air.damage = 0.0
		await create_timer(1.2).timeout
		await shot("team%d_base" % team)
		unit.move_speed = 44.0
		await create_timer(0.3).timeout
		await shot("team%d_run" % team)
		unit.move_speed = 0.0
		if team == 0:
			main._elixir.elixir = 5.0
			main.use_active_skill(unit.active_ability_id, 0)
			await create_timer(0.2).timeout
			await shot("team0_skill_pending")
			await create_timer(0.5).timeout
		else:
			main.preview_active_skill(unit, CardDB.active_skills_for("sion")[0])
			await create_timer(0.2).timeout
		await shot("team%d_shield" % team)
		await create_timer(1.85).timeout
		await shot("team%d_explosion" % team)
		await create_timer(0.3).timeout
		unit.take_damage(10000)
		await create_timer(0.45).timeout
		await shot("team%d_revival_wait" % team)
		await create_timer(1.0).timeout
		await shot("team%d_revival_late" % team)
		await create_timer(0.6).timeout
		await shot("team%d_passive" % team)
		await create_timer(0.25).timeout
		await shot("team%d_passive_run" % team)
		main.play_card(1-team, "garen", center + Vector2(80, 0), {"immediate": true, "validate_position": false})
		var ground: Unit = main._latest_unit_for_card("garen", 1-team)
		ground.move_speed = 0.0
		ground.damage = 0.0
		ground.hp = 10000
		ground.max_hp = 10000
		await create_timer(1.4).timeout
		await shot("team%d_passive_attack" % team)
		await create_timer(1.0).timeout
		unit.take_damage(10000)
		await create_timer(0.3).timeout
		await shot("team%d_death" % team)
		await create_timer(0.4).timeout
		await shot("team%d_death_late" % team)
	record.set_recording_active(false)
	await create_timer(0.2).timeout
	var wav := record.get_recording()
	if wav != null: wav.save_to_wav(output + "/battle_mix.wav")
	AudioServer.remove_bus_effect(0, slot)
	main._deck_builder = DeckBuilder.new()
	main.add_child(main._deck_builder)
	main._deck_builder.open(main._deck, main._active_skill_choices, main._skin_choices, func(_deck, _skills, _skins): pass)
	main._deck_builder._open_card_info("sion")
	await create_timer(0.2).timeout
	await shot("sion_card_info")
	print("SION_REVIEW_OUTPUT ", output)
	main._clear_art_dev_units()
	main._audio_manager.end_battle()
	main.queue_free()
	await process_frame
	await create_timer(1.0).timeout
	quit()

func _run_network() -> void:
	for attempt in 300:
		if main._match_started: break
		await create_timer(0.1).timeout
	if not main._match_started:
		push_error("SION_NETWORK match did not start")
		quit(1)
		return
	main._minion_waves_enabled = false
	for tower in main._towers: tower.can_attack = false
	var saw_shield := false
	var saw_wait := false
	var saw_berserk := false
	var saw_recovery_bar := false
	var saw_thawed_wait := false
	if main.mode == "host":
		main.play_card(0, "sion", Vector2(350, 900), {"immediate": true, "validate_position": false})
		var unit: Unit = main._latest_unit_for_card("sion", 0)
		unit.move_speed = 0.0
		await create_timer(1.2).timeout
		main.preview_active_skill(unit, CardDB.active_skills_for("sion")[0])
		await create_timer(2.4).timeout
		unit.hp = 1.0
		unit.freeze(8.0)
		await create_timer(0.3).timeout
		print("SION_NETWORK before lethal hp=", unit.hp, " state=", unit.death_form.snapshot(), " tick=", main._sim_tick_id)
		unit.take_damage(10000)
		print("SION_NETWORK after lethal hp=", unit.hp, " state=", unit.death_form.snapshot(), " ids=", main.authoritative_units_snapshot().keys())
		await create_timer(2.2).timeout
		print("SION_NETWORK after revival hp=", unit.hp, " state=", unit.death_form.snapshot(), " form=", unit.form_index, " ids=", main.authoritative_units_snapshot().keys())
		await create_timer(10.0).timeout
		print("SION_NETWORK host completed")
	else:
		for sample in 140:
			for id in main.client_unit_ids():
				var unit: Unit = main.find_client_unit(id)
				if unit.card_id != "sion": continue
				if sample % 5 == 0: print("SION_NETWORK sample=", sample, " hp=", unit.hp, " form=", unit.get_form_index(), " state=", unit.death_form.snapshot())
				saw_shield = saw_shield or unit.has_explosive_shield()
				saw_wait = saw_wait or (unit.hp == 0 and unit.death_form.waiting())
				if unit.death_form.waiting():
					saw_thawed_wait = saw_thawed_wait or not unit.presentation_state().frozen
					var bar := unit.presentation_state().health_ratio
					saw_recovery_bar = saw_recovery_bar or (bar > 0.2 and bar < 0.8 and unit.hp == 0)
				saw_berserk = saw_berserk or (unit.get_form_index() == 1 and unit.hp > 0)
			await create_timer(0.1).timeout
		print("SION_NETWORK client shield=", saw_shield, " zero_hp_wait=", saw_wait, " berserk=", saw_berserk, " thawed_wait=", saw_thawed_wait, " recovery_bar=", saw_recovery_bar)
		if not (saw_shield and saw_wait and saw_berserk and saw_thawed_wait and saw_recovery_bar):
			push_error("SION_NETWORK missed authoritative states")
	var success: bool = main.mode == "host" or (saw_shield and saw_wait and saw_berserk and saw_thawed_wait and saw_recovery_bar)
	if main._network_peer != null: main._network_peer.close()
	main.multiplayer.multiplayer_peer = null
	main._clear_art_dev_units()
	main.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	quit(0 if success else 1)

func _run_frozen_revival() -> void:
	main.play_card(0, "sion", Vector2(260, 880), {"immediate": true, "validate_position": false})
	main.play_card(0, "anivia", Vector2(460, 880), {"immediate": true, "validate_position": false})
	var sion: Unit = main._latest_unit_for_card("sion", 0)
	var bird: Unit = main._latest_unit_for_card("anivia", 0)
	sion.move_speed = 0.0
	bird.move_speed = 0.0
	await create_timer(1.1).timeout
	for unit in [sion, bird]:
		unit.hp = 1.0
		unit.freeze(8.0)
	await create_timer(0.25).timeout
	await shot("frozen_alive")
	for unit in [sion, bird]: unit.take_damage(2.0)
	for sample in [0.1, 0.85, 0.85, 0.3, 1.2]:
		await create_timer(sample).timeout
		print("FROZEN_REVIVAL hp=", sion.hp, " ticks=", sion.death_form.waiting_ticks, " bar=", sion.presentation_state().health_ratio, " frozen=", sion.is_frozen())
		await shot("frozen_revival_%d" % sion.death_form.waiting_ticks)
	print("SION_REVIEW_OUTPUT ", output)
	main._clear_art_dev_units()
	main._audio_manager.end_battle()
	main.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	quit()

func _run_attack_order() -> void:
	var target: Tower
	for tower in main._towers:
		if tower.team == 1:
			target = tower
			break
	var record := AudioEffectRecord.new()
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	main.play_card(0, "sion", target.global_position + Vector2(0, target.body_radius + 45), {"immediate": true, "validate_position": false})
	var unit: Unit = main._latest_unit_for_card("sion", 0)
	var last_serial := 0
	for sample in 100:
		await create_timer(0.05).timeout
		var serial := unit.get_attack_visual_serial()
		if serial > last_serial:
			last_serial = serial
			await create_timer(0.18).timeout
			await shot("attack_order_%d" % serial)
		if serial >= 3: break
	record.set_recording_active(false)
	await create_timer(0.1).timeout
	var wav := record.get_recording()
	if wav != null: wav.save_to_wav(output + "/attack_order.wav")
	AudioServer.remove_bus_effect(0, slot)
	print("SION_ORDER cost=", CardDB.get_card("sion").cost, " attacks=", last_serial, " output=", output)
	main._clear_art_dev_units()
	main._audio_manager.end_battle()
	main.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	quit()
