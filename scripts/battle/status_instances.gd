class_name StatusInstances
extends RefCounted
## 轻量独立效果窗口。强度包整体替换；同源同强度仅刷新结束 Tick。
const TICKS_PER_SECOND := 20
var tick_index := 0
var _fraction := 0.0
var _next_id := 0
var _instances: Array[Dictionary] = []

func apply(family: StringName, source: StringName, duration: float, potency: Dictionary) -> bool:
	if not is_finite(duration) or duration <= 0.0:
		return false
	var end_tick := tick_index + maxi(1, ceili(duration * TICKS_PER_SECOND - 0.00000001))
	for effect in _instances:
		if effect.family == family and effect.source == source:
			if effect.potency == potency:
				effect.end_tick = maxi(int(effect.end_tick), end_tick)
			else:
				effect.potency = potency.duplicate(true)
				effect.start_tick = tick_index
				effect.end_tick = end_tick
			return false
	_next_id += 1
	_instances.append({"id": _next_id, "family": family, "source": source,
		"start_tick": tick_index, "end_tick": end_tick, "potency": potency.duplicate(true)})
	return true

func advance(dt: float) -> void:
	_fraction += maxf(dt, 0.0) * TICKS_PER_SECOND
	var steps := floori(_fraction + 0.00000001)
	_fraction -= steps
	tick_index += steps
	for i in range(_instances.size() - 1, -1, -1):
		if int(_instances[i].end_tick) <= tick_index:
			_instances.remove_at(i)

func clear_family(family: StringName) -> void:
	for i in range(_instances.size() - 1, -1, -1):
		if _instances[i].family == family:
			_instances.remove_at(i)

func remaining(family: StringName) -> float:
	var end_tick := tick_index
	for effect in _instances:
		if effect.family == family:
			end_tick = maxi(end_tick, int(effect.end_tick))
	return float(end_tick - tick_index) / TICKS_PER_SECOND

func strongest(family: StringName, field: StringName, baseline: float, minimum: bool = false) -> float:
	var result := baseline
	for effect in _instances:
		if effect.family == family:
			var value := float(effect.potency.get(field, baseline))
			result = minf(result, value) if minimum else maxf(result, value)
	return result

func any_flag(family: StringName, field: StringName) -> bool:
	for effect in _instances:
		if effect.family == family and bool(effect.potency.get(field, false)):
			return true
	return false
