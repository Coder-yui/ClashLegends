class_name AssistConversionState
extends RefCounted
## 受击者持有的一次性转化资格；只保存值，来源死亡不撤销已命中的窗口。
var _mark: Dictionary = {}
var _consumed := false

static func source_definition(source: Node2D) -> Dictionary:
	if not is_instance_valid(source) or not source is Unit: return {}
	var stats := CardDB.get_unit_stats(source.card_id)
	if float(stats.get("assist_conversion_window", 0.0)) <= 0.0: return {}
	return {"team": source.team, "window": stats.assist_conversion_window,
		"unit_id": stats.assist_conversion_unit_id, "building_id": stats.assist_conversion_building_id}

func record(target: Node2D, definition: Dictionary) -> void:
	if definition.is_empty() or _consumed or target.battle_context == null or target.battle_context.is_net_client(): return
	if int(definition.team) == target.team or (target is Tower and target.is_king): return
	_mark = definition.duplicate()
	_mark["expires_tick"] = target.battle_context.simulation_tick() + ceili(float(definition.window) * 20.0)

func consume(target: Node2D) -> void:
	if _consumed: return
	_consumed = true
	if _mark.is_empty() or target.battle_context == null or target.battle_context.is_net_client(): return
	if target.battle_context.simulation_tick() > int(_mark.expires_tick): return
	var building: bool = target is Tower or (target is Unit and target.is_building)
	if building and not target.nav_cells.is_empty():
		target.battle_context.unblock_nav_cells(target.nav_cells)
		target.nav_cells = []
	var id := String(_mark.building_id if building else _mark.unit_id)
	# 原结构的导航占位已释放；不继承主动资格，也不赋予塔墟免衰减。
	target.battle_context.spawn_summoned(int(_mark.team), id, target.global_position)
