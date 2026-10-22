extends Node3D
## 原版战吼武器层；只读已同步增益时钟。
const PLAYER = preload("res://assets/effects/xin_dash/player.gd")
var _unit: WeakRef
var _buff: Node3D
var _skeleton: Skeleton3D
var _weapon := -1
var _dead := false

func configure_unit_visual(unit: Unit) -> void:
	_unit = weakref(unit)
	_skeleton = $Model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton != null: _weapon = _skeleton.find_bone("Weapon_Main")

func _ensure_parts() -> void:
	if _buff != null: return
	_buff = PLAYER.new()
	add_child(_buff)
	_buff.load_kind("buff")
	_buff.setup_native(PLAYER.NATIVE_SCALE)

func advance_ambient_visual(_delta: float) -> void:
	var unit = _unit.get_ref() if _unit != null else null
	if _dead or not is_instance_valid(unit) or unit.hp <= 0.0:
		_hide_parts()
		return
	var clock: Vector2 = unit.active_buff_clock_visual()
	var buffing: bool = unit.get_active_buff_active_visual() and unit.get_active_attack_speed_multiplier_visual() > 1.001 and clock.y > 0.0
	if not buffing:
		_hide_parts()
		return
	_ensure_parts()
	var shown := PresentationConfig.status_indicators_visible(unit)
	_buff.visible = buffing and shown
	if buffing:
		if is_instance_valid(_skeleton) and _weapon >= 0:
			_buff.global_transform = _skeleton.global_transform * _skeleton.get_bone_global_pose(_weapon)
			# 完整骨骼变换已包含Model的0.0108和单位缩放，不再覆盖缩放或叠乘。
		_buff.seek(clock.x)

func _hide_parts() -> void:
	if _buff != null: _buff.hide()

func begin_visual_death(_duration: float) -> void:
	_dead = true
	_hide_parts()

func reset_pool_visual() -> void:
	_unit = null
	_dead = false
	_hide_parts()
