extends SceneTree
## 每种加工机制一个同帧代表；生产shader、随机材质和LOD均保留。
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
const ORACLE = preload("res://tools/maintenance/model_remaining_oracle.gd")
const CONTRACT = preload("res://tools/maintenance/model_remaining_contract.gd")
var pulse: RefCounted
var output := ""
var baseline := ""
var selected := ""
var world: Node3D
var camera: Camera3D
var failures: Array[String] = []
var checks := 0
var reports := {}
func _initialize() -> void:
	Engine.max_fps = 30
	pulse = HEARTBEAT.new(self)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--baseline="): baseline = arg.trim_prefix("--baseline=")
		if arg.begins_with("--select="): selected = arg.trim_prefix("--select=")
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func deformed_vertices(mesh: MeshInstance3D, skeleton: Skeleton3D) -> PackedVector3Array:
	var matrices: Array[Transform3D] = []
	for bind in mesh.skin.get_bind_count():
		var bone := skeleton.find_bone(mesh.skin.get_bind_name(bind))
		if bone < 0: bone = mesh.skin.get_bind_bone(bind)
		if bone < 0 or bone >= skeleton.get_bone_count():
			failures.append("Invalid skin bind")
			return PackedVector3Array()
		matrices.append(skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
	var result := PackedVector3Array()
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var influences := int(weights.size() / vertices.size())
		if influences not in [4, 8]:
			failures.append("Unsupported skin influence count")
			return PackedVector3Array()
		for index in vertices.size():
			var position := Vector3.ZERO
			for influence in influences:
				var slot := index * influences + influence
				if weights[slot] != 0.0: position += (matrices[bones[slot]] * vertices[index]) * weights[slot]
			result.append(skeleton.global_transform * position)
	return result

func subject_vertices(subject: Node3D) -> PackedVector3Array:
	var skeleton := subject.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	skeleton.force_update_all_bone_transforms()
	var vertices := PackedVector3Array()
	for mesh in subject.find_children("*", "MeshInstance3D", true, false):
		vertices.append_array(deformed_vertices(mesh, skeleton))
	return vertices

func pose(subject: Node3D, id: String, clip: String, age: float) -> void:
	var player := subject.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if subject.has_method("set_visual_clip"): subject.set_visual_clip(clip)
	player.play(clip)
	player.seek(age, true)
	player.advance(0.0)
	match id:
		"void_gate":
			subject._idle_age = 1.7
			subject._apply_additive_spit(age)
		"yorick":
			for layer in 2: subject._cape_materials[layer].set_shader_parameter("uv_phase", [0.25, 0.75][layer])
			subject.advance_ambient_visual(0.4)
			subject._cape_path._process_modification()
			subject._weapon_blend._process_modification()
		"pantheon":
			subject.update_animation_parts(clip, age)
			subject._helmet_snap._process_modification()
			subject.advance_skill_resource_visual(true, 0.4)
func frame_vertices(vertices: PackedVector3Array) -> void:
	var box := AABB(vertices[0], Vector3.ZERO)
	for vertex in vertices: box = box.expand(vertex)
	var focus := box.get_center()
	camera.position = focus + Vector3(4, 2.5, 6)
	camera.look_at(focus)
	var horizontal := 0.0
	var vertical := 0.0
	for vertex in vertices:
		horizontal = maxf(horizontal, absf(camera.global_basis.x.dot(vertex - focus)))
		vertical = maxf(vertical, absf(camera.global_basis.y.dot(vertex - focus)))
	camera.size = 2.0 * maxf(vertical, horizontal * 1280.0 / 720.0) * 1.2
func compare(id: String, clip: String, age: float) -> void:
	pulse.set_phase("pair:" + id, true)
	var generated: Node3D = load(CONTRACT.SCENES[id]).instantiate()
	var reference := ORACLE.legacy(CONTRACT.SCENES[id], baseline)
	world.add_child(generated); world.add_child(reference)
	var subjects: Array[Node3D] = [generated, reference]
	for subject in subjects:
		subject.process_mode = Node.PROCESS_MODE_DISABLED
		pose(subject, id, clip, age)
	var first := subject_vertices(generated)
	var second := subject_vertices(reference)
	var same := first.size() == second.size()
	for index in mini(first.size(), second.size()): same = same and first[index].is_equal_approx(second[index])
	check(same, id + ": deformed vertex positions equal original")
	var all := first.duplicate(); all.append_array(second)
	frame_vertices(all)
	var viewports: Array[SubViewport] = []
	for index in subjects.size():
		for mesh in subjects[index].find_children("*", "GeometryInstance3D", true, false): mesh.layers = 1 << (index + 1)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(720, 1280)
		viewport.world_3d = world.get_world_3d()
		viewport.msaa_3d = root.msaa_3d
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var view_camera := Camera3D.new()
		viewport.add_child(view_camera)
		view_camera.projection = camera.projection
		view_camera.keep_aspect = camera.keep_aspect
		view_camera.size = camera.size
		view_camera.near = camera.near
		view_camera.far = camera.far
		view_camera.global_transform = camera.global_transform
		view_camera.cull_mask = 1 << (index + 1)
		view_camera.current = true
		viewports.append(viewport)
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := []
	var framed := true
	for index in subjects.size():
		var picture := viewports[index].get_texture().get_image()
		picture.save_png(output.path_join(id + ("-generated.png" if index == 0 else "-legacy.png")))
		pixels.append(picture.get_data())
		for vertex in subject_vertices(subjects[index]):
			var point := camera.unproject_position(vertex)
			framed = framed and point.x > 2 and point.y > 2 and point.x < 718 and point.y < 1278
		viewports[index].free()
	check(framed, id + ": complete subject inside shared frame")
	var different := 0
	if pixels[0] != pixels[1]:
		for pixel in range(0, pixels[0].size(), 4):
			if pixel % 131072 == 0: pulse.set_phase("pixels:" + id, true)
			if pixels[0].slice(pixel, pixel + 4) != pixels[1].slice(pixel, pixel + 4): different += 1
	check(different == 0, id + ": strict pixel mismatch " + str(different))
	reports[id] = {"clip": clip, "age": age, "different_pixels": different, "vertices": first.size(), "camera": {"transform": str(camera.global_transform), "size": camera.size}, "native_lods_retained": true, "reference": "unchanged legacy", "scope": "one static pose; independent instance state fixed equally"}
	generated.free(); reference.free()
	await process_frame
func run() -> void:
	if not pulse.enabled or output.is_empty() or baseline.is_empty() or DisplayServer.get_name() == "headless": quit(2); return
	root.size = Vector2i(720, 1280)
	world = Node3D.new(); root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.08, 0.10, 0.13)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -25, 0); world.add_child(light)
	camera = Camera3D.new(); world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.current = true
	if selected.is_empty() or selected == "void_gate": await compare("void_gate", "Spit", 0.35)
	if selected.is_empty() or selected == "yorick": await compare("yorick", "IdleIn", 0.3)
	if selected.is_empty() or selected == "gnar_mega": await compare("gnar_mega", "gnar_runtime/Rage_Spell2_Transform", 0.55)
	var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "states": reports, "renderer": RenderingServer.get_current_rendering_method()}, "\t")); file.close()
	quit(0 if failures.is_empty() else 1)
