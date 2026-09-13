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
	get: return is_instance_valid(_unit) and _unit.is_frozen()
var stunned: bool:
	get: return is_instance_valid(_unit) and _unit.is_stunned()
var dead: bool:
	get: return not is_instance_valid(_unit) or _unit.hp <= 0.0
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

var shroud_active: bool:
	get: return _unit.net_shroud_active if _unit._in_client_mode() else _unit._shroud_active
