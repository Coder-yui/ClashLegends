extends PreDeploymentVisual3D
## Visual only. A single tilted spear, a silhouette comet and a directional wake.
const SWEEP := preload("res://scripts/battle/pre_deployment_sweep.gd")
const COMET := preload("res://assets/units/pantheon/arrival/original_comet.gd")
const METRICS := preload("res://assets/units/pantheon/visual_metrics.gd")
const SPEAR_TEXTURE := preload("res://assets/units/pantheon/r_original/pantheon_base_tx_cm.png")
const PROXY := preload("res://assets/units/pantheon/r_original/pantheon_r_proxy.glb")
const ORIGINAL_MATERIAL := preload("res://assets/units/pantheon/arrival/particle_mix.gdshader")
const STARRY := preload("res://assets/units/pantheon/r_original/kassadin_skin05_i_starrybackdrop.png")
static var _spear_mesh: ArrayMesh
var _spear: MeshInstance3D
var _ghost: Node3D
var _proxy: Node3D
var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _proxy_material: ShaderMaterial
var _comet: Node3D
var _end := Vector3.ZERO
var _slide_start := Vector3.ZERO
var _direction := Vector3.ZERO
var _time := 0.0
var _sample_tick := -1
const PROFILE := preload("res://assets/units/pantheon/arrival/profile.gd")
# Camera nearly looks down a world 45-degree approach. A shallower visual pitch
# preserves the same ground direction while keeping the shaft and approach readable.
const VISUAL_RISE := 0.5

static func prepare_assets() -> void:
	preload("res://assets/units/pantheon/arrival/particle_player.gd").prepare_assets()
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
	var material := ShaderMaterial.new()
	material.shader = ORIGINAL_MATERIAL
	material.set_shader_parameter("source_texture", STARRY)
	material.set_shader_parameter("uv_offset", Vector2(0, -0.2))
	_proxy_material = material
	for mesh: MeshInstance3D in _proxy.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_player = _proxy.find_child("AnimationPlayer", true, false)
	_skeleton = _proxy.find_child("Skeleton3D", true, false)
	if _skeleton == null: _skeleton = _proxy.find_child("Skeleton", true, false)
	_comet = COMET.new()
	add_child(_comet)
	_comet.setup(_direction, VISUAL_RISE)
	advance_visual(0.0)

func _point_at(time: float) -> Vector3:
	if time >= float(CardDB.get_card("pantheon").pre_deploy_sweep_start):
		return ground(SWEEP.position_at(destination, team, CardDB.get_card("pantheon"), time))
	var fly := clampf((time - 0.2) / 0.45, 0.0, 1.0)
	return _slide_start + (Vector3.UP * VISUAL_RISE - _direction) * 4.0 * (1.0 - fly)

func advance_visual(progress: float) -> void:
	var next_time := clampf(progress, 0, 1) * float(CardDB.get_card("pantheon").pre_deploy_time)
	if next_time < _time - 0.000001:
		_comet.reset()
		_sample_tick = -1
	_time = next_time
	var hz := float(PROFILE.data().sample_hz)
	var target_tick := floori(_time * hz + 0.00001)
	# Replay analytical poses on a fixed visual grid. Late first snapshots and
	# low FPS create exactly the same detached births and trail samples.
	while _sample_tick < target_tick:
		_sample_tick += 1
		var at := float(_sample_tick) / hz
		_comet.advance(at, _point_at(at), _end, _slide_start)
	_pose_at(_time)
	_spear.position = _end + (Vector3.UP * VISUAL_RISE - _direction) * 6.0 * (1.0 - clampf(_time / 0.2, 0.0, 1.0))
	_comet.present(_time, _point_at(_time), _end, _slide_start)

func _pose_at(time: float) -> void:
	var system := "update_missile" if time < float(PROFILE.data().systems.Sliding_Comet.start) else "Sliding_Comet"
	var phase: Dictionary = PROFILE.data().systems[system]
	var source: Dictionary = PROFILE.native_composition().proxies[system]
	var age := maxf(time - float(phase.start), 0.0)
	var frame: Transform3D = _comet._transform(phase, _point_at(time), _end, _slide_start, time)
	var particles := preload("res://assets/units/pantheon/arrival/particle_player.gd")
	# Both proxies are emitter children: use the same frame, native offset and rotation.
	_ghost.global_transform = Transform3D(frame.basis * Basis.from_euler(particles.vec3(source.rotation) * PI / 180.0), frame * (particles.vec3(source.offset) * METRICS.PARTICLE_SCALE))
	_proxy.scale = Vector3.ONE * float(source.uniform_scale) * METRICS.PARTICLE_SCALE
	_proxy_material.render_priority = int(source.get("pass", 0))
	var rgba: Array = particles.sample(source.color, age / float(source.life))
	_proxy_material.set_shader_parameter("tint", Color(rgba[0], rgba[1], rgba[2], rgba[3]))
	_proxy_material.set_shader_parameter("uv_offset", particles.vec2(source.uv_offset))
	_ghost.visible = time >= float(phase.start) and time < float(phase.stop)
	var clip: String = source.animation
	if _player.assigned_animation != clip:
		_player.play(clip)
		_player.pause()
	_player.seek(minf(age, _player.current_animation_length), true)
	_skeleton.force_update_all_bone_transforms()
