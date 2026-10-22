extends Node3D
## 原版E起手与战吼武器层；只读已同步动作/增益时钟。
const PLAYER = preload("res://assets/effects/xin_dash/player.gd")
var _unit: WeakRef
var _cast: Node3D
var _buff: Node3D
var _skeleton: Skeleton3D
var _weapon := -1
var _dead := false
var _cast_serial := -1
var _cast_age := 2.0

func configure_unit_visual(unit: Unit) -> void:
	_unit = weakref(unit)
	_skeleton = $Model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton != null: _weapon = _skeleton.find_bone("Weapon_Main")

func _ensure_parts() -> void:
	if _cast != null: return
	_cast = PLAYER.new()
	_buff = PLAYER.new()
	for entry in [[_cast, "cas"], [_buff, "buff"]]:
		add_child(entry[0])
		entry[0].load_kind(entry[1])
		entry[0].setup_native(PLAYER.NATIVE_SCALE)

func advance_ambient_visual(delta: float) -> void:
	var unit = _unit.get_ref() if _unit != null else null
	if _dead or not is_instance_valid(unit) or unit.hp <= 0.0:
		_hide_parts()
		return
	var charge_action: bool = unit.get_visual_action_name() == &"charge_strike"
	if charge_action and unit.get_visual_action_serial() != _cast_serial:
		_cast_serial = unit.get_visual_action_serial()
		_cast_age = unit.get_visual_action_duration() - unit.get_visual_action_time_left()
	elif not unit.is_frozen() and not CombatInteraction.in_stasis(unit):
		_cast_age += delta
	var charging: bool = charge_action and _cast_age < 1.65
	var clock: Vector2 = unit.active_buff_clock_visual()
	var buffing: bool = unit.get_active_buff_active_visual() and unit.get_active_attack_speed_multiplier_visual() > 1.001 and clock.y > 0.0
	if not charging and not buffing:
		_hide_parts()
		return
	_ensure_parts()
	var shown := PresentationConfig.status_indicators_visible(unit)
	_cast.visible = charging and shown
	_buff.visible = buffing and shown
	if charging: _cast.seek(_cast_age)
	if buffing:
		if is_instance_valid(_skeleton) and _weapon >= 0:
			_buff.global_transform = _skeleton.global_transform * _skeleton.get_bone_global_pose(_weapon)
			# 完整骨骼变换已包含Model的0.0108和单位缩放，不再覆盖缩放或叠乘。
		_buff.seek(clock.x)

func _hide_parts() -> void:
	if _cast != null: _cast.hide()
	if _buff != null: _buff.hide()

func begin_visual_death(_duration: float) -> void:
	_dead = true
	_hide_parts()

func reset_pool_visual() -> void:
	_unit = null
	_dead = false
	_cast_serial = -1
	_cast_age = 2.0
	_hide_parts()
