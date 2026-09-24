class_name TerrainTraversalState
extends RefCounted
## 只记录完整圆柱由合法地面进入河道/结构的边沿；相连地形算同一次。
var enabled := false
var inside := false
var heal_amount := 0.0
var haste_multiplier := 1.0

func configure(stats: Dictionary) -> void:
	enabled = bool(stats.get("terrain_traversal", false))
	heal_amount = float(stats.get("terrain_entry_heal", 0.0))
	haste_multiplier = float(stats.get("terrain_entry_speed_multiplier", 1.0))
	inside = false

func update(unit: Unit) -> void:
	if not enabled or unit.battle_context == null or unit.hp <= 0.0: return
	var now_inside := not unit.battle_context.is_ground_position_walkable(unit.global_position, unit.body_radius, unit)
	if now_inside and not inside:
		unit.heal(heal_amount)
		if haste_multiplier > 1.0:
			unit.apply_active_buff(1.0, haste_multiplier, 1.0, 1.0, false, false, unit.status_source("terrain_entry"))
		unit.battle_context.notify_unit_audio_event(unit, &"terrain:enter", unit.global_position)
	inside = now_inside

func leave_for_attack(unit: Unit) -> bool:
	if not enabled or unit.battle_context == null: return true
	update(unit)
	if not inside: return true
	var point := unit.battle_context.find_unit_landing(unit, unit.global_position, false)
	if not point.is_finite(): return false
	unit.global_position = point
	unit._prev_pos = point
	unit.net_target_pos = point
	unit._path = PackedVector2Array()
	unit._path_index = 0
	unit._repath_cd = 0.0
	update(unit)
	unit.cancel_basic_attack(&"terrain_exit")
	return false # 下一权威步重新索敌、射程和前摇，不在挪位当步出手。
