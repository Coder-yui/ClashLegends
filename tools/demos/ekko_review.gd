extends SceneTree
## 正式工作台双阵营连击、回溯、卡面和运行混音检查。
## -- --viewer-team=1 使用红方观察视角。
var main: Node2D
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("ekko")
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
		if id == "ekko": print("[Ekko audio] ", cue))
	var units: Array[Unit] = []
	var targets: Array[Unit] = []
	for team in [0, 1]:
		var pos := Vector2(200 + 320 * team, 780)
		main.play_card(team, "ekko", pos, {"immediate": true, "validate_position": false})
		for unit in get_nodes_in_group("combatants"):
			if unit is Unit and unit.card_id == "ekko" and unit.team == team:
				units.append(unit)
				unit.configure_carried_active_skill(CardDB.active_skills_for("ekko")[0])
		var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1-team, "target_dummy", pos + Vector2(0, -110 if team == 0 else 110), {"deploy_time_override": 0.0}))
		target.max_hp = 10000.0
		target.hp = 10000.0
		targets.append(target)
	for tick in 260:
		if tick == 80:
			for target in targets: target.teleport_to(target.position + Vector2(100, 0))
		if tick == 130:
			for unit in units:
				unit.hp = 150.0
				main.preview_active_skill(unit, CardDB.active_skills_for("ekko")[0])
		if tick == 230:
			for unit in units: unit.take_damage(10000.0)
		main._sim_step(0.05)
		main._skill_presentation.tick_visuals(0.05)
		for frame in 3: await process_frame
		if tick == 10 or tick == 115:
			for node in main._battle_presentation._world_root.get_children():
				if not node is UnitModel3D or node._source.card_id != "ekko": continue
				if tick == 10:
					var player: AnimationPlayer = node._animation_player
					assert(player.current_animation == "Idle_In")
					assert(is_equal_approx(player.get_playing_speed(), player.get_animation("Idle_In").length / 1.0))
					print("[Ekko deploy] team=",node._source.team," clip=",player.current_animation," speed=",player.get_playing_speed()," duration=",node._source.deploy_time)
				else:
					var wrapper = node._model_root
					assert(wrapper._enemy_visual == (node._source.team != main.runtime.local_team))
					print("[Ekko palette] viewer=",main.runtime.local_team," team=",node._source.team," enemy=",wrapper._enemy_visual)
		if tick in [2, 10, 19, 35, 67, 115, 131, 135, 134, 139, 140, 144, 145, 147, 150, 153, 164, 184, 231, 237, 240, 246]:
			await _capture("tick-%03d" % tick)
			for unit in units:
				if is_instance_valid(unit): print("[Ekko state] ",tick," hp=",unit.hp," pos=",unit.position," haste=",unit.get_active_speed_multiplier_visual())
	panel.show_workspace(2)
	await _capture("card-info")
	record.set_recording_active(false)
	var path := preload("res://tools/lib/development_paths.gd").output("ekko-runtime.wav")
	record.get_recording().save_to_wav(path)
	print("[Ekko recording] ",path)
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	main.queue_free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	for frame in 3: await process_frame
	RenderingServer.force_draw()
	var path := preload("res://tools/lib/development_paths.gd").output("ekko-"+label+".png")
	root.get_texture().get_image().save_png(path)
	print("[Ekko render] ",path)
