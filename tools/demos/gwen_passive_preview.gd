extends SceneTree
## 真实运行格温新被动与万能牌轨迹提示；输出渲染与主混音供复核。
var OUTPUT := preload("res://tools/lib/development_paths.gd").output("clash-gwen-passive")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	print("[输出] ", OUTPUT)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_local()
	main._ai.enabled = false
	main._minion_waves_enabled = false
	for tower in main._towers:
		tower.can_attack = false
	var record := AudioEffectRecord.new()
	var effect_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	for team in [0, 1]:
		main._clear_art_dev_units()
		await process_frame
		var caster_pos := Vector2(360, 950) if team == 0 else Vector2(360, 350)
		var forward := Vector2.UP if team == 0 else Vector2.DOWN
		main.play_card(team, "twisted_fate", caster_pos, {"immediate": true, "validate_position": false})
		await create_timer(float(CardDB.get_card("twisted_fate").pre_deploy_time) + 0.6).timeout
		var caster: Unit = main._latest_unit_for_card("twisted_fate", team)
		caster.move_speed = 0.0
		main.preview_active_skill(caster, CardDB.active_skills_for("twisted_fate")[0])
		await create_timer(0.12).timeout
		await _capture("cards_%d_telegraph" % team)
		await create_timer(0.32).timeout
		await _capture("cards_%d_flight" % team)
		main._clear_art_dev_units()
		await process_frame
		main.play_card(team, "gwen", caster_pos, {"immediate": true, "validate_position": false})
		await create_timer(1.1).timeout
		var gwen: Unit = main._latest_unit_for_card("gwen", team)
		gwen.move_speed = 0.0
		gwen.hp = 300.0
		var skill := CardDB.active_skills_for("gwen")[0]
		gwen.configure_carried_active_skill(skill)
		gwen.add_skill_resource(3.0)
		main._workbench.selection = "training_dummy"
		main._workbench.team = 1 - team
		main._place_art_dev_item(gwen.global_position + forward * 100.0)
		main.preview_active_skill(gwen, skill)
		await create_timer(0.15).timeout
		await _capture("gwen_%d_first" % team)
		await create_timer(0.60).timeout
		await _capture("gwen_%d_middle" % team)
		await create_timer(0.37).timeout
		await _capture("gwen_%d_last" % team)
		await create_timer(0.50).timeout
		print("[格温实战] 阵营=", team, " 技能后生命=", gwen.hp)
	record.set_recording_active(false)
	var recording := record.get_recording()
	if recording != null:
		recording.save_to_wav(OUTPUT + "/live_mix.wav")
	AudioServer.remove_bus_effect(0, effect_index)
	main.queue_free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png")
