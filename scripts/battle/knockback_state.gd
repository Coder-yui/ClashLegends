class_name KnockbackState
extends RefCounted
## 当前击退轨迹；Unit 负责准入，MovementSystem 仍负责实际移动和碰撞。
var velocity := Vector2.ZERO
var remaining := 0.0
var end_reason: StringName = &"none"
# 两类外力共用唯一行动锁；只有强制位移在途中忽略碰撞。
var collisionless := false
var in_transit := false
var origin := Vector2.ZERO
var endpoint := Vector2.ZERO
var original_distance := 0.0
var original_duration := 0.0
var travel_left := 0.0
var speed := 0.0
var extension_limit := 0.0
var arrival_pending := false
var recovery_pending := false

func replace_forced(start: Vector2, end: Vector2, direction: Vector2, distance: float, duration: float, extension: float) -> void:
	replace(direction, distance, duration)
	collisionless = true
	in_transit = true
	origin = start
	endpoint = end
	original_distance = distance
	original_duration = duration
	speed = distance / duration
	velocity = direction * speed
	travel_left = start.distance_to(end)
	extension_limit = extension
	remaining = maxf(duration, travel_left / speed)
	arrival_pending = travel_left <= 0.000001


func replace(direction: Vector2, distance: float, duration: float) -> void:
	collisionless = false
	in_transit = false
	arrival_pending = false
	recovery_pending = false
	remaining = maxf(duration, FixedStepClock.STEP)
	velocity = direction * distance / remaining
	end_reason = &"running"

func advance(dt: float) -> Vector2:
	if collisionless:
		remaining = maxf(0.0, remaining-dt)
		if remaining < 0.000001: remaining = 0.0
		var travel := minf(travel_left, speed*dt)
		travel_left = maxf(0.0, travel_left-travel)
		if travel_left <= 0.000001: arrival_pending = in_transit
		return velocity.normalized()*travel/maxf(dt,0.0001)
	var movement_time := minf(remaining, dt)
	remaining = maxf(0.0, remaining - dt)
	if remaining == 0.0 and end_reason == &"running": end_reason = &"completed"
	return velocity * movement_time / maxf(dt, 0.0001)

func cancel(reason: StringName) -> void:
	collisionless = false
	in_transit = false
	arrival_pending = false
	remaining = 0.0
	end_reason = reason

## 撞停只清除轨迹速度；原定行动锁继续到期，不补走被截断距离。
func stop_at_obstacle() -> void:
	velocity = Vector2.ZERO
	end_reason = &"blocked"
