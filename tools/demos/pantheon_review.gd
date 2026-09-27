extends SceneTree
var output := preload("res://tools/lib/development_paths.gd").output("pantheon-review")
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
	main._start_local()
	main._ai.enabled = false
	main._minion_waves_enabled = false
	for tower in main._towers: tower.can_attack = false
	for attempt in 100:
		if main._match_started: break
		await create_timer(0.1).timeout
	if "--review-live" in OS.get_cmdline_user_args():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--review-output="): output = arg.trim_prefix("--review-output=")
		AudioServer.set_bus_mute(0, true)
		await _capture_pack_live()
		var file := FileAccess.open(output + "/review_manifest.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"items": _pack_manifest}, "\t"))
		file.close()
		print("PANTHEON_REVIEW_OUTPUT ", output)
		await _finish_arrival_review()
		return
	if "--review-pack" in OS.get_cmdline_user_args():
		await _review_pack()
		await _finish_arrival_review()
		return
	if "--movement-range" in OS.get_cmdline_user_args():
		await _movement_range()
		quit()
		return
	if "--arrival-timeline" in OS.get_cmdline_user_args():
		await _arrival_timeline()
		await _finish_arrival_review()
		return
	if "--arrival-materials" in OS.get_cmdline_user_args() or not _layer_system().is_empty():
		await _arrival_materials()
		await _finish_arrival_review()
		return
	if "--size-comparison" in OS.get_cmdline_user_args():
		await _size_comparison()
		quit()
		return
	main._audio_manager.cue_played.connect(func(card: String, cue: StringName, _position: Vector2):
		if card == "pantheon": print("PANTHEON_AUDIO ", cue))
	var record := AudioEffectRecord.new()
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	for team in [0, 1]:
		main._clear_art_dev_units()
		await process_frame
		var center := Vector2(320, 820 if team == 0 else 460)
		var direction := Vector2.UP if team == 0 else Vector2.DOWN
		var victims: Array[Unit] = []
		for point in ([] if "--clean-arrival" in OS.get_cmdline_user_args() else [center - direction * 120.0 + Vector2(60, 0), center + direction * 80.0]):
			var victim: Unit = main._spawn_unit(1-team, "garen", point, 0.0)
			victim.move_speed = 0.0
			victim._deploy_timer = 99.0
			victims.append(victim)
		main.play_card(team, "pantheon", center, {"immediate": true, "validate_position": false})
		await create_timer(0.1).timeout
		await shot("team%d_pre_spear" % team)
		await create_timer(0.25).timeout
		await shot("team%d_pre_air" % team)
		await create_timer(0.35).timeout
		await shot("team%d_pre_slide" % team)
		await create_timer(0.4).timeout
		await shot("team%d_pre_arrive" % team)
		while main._latest_unit_for_card("pantheon", team) == null:
			await process_frame
		await create_timer(0.08).timeout
		await shot("team%d_landing" % team)
		await create_timer(0.35).timeout
		await shot("team%d_landing_recovery" % team)
		for victim in victims: victim.free()
		var unit: Unit = main._latest_unit_for_card("pantheon", team)
		unit.move_speed = 0.0
		unit.configure_carried_active_skill(CardDB.active_skills_for("pantheon")[0])
		main.play_card(1-team, "garen", center + Vector2(0, -65 if team == 0 else 65), {"immediate": true, "validate_position": false})
		var target: Unit = main._latest_unit_for_card("garen", 1-team)
		target.move_speed = 0.0
		target.damage = 0.0
		target.hp = 10000
		target.max_hp = 10000
		await create_timer(4.5).timeout
		await shot("team%d_attack" % team)
		unit.skill_resource_value = 1
		main.preview_active_skill(unit, CardDB.active_skills_for("pantheon")[0])
		await create_timer(0.3).timeout
		await shot("team%d_q" % team)
		await create_timer(1.0).timeout
		unit.skill_resource_value = 4
		await create_timer(0.1).timeout
		await shot("team%d_full_rage" % team)
		main.preview_active_skill(unit, CardDB.active_skills_for("pantheon")[0])
		await create_timer(0.3).timeout
		await shot("team%d_empowered_q" % team)
		await create_timer(1.0).timeout
		unit.take_damage(10000)
		await create_timer(0.3).timeout
		await shot("team%d_death" % team)
		await create_timer(0.22).timeout
		await shot("team%d_death_head" % team)
	record.set_recording_active(false)
	await create_timer(0.2).timeout
	var wav := record.get_recording()
	if wav != null: wav.save_to_wav(output + "/battle_mix.wav")
	AudioServer.remove_bus_effect(0, slot)
	main._deck_builder = DeckBuilder.new()
	main.add_child(main._deck_builder)
	main._deck_builder.open(main._deck, main._active_skill_choices, main._skin_choices, func(_deck, _skills, _skins): pass)
	main._deck_builder._open_card_info("pantheon")
	await create_timer(0.2).timeout
	await shot("pantheon_card_info")
	print("PANTHEON_REVIEW_OUTPUT ", output)
	main._audio_manager.end_battle()
	main.queue_free()
	await process_frame
	preload("res://assets/units/pantheon/arrival/particle_player.gd").release_prepared_assets()
	await create_timer(0.3).timeout
	quit()

func _size_comparison() -> void:
	var cards := ["twisted_fate", "pantheon", "kayn"]
	var actors: Array[Unit] = []
	for index in cards.size():
		var point := Vector2(160 + index * 190, 860)
		var unit: Unit = main._spawn_unit(0, cards[index], point, 0.0)
		unit.move_speed = 0.0
		actors.append(unit)
		var label := Label.new()
		label.text = String(CardDB.get_card(cards[index]).name) + "（中）"
		label.position = point + Vector2(-45, -120)
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		main.add_child(label)
	await create_timer(0.2).timeout
	await shot("medium_comparison")
	actors[1].configure_carried_active_skill(CardDB.active_skills_for("pantheon")[0])
	actors[1].add_skill_resource(4)
	await create_timer(0.1).timeout
	await shot("medium_comparison_rage")
	print("PANTHEON_REVIEW_OUTPUT ", output)

func _layer_system() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--arrival-layers="): return arg.trim_prefix("--arrival-layers=")
	return ""

## Single layers and composed systems share the battle camera and profile frames.
func _arrival_materials() -> void:
	var presentation = main._battle_presentation
	var native := preload("res://assets/units/pantheon/arrival/particle_player.gd")
	var profile := preload("res://assets/units/pantheon/arrival/profile.gd")
	for team in [0, 1]:
		var map := preload("res://scripts/presentation/pre_deployment_visual_3d.gd").new()
		presentation._world_root.add_child(map)
		map.setup(presentation._camera, Vector2(350, 760), team)
		var origin: Vector3 = map.ground(Vector2(350, 760))
		var forward: Vector3 = (map.ground(Vector2(350, 740 if team == 0 else 780)) - origin).normalized()
		for system: String in native.systems():
			if not _layer_system().is_empty() and system != _layer_system(): continue
			var layers: Array = [""]
			if not _layer_system().is_empty():
				layers.clear()
				for definition: Dictionary in native.systems()[system]: layers.append(definition.name)
			for index in layers.size():
				var particles := native.new()
				presentation._world_root.add_child(particles)
				var kind: String = profile.data().systems[system].frame
				var moving := kind in ["flight", "slide"]
				particles.global_transform = Transform3D(profile.frame(kind, forward), origin)
				particles.setup(system, preload("res://assets/units/pantheon/visual_metrics.gd").PARTICLE_SCALE, moving, layers[index])
				var previous := 0.0
				for time in [0.12, 0.35, 0.60]:
					while previous < time - 0.001:
						var dt: float = minf(1.0 / 120.0, time - previous)
						previous += dt
						if moving: particles.global_position = origin + forward * previous * 4.0
						particles.advance(dt)
					var suffix := "" if String(layers[index]).is_empty() else "_layer%02d" % index
					await shot("material_team%d_%s%s_%03d" % [team, system, suffix, roundi(time * 100)])
				particles.free()
		map.free()
	print("PANTHEON_REVIEW_OUTPUT ", output)

func _movement_range() -> void:
	for team in [0, 1]:
		main._clear_art_dev_units()
		var unit: Unit = main._spawn_unit(team, "pantheon", Vector2(320, 850 if team == 0 else 430), 0.0)
		unit.configure_carried_active_skill(CardDB.active_skills_for("pantheon")[0])
		for stacks in [0, 3, 4, 0]:
			unit.skill_resource_value = stacks
			await create_timer(0.2).timeout
			await shot("team%d_move_%d_%d" % [team, stacks, Time.get_ticks_msec()])
			for child in main._battle_presentation._world_root.get_children():
				if child is UnitModel3D and child._source == unit:
					print("MOVE_REVIEW team=", team, " stacks=", stacks, " clip=", child._animation_player.current_animation)
		unit.move_speed = 0.0
		main.preview_active_skill(unit, CardDB.active_skills_for("pantheon")[0])
		await create_timer(0.3).timeout
		await shot("team%d_short_q_range" % team)
	print("PANTHEON_REVIEW_OUTPUT ", output)

## Fixed timestamps in the real arena/camera; supplements the live play_card review.
func _arrival_timeline() -> void:
	var presentation = main._battle_presentation
	main.set_process(false)
	for team in [0, 1]:
		var view := preload("res://assets/units/pantheon/pantheon_arrival.tscn").instantiate()
		presentation._world_root.add_child(view)
		view.setup(presentation._camera, Vector2(350, 760), team)
		for time in [0.10, 0.35, 0.65, 0.80, 1.00, 1.25]:
			view.advance_visual(time / 1.3)
			await shot("timeline_team%d_%03d" % [team, roundi(time * 100)])
		var end: Vector3 = view._end
		var forward: Vector3 = view._direction
		view.free()
		var ending := preload("res://assets/units/pantheon/pantheon_view.tscn").instantiate()
		presentation._world_root.add_child(ending)
		ending.global_transform = Transform3D(Basis(Vector3.UP, atan2(forward.x, forward.z)), end)
		ending.prepare_visual_animations()
		var player: AnimationPlayer = ending.find_child("AnimationPlayer", true, false)
		for time in [0.1, 0.4, 0.95]:
			var clip := "Spell4_Hit" if time < 0.3 else "Spell4_Hit_ToIdle"
			player.play(clip)
			player.pause()
			player.seek(time if time < 0.3 else time - 0.3, true)
			ending.advance_deployment_visual(time, 1.0, true)
			await shot("timeline_team%d_%03d" % [team, roundi((1.3 + time) * 100)])
		ending.free()
	print("PANTHEON_REVIEW_OUTPUT ", output)

func _finish_arrival_review() -> void:
	main._audio_manager.end_battle()
	main.queue_free()
	await process_frame
	preload("res://assets/units/pantheon/arrival/particle_player.gd").release_prepared_assets()
	await create_timer(0.3).timeout
	quit()

## Offline media packet. Reuses the production adapter and the existing review entry.
## Run with --fixed-fps 30 so the live deployment is captured at exactly 0.25x.
var _pack_manifest: Array = []
var _pack_view: SubViewport
var _pack_camera: Camera3D
var _pack_world: Node3D
var _pack_reference: Node3D

func _review_pack() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-output="): output = arg.trim_prefix("--review-output=")
	main.set_process(false)
	main._battle_presentation.set_process(false)
	AudioServer.set_bus_mute(0, true)
	_pack_view = SubViewport.new()
	_pack_view.size = Vector2i(512, 512)
	_pack_view.own_world_3d = true
	_pack_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_pack_view)
	_pack_world = Node3D.new()
	_pack_view.add_child(_pack_world)
	_pack_camera = Camera3D.new()
	_pack_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_pack_camera.position = Vector3(0, 12, 12)
	_pack_world.add_child(_pack_camera)
	_pack_camera.look_at(Vector3.ZERO)
	_pack_camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.27, 0.31, 0.29)
	_pack_world.add_child(environment)
	var floor_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_node.mesh = plane
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.27, 0.31, 0.29)
	floor_node.material_override = material
	_pack_world.add_child(floor_node)
	_pack_reference = preload("res://assets/units/pantheon/pantheon_arrival.tscn").instantiate()
	main._battle_presentation._world_root.add_child(_pack_reference)
	_pack_reference.setup(main._battle_presentation._camera, Vector2(350, 800), 0)
	_pack_reference.hide()
	var native := preload("res://assets/units/pantheon/arrival/particle_player.gd")
	var profile := preload("res://assets/units/pantheon/arrival/profile.gd")
	var serial := 0
	for system: String in native.systems():
		for definition: Dictionary in native.systems()[system]:
			serial += 1
			await _capture_pack_layer("L%03d" % serial, system, definition.name)
		print("REVIEW_PACK_GROUP ", system, " layers=", serial)
	# Full systems let a viewer connect an isolated layer with its composed stage.
	var group_index := 0
	for system: String in native.systems():
		group_index += 1
		await _capture_pack_layer("G%02d" % group_index, system, "")
	await _capture_pack_props()
	_pack_reference.free()
	_pack_view.free()
	await _capture_pack_live()
	var file := FileAccess.open(output + "/review_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "items": _pack_manifest, "scope": "landing_only", "speed": 0.25}, "\t"))
	file.close()
	print("PANTHEON_REVIEW_OUTPUT ", output)

func _pack_transform(system: String, age: float) -> Transform3D:
	var phase: Dictionary = preload("res://assets/units/pantheon/arrival/profile.gd").data().systems[system]
	var time := age + float(phase.start)
	var transform: Transform3D = _pack_reference._comet._transform(phase, _pack_reference._point_at(time), _pack_reference._end, _pack_reference._slide_start, time)
	if system == "Ending_Shockwave":
		var particles := preload("res://assets/units/pantheon/arrival/particle_player.gd")
		var parent: Dictionary = particles.systems().Damage_Mis[0]
		var parent_basis: Basis = preload("res://assets/units/pantheon/arrival/profile.gd").frame("slide", _pack_reference._direction)
		transform = Transform3D(parent_basis * Basis.from_euler(particles.vec3(parent.birthRotation0.base) * PI / 180.0), _pack_reference._end + parent_basis * particles.vec3(parent.birthOffset.base) * preload("res://assets/units/pantheon/visual_metrics.gd").PARTICLE_SCALE)
	transform.origin -= _pack_reference._end
	return transform

func _capture_pack_layer(id: String, system: String, emitter: String) -> void:
	var native := preload("res://assets/units/pantheon/arrival/particle_player.gd")
	var profile := preload("res://assets/units/pantheon/arrival/profile.gd")
	var phase: Dictionary = profile.data().systems[system]
	var duration := float(phase.stop) - float(phase.start)
	var ticks := ceili(duration * 120.0)
	var item := {"id": id, "system": system, "emitter": emitter, "kind": "layer" if not emitter.is_empty() else "group", "source_start": phase.start, "source_duration": duration, "fps": 15, "frames": ticks / 2 + 1}
	if FileAccess.file_exists(output + "/frames/%s/%04d.png" % [id, ticks / 2]):
		_pack_manifest.append(item)
		return
	var bounds := AABB()
	var has_bounds := false
	for pass_index in 2:
		var effect := native.new()
		_pack_world.add_child(effect)
		effect.global_transform = _pack_transform(system, 0.0)
		effect.setup(system, preload("res://assets/units/pantheon/visual_metrics.gd").PARTICLE_SCALE, phase.frame in ["flight", "slide"], emitter, not emitter.is_empty())
		var proxy_view: Node3D
		if emitter.is_empty() and system in ["update_missile", "Sliding_Comet"]:
			proxy_view = preload("res://assets/units/pantheon/pantheon_arrival.tscn").instantiate()
			_pack_world.add_child(proxy_view)
			proxy_view.setup(main._battle_presentation._camera, Vector2(350, 800), 0)
			proxy_view._comet.hide()
			proxy_view._spear.hide()
		if pass_index == 1: DirAccess.make_dir_recursive_absolute(output + "/frames/" + id)
		for tick in range(ticks + 1):
			var age := float(tick) / 120.0
			effect.global_transform = _pack_transform(system, age)
			if proxy_view != null:
				proxy_view._pose_at(age + float(phase.start))
				proxy_view._ghost.global_position -= proxy_view._end
			effect.advance(0.0 if tick == 0 else 1.0 / 120.0)
			if tick % 2 != 0: continue
			if pass_index == 0:
				var meshes := effect.find_children("*", "MeshInstance3D", true, false)
				if proxy_view != null: meshes.append_array(proxy_view._ghost.find_children("*", "MeshInstance3D", true, false))
				for node: MeshInstance3D in meshes:
					if not node.visible or node.mesh == null: continue
					var box: AABB = node.global_transform * node.get_aabb()
					if box.end.y < 0.0: continue
					var camera_box: AABB = Transform3D(_pack_camera.basis.inverse(), Vector3.ZERO) * box
					bounds = bounds.merge(camera_box) if has_bounds else camera_box
					has_bounds = true
			else:
				await process_frame
				RenderingServer.force_draw()
				_pack_view.get_texture().get_image().save_png(output + "/frames/%s/%04d.png" % [id, tick / 2])
		effect.free()
		if proxy_view != null: proxy_view.free()
		if pass_index == 0:
			var center: Vector3 = _pack_camera.basis * bounds.get_center() if has_bounds else Vector3.ZERO
			_pack_camera.position = center + _pack_camera.basis.z * 80.0
			_pack_camera.size = maxf(maxf(bounds.size.x, bounds.size.y) * 1.2, 2.5)
	_pack_manifest.append(item)

func _capture_pack_props() -> void:
	for spec in [{"id": "P01", "name": "独立斜插长矛", "start": 0.0, "end": 1.3}, {"id": "P02", "name": "俯冲人物代理", "start": 0.2, "end": 0.65}, {"id": "P03", "name": "滑行人物代理", "start": 0.65, "end": 1.3}]:
		var view := preload("res://assets/units/pantheon/pantheon_arrival.tscn").instantiate()
		_pack_world.add_child(view)
		view.setup(main._battle_presentation._camera, Vector2(350, 800), 0)
		# World positions still come from the unmodified battle camera.
		var center: Vector3 = view._end + Vector3(0, 0.6, 2.0)
		_pack_camera.position = center + _pack_camera.basis.z * 80.0
		_pack_camera.size = 12.0
		var ticks := roundi((float(spec.end) - float(spec.start)) * 60.0)
		DirAccess.make_dir_recursive_absolute(output + "/frames/" + spec.id)
		for frame in range(ticks + 1):
			var time := float(spec.start) + float(frame) / 60.0
			view.advance_visual(time / 1.3)
			view._comet.hide()
			view._spear.visible = spec.id == "P01"
			view._ghost.visible = spec.id != "P01"
			await process_frame
			RenderingServer.force_draw()
			_pack_view.get_texture().get_image().save_png(output + "/frames/%s/%04d.png" % [spec.id, frame])
		view.free()
		_pack_manifest.append({"id": spec.id, "system": "独立对象", "emitter": spec.name, "kind": "prop", "source_start": spec.start, "source_duration": float(spec.end)-float(spec.start), "fps": 15, "frames": ticks+1})

func _capture_pack_live() -> void:
	var presentation = main._battle_presentation
	var mapping := preload("res://scripts/presentation/pre_deployment_visual_3d.gd").new()
	presentation._world_root.add_child(mapping)
	mapping.setup(presentation._camera, Vector2(350, 800), 0)
	var focus: Vector3 = mapping.ground(Vector2(350, 800)) + Vector3(0, 0.8, 0)
	mapping.free()
	var views: Array[SubViewport] = []
	for index in 2:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(960, 720)
		viewport.world_3d = presentation._viewport.find_world_3d()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 17.0
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		viewport.add_child(camera)
		camera.position = focus + (Vector3(0, 24, 24) if index == 0 else Vector3(28, 13, 0))
		camera.look_at(focus)
		camera.current = true
		views.append(viewport)
	Engine.time_scale = 0.25
	presentation.set_process(true)
	main.set_process(true)
	for team in [0, 1]:
		main._clear_art_dev_units()
		await process_frame
		for index in 2: DirAccess.make_dir_recursive_absolute(output + "/frames/D%d%d" % [team, index])
		main.play_card(team, "pantheon", Vector2(350, 800), {"immediate": true, "validate_position": false})
		for frame in 384:
			await process_frame
			var unit: Unit = main._latest_unit_for_card("pantheon", team)
			if unit != null: unit.move_speed = 0.0
			RenderingServer.force_draw()
			for index in 2:
				views[index].get_texture().get_image().save_png(output + "/frames/D%d%d/%04d.png" % [team, index, frame])
		for index in 2:
			_pack_manifest.append({"id": "D%d%d" % [team, index], "kind": "deployment", "system": "完整部署", "emitter": "蓝方" if team == 0 else "红方", "view": "实战俯视" if index == 0 else "侧面", "fps": 30, "frames": 384, "source_duration": 3.2})
		print("REVIEW_PACK_LIVE team=", team)
	Engine.time_scale = 1.0
	main.set_process(false)
	presentation.set_process(false)
	for viewport in views: viewport.free()
