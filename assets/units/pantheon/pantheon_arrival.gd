extends PreDeploymentVisual3D
## Visual only. A single tilted spear, a silhouette comet and a directional wake.
const SWEEP := preload("res://scripts/battle/pre_deployment_sweep.gd")
const COMET := preload("res://assets/units/pantheon/arrival/original_comet.gd")
const METRICS := preload("res://assets/units/pantheon/visual_metrics.gd")
const PROXY := preload("res://assets/units/pantheon/r_original/pantheon_r_proxy.glb")
const SPEAR_TEXTURE := preload("res://assets/units/pantheon/r_original/pantheon_base_tx_cm.png")
const ORIGINAL_MATERIAL := preload("res://assets/units/pantheon/r_original/particle_mix.gdshader")
const STARRY := preload("res://assets/units/pantheon/r_original/kassadin_skin05_i_starrybackdrop.png")
static var _spear_mesh: ArrayMesh
var _spear: MeshInstance3D
var _ghost: Node3D
var _proxy: Node3D
var _player: AnimationPlayer
var _proxy_material: ShaderMaterial
var _comet: Node3D
var _end := Vector3.ZERO
var _slide_start := Vector3.ZERO
var _direction := Vector3.ZERO
var _time := 0.0
# Camera nearly looks down a world 45-degree approach. A shallower visual pitch
# preserves the same ground direction while keeping the shaft and approach readable.
const VISUAL_RISE := 0.5

static func prepare_assets() -> void:
	preload("res://assets/units/pantheon/r_original/particles.gd").prepare_assets()
	if _spear_mesh != null: return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/units/pantheon/r_original/pantheon_base_q_hold_spear.mesh.json"))
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in range(0, data.vertices.size(), 3): vertices.append(Vector3(data.vertices[i],data.vertices[i+1],data.vertices[i+2]))
	for i in range(0, data.uv.size(), 2): uvs.append(Vector2(data.uv[i],data.uv[i+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	_spear_mesh = ArrayMesh.new()
	_spear_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func setup(view_camera: Camera3D, point: Vector2, source_team: int) -> void:
	super.setup(view_camera, point, source_team)
	prepare_assets()
	_end = ground(point)
	_slide_start = ground(SWEEP.start_position(point, team, CardDB.get_card("pantheon")))
	_direction = (_end - _slide_start).normalized()
	_spear = MeshInstance3D.new()
	_spear.mesh = _spear_mesh
	var spear_material := StandardMaterial3D.new()
	spear_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spear_material.albedo_texture = SPEAR_TEXTURE
	spear_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_spear.material_override = spear_material
	_spear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_spear)
	# Original mesh extends toward -Y from its tip. Grip remains above and behind tip.
	_spear.basis = Basis(Vector3.UP, atan2(_direction.x, _direction.z)) * Basis(Vector3.RIGHT, -atan2(1.0, VISUAL_RISE)) * Basis(Vector3.UP, PI / 2.0) * Basis(Vector3.RIGHT, PI)
	_spear.scale = Vector3.ONE * METRICS.PROP_SCALE
	_ghost = Node3D.new()
	add_child(_ghost)
	_ghost.rotation.y = atan2(_direction.x, _direction.z)
	_proxy = PROXY.instantiate()
	_ghost.add_child(_proxy)
	_proxy.scale = Vector3.ONE * METRICS.PROP_SCALE
	_proxy.position.y = -0.3 * METRICS.RATIO
	var material := ShaderMaterial.new()
	material.shader = ORIGINAL_MATERIAL
	material.set_shader_parameter("source_texture", STARRY)
	material.set_shader_parameter("uv_offset", Vector2(0, -0.2))
	_proxy_material = material
	for mesh: MeshInstance3D in _proxy.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_player = _proxy.find_child("AnimationPlayer", true, false)
	_comet = COMET.new()
	add_child(_comet)
	_comet.setup(_direction, VISUAL_RISE)
	advance_visual(0.0)

func advance_visual(progress: float) -> void:
	_time = clampf(progress, 0, 1) * float(CardDB.get_card("pantheon").pre_deploy_time)
	var fly := clampf((_time - 0.2) / 0.45, 0.0, 1.0)
	var slide := clampf((_time - 0.65) / 0.65, 0.0, 1.0)
	var point := _slide_start + (Vector3.UP * VISUAL_RISE - _direction) * 4.0 * (1.0 - fly)
	if _time >= 0.65: point = ground(SWEEP.position_at(destination, team, CardDB.get_card("pantheon"), _time))
	_ghost.position = point
	var pitch := atan2(VISUAL_RISE, 1.0) * (1.0 - smoothstep(0.55, 0.65, _time))
	_ghost.basis = Basis(Vector3.UP, atan2(_direction.x, _direction.z)) * Basis(Vector3.RIGHT, pitch)
	_proxy_material.set_shader_parameter("tint", Color(1.0, 0.07450981, 0.011764706, 1.0) if _time < 0.65 else Color(0.68235296, 0.039215688, 0.039215688, 1.0))
	_ghost.visible = _time >= 0.2 and _time < 1.3
	var clip := "pantheon_spell4_fly" if _time < 0.65 else "pantheon_spell4_slide"
	if _player.assigned_animation != clip:
		_player.play(clip)
		_player.pause()
	_player.seek(fly * 0.5 if _time < 0.65 else slide * 0.6666667, true)
	_spear.position = _end + (Vector3.UP * VISUAL_RISE - _direction) * 6.0 * (1.0 - clampf(_time / 0.2, 0.0, 1.0))
	_comet.advance(_time, point, _end, _slide_start)
