extends SceneTree
## 正式工作台双阵营飞爪、强化拳、冻结、死亡、卡面和运行混音检查。
## -- --viewer-team=1 使用红方观察视角；--hook-interrupt 在出钩后冻结/击杀来源并移远目标。
## --tower-pull 检查人马正在攻击防御塔时从塔另一侧拉回。
var main: Node2D
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("blitzcrank")
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
		if id == "blitzcrank": print("[Blitzcrank audio] ", cue))
	var units: Array[Unit] = []
	var targets: Array[Unit] = []
	for team in [0, 1]:
		var pos := Vector2(200 + 320 * team, 780)
		var target_pos := pos + Vector2(0, -190 if team == 0 else 190)
		var target_card := "ashe"
		if "--tower-pull" in OS.get_cmdline_user_args():
			for tower in main.world.towers_snapshot():
				if tower.team != team or tower.is_king: continue
				var side := Vector2.DOWN if team == 0 else Vector2.UP
				pos = tower.position + side * (tower.body_radius + 20.0)
				target_pos = tower.position - side * (tower.body_radius + 40.0)
				target_card = "hecarim"
				break
		main.play_card(team, "blitzcrank", pos, {"immediate": true, "validate_position": false})
		for unit in get_nodes_in_group("combatants"):
			if unit is Unit and unit.card_id == "blitzcrank" and unit.team == team:
				units.append(unit)
				unit.configure_carried_active_skill(CardDB.active_skills_for("blitzcrank")[0])
		var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1-team, target_card, target_pos, {"deploy_time_override": 0.0}))
		target.can_attack = target_card == "hecarim"
		if target_card != "hecarim": target.root(100.0)
		target.max_hp = 10000.0
		target.hp = 10000.0
		targets.append(target)
	for tick in 130:
		if tick == 42 and "--hook-interrupt" in OS.get_cmdline_user_args():
			units[0].freeze(2.0)
			units[1].take_damage(10000.0)
			targets[0].position = Vector2(200, 430)
			targets[1].position = Vector2(520, 1130)
		if tick == 50:
			for unit in units:
				if is_instance_valid(unit) and unit.hp > 0.0: main.preview_active_skill(unit, CardDB.active_skills_for("blitzcrank")[0])
		if tick == 85:
			for unit in units:
				if is_instance_valid(unit): unit.freeze(0.5)
		if tick == 105:
			for unit in units:
				if is_instance_valid(unit): unit.take_damage(10000.0)
		main._sim_step(0.05)
		main._skill_presentation.tick_visuals(0.05)
		main._projectile_system.tick_visuals(0.05)
		await create_timer(0.05).timeout
		if tick in [10,20,23,25,28,30,35,40,43,46,48,50,60,66,87,107,125]: await _capture("combat-%03d" % tick)
	panel.show_workspace(2)
	await create_timer(0.3).timeout
	await _capture("card-info")
	record.set_recording_active(false)
	record.get_recording().save_to_wav(preload("res://tools/lib/development_paths.gd").output("blitzcrank-runtime.wav"))
	main.queue_free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	for frame in 3: await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var path := preload("res://tools/lib/development_paths.gd").output("blitzcrank-"+label+".png")
	root.get_texture().get_image().save_png(path)
	print("[Blitzcrank render] ",path)
