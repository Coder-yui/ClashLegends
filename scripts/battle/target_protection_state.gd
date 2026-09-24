class_name TargetProtectionState
extends RefCounted
## 固定结界的唯一实例所有者；不清除/抑制既有状态，不改变碰撞。
var center := Vector2.ZERO
var radius := 0.0
var serial := 0
var _windows := StatusInstances.new()
var _replica := false
var _replica_remaining := 0.0

func begin(position: Vector2, reach: float, duration: float) -> void:
	_replica = false
	center = position
	radius = reach
	serial += 1
	_windows.clear_family(&"sanctuary")
	_windows.apply(&"sanctuary", &"self", duration, {})

func remaining() -> float:
	return _replica_remaining if _replica else _windows.remaining(&"sanctuary")

func active() -> bool:
	return radius > 0.0 and remaining() > 0.0

func contains(position: Vector2) -> bool:
	return position.is_finite() and position.distance_squared_to(center) <= radius * radius

func advance(dt: float, position: Vector2) -> void:
	if _replica: return
	_windows.advance(dt)
	check_position(position)

func check_position(position: Vector2) -> void:
	if not _replica and active() and not contains(position): clear()

func clear() -> void:
	_windows.clear_family(&"sanctuary")
	_replica_remaining = 0.0

func snapshot() -> Array:
	return [center, radius, remaining(), serial]

static func valid_snapshot(value: Variant) -> bool:
	if not value is Array or value.size() != 4: return false
	if not value[0] is Vector2 or not value[0].is_finite(): return false
	for index in [1, 2]:
		if typeof(value[index]) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value[index])) or float(value[index]) < 0.0: return false
	return value[3] is int and int(value[3]) >= 0 and (float(value[2]) == 0.0 or float(value[1]) > 0.0)

func apply_replica(value: Array) -> void:
	_replica = true
	center = value[0]
	radius = float(value[1])
	_replica_remaining = float(value[2])
	serial = int(value[3])
