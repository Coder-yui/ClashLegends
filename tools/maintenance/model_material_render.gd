extends SceneTree
## 单流程最小代表：整表面过滤、静态换纹理，以及按需freeze/stealth的严格同条件对照。
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
var pulse: RefCounted
var output := ""
var strict_plan := false
var stasis_only := false
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
	strict_plan = "--strict-plan" in OS.get_cmdline_user_args()
	stasis_only = "--stasis-only" in OS.get_cmdline_user_args()
	call_deferred("run")

func legacy(id: String, transform: Transform3D) -> Node3D:
	var subject := Node3D.new()
	var model: Node3D = load("res://assets/units/" + id + "/source/" + id + ".glb").instantiate()
	model.name = "Model"
	model.transform = transform
	subject.add_child(model)
	var instance := subject.find_child("Meshes", true, false) as MeshInstance3D
	var original := instance.mesh as ArrayMesh
	if id == "ornn":
		var filtered := original.duplicate() as ArrayMesh
		for index in range(original.get_surface_count() - 1, -1, -1):
			var material := original.surface_get_material(index)
			if material != null and material.resource_name in ["Ornn_Base_Sword_Mat", "Ornn_Base_Bucket_Mat", "Ornn_Base_Poro_Mat"]: filtered.surface_remove(index)
		instance.mesh = filtered
	else:
		var filtered := ArrayMesh.new()
		for surface in original.get_surface_count():
			var material := original.surface_get_material(surface) as StandardMaterial3D
			if material != null and material.resource_name.to_lower() == "head": continue
			filtered.add_surface_from_arrays(original.surface_get_primitive_type(surface), original.surface_get_arrays(surface))
			if material != null:
				material = material.duplicate() as StandardMaterial3D
				if material.resource_name.to_lower() == "body": material.albedo_texture = load("res://assets/units/belveth/source/ultimate_body.png")
			filtered.surface_set_material(filtered.get_surface_count() - 1, material)
		instance.mesh = filtered
	return subject

func legacy_materials(subject: Node3D, state: String) -> void:
	for mesh in subject.find_children("*", "MeshInstance3D", true, false):
		if state == "freeze":
			var tint := StandardMaterial3D.new()
			tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tint.albedo_color = Color(0.3, 0.7, 1.0, 0.28)
			tint.next_pass = mesh.material_overlay
			mesh.material_overlay = tint
		elif state == "buff":
			var buff := ShaderMaterial.new()
			buff.shader = load("res://assets/effects/baron_minion/overlay.gdshader")
			buff.set_shader_parameter("strength", 1.0)
			buff.next_pass = mesh.material_overlay
			mesh.material_overlay = buff
		elif state == "stasis":
			var gold := ShaderMaterial.new()
			gold.shader = load("res://assets/effects/stasis/attached_mesh.gdshader")
			gold.set_shader_parameter("swirl", load("res://assets/effects/stasis/bard_swirl.png"))
			var layer := ShaderMaterial.new()
			layer.shader = load("res://assets/effects/stasis/attached_gold.gdshader")
			layer.set_shader_parameter("swirl", load("res://assets/effects/stasis/zhonya_swirl.png"))
			gold.next_pass = layer
			mesh.material_overlay = gold
		elif state == "stealth":
			for surface in mesh.get_surface_override_material_count():
				var material: Material = mesh.get_active_material(surface)
				var ghost := material.duplicate() as BaseMaterial3D if material is BaseMaterial3D else StandardMaterial3D.new()
				ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ghost.albedo_color = Color(0.75, 0.95, 0.90, 0.42)
				ghost.emission_enabled = true
				ghost.emission = Color(0.035, 0.10, 0.08)
				ghost.next_pass = null
				mesh.set_surface_override_material(surface, ghost)
			mesh.material_override = null
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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
	var mesh := subject.find_child("Meshes", true, false) as MeshInstance3D
	var skeleton := subject.find_child("Skeleton3D", true, false) as Skeleton3D
	skeleton.force_update_all_bone_transforms()
	return deformed_vertices(mesh, skeleton)

func frame_subject(subject: Node3D, clip: String) -> void:
	var player := subject.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.play(clip)
	player.seek(0.3, true)
	player.advance(0.0)
	var vertices := subject_vertices(subject)
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

func capture(subject: Node3D, clip: String, name: String) -> PackedByteArray:
	pulse.set_phase("capture:" + name, true)
	var player := subject.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.play(clip)
	player.seek(0.3, true)
	player.advance(0.0)
	subject.show()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var framed := true
	for vertex in subject_vertices(subject):
		var point := camera.unproject_position(vertex)
		framed = framed and point.x > 2 and point.y > 2 and point.x < 718 and point.y < 1278
	checks += 1
	if not framed: failures.append(name + ": mesh outside fixed frame")
	picture.save_png(output.path_join(name + ".png"))
	subject.hide()
	return picture.get_data()

## TIME是全帧渲染时钟：两个隔离层视口在同一帧采集，不修改生产shader或阈值。
func capture_same_frame(generated: Node3D, reference: Node3D, clip: String, name: String) -> Dictionary:
	pulse.set_phase("same-frame:" + name, true)
	var viewports: Array[SubViewport] = []
	var subjects: Array[Node3D] = [generated, reference]
	for index in subjects.size():
		var subject := subjects[index]
		var player := subject.find_child("AnimationPlayer", true, false) as AnimationPlayer
		player.play(clip)
		player.seek(0.3, true)
		player.advance(0.0)
		for mesh in subject.find_children("*", "GeometryInstance3D", true, false): mesh.layers = 1 << (index + 1)
		subject.show()
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
	for index in subjects.size():
		var picture := viewports[index].get_texture().get_image()
		picture.save_png(output.path_join(name + ("-generated.png" if index == 0 else "-legacy.png")))
		pixels.append(picture.get_data())
		var framed := true
		for vertex in subject_vertices(subjects[index]):
			var point := camera.unproject_position(vertex)
			framed = framed and point.x > 2 and point.y > 2 and point.x < 718 and point.y < 1278
		checks += 1
		if not framed: failures.append(name + ": mesh outside fixed frame")
		subjects[index].hide()
		viewports[index].free()
	return {"actual": pixels[0], "expected": pixels[1]}

func compare(id: String) -> void:
	pulse.set_phase("setup:" + id, true)
	var generated: Node3D = load("res://assets/units/" + id + "/" + id + "_view.tscn").instantiate()
	world.add_child(generated)
	generated.process_mode = Node.PROCESS_MODE_DISABLED
	generated.hide()
	var reference := legacy(id, generated.get_node("Model").transform)
	world.add_child(reference)
	reference.process_mode = Node.PROCESS_MODE_DISABLED
	reference.hide()
	var clip := "Idle1_Base" if id == "ornn" else "Idle_Ult_anm"
	frame_subject(generated, clip) # 按蒙皮顶点范围定相机，所有后续对照共用。
	var owner := ModelVisualResources.new()
	var scene := "res://tests/fixtures/material_plan_buff.tscn"
	var key := ModelVisualResources.buff_key(scene, 20.0, 0)
	var material_plan := {"mode": "match", "freeze": true, "stasis": true, "stealth": true, "buffs": [{"scene": scene, "radius": 20.0, "team": 0, "key": key}]} if strict_plan else ModelVisualResources.tool_material_states()
	owner.bind_model(generated, {}, material_plan)
	var initial_counts := owner.material_creations.duplicate()
	var originals := []
	for mesh in reference.find_children("*", "MeshInstance3D", true, false):
		var surfaces := []
		for surface in mesh.get_surface_override_material_count(): surfaces.append(mesh.get_surface_override_material(surface))
		originals.append({"mesh": mesh, "override": mesh.material_override, "shadow": mesh.cast_shadow, "surfaces": surfaces})
	var cases := (["stasis"] if stasis_only else ["base", "freeze", "stealth", "buff", "stasis"]) if strict_plan else (["base", "freeze", "stealth"] if id == "ornn" else ["base"])
	for state in cases:
		if strict_plan:
			owner.select_buff(key if state == "buff" else "")
			if state == "buff": owner.buff_node(key).advance_status(true, true, 0.0)
		owner.apply_overlays(false, state == "freeze", state == "buff", state == "stasis", state == "stealth")
		legacy_materials(reference, state)
		var actual: PackedByteArray
		var expected: PackedByteArray
		if strict_plan and state == "stasis":
			var paired := await capture_same_frame(generated, reference, clip, id + "-" + state)
			actual = paired.actual
			expected = paired.expected
		else:
			actual = await capture(generated, clip, id + "-" + state + "-generated")
			expected = await capture(reference, clip, id + "-" + state + "-legacy")
		var different := 0
		if actual != expected:
			for pixel in range(0, actual.size(), 4):
				if pixel % 131072 == 0: pulse.set_phase("compare:" + id + ":" + state, true)
				if actual.slice(pixel, pixel + 4) != expected.slice(pixel, pixel + 4): different += 1
		checks += 1
		if different != 0: failures.append(id + ": " + state + " strict pixel mismatch: " + str(different))
		reports[id + ":" + state] = {"different_pixels": different, "pixel_bytes": actual.size()}
		for original in originals:
			var mesh: MeshInstance3D = original.mesh
			mesh.material_overlay = null
			mesh.material_override = original.override
			mesh.cast_shadow = original.shadow
			for surface in original.surfaces.size(): mesh.set_surface_override_material(surface, original.surfaces[surface])
	if strict_plan:
		checks += 1
		if owner.material_creations != initial_counts: failures.append("Strict rendered transitions created new candidate")
	owner.clear()
	generated.free()
	reference.free()
	await process_frame

func run() -> void:
	if not pulse.enabled or output.is_empty() or DisplayServer.get_name() == "headless": quit(2); return
	root.size = Vector2i(720, 1280)
	world = Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.08, 0.10, 0.13)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -25, 0)
	world.add_child(light)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.current = true
	for id in ["ornn"] if strict_plan else ["ornn", "belveth"]: await compare(id)
	var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "states": reports}, "\t"))
	file.close()
	quit(0 if failures.is_empty() else 1)
