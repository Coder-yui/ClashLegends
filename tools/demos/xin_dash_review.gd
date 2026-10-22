extends SceneTree
## 正式工作台运行、双方突进与声音取证，不参与玩法。
var main: Node2D
var area_review := "--area" in OS.get_cmdline_user_args()
var review_ring: MeshInstance3D
var output := "res://ClashLegends-开发素材库/04-中间产物/赵信无畏冲锋验收/"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	if area_review: output += "范围与枪光/" + ("red/" if "--red" in OS.get_cmdline_user_args() else "blue/")
	DirAccess.make_dir_recursive_absolute(output)
	var recorder := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, recorder)
	recorder.set_recording_active(true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("xin")
	panel.show_workspace(1)
	main.set_physics_process(false)
	main.set_process(false)
	panel._set_battle_zoom(1.3)
	var units: Array[Unit] = []
	for team in ([1 if "--red" in OS.get_cmdline_user_args() else 0] if area_review else [0,1]):
		var start := Vector2(360,1000 if team==0 else 700) if area_review else Vector2(210 + team * 280, 1050 if team == 0 else 800)
		var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1-team,"target_dummy",start+Vector2(0,-180 if team==0 else 180),{"deploy_time_override":0.0}))
		target.hp = 10000
		target.max_hp = 10000
		if area_review:
			for distance in [95,160]:
				main._spawn_unit(UnitSpawnRequest.new(1-team,"target_dummy",target.position+Vector2(distance,0),{"deploy_time_override":0.0}))
			_add_range_ring(target.position)
		var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(team,"xin",start,{"deploy_time_override":0.0}))
		unit._target = target
		units.append(unit)
	await create_timer(0.4).timeout
	await _capture("ready")
	for unit in units: main.preview_active_skill(unit, CardDB.active_skills_for("xin")[1])
	for frame in 130:
		main._sim_step(0.05)
		main._projectile_system.tick_visuals(0.05)
		main._skill_presentation.tick_visuals(0.05)
		await create_timer(0.05).timeout
		if frame in [0,1,2,3,5,8,16,30,60,105,125]:
			await _capture("combat-%03d" % frame)
			for unit in units:
				print("XIN_REVIEW frame=",frame," pos=",unit.position," haste=",unit.active_attack_speed_multiplier," action=",unit.get_visual_action_name()," clock=",unit.active_buff_clock_visual())
	for unit in units: unit.take_damage(99999)
	await create_timer(0.3).timeout
	await _capture("death")
	if is_instance_valid(review_ring): review_ring.queue_free()
	main.clear_preview_battle()
	await create_timer(0.5).timeout
	await _capture("clear")
	recorder.set_recording_active(false)
	recorder.get_recording().save_to_wav(output + "runtime.wav")
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0)-1)
	main.queue_free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + label + ".png")

func _add_range_ring(center: Vector2) -> void:
	# 只用于验收的权威范围参考圈（读取当前技能配置），不进入正式特效。
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.0,0.9,0.9)
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,material)
	var projection = preload("res://scripts/presentation/spell_effect_projection.gd")
	for index in 97:
		mesh.surface_add_vertex(projection.ground(main._battle_presentation._camera,center+Vector2.from_angle(TAU*index/96.0)*float(CardDB.active_skills_for("xin")[1].charge_impact_radius)))
	mesh.surface_end()
	review_ring = MeshInstance3D.new()
	review_ring.mesh = mesh
	main._battle_presentation._world_root.add_child(review_ring)
