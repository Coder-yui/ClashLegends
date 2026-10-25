extends SceneTree
## 正式工作台双阵营火药桶受击、主动引爆、死亡爆炸与运行混音检查。
var main: Node2D
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("powder_keg")
	panel.show_workspace(1)
	main._clear_art_dev_units()
	await process_frame
	if "--viewer-team=1" in OS.get_cmdline_user_args():
		main._battle_presentation.free()
		main._battle_presentation = null
		main.runtime.local_team = 1
		main._setup_battle_presentation()
		main._cast_notice.presentation = main._battle_presentation
		for tower in main.world.towers_snapshot():
			main._battle_presentation.attach_tower(tower, CardDB.NEXUS_VISUAL_CONFIG if tower.is_king else CardDB.PRINCESS_TOWER_VISUAL_CONFIG)
	main.set_process(false)
	main.set_physics_process(false)
	panel._set_battle_zoom(1.2)
	if main.runtime.local_team == 1:
		root.canvas_transform = root.canvas_transform * Transform2D(PI, Vector2(ArenaRules.FIELD_W, ArenaRules.FIELD_H))
	for tower in main.world.towers_snapshot(): tower.can_attack = false
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id == "powder_keg": print("[PowderKeg audio] ", cue))
	var units: Array[Unit] = []
	for team in [0, 1]:
		var pos := Vector2(210 + 300 * team, 850)
		main.play_card(team, "powder_keg", pos, {"immediate": true, "validate_position": false})
		for unit in get_nodes_in_group("combatants"):
			if unit is Unit and unit.card_id == "powder_keg" and unit.team == team:
				units.append(unit)
				unit.configure_carried_active_skill(CardDB.active_skills_for("powder_keg")[0])
		var dummy: Unit = main._spawn_unit(UnitSpawnRequest.new(team, "target_dummy", pos + Vector2(0, 130), {"deploy_time_override": 0.0}))
		dummy.lifespan = 0
		var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1-team, "garen", pos + Vector2(0, -70), {"deploy_time_override": 0.0}))
		target.can_attack = false
		target.root(100.0)
		target.hp = 100.0
	for tick in 140:
		if tick == 40:
			for unit in units: unit.take_damage(50)
		if tick == 70:
			main.preview_active_skill(units[0], CardDB.active_skills_for("powder_keg")[0])
			units[1].take_damage(10000)
		main._sim_step(0.05)
		main._skill_presentation.tick_visuals(0.05)
		await create_timer(0.05).timeout
		if tick in [25,42,70,72,76,82,105,135]: await _capture("combat-%03d" % tick)
	panel.show_workspace(2)
	await create_timer(0.3).timeout
	await _capture("card-info")
	record.set_recording_active(false)
	record.get_recording().save_to_wav(preload("res://tools/lib/development_paths.gd").output("powder_keg-runtime.wav"))
	main.queue_free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	for frame in 3: await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var path := preload("res://tools/lib/development_paths.gd").output("powder_keg-"+label+".png")
	root.get_texture().get_image().save_png(path)
	print("[PowderKeg render] ",path)
