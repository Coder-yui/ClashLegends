class_name AttackTimeline
extends RefCounted
## 当前普攻阶段的权威剩余时间；只在固定 Tick 或权威状态变化时写入。
var cooldown := 0.0
var windup := 0.0
var recovery := 0.0
## 归一到基础攻速的表现已流逝时间，只发布给表现消费者。
var visual_elapsed := 0.0

func rescale(previous_speed: float, next_speed: float) -> void:
	var ratio := previous_speed / maxf(next_speed, 0.01)
	cooldown *= ratio
	windup *= ratio
	recovery *= ratio

## 丢失目标取消本次挥击，但保留已经出手后的攻击间隔；施法/变形显式重置间隔。
func cancel(reset_cooldown: bool = false) -> void:
	windup = 0.0
	recovery = 0.0
	if reset_cooldown:
		cooldown = 0.0

func begin_windup(base_first_hit: float, attack_speed: float) -> void:
	windup = maxf(base_first_hit / attack_speed, cooldown)

func commit_hit(next_gap: float) -> void:
	cooldown = next_gap

func begin_recovery(next_gap: float, base_first_hit: float, attack_speed: float) -> void:
	recovery = maxf(next_gap - base_first_hit / attack_speed, 0.0)

func tick_cooldown(dt: float) -> void:
	cooldown = _tick_remaining(cooldown, dt)

func tick_windup(dt: float) -> void:
	windup = _tick_remaining(windup, dt)

func tick_recovery(dt: float) -> void:
	recovery = _tick_remaining(recovery, dt)

func advance_visual(dt: float, attack_speed: float) -> void:
	visual_elapsed += dt * attack_speed

func restart_visual() -> void:
	visual_elapsed = 0.0

func align_visual(base_first_hit: float, time_until_hit: float, attack_speed: float) -> void:
	visual_elapsed = maxf(base_first_hit - maxf(time_until_hit, 0.0) * attack_speed, 0.0)

## 避免0.30连续减去0.05后的浮点尾差额外等待一个50ms Tick。
func _tick_remaining(value: float, dt: float) -> float:
	var remaining := maxf(0.0, value - dt)
	return 0.0 if remaining < 0.000000001 else remaining
