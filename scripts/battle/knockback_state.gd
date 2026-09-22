class_name KnockbackState
extends RefCounted
## 当前击退轨迹；Unit 负责准入，MovementSystem 仍负责实际移动和碰撞。
var velocity := Vector2.ZERO
var remaining := 0.0
var end_reason: StringName = &"none"

func replace(direction: Vector2, distance: float, duration: float) -> void:
	remaining = maxf(duration, FixedStepClock.STEP)
	velocity = direction * distance / remaining
	end_reason = &"running"

func advance(dt: float) -> Vector2:
	var movement_time := minf(remaining, dt)
	remaining = maxf(0.0, remaining - dt)
	if remaining == 0.0 and end_reason == &"running": end_reason = &"completed"
	return velocity * movement_time / maxf(dt, 0.0001)

func cancel(reason: StringName) -> void:
	remaining = 0.0
	end_reason = reason

## 撞停只清除轨迹速度；原定行动锁继续到期，不补走被截断距离。
func stop_at_obstacle() -> void:
	velocity = Vector2.ZERO
	end_reason = &"blocked"
