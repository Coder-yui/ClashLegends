extends Node3D
## 原生Q飞拳/电缆与E拳部粒子，只消费同步动作和目标端点。
const Native = preload("res://assets/effects/blitzcrank/player.gd")
## 原始SKN/骨架与用户GLB逐轴比对为0.0085；Model节点另有1.25包装缩放。
const SOURCE_TO_GLB := 0.0085
var _unit: WeakRef
var _skeleton: Skeleton3D
var _hand := -1
var _ebuf: Node3D
var _dead := false
var _buff_age := 0.0
var _emitting := false

func configure_unit_visual(unit: Unit) -> void:
	_unit = weakref(unit)
	_dead = false
	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton != null: _hand = _skeleton.find_bone("R_hand")
	_hide()

func _effect(kind: String) -> Node3D:
	var effect := Native.new()
	add_child(effect)
	effect.load_kind(kind)
	effect.setup_native(SOURCE_TO_GLB * $Model.scale.x)
	return effect

func _hand_position() -> Vector3:
	if is_instance_valid(_skeleton) and _hand >= 0:
		return to_local(_skeleton.to_global(_skeleton.get_bone_global_pose(_hand).origin))
	return Vector3(-0.5, 0.8, 0.3)

func advance_ambient_visual(delta: float) -> void:
	var unit = _unit.get_ref() if _unit != null else null
	if _dead or not is_instance_valid(unit) or unit.hp <= 0.0:
		_hide()
		return
	var hand := _hand_position()
	unit.set_meta("blitzcrank_hand_world", to_global(hand))
	unit.set_meta("blitzcrank_vfx_scale", SOURCE_TO_GLB * $Model.global_basis.get_scale().abs().x)
	var empowered: bool = unit.is_empowered_attack_ready_visual()
	if empowered and not _emitting:
		if not is_instance_valid(_ebuf): _ebuf = _effect("ebuf")
		_ebuf.restart_emitting()
		_buff_age = 0.0
		_emitting = true
	elif not empowered and _emitting:
		_ebuf.stop_emitting()
		_emitting = false
	if not is_instance_valid(_ebuf): return
	_ebuf.position = hand
	if is_instance_valid(_skeleton) and _hand >= 0:
		var pose := _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand)
		_ebuf.global_basis = pose.basis.orthonormalized().scaled(Vector3.ONE * float(unit.get_meta("blitzcrank_vfx_scale")))
	if _emitting:
		if not unit.is_frozen(): _buff_age += delta
		_ebuf.seek(0.5 + fmod(_buff_age - 0.5, 0.9) if _buff_age >= 1.4 else _buff_age)
	elif not unit.is_frozen():
		_ebuf.advance(delta)
	_ebuf.visible = _emitting or _ebuf.has_live_particles()

func _hide() -> void:
	_emitting = false
	for effect in [_ebuf]:
		if is_instance_valid(effect): effect.hide()

func begin_visual_death(_duration: float) -> void:
	_dead = true
	_hide()

func reset_pool_visual() -> void:
	if is_instance_valid(_ebuf): _ebuf.free()
	_ebuf = null
	_unit = null
	_dead = false
	_buff_age = 0.0
	_hide()
