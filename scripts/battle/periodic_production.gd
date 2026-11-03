class_name PeriodicProduction
extends RefCounted
## 权威周期产出：金币与召唤共享。到期受控只保留一批，实际发出后重计完整周期。
var remaining := 0.0

func reset(interval: float) -> void:
	remaining = interval

func tick(dt: float, interval: float, blocked: bool) -> bool:
	if interval <= 0.0: return false
	remaining = maxf(0.0, remaining - dt)
	if remaining > 0.000001 or blocked: return false
	reset(interval)
	return true

static func blocked(source: Unit) -> bool:
	return source.is_frozen() or source.is_stunned() or CombatInteraction.in_stasis(source)
