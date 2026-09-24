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
	if used or delay <= 0.0 or unit.transformed_stats.is_empty(): return false
	created_tick = unit.battle_context.simulation_tick() if unit.battle_context != null else -1
	used = true
	waiting_ticks = maxi(1, int(ceil(delay * 20.0)))
	unit.cancel_basic_attack(&"death_form")
	unit.cancel_skill_cast()
	unit.clear_shields()
	unit.knockback.cancel(&"death_form")
	unit._target = null
	unit._move_intent = Vector2.ZERO
	unit.play_visual_action(&"death_form", delay)
	if unit.battle_context != null:
		unit.battle_context.notify_unit_audio_event(unit, &"rebirth:begin", unit.global_position)
		unit.battle_context.notify_unit_audio_event(unit, &"rebirth:voice", unit.global_position)
	return true

func advance(unit: Unit, dt: float) -> void:
	if unit.battle_context != null and created_tick == unit.battle_context.simulation_tick(): return
	if waiting():
		waiting_ticks -= 1
		if waiting(): return
		unit._apply_form(1, false)
		unit.hp = unit.max_hp
		unit._deploy_timer = 0.0
		if unit.battle_context != null:
			unit.battle_context.notify_unit_audio_event(unit, &"rebirth:ready", unit.global_position)
		return
	if not used or unit.form_index != 1 or unit.hp <= 0.0: return
	decay_remainder += unit.max_hp * dt / float(unit._base_form_stats.death_form_decay_duration)
	var amount := roundf(decay_remainder)
	decay_remainder -= amount
	unit.hp = maxf(0.0, unit.hp - amount)
	if unit.hp <= 0.0: unit._die()

func snapshot() -> Array:
	return [used, waiting_ticks]

static func valid_snapshot(value: Variant) -> bool:
	return value is Array and value.size() == 2 and value[0] is bool and value[1] is int and value[1] >= 0 and (value[0] or value[1] == 0)

func apply_replica(value: Array) -> void:
	used = value[0]
	waiting_ticks = value[1]
