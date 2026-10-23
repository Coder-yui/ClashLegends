extends SceneTree
## 正式工作台出牌、双方枪刀/R、尺寸参考与运行混音。
var main: Node2D
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	if "--stance-review" in OS.get_cmdline_user_args() or "--r-exit-review" in OS.get_cmdline_user_args():
		await _stance_review()
		return
	if "--passive-review" in OS.get_cmdline_user_args() or "--ready-audit" in OS.get_cmdline_user_args():
		await _passive_review()
		return
	if "--attack-audit" in OS.get_cmdline_user_args():
		await _attack_audit()
		return
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("samira")
	panel.show_workspace(1)
	main.set_process(false)
	main.set_physics_process(false)
	panel._set_battle_zoom(1.3)
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id == "samira": print("[Samira audio] ", cue))
	var units: Array[Unit] = []
	var targets: Array[Unit] = []
	var bullet_captured := false
	for team in [0, 1]:
		var pos := Vector2(180 + 360 * team, 780)
		main.play_card(team, "samira", pos, {"immediate": true, "validate_position": false})
		for unit in get_nodes_in_group("combatants"):
			if unit is Unit and unit.card_id == "samira" and unit.team == team:
				units.append(unit)
				unit.configure_carried_active_skill(CardDB.active_skills_for("samira")[0])
				unit.move_speed = 0.0
				unit.max_hp = 10000.0
				unit.hp = 10000.0
		var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1-team, "target_dummy", pos + Vector2(0, -130 if team == 0 else 45), {"deploy_time_override": 0.0}))
		target.max_hp = 10000.0
		target.hp = 10000.0
		targets.append(target)
	for pair in [["ashe", Vector2(240, 970)], ["samira", Vector2(360, 970)], ["jinx", Vector2(480, 970)]]:
		main.play_card(0, pair[0], pair[1], {"immediate": true, "validate_position": false})
	for unit in get_nodes_in_group("combatants"):
		if unit is Unit and unit.position.y > 900: unit.can_attack = false; unit.move_speed = 0.0
	for tick in 200:
		if tick == 110:
			for index in units.size():
				units[index].move_speed = 60.0
				targets[index].position = units[index].position + Vector2(0, -245.0)
			for unit in units:
				unit.skill_resource_value = 5.0
				print("[Samira cast] ", main.preview_active_skill(unit, CardDB.active_skills_for("samira")[0]))
		if tick == 158:
			for unit in units: unit.skill_resource_value = 5.0; main.preview_active_skill(unit, CardDB.active_skills_for("samira")[0])
		if tick == 168:
			units[0].freeze(1.0)
			units[1].take_damage(99999.0)
		main._sim_step(0.05)
		await create_timer(0.05).timeout
		if not bullet_captured:
			for projectile in main._projectile_system.visible_view().values():
				if str(projectile.get("visual", "")) == "samira_bullet":
					await _capture("native-bullet")
					bullet_captured = true
					break
		if tick == 120 and "--isolate" in OS.get_cmdline_user_args():
			var players: Array = []
			for node in root.find_children("*", "", true, false):
				if node.get_script() != null and node.get_script().resource_path == "res://assets/effects/samira/player.gd": players.append(node)
			for layer in [-1, 2, 3, 4, 10, 11, 15, 18, 20]:
				for node in players:
					if layer == -1: node.visible = false
					else:
						for item in node._pools[layer]: item.visible = false
				await _capture("without-layer-%d" % layer)
				for node in players:
					node.visible = true
					node._frame = -1
					node.seek(node._age)
		if tick in [12, 40, 75, 112, 120, 135, 148, 152, 171, 195]:
			await _capture("tick-%03d" % tick)
			for unit in units:
				if is_instance_valid(unit): print("[Samira state] ", tick, " team=", unit.team, " hp=", unit.hp, " score=", unit.skill_resource_value, " melee=", unit.close_attack, " serial=", unit.get_attack_visual_serial())
	panel.show_workspace(2)
	await _capture("card-info")
	record.set_recording_active(false)
	var path := preload("res://tools/lib/development_paths.gd").output("samira-runtime.wav")
	record.get_recording().save_to_wav(path)
	print("[Samira recording] ", path)
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	main.queue_free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var path := preload("res://tools/lib/development_paths.gd").output("samira-"+label+".png")
	root.get_texture().get_image().save_png(path)
	print("[Samira render] ",path)


func _attack_audit() -> void:
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("samira")
	panel.show_workspace(1)
	panel._set_battle_zoom(1.6)
	main.set_process(false)
	main.set_physics_process(false)
	var rows: Array = []
	var directions := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for actor in get_nodes_in_group("combatants"):
		if actor is Tower: actor.can_attack = false
	for case_index in 16:
		# 审核模型暂停了自动_process，显式释放以免上一案例残影留在画面。
		for node in main._battle_presentation._world_root.get_children():
			if node is UnitModel3D: node.free()
		for actor in get_nodes_in_group("combatants"):
			if actor is Unit: actor.free()
		main._projectile_system.clear_all()
		await process_frame
		var segment: int = case_index % 4
		var direction: Vector2 = directions[case_index / 4]
		var team: int = (case_index / 4) % 2
		main.play_card(team, "samira", Vector2(360, 800), {"immediate": true, "validate_position": false})
		var unit: Unit
		for actor in get_nodes_in_group("combatants"):
			if actor is Unit and actor.card_id == "samira": unit = actor
		unit._deploy_timer = 0.0
		unit.can_attack = false
		unit.move_speed = 0.0
		unit.max_hp = 100000.0
		unit.hp = unit.max_hp
		unit._attack_swing_count = segment % 2
		var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1-team, "target_dummy", unit.position + direction * (130.0 if segment < 2 else 50.0), {"deploy_time_override": 0.0}))
		target.lifespan_hp_decay = false
		target.max_hp = 100000.0
		target.hp = target.max_hp
		unit._target = target
		unit._body_facing_direction = direction
		for frame in 5: await process_frame
		var view: Node
		for node in main._battle_presentation._world_root.get_children():
			if node is UnitModel3D and node._source == unit: view = node
		view.set_process(false)
		view._animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		main._battle_presentation._samira_projectiles.set_process(false)
		unit.can_attack = true
		var previous_serial := 0
		var previous_swing := segment % 2
		var previous_hp := target.hp
		var first_event := false
		var flight_capture_tick := -1
		for tick in 65:
			main._sim_step(0.05)
			# 固定步驱动实际模型，避免截图等待使动画时钟领先模拟。
			if unit.get_attack_visual_serial() == previous_serial:
				view._animation_player.advance(0.05)
				view._update_attack_stages(0.05)
			view._process(0.0)
			view._sync_transform(false, 0.05)
			await process_frame
			view._update_health_bar_anchor()
			main._battle_presentation._samira_projectiles.sync_effects(main._projectile_system, main._battle_presentation._camera)
			var event := ""
			if unit.get_attack_visual_serial() != previous_serial: event += "start;"
			if unit._attack_swing_count != previous_swing: event += "release;" if segment < 2 else "melee_hit;"
			if target.hp != previous_hp: event += "damage;"
			var bullet: Dictionary = {}
			for projectile in main._projectile_system.visible_view().values():
				if str(projectile.get("visual", "")) == "samira_bullet":
					bullet = {"position": str(main._projectile_system._visual_position(projectile)), "progress": projectile.visual_path.progress, "origin": str(main._projectile_system._visual_origin_cache.get(projectile.visual_id, Vector2.INF)), "spawn_fallback": str(projectile.visual_path.start_model_offset)}
			var ap: AnimationPlayer = view._animation_player
			rows.append({"case": case_index, "segment": segment, "direction": str(direction), "team": team, "tick": tick, "event": event, "serial": unit.get_attack_visual_serial(), "swing": unit._attack_swing_count, "windup": unit.attack_timeline.windup, "cooldown": unit.attack_timeline.cooldown, "elapsed": unit.attack_timeline.visual_elapsed, "hp": target.hp, "animation": ap.current_animation, "animation_time": ap.current_animation_position, "animation_speed": ap.get_playing_speed(), "muzzle": str(unit.get_meta("projectile_model_offset", Vector2.INF)), "bullet": bullet})
			if tick == flight_capture_tick:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(preload("res://tools/lib/development_paths.gd").output("samira-attack-%02d-flight.png" % case_index))
			if not first_event and ("release" in event or "melee_hit" in event):
				await RenderingServer.frame_post_draw
				var path := preload("res://tools/lib/development_paths.gd").output("samira-attack-%02d-event.png" % case_index)
				root.get_texture().get_image().save_png(path)
				print("[Samira attack] ", path)
				first_event = true
				if segment < 2: flight_capture_tick = tick + 1
			previous_serial = unit.get_attack_visual_serial()
			previous_swing = unit._attack_swing_count
			previous_hp = target.hp
	var path := preload("res://tools/lib/development_paths.gd").output("samira-attack-events.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "  "))
	file.close()
	print("[Samira attack evidence] ", path)
	main.queue_free()
	await process_frame
	quit()


func _passive_review() -> void:
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("samira")
	panel.show_workspace(1)
	panel._set_battle_zoom(1.3)
	main.set_process(false)
	main.set_physics_process(false)
	var units: Array[Unit] = []
	for actor in get_nodes_in_group("combatants"):
		if actor is Tower: actor.can_attack = false
	for team in [0, 1]:
		main.play_card(team, "samira", Vector2(230 + team * 260, 780), {"immediate": true, "validate_position": false})
		for actor in get_nodes_in_group("combatants"):
			if actor is Unit and actor.card_id == "samira" and actor.team == team:
				actor._deploy_timer = 0.0
				actor.move_speed = 0.0
				actor.can_attack = false
				units.append(actor)
	units[1].configure_carried_active_skill(CardDB.active_skills_for("samira")[0])
	if "--ready-audit" in OS.get_cmdline_user_args():
		await _ready_audit(units)
		return
	for tick in 135:
		if tick == 5:
			for unit in units: unit.on_attack_landed(0, 72.0, -1, -1, 1.0)
		if tick == 20:
			for unit in units: unit.on_attack_landed(0, 108.0, -1, -1, 2.0); unit.on_attack_landed(0, 108.0, -1, -1, 2.0)
		if tick == 80: units[1].on_attack_landed(0, 72.0, -1, -1, 1.0)
		if tick == 90: main.preview_active_skill(units[1], CardDB.active_skills_for("samira")[0])
		main._sim_step(0.05)
		await create_timer(0.05).timeout
		if tick in [10, 22, 35, 65, 88, 95, 105, 132]:
			await _capture("passive-%03d" % tick)
			for unit in units: print("[Samira passive] ", tick, " team=", unit.team, " stacks=", unit.skill_resource_value, " remaining=", unit.skill_resource_time_left, " move=", unit._effective_movement_multiplier())
	main.queue_free()
	await process_frame
	quit()

func _ready_audit(units: Array[Unit]) -> void:
	for frame in 5: await process_frame
	var views: Array = []
	for unit in units:
		for node in main._battle_presentation._world_root.get_children():
			if node is UnitModel3D and node._source == unit:
				node.set_process(false)
				views.append(node)
	var report: Array = []
	for facing in 4:
		for view in views:
			view.rotation.y = facing * PI / 2.0
			view._source.skill_resource_value = 5.0
			view._active_buff_visual._ready_age = 0.0
		for tick in 22:
			for view in views: view._update_active_buff_visual(0.05)
			if tick in [2, 19]:
				await _capture("ready-dir%d-age%02d" % [facing, tick])
		for view in views:
			var buff = view._active_buff_visual
			var native_model = view._model_root.get_node("Model")
			var error: float = buff._ready_particles.global_position.distance_to(native_model.global_position)
			var attached_error := 0.0
			for entry in buff._ready_surfaces:
				attached_error = maxf(attached_error, entry.effect.global_position.distance_to(entry.source.get_ref().global_position))
			report.append({"direction": facing, "team": view._source.team, "origin_error": error, "skin_origin_error": attached_error, "source_scale": buff._ready_particles.global_basis.get_scale().x})
	for view in views:
		view._source.skill_resource_value = 0.0
		view._update_active_buff_visual(0.05)
	await _capture("ready-cleared")
	var output := FileAccess.open(preload("res://tools/lib/development_paths.gd").output("samira-ready-audit.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	main.queue_free()
	await process_frame
	quit()


func _stance_review() -> void:
	var r_review := "--r-exit-review" in OS.get_cmdline_user_args()
	var capture_ticks := [30, 50, 75, 82, 90, 105, 120, 155, 199] if r_review else [0, 30, 75, 95, 110, 135, 155, 161, 199]
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("samira")
	panel.show_workspace(1)
	panel._set_battle_zoom(1.7)
	main.set_process(false)
	main.set_physics_process(false)
	for actor in get_nodes_in_group("combatants"):
		if actor is Tower: actor.can_attack = false
	var units: Array[Unit] = []
	var views: Array[UnitModel3D] = []
	for index in 4:
		var team: int = index / 2
		var pos := Vector2(270 + 180 * (index % 2), 740 + 170 * team)
		main.play_card(team, "samira", pos, {"immediate": true, "validate_position": false})
		var unit: Unit
		for actor in get_nodes_in_group("combatants"):
			if actor is Unit and actor.card_id == "samira" and not units.has(actor): unit = actor
		units.append(unit)
		unit._deploy_timer = 0.0
		unit.move_speed = 0.0
		unit.can_attack = false
		unit._body_facing_direction = Vector2.UP if team == 0 else Vector2.DOWN
		unit.max_hp = 100000.0
		unit.hp = unit.max_hp
		await process_frame
		for node in main._battle_presentation._world_root.get_children():
			if node is UnitModel3D and node._source == unit:
				views.append(node)
				node.set_process(false)
				node._animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var rows: Array = []
	for tick in 200:
		for index in 4:
			var unit := units[index]
			var view := views[index]
			if tick == 0:
				unit._attack_visual_serial = 1 if index % 2 == 0 else 3
				unit._attacking = true
			if tick == 8:
				unit._attacking = false
				unit._move_intent = Vector2.RIGHT
			if tick == 35: unit._move_intent = Vector2.ZERO
			if tick == 100 and not r_review: unit._move_intent = Vector2.RIGHT
			if tick == 160:
				unit._attack_visual_serial = 7 if index % 2 == 0 else 5
				unit._attacking = true
			if tick == 168:
				unit._attacking = false
				unit._move_intent = Vector2.ZERO
			if r_review:
				if tick == 40:
					unit._move_intent = Vector2.RIGHT if index % 2 == 0 else Vector2.ZERO
					unit.play_visual_action(&"inferno", 2.0)
				elif tick > 40:
					unit._visual_action_time_left = maxf(unit._visual_action_time_left - 0.05, 0.0)
			view._animation_player.advance(0.05)
			view._process(0.05)
			if tick in capture_ticks:
				rows.append({"tick":tick,"team":unit.team,"serial":unit.get_attack_visual_serial(),"animation":view._animation_player.assigned_animation,"time":view._animation_player.current_animation_position})
		if tick in capture_ticks: await _capture(("r-exit-%03d" if r_review else "stance-%03d") % tick)
	var file := FileAccess.open(preload("res://tools/lib/development_paths.gd").output("samira-r-exit-events.json" if r_review else "samira-stance-events.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "	"))
	for view in views: view.free()
	main.queue_free()
	await process_frame
	quit()
