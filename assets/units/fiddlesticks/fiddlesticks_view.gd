extends Node3D
## W式汲取连线只读取权威目标；弯曲、脉动和流向不参与结算。
var _beams: Array[MeshInstance3D] = []
var _age := 0.0
var _skeleton: Skeleton3D
var _chest := -1
var _material: StandardMaterial3D
var _parts_prepared := false
var _optional_parts: Dictionary = {}
# skin0 AnimationGraphData, native 30Hz event frames. No visibility event means
# restore initialSubmeshToHide, never carry the preceding clip's temporary props.
const PART_WINDOWS := {
	"fiddlesticks_idle1": {"Lantern": Vector2(0, -1), "R_Demon_Arm": Vector2(0, -1), "Tongue": Vector2(64, 91)},
	"fiddlesticks_death_v2": {"L_Demon_Arm": Vector2(0, 77), "R_Demon_Arm": Vector2(0, 77)},
}
const OPTIONAL_PARTS := ["Lantern", "Tongue", "L_Demon_Arm", "R_Demon_Arm"]

func prepare_visual_animations() -> void:
	if _parts_prepared: return
	var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null: return
	for instance in find_children("*", "MeshInstance3D", true, false):
		var original := instance.mesh as ArrayMesh
		if original == null or original.get_surface_count() != 6: continue
		var core := ArrayMesh.new()
		for surface in original.get_surface_count():
			var material := original.surface_get_material(surface)
			var part_name := String(material.resource_name)
			var mesh := ArrayMesh.new() if part_name in OPTIONAL_PARTS else core
			mesh.add_surface_from_arrays(original.surface_get_primitive_type(surface), original.surface_get_arrays(surface))
			mesh.surface_set_material(mesh.get_surface_count() - 1, material)
			mesh.surface_set_name(mesh.get_surface_count() - 1, part_name)
			if part_name in OPTIONAL_PARTS:
				var part := MeshInstance3D.new()
				part.name = part_name
				part.mesh = mesh
				part.skin = instance.skin
				part.skeleton = instance.skeleton
				part.transform = instance.transform
				part.visible = false
				instance.get_parent().add_child(part)
				_optional_parts[part_name] = part
		instance.mesh = core
	assert(_optional_parts.size() == 4, "Fiddlesticks requires all native optional submeshes")
	# Evaluate the incoming clip's events independently of outgoing pose weights.
	player.current_animation_changed.connect(_on_clip_changed)
	player.mixer_applied.connect(_sync_part_windows.bind(player))
	_parts_prepared = true

func _on_clip_changed(clip: StringName) -> void:
	_show_parts_at(clip, 0.0)

func _sync_part_windows(player: AnimationPlayer) -> void:
	if player.assigned_animation != &"":
		_show_parts_at(player.assigned_animation, player.current_animation_position * 30.0)

func _show_parts_at(clip: StringName, frame: float) -> void:
	var windows: Dictionary = PART_WINDOWS.get(clip, {})
	for part_name in OPTIONAL_PARTS:
		var window: Vector2 = windows.get(part_name, Vector2(-1, -1))
		_optional_parts[part_name].visible = window.x >= 0 and frame >= window.x and (window.y < 0 or frame < window.y)

func _ready() -> void:
	prepare_visual_animations()
	_skeleton = _find_skeleton(self)
	if _skeleton != null:
		_chest = _skeleton.find_bone("Chest")
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(0.65, 0.08, 0.025, 0.8)
	_material.emission_enabled = true
	_material.emission = Color(0.75, 0.055, 0.01)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null: return found
	return null

func get_beam_origin_world() -> Vector3:
	if _skeleton != null and _chest >= 0:
		return _skeleton.to_global(_skeleton.get_bone_global_pose(_chest).origin)
	return global_position + Vector3.UP * 0.8

func stop_continuous_attack_visual() -> void:
	_age = 0.0
	for beam in _beams: beam.visible = false

func reset_pool_visual() -> void:
	stop_continuous_attack_visual()
	for part in _optional_parts.values(): part.visible = false

func advance_continuous_multi_attack_visual(endpoints: PackedVector2Array, camera: Camera3D, delta: float) -> void:
	if endpoints.is_empty() or camera == null:
		stop_continuous_attack_visual()
		return
	_age += delta
	while _beams.size() < endpoints.size():
		var beam := MeshInstance3D.new()
		beam.mesh = ImmediateMesh.new()
		beam.material_override = _material
		add_child(beam)
		beam.top_level = true
		beam.global_transform = Transform3D.IDENTITY
		_beams.append(beam)
	var start := get_beam_origin_world()
	var depth := -camera.to_local(start).z
	for i in _beams.size():
		var beam := _beams[i]
		beam.visible = i < endpoints.size()
		if not beam.visible: continue
		var end := camera.project_position(BattleGroundProjection.reference_point(camera, endpoints[i]), depth)
		var mesh := beam.mesh as ImmediateMesh
		mesh.clear_surfaces()
		var direction := end - start
		if direction.length_squared() < 0.001: continue
		var side := direction.normalized().cross(camera.global_basis.z).normalized()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for step in 25:
			var t := float(step) / 24.0
			var wave := sin(t * TAU * 2.0 + _age * 6.0 + i) * sin(t * PI) * 0.075
			var center := start.lerp(end, t) + side * wave
			var width := 0.016 + 0.0125 * pow(0.5 + 0.5 * sin(t * 22.0 + _age * 10.0), 3.0)
			mesh.surface_add_vertex(center - side * width)
			mesh.surface_add_vertex(center + side * width)
		mesh.surface_end()
