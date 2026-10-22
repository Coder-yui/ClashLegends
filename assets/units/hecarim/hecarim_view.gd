extends Node3D
## 原版Q施放层与模型附着层，只读同步攻击时钟。
const Native = preload("res://assets/effects/hecarim/player.gd")
const GEOMETRY = preload("res://assets/effects/hecarim/geometry.gd")
var _skeleton: Skeleton3D
var _torso_bone := -1
const Q_SOURCE_LENGTH := 0.96774149
var _unit: WeakRef
var _cas: Node3D
var _buf: Node3D
var _dead := false

func configure_unit_visual(unit: Unit) -> void:
	_unit = weakref(unit)
	_dead = false
	_ensure_effects()
	_hide_effects()

func _ensure_effects() -> void:
	if is_instance_valid(_cas): return
	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton != null: _torso_bone = _skeleton.find_bone("root")
	_cas = Native.new()
	_buf = Native.new()
	for entry in [[_cas, "qcas"], [_buf, "qbuf"]]:
		add_child(entry[0])
		entry[0].load_kind(entry[1])
		entry[0].setup_native(GEOMETRY.Q_SCALE)
	for mesh in $Model.find_children("*", "MeshInstance3D", true, false):
		for index in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(index, _buf.make_overlay(mesh.get_active_material(index)))

func advance_ambient_visual(_delta: float) -> void:
	var unit = _unit.get_ref() if _unit != null else null
	if _dead or not is_instance_valid(unit) or unit.hp <= 0.0:
		_hide_effects()
		return
	# action名称保留最近一次事件，结束后不会清空；仅在冲刺动作窗口内抑制Q。
	# 普通攻击序号、elapsed及动作剩余时间均由快照提供。
	var charge_active: bool = unit.get_visual_action_name() == &"charge_strike" and unit.get_visual_action_time_left() > 0.0
	var shown: bool = unit.get_visual_state_code() == 3 and unit.get_attack_visual_serial() > 0 and not charge_active
	var age: float = unit.get_attack_elapsed_visual() * Q_SOURCE_LENGTH / maxf(unit.attack_interval, 0.01)
	_cas.visible = shown
	_buf.visible = shown
	if shown:
		# 水平旋斩的中心保持单位脚点XZ，仅高度跟随上身root骨骼；不随骨骼倾斜刀光平面。
		var torso_height := 1.05
		if is_instance_valid(_skeleton) and _torso_bone >= 0:
			torso_height = to_local(_skeleton.to_global(_skeleton.get_bone_global_pose(_torso_bone).origin)).y
		_cas.position = Vector3(0.0, torso_height, 0.0)
		_buf.position = Vector3.ZERO # Q_buf由原版武器轨迹定位，不能再叠加上身高度。
		_cas.seek(age)
		_buf.seek(age)
	_buf.update_attached(shown)

func _hide_effects() -> void:
	if is_instance_valid(_cas): _cas.hide()
	if is_instance_valid(_buf):
		_buf.hide()
		_buf.update_attached(false)

func begin_visual_death(_duration: float) -> void:
	_dead = true
	_hide_effects()

func reset_pool_visual() -> void:
	_unit = null
	_dead = false
	_hide_effects()
