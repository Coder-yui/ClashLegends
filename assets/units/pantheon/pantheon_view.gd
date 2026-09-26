extends Node3D
## 只读模型表现：基础皮肤显隐、满怒附着、固定落点冲击。动画和材质不结算伤害。
const EFFECTS := "res://assets/units/pantheon/effects/"
var _prepared := false
var _body_mesh: MeshInstance3D
var _living_mesh: ArrayMesh
var _death_mesh: ArrayMesh
var _player: AnimationPlayer
var _helmet_snap: SkeletonModifier3D
var _rage_materials: Array[ShaderMaterial] = []
var _rage_elapsed := 0.0
var _rage_full := false
var _ending_wave: Node3D
var _ending_elapsed := 0.0
var _ending_started := false
const ARRIVAL_PARTICLES := preload("res://assets/units/pantheon/r_original/particles.gd")
const VISUAL_METRICS := preload("res://assets/units/pantheon/visual_metrics.gd")

func prepare_visual_animations() -> void:
	if _prepared: return
	preload("res://assets/units/pantheon/pantheon_arrival.gd").prepare_assets()
	var mesh := find_child("Meshes", true, false) as MeshInstance3D
	if mesh == null: return
	var original := mesh.mesh as ArrayMesh
	_body_mesh = mesh
	_living_mesh = ArrayMesh.new()
	_death_mesh = ArrayMesh.new()
	for index in original.get_surface_count():
		var material := original.surface_get_material(index)
		var label := String(material.resource_name).to_lower() if material != null else ""
		if label in ["comet", "recall", "joke"]: continue
		if material != null and label in ["spear", "shield", "helmet", "pantheon_base_mat", "l_arm", "l_arm_only", "headhelmet", "head"]:
			material = material.duplicate()
			var rage := ShaderMaterial.new()
			rage.shader = preload("res://assets/units/pantheon/effects/rage.gdshader")
			rage.set_shader_parameter("glow_texture", preload("res://assets/units/pantheon/effects/pantheon_base_p_weapons_glow.png"))
			rage.set_shader_parameter("streak_texture", preload("res://assets/units/pantheon/effects/pantheon_base_q_nebula_streak_mult_vertical.png"))
			rage.set_shader_parameter("flare_texture", preload("res://assets/units/pantheon/effects/pantheon_base_p_enrage_flare.png"))
			rage.set_shader_parameter("weapon", 1.0 if label in ["spear", "shield"] else 0.0)
			material.next_pass = rage
			_rage_materials.append(rage)
		for variant in [_living_mesh, _death_mesh]:
			if variant == _living_mesh and label == "head": continue
			if variant == _death_mesh and label == "headhelmet": continue
			variant.add_surface_from_arrays(original.surface_get_primitive_type(index), original.surface_get_arrays(index))
			variant.surface_set_material(variant.get_surface_count() - 1, material)
			variant.surface_set_name(variant.get_surface_count() - 1, label)
	mesh.mesh = _living_mesh
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		skeleton = find_child("Skeleton", true, false) as Skeleton3D
	if skeleton != null:
		_helmet_snap = preload("res://assets/units/pantheon/death_helmet.gd").new()
		_helmet_snap.active = false
		skeleton.add_child(_helmet_snap)
	_prepared = true

func _ready() -> void:
	prepare_visual_animations()

## 原片第77帧切裸头；播放位置已含死亡压缩/暂停，不使用战斗计时。
func update_animation_parts(clip: StringName, source_time: float) -> void:
	if not _prepared: return
	var death := clip == &"Death"
	var selected := _death_mesh if death and source_time >= 77.0 / 30.0 else _living_mesh
	if _body_mesh.mesh != selected: _body_mesh.mesh = selected
	if _helmet_snap != null: _helmet_snap.active = death

func set_visual_clip(clip: StringName) -> void:
	update_animation_parts(clip, 0.0)

func _process(_delta: float) -> void:
	if _player != null and not _player.assigned_animation.is_empty():
		update_animation_parts(_player.assigned_animation, _player.current_animation_position)

func advance_skill_resource_visual(full: bool, delta: float) -> void:
	if full and not _rage_full: _rage_elapsed = 0.0
	_rage_full = full
	_rage_elapsed += delta
	for material in _rage_materials:
		material.set_shader_parameter("strength", 1.0 if full else 0.0)
		material.set_shader_parameter("elapsed", _rage_elapsed)

func reset_pool_visual() -> void:
	_clear_ending_wave()
	_ending_started = false
	_ending_elapsed = 0.0
	update_animation_parts(&"", 0.0)
	advance_skill_resource_visual(false, 0.0)
	_rage_elapsed = 0.0

## Called from the existing read-only deployment presentation interface.
## Freeze the endpoint/frame once: pushes and subsequent facing changes cannot
## drag the original on-death shockwave sideways. This never deals damage.
func advance_deployment_visual(elapsed: float, duration: float, active: bool) -> void:
	if not active or duration <= 0.0 or elapsed >= 0.9:
		_clear_ending_wave()
		return
	if not _ending_started:
		_ending_started = true
		_ending_wave = ARRIVAL_PARTICLES.new()
		add_child(_ending_wave)
		_ending_wave.top_level = true
		var forward := global_basis.z.normalized()
		forward.y = 0.0
		forward = forward.normalized()
		_ending_wave.global_transform = Transform3D(Basis(forward, Vector3.UP, forward.cross(Vector3.UP)), global_position)
		_ending_wave.setup("Ending_Shockwave", VISUAL_METRICS.PARTICLE_SCALE)
		_ending_elapsed = 0.0
	if is_instance_valid(_ending_wave):
		_ending_wave.advance(maxf(elapsed - _ending_elapsed, 0.0))
		_ending_elapsed = maxf(elapsed, _ending_elapsed)

func _clear_ending_wave() -> void:
	if is_instance_valid(_ending_wave): _ending_wave.free()
	_ending_wave = null
