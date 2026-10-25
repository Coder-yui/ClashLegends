extends SceneTree
## 正式工作台双阵营周期换形、攻速强化、冻结、死亡和运行混音检查。
var main: Node2D
var first_capture := 0
var w_capture := 0
var w_review := "--w-jets-review" in OS.get_cmdline_user_args()
var close_review := "--vfx-close" in OS.get_cmdline_user_args()
var rules_review := "--rules-review" in OS.get_cmdline_user_args()
var anchors_review := "--anchors-review" in OS.get_cmdline_user_args()
var transform_review := "--transform-review" in OS.get_cmdline_user_args()
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("jayce")
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
	panel._set_battle_zoom(3.0 if close_review else 1.2)
	if close_review: panel._desktop.pan(Vector2(0, -250))
	if main.runtime.local_team == 1:
		root.canvas_transform = root.canvas_transform * Transform2D(PI, Vector2(ArenaRules.FIELD_W, ArenaRules.FIELD_H))
	for tower in main.world.towers_snapshot(): tower.can_attack = false
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id == "jayce":
			print("[Jayce audio] ", cue)
			if close_review and cue == &"active_buff:attack_swing":
				w_capture += 1
				_capture.call_deferred("w-shot-%d" % w_capture)
			if cue == &"first_strike_hit":
				first_capture += 1
				_capture.call_deferred("first-hit-%d" % first_capture))
	var units: Array[Unit] = []
	var targets: Array[Unit] = []
	for team in [0, 1]:
		var pos := Vector2(290 + 140 * team, 780) if close_review else Vector2(200 + 320 * team, 780)
		if anchors_review: pos = Vector2(290 + 140 * team, 800) if close_review else Vector2(240 + 240 * team, 800)
		var target_pos := pos + Vector2(0, -60 if team == 0 else 60) if anchors_review else pos + Vector2(0, -110 if team == 0 else 110)
		var target_card := "ashe"
		main.play_card(team, "jayce", pos, {"immediate": true, "validate_position": false})
		for unit in get_nodes_in_group("combatants"):
			if unit is Unit and unit.card_id == "jayce" and unit.team == team:
				units.append(unit)
				unit.configure_carried_active_skill(CardDB.active_skills_for("jayce")[0])
		var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1-team, target_card, target_pos, {"deploy_time_override": 0.0}))
		target.can_attack = false
		target.root(100.0)
		target.max_hp = 10000.0
		target.hp = 10000.0
		targets.append(target)
	for unit in units: unit.cyclic_form.elapsed = 0.0
	units[1]._apply_form(1, false)
	units[1].cyclic_form.first_attack = true
	if anchors_review:
		for unit in units:
			unit.root(100.0)
			unit.can_attack = false
	if rules_review:
		if main._active_skill_bar == null:
			main._active_skill_bar = ActiveSkillBar.new()
			main.add_child(main._active_skill_bar)
		main._active_skill_bar.layer = 31
		main._active_skill_bar.offset = root.get_visible_rect().size * Vector2(0.52, 0.88)
		main._active_skill_bar.show()
		var skill: Dictionary = CardDB.active_skills_for("jayce")[0]
		main._active_skill_bar.show_skill(0, 1, skill.name, Color.CORNFLOWER_BLUE, 1.0, 2, 2, 0.0, true, CardArt.skill_icon(skill))
	for tick in 240:
		for unit in units:
			if is_instance_valid(unit): unit.cyclic_form.elapsed = 0.0
		if anchors_review:
			if tick in [30, 50]:
				for unit in units: unit.toggle_weapon_form()
			if tick == 60:
				for unit in units: unit.cyclic_form.first_attack = false
			if tick == 90:
				for unit in units:
					unit.cyclic_form.first_attack = true
					unit.can_attack = true
		if transform_review and tick == 30:
			for i in units.size(): targets[i].position = units[i].position + Vector2(0, -350 if i == 0 else 350)
		if transform_review and tick == 90:
			for i in units.size(): targets[i].position = units[i].position + Vector2(0, -50 if i == 0 else 50)
		if transform_review and tick in [35,50,100,115]:
			for unit in units:
				unit.toggle_weapon_form()
				unit.cyclic_form.first_attack = true
		if tick in [70]:
			for unit in units:
				if w_review:
					unit.prepare_attack_burst(3, 3.0, 4.0)
					continue
				if anchors_review and unit.form_index == 1: continue
				main.runtime._start_active_skill_cast(unit, CardDB.active_skills_for("jayce")[0])
		if tick == 80 and not transform_review and not anchors_review:
			for unit in units: unit._apply_form(1-unit.form_index, false)
		if tick == 155: units[0].freeze(1.0)
		if tick == 215:
			for unit in units: unit.take_damage(10000.0)
		main._sim_step(0.05)
		if w_review and is_instance_valid(units[0]) and is_instance_valid(units[1]):
			units[0]._body_facing_direction = Vector2(1, -0.4).normalized()
			units[1]._body_facing_direction = Vector2(-1, 0.4).normalized()
		main._skill_presentation.tick_visuals(0.05)
		main._projectile_system.tick_visuals(0.05)
		await create_timer(0.05).timeout
		if anchors_review and tick in [20,31,33,51,53,75,85,92,96]: await _capture("anchors-%03d" % tick)
		if transform_review and tick in [34,35,37,40,49,50,52,55,100,102,105,115,117,120]: await _capture("transform-%03d" % tick)
		if tick in [20,40,72,78,82,90,110,135,165,220,235]: await _capture("combat-%03d" % tick)
	panel.show_workspace(2)
	await create_timer(0.3).timeout
	await _capture("card-info")
	record.set_recording_active(false)
	record.get_recording().save_to_wav(preload("res://tools/lib/development_paths.gd").output("jayce-runtime.wav"))
	main.queue_free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	for frame in 3: await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var path := preload("res://tools/lib/development_paths.gd").output("jayce-"+label+".png")
	root.get_texture().get_image().save_png(path)
	print("[Jayce render] ",path)
