extends Node3D
## 原版普通死亡及连续撞建筑特效；仅消费表现时钟，不参与战斗。
const PARTICLES = preload("res://assets/effects/void_spawn/player.gd")
var _effects := {}
var _animation: AnimationPlayer
var _skeleton: Skeleton3D
var _death_duration := 0.0
var _impact_started := false
var _birth_start := Vector3.ZERO
var _birth_age := -1.0
var _birth_finished := false
var _summoned := false

func _ready() -> void:
	process_priority = 21
	_animation = find_child("AnimationPlayer", true, false) as AnimationPlayer
	for node in find_children("*", "Skeleton3D", true, false):
		_skeleton = node
		break

func configure_unit_visual(unit: Unit) -> void:
	_summoned = unit.summon_visual_origin.is_finite()
	if not _summoned: return
	_animation.play("VoidSpawn_Spawn_anm")
	_animation.seek(0.0, true)
	_skeleton.force_update_all_bone_transforms()
	_birth_start = _bone_position("Thorax")
	_animation.stop(true)

func _effect(kind: String) -> Node3D:
	if not _effects.has(kind):
		var effect := PARTICLES.new()
		add_child(effect)
		effect.load_kind(kind)
		effect.setup_native(PARTICLES.native_scale(kind))
		_effects[kind] = effect
	return _effects[kind]

func _bone_position(bone_name: String) -> Vector3:
	if _skeleton == null: return Vector3.ZERO
	_skeleton.force_update_all_bone_transforms()
	var bone := _skeleton.find_bone(bone_name)
	return to_local(_skeleton.to_global(_skeleton.get_bone_global_pose(bone).origin)) if bone >= 0 else Vector3.ZERO

func begin_visual_death(duration: float) -> void:
	_death_duration = duration
	var effect := _effect("death")
	effect.position = _bone_position("Buffbone_Glb_Channel_Loc")
	effect.seek(0.0)

func _process(_delta: float) -> void:
	_update_birth_effects()
	if _death_duration <= 0.0 or _animation == null: return
	var duration := _animation.current_animation_length
	if duration <= 0.0: return
	var age := _animation.current_animation_position / duration * _death_duration
	_effect("death").seek(age)
	$Model.visible = age < 0.35

func finish_visual_death() -> void:
	for effect in _effects.values(): effect.hide()

func sacrifice_impact_basis() -> Basis:
	if _skeleton == null: return Basis.IDENTITY
	_skeleton.force_update_all_bone_transforms()
	var bone := _skeleton.find_bone("Buffbone_Glb_Channel_Loc")
	if bone < 0: return Basis.IDENTITY
	return (global_transform.affine_inverse() * _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)).basis.orthonormalized()

func sacrifice_impact_offset() -> Vector3:
	return _bone_position("Buffbone_Glb_Channel_Loc")

func seek_sacrifice_visual(source_age: float, burst_age: float = -1.0) -> void:
	for pair in [["energy", "C_Buffbone_Glb_Overhead_Loc"], ["glow", "Buffbone_Glb_Weapon_1"]]:
		var effect := _effect(pair[0])
		effect.position = _bone_position(pair[1])
		effect.seek(source_age)
		effect.visible = burst_age < 0.0
	if burst_age < 0.0: return
	if not _impact_started:
		_impact_started = true
		var effect := _effect("burst")
		effect.position = sacrifice_impact_offset()
		effect.basis = sacrifice_impact_basis() * Basis.from_scale(Vector3.ONE * PARTICLES.native_scale("burst"))
		var pose := effect.global_transform
		effect.top_level = true
		effect.global_transform = pose
	$Model.hide() # 原版第24帧用极远骨骼位移隐藏身体，这里避免巨大包围盒。
	_effects.burst.seek(burst_age)

func reset_pool_visual() -> void:
	_birth_age = -1.0
	_birth_finished = false
	_summoned = false
	for effect in _effects.values(): effect.free()
	_effects.clear()
	_death_duration = 0.0
	_impact_started = false
	$Model.show()


func summon_birth_offset(origin: Vector3, age: float, duration: float) -> Vector3:
	# Native Spawn first-frame Thorax in wrapper coordinates (GLB Root rotates 180 degrees).
	var authored_start := _birth_start
	var progress := clampf(age / maxf(duration, 0.001), 0.0, 1.0)
	var correction := origin - authored_start
	# Keep the authored below-ground emergence and jump height; align only its exit plane.
	correction.y = origin.y
	# Preserve vertical flight curve; only settle the correction, never move the Unit.
	return correction * (1.0 - smoothstep(0.0, 1.0, progress))


func _update_birth_effects() -> void:
	if not _summoned or _birth_finished or _animation == null: return
	if _death_duration > 0.0:
		for kind in ["trail", "spawn"]:
			if _effects.has(kind): _effects[kind].hide()
		_birth_finished = true
		return
	var spawning := String(_animation.assigned_animation) == "VoidSpawn_Spawn_anm"
	if spawning: _birth_age = _animation.current_animation_position
	elif _birth_age >= 0.0: _birth_age += get_process_delta_time()
	if _birth_age < 0.0: return
	var trail := _effect("trail")
	trail.position = _bone_position("Thorax")
	trail.emission_end = 34.0 / 30.0
	trail.seek(_birth_age)
	trail.visible = _birth_age < 34.0 / 30.0 + 0.4
	if _birth_age >= 0.6:
		var splat := _effect("spawn")
		if not splat.top_level:
			splat.position = _bone_position("C_Buffbone_Glb_Overhead_Loc")
			var pose := splat.global_transform
			splat.top_level = true
			splat.global_transform = pose
			splat.global_position.y = 0.015
		splat.seek(_birth_age - 0.6)
		splat.visible = _birth_age < 2.8
	if _birth_age >= 2.8: _birth_finished = true
