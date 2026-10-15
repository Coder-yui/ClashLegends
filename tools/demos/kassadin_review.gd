extends SceneTree
var range_age := 0.15
var range_playing := false

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var recorder := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, recorder)
	recorder.set_recording_active(true)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("kassadin")
	panel.show_workspace(1)
	main.set_physics_process(false)
	main.set_process(false)
	var units: Array[Unit] = []
	for team in [0,1]:
		var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(team,"kassadin",Vector2(230+260*team,800),{"deploy_time_override":0.0}))
		units.append(unit)
	var reference: Unit = main._spawn_unit(UnitSpawnRequest.new(0,"ashe",Vector2(360,800),{"deploy_time_override":0.0}))
	panel._set_battle_zoom(1.5)
	await create_timer(1.0).timeout
	await _capture("idle")
	for unit in units: unit.teleport_to(Vector2(unit.position.x,640))
	await _capture("river-idle")
	var views: Array[UnitModel3D] = []
	for child in main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source in units:
			views.append(child)
			child.set_process(false)
	if "--range" in OS.get_cmdline_user_args():
		recorder.set_recording_active(false)
		AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
		await _range_review(main, units, views)
		return
	if "--live" in OS.get_cmdline_user_args():
		recorder.set_recording_active(false)
		AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
		DisplayServer.window_set_title("虚空行者：出场混合 / 虚空行走特效循环预览")
		while is_instance_valid(main):
			await _review_cycle(main, units, views)
		return
	await _review_cycle(main, units, views, true)
	for clip in ["Run_Base", "Attack1", "Attack2", "Spell4", "Spell4_To_Run"]:
		for view in views:
			view._animation_player.play(clip)
			view._animation_player.advance(0.2)
			view._model_root.advance_ambient_visual(0.2)
		await _capture("river-"+clip)
	for view in views: view.set_process(true)
	for unit in units:
		var skill: Dictionary = CardDB.active_skills_for("kassadin")[0].duplicate(true)
		skill.cast_forward = Vector2.UP if unit.team == 0 else Vector2.DOWN
		main._start_active_skill_cast(unit,skill)
		main._active_skill_effect_system.apply(unit,skill)
	for age in [0.05,0.15,0.3,0.6,1.1,2.0,3.0]:
		for effect in main._skill_presentation.frontal_effects: effect.timer = 3.0-age
		await _capture("r-"+str(age))
	for unit in units: unit.take_damage(99999)
	await create_timer(1.5).timeout
	await _capture("death")
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	recording.save_to_wav(preload("res://tools/lib/development_paths.gd").output("kassadin-runtime.wav"))
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	main.queue_free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var path := preload("res://tools/lib/development_paths.gd").output("kassadin-"+label+".png")
	root.get_texture().get_image().save_png(path)
	print("[Kassadin render] ",path)

# 只用于工作台表现审查；冻结战场后按实际播放器和技能效果入口展示。
func _review_cycle(main: Node, units: Array[Unit], views: Array[UnitModel3D], capture: bool = false) -> void:
	for destination in ["move", "attack"]:
		for view in views:
			view._clear_visual_action_state()
			view._animation_player.play("Respawn",0.0)
		await _preview_advance(main,views,3.3)
		for view in views:
			if destination == "move": view._transition_to_basic_state(2,-1.0,&"deploy")
			else: view._play_attack(1)
		await _preview_advance(main,views,0.07)
		if capture: await _capture("respawn-to-"+destination+"-blend")
		await _preview_advance(main,views,0.8)
	for index in units.size():
		units[index].teleport_to(Vector2(230+260*index,720))
	for view in views: view._animation_player.play("Spell4",0.08)
	await _preview_advance(main,views,0.25)
	for unit in units:
		var skill: Dictionary = CardDB.active_skills_for("kassadin")[0].duplicate(true)
		skill.cast_forward = Vector2.UP
		main._active_skill_effect_system.apply(unit,skill)
	await _preview_advance(main,views,0.15)
	if capture: await _capture("live-r-0.15")
	for view in views: view._transition_to_basic_state(2,-1.0,&"active")
	await _preview_advance(main,views,0.45)
	if capture: await _capture("live-r-0.60")
	await _preview_advance(main,views,2.5)
	if capture:
		await _capture("live-r-clean")
		print("[Kassadin cleanup] ",main._battle_presentation._riftwalk_effect._views.size())
	await _preview_advance(main,views,0.7)

func _preview_advance(main: Node, views: Array[UnitModel3D], seconds: float) -> void:
	for index in ceili(seconds*60.0):
		for view in views:
			view._sync_transform(false,1.0/60.0)
			view._animation_player.advance(1.0/60.0)
			view._model_root.advance_ambient_visual(1.0/60.0)
		main._skill_presentation.tick_visuals(1.0/60.0)
		await create_timer(1.0/60.0).timeout

# 仅本脚本 --range 使用：按权威坐标投影范围圈，不进入正式游戏场景。
func _range_review(main: Node, units: Array[Unit], views: Array[UnitModel3D]) -> void:
	DisplayServer.window_set_title("卡萨丁伤害范围对照 · 黄色圈为技能实际半径 · 仅预览")
	var skill: Dictionary = CardDB.active_skills_for("kassadin")[0].duplicate(true)
	var radius := float(skill.radius)
	var camera: Camera3D = main._battle_presentation._camera
	var projection = preload("res://scripts/presentation/spell_effect_projection.gd")
	for unit in units:
		unit.teleport_to(Vector2(unit.position.x,720))
		skill.cast_forward = Vector2.UP
		main._active_skill_effect_system.apply(unit,skill)
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for segment in 128:
			for endpoint in [segment,segment+1]:
				var point := unit.position + Vector2.from_angle(TAU*float(endpoint)/128.0)*radius
				mesh.surface_add_vertex(projection.ground(camera,point))
		mesh.surface_end()
		var ring := MeshInstance3D.new()
		ring.mesh = mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		material.albedo_color = Color(1.0,0.85,0.1)
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		main._battle_presentation._world_root.add_child(ring)
	for view in views:
		view._animation_player.play("Spell4")
		view._animation_player.seek(0.4,true)
		view._sync_transform(false,0.0)
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	root.add_child(overlay)
	var box := PanelContainer.new()
	box.position = Vector2(20,20)
	box.custom_minimum_size = Vector2(330,0)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.035,0.055,0.085,1.0)
	background.content_margin_left = 12
	background.content_margin_right = 12
	background.content_margin_top = 12
	background.content_margin_bottom = 12
	box.add_theme_stylebox_override("panel",background)
	overlay.add_child(box)
	var controls := VBoxContainer.new()
	box.add_child(controls)
	var caption := Label.new()
	caption.text = "黄色圈：实际伤害半径 %.0f\n落点为中心；敌方身体接触圈内即命中\n仅预览，不加入正式游戏" % radius
	controls.add_child(caption)
	var clock := Label.new()
	controls.add_child(clock)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.2
	slider.step = 1.0/120.0
	slider.value = range_age
	controls.add_child(slider)
	slider.value_changed.connect(func(value): range_age=value; range_playing=false)
	var button := Button.new()
	button.text = "播放 / 暂停（落地后0—1.2秒循环）"
	button.pressed.connect(func(): range_playing=not range_playing)
	controls.add_child(button)
	var row := HBoxContainer.new()
	controls.add_child(row)
	for age in [0.05,0.15,0.3,0.6]:
		var preset := Button.new()
		preset.text = "%.2fs" % age
		preset.pressed.connect(func(): range_age=age; range_playing=false)
		row.add_child(preset)
	var captured := false
	while is_instance_valid(main):
		if range_playing: range_age=fmod(range_age+root.get_process_delta_time(),1.2)
		for effect in main._skill_presentation.frontal_effects:
			effect.timer=float(effect.duration)-range_age
		main._battle_presentation._riftwalk_effect.sync_effects(main._skill_presentation,camera)
		slider.set_value_no_signal(range_age)
		clock.text="落地后 %.3f 秒（伤害在落地瞬间结算一次）" % range_age
		await process_frame
		if not captured:
			await _capture("range-overlay-0.15")
			captured=true
