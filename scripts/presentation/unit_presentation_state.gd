class_name UnitPresentationState
extends RefCounted
## 每单位一个只读视图，不复制字典；网络/本地差异只在 Unit 查询入口解决。
var _unit: Unit
func _init(unit: Unit) -> void:
	_unit = unit
var behavior: int:
	get: return _unit.get_visual_state_code()
var locomotion: int:
	get: return _unit.get_locomotion_visual_state_code()
var frozen: bool:
	get: return is_instance_valid(_unit) and not _unit.death_form.waiting() and _unit.is_frozen()
var stunned: bool:
	get: return is_instance_valid(_unit) and not _unit.death_form.waiting() and _unit.is_stunned()
var dead: bool:
	get: return not is_instance_valid(_unit) or (_unit.hp <= 0.0 and not _unit.death_form.waiting())
var attack_serial: int:
	get: return _unit.get_attack_visual_serial()
var attack_elapsed: float:
	get: return _unit.get_attack_elapsed_visual()
var action_serial: int:
	get: return _unit.get_visual_action_serial()
var action: StringName:
	get: return _unit.get_visual_action_name()
var action_time_left: float:
	get: return _unit.get_visual_action_time_left()
var movement_rate: float:
	get: return _unit.get_effective_movement_rate_visual()
var attack_rate: float:
	get: return _unit.get_active_attack_speed_multiplier_visual()
var active_buff: bool:
	get: return _unit.get_active_buff_active_visual()
var can_move: bool:
	get: return not dead and (_unit.get_action_permissions_visual() & 1) != 0
var can_attack: bool:
	get: return not dead and (_unit.get_action_permissions_visual() & 2) != 0

## 血条只读权威复生计时。帧间最多外推一个Tick，不能恢复真实生命或提前解锁。
var _recovery_ratio := 0.0
var _observed_wait_ticks := -1
var health_ratio: float:
	get:
		if not is_instance_valid(_unit): return 0.0
		if _unit.death_form.waiting():
			return _authoritative_recovery_ratio() if _observed_wait_ticks < 0 else _recovery_ratio
		return maxf(_unit.hp / maxf(_unit.max_hp, 0.001), 0.0)

func _authoritative_recovery_ratio() -> float:
	var duration := maxf(float(_unit._base_form_stats.get("death_form_delay", 0.0)), 0.05)
	return clampf(1.0 - float(_unit.death_form.waiting_ticks) / ceilf(duration * 20.0), 0.0, 1.0)

func advance_health_bar(delta: float) -> void:
	if not is_instance_valid(_unit) or not _unit.death_form.waiting():
		_observed_wait_ticks = -1
		_recovery_ratio = 0.0
		return
	var target := _authoritative_recovery_ratio()
	var duration := maxf(float(_unit._base_form_stats.get("death_form_delay", 0.0)), 0.05)
	if _observed_wait_ticks < 0:
		_recovery_ratio = target
	elif _observed_wait_ticks != _unit.death_form.waiting_ticks:
		_recovery_ratio = maxf(_recovery_ratio, target)
	else:
		_recovery_ratio = minf(_recovery_ratio + maxf(delta, 0.0) / duration, minf(target + 0.05 / duration, 1.0))
	_observed_wait_ticks = _unit.death_form.waiting_ticks
