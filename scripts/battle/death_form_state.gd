class_name DeathFormState
extends RefCounted
## 一次性致死换形；等待保留实体身份，生命为零，不发布最终死亡。
var created_tick := -1
var used := false
var waiting_ticks := 0
var decay_remainder := 0.0

func waiting() -> bool:
	return waiting_ticks > 0

func begin(unit: Unit) -> bool:
	var delay := float(unit._base_form_stats.get("death_form_delay", 0.0))
	if used or delay <= 0.0 or unit.transformed_stats.is_empty():
		return false
	created_tick = unit.battle_context.simulation_tick() if unit.battle_context != null else -1
	used = true
	waiting_ticks = maxi(1, int(ceil(delay * 20.0)))
	unit.begin_death_form_transition(delay)
	return true

func advance(unit: Unit, dt: float) -> void:
	if unit.battle_context != null and created_tick == unit.battle_context.simulation_tick():
		return
	if waiting():
		waiting_ticks -= 1
		if waiting():
			return
		unit.complete_death_form_transition()
		return
	if not used or unit.form_index != 1 or unit.hp <= 0.0:
		return
	decay_remainder += unit.max_hp * dt / float(unit._base_form_stats.death_form_decay_duration)
	var amount := roundf(decay_remainder)
	decay_remainder -= amount
	unit.apply_death_form_decay(amount)

func snapshot() -> Array:
	return [used, waiting_ticks]

static func valid_snapshot(value: Variant) -> bool:
	return value is Array and value.size() == 2 and value[0] is bool and value[1] is int and value[1] >= 0 and (value[0] or value[1] == 0)

func apply_replica(value: Array) -> void:
	used = value[0]
	waiting_ticks = value[1]
