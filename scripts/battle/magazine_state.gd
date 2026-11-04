class_name MagazineState
extends RefCounted
## 固定Tick弹匣；补弹不是技能资源，不依赖主动槽资格。
var capacity := 0
var rounds := 0
var duration := 0.0
var remaining := 0.0
var serial := 0

func setup(stats: Dictionary) -> void:
	capacity = int(stats.get("magazine_size", 0))
	rounds = capacity
	duration = float(stats.get("reload_duration", 0.0))
	remaining = 0.0
	serial = 0

func start(unit: Unit) -> void:
	if capacity <= 0 or rounds >= capacity or remaining > 0.0: return
	remaining = duration
	serial += 1
	unit.battle_context.notify_unit_audio_event(unit, &"reload:start", unit.global_position)

func tick(unit: Unit, dt: float) -> void:
	if remaining <= 0.0: return
	remaining = AttackTimeline.tick_remaining(remaining, dt)
	if remaining <= 0.0:
		rounds = capacity
		unit.battle_context.notify_unit_audio_event(unit, &"reload:end", unit.global_position)

func consume(unit: Unit) -> void:
	if capacity <= 0: return
	rounds = maxi(0, rounds - 1)
	remaining = 0.0
	if rounds == 0: start(unit)

func restore(amount: int) -> void:
	rounds = mini(capacity, rounds + amount)
	remaining = 0.0

func snapshot() -> Vector3:
	return Vector3(rounds, remaining, serial)
