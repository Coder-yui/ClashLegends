class_name ControlState
extends RefCounted
## 控制独立实例的唯一所有者；公开秒数为适配/副本视图。
const MOVE := 1
const BASIC_ATTACK := 2
const START_SKILL := 4
const TURN := 8
const CONTINUE_SKILL := 16
const EXTERNAL_MOTION := 32
const ALL_PERMISSIONS := 63
var hard := StatusInstances.new()
var modifiers := StatusInstances.new()
var frozen_timer: float:
	get: return hard.remaining(&"freeze")
var stun_timer: float:
	get: return hard.remaining(&"stun")
var slow_timer: float:
	get: return modifiers.remaining(&"slow")
var slow_multiplier: float:
	get: return modifiers.strongest(&"slow", &"multiplier", 1.0, true)
var attack_speed_slow_timer: float:
	get: return modifiers.remaining(&"attack_slow")
var attack_speed_slow_multiplier: float:
	get: return modifiers.strongest(&"attack_slow", &"multiplier", 1.0, true)

func _replace_hard(family: StringName, duration: float) -> void:
	hard.clear_family(family)
	hard.apply(family, &"replica", duration, {})

func refresh_freeze(duration: float, source: StringName = &"legacy") -> bool:
	return hard.apply(&"freeze", source, duration, {})

func refresh_stun(duration: float, source: StringName = &"legacy") -> bool:
	return hard.apply(&"stun", source, duration, {})

func refresh_slow(duration: float, multiplier: float, source: StringName = &"legacy") -> bool:
	return modifiers.apply(&"slow", source, duration, {"multiplier": clampf(multiplier, 0.1, 1.0)})

func refresh_attack_slow(duration: float, multiplier: float, source: StringName = &"legacy") -> bool:
	return modifiers.apply(&"attack_slow", source, duration, {"multiplier": clampf(multiplier, 0.1, 1.0)})

func tick_slows(dt: float) -> void:
	modifiers.advance(dt)

func tick_hard_controls(dt: float) -> void:
	hard.advance(dt)

func apply_replica_flags(frozen: bool, stunned: bool) -> void:
	_replace_hard(&"freeze", 0.15 if frozen else 0.0)
	_replace_hard(&"stun", 0.15 if stunned else 0.0)

func apply_replica_stun(stunned: bool) -> void:
	_replace_hard(&"stun", 0.15 if stunned else 0.0)

## 致死结算建立新的生命阶段，旧硬控不能阻塞死亡/复生表现或继承给下一条命。
func clear_on_death() -> void:
	hard.clear_family(&"freeze")
	hard.clear_family(&"stun")

func permissions() -> int:
	var allowed := ALL_PERMISSIONS
	if frozen_timer > 0.0 or stun_timer > 0.0:
		allowed &= ~(MOVE | BASIC_ATTACK | START_SKILL | TURN)
	if frozen_timer > 0.0:
		allowed &= ~CONTINUE_SKILL
	return allowed
