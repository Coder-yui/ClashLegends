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
