extends Node3D
## 原版普通死亡及连续撞建筑特效；仅消费表现时钟，不参与战斗。
const PARTICLES = preload("res://assets/effects/void_spawn/player.gd")
var _effects := {}
var _animation: AnimationPlayer
var _skeleton: Skeleton3D
var _death_duration := 0.0
var _impact_started := false

func _ready() -> void:
	_animation = find_child("AnimationPlayer", true, false) as AnimationPlayer
	for node in find_children("*", "Skeleton3D", true, false):
		_skeleton = node
		break

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
	for effect in _effects.values(): effect.free()
	_effects.clear()
	_death_duration = 0.0
	_impact_started = false
	$Model.show()
