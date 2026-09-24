extends SceneTree
## 双方正式技能入口：Spell2、固定圣霭、圈内移动/敌人入圈、到期/出圈、混音与UI。
var output := preload("res://tools/lib/development_paths.gd").output("gwen-mist")
var main: Node2D
func _initialize() -> void:
	_run.call_deferred()
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/" + label + ".png")
func _run() -> void:
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
	main._active_skill_choices["gwen"] = 1
	main._deck[0] = "gwen"
	main._audio_manager.cue_played.connect(func(card: String, cue: StringName, position: Vector2):
		if card == "gwen": print("MIST_AUDIO ", cue, " at ", position))
	var record := AudioEffectRecord.new()
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	for team in [0, 1]:
		main._clear_art_dev_units()
		await process_frame
		var center := Vector2(360, 820 if team == 0 else 440)
		main.play_card(team, "gwen", center, {"immediate": true, "validate_position": false})
		var gwen: Unit = main._latest_unit_for_card("gwen", team)
		if team == 0:
			gwen.active_ability_id = 9000
			gwen.active_ability_slot = 0
			main._register_active_skill(gwen, "gwen", team)
		gwen.move_speed = 0.0
		gwen.hp = 10000; gwen.max_hp = 10000
		main.play_card(1-team, "ashe", center + Vector2(180, 0), {"immediate": true, "validate_position": false})
		var enemy: Unit = main._latest_unit_for_card("ashe", 1-team)
		enemy.move_speed = 0.0
		await create_timer(1.15).timeout
		main.preview_active_skill(gwen, CardDB.active_skills_for("gwen")[1])
		await create_timer(0.18).timeout
		await shot("team%d_spell2" % team)
		await create_timer(0.72).timeout
		await shot("team%d_idle_transition" % team)
		gwen.position += Vector2(-40, 0)
		await create_timer(0.30).timeout
		await shot("team%d_fixed_center" % team)
		enemy.position = center + Vector2(75, 0)
		await create_timer(0.9).timeout
		await shot("team%d_enemy_inside" % team)
		await create_timer(2.1).timeout
		await shot("team%d_expired" % team)
		# 第二次：真实行走出圈，检查Spell2转跑及声音提前结束。
		enemy.position = gwen.position + Vector2(195, 0)
		main.preview_active_skill(gwen, CardDB.active_skills_for("gwen")[1])
		gwen.move_speed = 100.0
		await create_timer(0.87).timeout
		await shot("team%d_run_transition" % team)
		await create_timer(0.75).timeout
		await shot("team%d_exit" % team)
		print("MIST_EXIT team=", team, " active=", gwen.target_protection.active())
		await create_timer(0.5).timeout
	record.set_recording_active(false)
	var wav := record.get_recording()
	if wav != null: wav.save_to_wav(output + "/battle_mix.wav")
	AudioServer.remove_bus_effect(0, slot)
	main._deck_builder = DeckBuilder.new()
	main.add_child(main._deck_builder)
	main._deck_builder.open(main._deck, main._active_skill_choices, main._skin_choices, func(_deck, _skills, _skins): pass)
	main._deck_builder._open_card_info("gwen")
	await create_timer(0.1).timeout
	await shot("gwen_skill_info")
	print("MIST_REVIEW_OUTPUT ", output)
	main.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit()
