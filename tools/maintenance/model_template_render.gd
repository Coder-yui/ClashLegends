extends SceneTree
## 单次定向：终极剑魔0.3秒 generated→legacy→generated，无普通/圆盘/对局。
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
var pulse: RefCounted
var output := ""
var world: Node3D
var camera: Camera3D
var failures: Array[String] = []

func _initialize() -> void:
	Engine.max_fps = 30
	pulse = HEARTBEAT.new(self)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func transform_data(value: Transform3D) -> Array:
	return [vec(value.basis.x), vec(value.basis.y), vec(value.basis.z), vec(value.origin)]

func legacy_reference() -> Dictionary:
	var wrapper := Node3D.new()
	wrapper.name = "AatroxView"
	var model: Node3D = load("res://assets/units/aatrox/source/ultimate.glb").instantiate()
	model.name = "Model"
	model.scale = Vector3.ONE * 0.013
	wrapper.add_child(model)
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for name in player.get_animation_library_list():
		var library := player.get_animation_library(name).duplicate(true) as AnimationLibrary
		var target := player.get_node(player.root_node).get_path_to(model)
		for clip in library.get_animation_list():
			var animation := library.get_animation(clip)
			var track := animation.add_track(Animation.TYPE_POSITION_3D)
			animation.track_set_path(track, target)
			animation.position_track_insert_key(track, 0.0, Vector3.ZERO)
		var passive := library.get_animation("Passive_Attack").duplicate(true) as Animation
		passive.track_set_key_value(passive.find_track(target, Animation.TYPE_POSITION_3D), 0, Vector3(0, 0.998591, 0))
		library.add_animation("Passive_Attack_Ult", passive)
		player.remove_animation_library(name)
		player.add_animation_library(name, library)
	var mesh := model.find_child("Meshes", true, false) as MeshInstance3D
	var snap: SkeletonModifier3D = load("res://assets/units/aatrox/weapon_snap.gd").new()
	snap.player = player
	mesh.get_parent().add_child(snap)
	return {"root": wrapper, "player": player, "mesh": mesh}

func pose(subject: Node3D, player: AnimationPlayer) -> void:
	player.play("Passive_Attack_Ult")
	player.seek(0.3, true)
	player.advance(0.0)
	var skeleton := subject.find_child("Skeleton3D", true, false) as Skeleton3D
	skeleton.force_update_all_bone_transforms()

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

func bounds(vertices: PackedVector3Array) -> AABB:
	var result := AABB(vertices[0], Vector3.ZERO)
	for vertex in vertices: result = result.expand(vertex)
	return result

func identity(resource: Resource) -> Dictionary:
	return {} if resource == null else {"id": str(resource.get_instance_id()), "rid": str(resource.get_rid().get_id()), "path": resource.resource_path, "class": resource.get_class(), "name": resource.resource_name}

func snapshot(subject: Node3D, player: AnimationPlayer) -> Dictionary:
	var model := subject.get_node("Model") as Node3D
	var mesh := model.find_child("Meshes", true, false) as MeshInstance3D
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var bones := []
	for bone in skeleton.get_bone_count():
		bones.append({"name": skeleton.get_bone_name(bone), "parent": skeleton.get_bone_parent(bone), "local": transform_data(skeleton.get_bone_pose(bone)), "global": transform_data(skeleton.get_bone_global_pose(bone))})
	var materials := []
	for surface in mesh.mesh.get_surface_count():
		materials.append({"surface": surface, "active": identity(mesh.get_active_material(surface)), "override": identity(mesh.get_surface_override_material(surface))})
	var modifiers := []
	for modifier in subject.find_children("*", "SkeletonModifier3D", true, false):
		modifiers.append({"id": str(modifier.get_instance_id()), "class": modifier.get_class(), "script": modifier.get_script().resource_path if modifier.get_script() != null else "", "active": modifier.active, "influence": modifier.influence})
	var vertices := deformed_vertices(mesh, skeleton)
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(vertices.to_byte_array())
	var digest := hash_context.finish().hex_encode()
	var projected := Rect2(camera.unproject_position(vertices[0]), Vector2.ZERO)
	for vertex in vertices: projected = projected.expand(camera.unproject_position(vertex))
	var framed := projected.position.x > 2 and projected.position.y > 2 and projected.end.x < 718 and projected.end.y < 1278
	return {"root_id": str(subject.get_instance_id()), "player_id": str(player.get_instance_id()), "skeleton_id": str(skeleton.get_instance_id()), "skin": identity(mesh.skin), "mesh": identity(mesh.mesh), "materials": materials, "override": identity(mesh.material_override), "overlay": identity(mesh.material_overlay), "modifiers": modifiers, "pose": {"root_local": transform_data(subject.transform), "root_global": transform_data(subject.global_transform), "model_local": transform_data(model.transform), "model_global": transform_data(model.global_transform), "skeleton_global": transform_data(skeleton.global_transform), "bones": bones, "clip": player.assigned_animation, "position": player.current_animation_position, "player_root": String(player.root_node), "speed": player.speed_scale, "skinned_vertex_count": vertices.size(), "skinned_sha256": digest}, "projected_bounds": [projected.position.x, projected.position.y, projected.end.x, projected.end.y], "fully_framed": framed}

func capture(subject: Node3D, player: AnimationPlayer, name: String) -> Dictionary:
	pulse.set_phase("capture:" + name, true)
	pose(subject, player)
	subject.show()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var state := snapshot(subject, player)
	picture.save_png(output.path_join(name + ".png"))
	subject.hide()
	return {"pixels": picture.get_data(), "state": state}

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
	var generated: Node3D = load("res://assets/units/aatrox/normal_view.tscn").instantiate()
	world.add_child(generated)
	generated.process_mode = Node.PROCESS_MODE_DISABLED
	generated.hide()
	generated.set_visual_form(1)
	generated.set_visual_clip("Passive_Attack_Ult")
	var legacy := legacy_reference()
	world.add_child(legacy.root)
	legacy.root.process_mode = Node.PROCESS_MODE_DISABLED
	legacy.root.hide()
	var player := generated.find_child("AnimationPlayer", true, false) as AnimationPlayer
	pose(generated, player)
	pose(legacy.root, legacy.player)
	var generated_mesh := generated.find_child("Meshes", true, false) as MeshInstance3D
	var shared: bool = generated_mesh.mesh == legacy.mesh.mesh
	if not shared: failures.append("Full source mesh is not shared")
	var vertices := deformed_vertices(generated_mesh, generated.find_child("Skeleton3D", true, false) as Skeleton3D)
	vertices.append_array(deformed_vertices(legacy.mesh, legacy.root.find_child("Skeleton3D", true, false) as Skeleton3D))
	var box := bounds(vertices)
	var center := box.get_center()
	camera.position = center + Vector3(0, 2, 10)
	camera.look_at(center)
	var view_bounds := AABB(camera.global_transform.affine_inverse() * vertices[0], Vector3.ZERO)
	for vertex in vertices: view_bounds = view_bounds.expand(camera.global_transform.affine_inverse() * vertex)
	camera.size = maxf(view_bounds.size.y, view_bounds.size.x / (720.0 / 1280.0)) * 1.25
	pulse.set_phase("prepared", true)
	var first := await capture(generated, player, "generated-first")
	var reference := await capture(legacy.root, legacy.player, "legacy")
	var repeated := await capture(generated, player, "generated-repeat")
	var equal_first: bool = first.pixels == reference.pixels
	var stable: bool = first.pixels == repeated.pixels
	var equal_repeat: bool = reference.pixels == repeated.pixels
	if not equal_first: failures.append("generated-first vs legacy pixels differ")
	if not stable: failures.append("generated-first vs generated-repeat pixels differ")
	if not equal_repeat: failures.append("legacy vs generated-repeat pixels differ")
	var pose_equal: bool = first.state.pose == reference.state.pose and first.state.pose == repeated.state.pose
	if not pose_equal: failures.append("Actual root/model/skeleton pose differs")
	if not first.state.fully_framed or not reference.state.fully_framed or not repeated.state.fully_framed: failures.append("Wing framing incomplete")
	var result := {"passed": failures.is_empty(), "checks": 6, "failures": failures, "scope": "one ultimate pose at .3; generated->legacy->generated", "pixels": {"first_legacy_equal": equal_first, "first_repeat_equal": stable, "legacy_repeat_equal": equal_repeat}, "pose_equal": pose_equal, "shared_full_mesh": shared, "states": {"generated_first": first.state, "legacy": reference.state, "generated_repeat": repeated.state}, "camera": {"transform": transform_data(camera.global_transform), "size": camera.size, "viewport": [720, 1280]}, "renderer": RenderingServer.get_current_rendering_method()}
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(result))
	generated.free()
	legacy.root.free()
	pulse.set_phase("done", true)
	await process_frame
	quit(0 if failures.is_empty() else 1)
