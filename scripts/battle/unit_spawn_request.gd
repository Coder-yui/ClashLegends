class_name UnitSpawnRequest
extends RefCounted
## 正式生成入口的局内请求。网络载荷仍由 Main 按既有协议显式编码。
var team: int
var card_id: String
var position: Vector2
var deploy_time_override: float = -1.0
var active_slot: int = -1
var pre_deploy_id: int = -1
var deployment_group_id: int = -1
var visual_transition: String = ""
var death_replacement_charges_override: int = -1
var built_on_tower_ruin: bool = false
var active_skill_card_id_override: String = ""
var position_resolved := false

func _init(p_team: int, p_card_id: String, p_position: Vector2, options: Dictionary = {}) -> void:
	team = p_team
	card_id = p_card_id
	position = p_position
	deploy_time_override = float(options.get("deploy_time_override", -1.0))
	active_slot = int(options.get("active_slot", -1))
	pre_deploy_id = int(options.get("pre_deploy_id", -1))
	deployment_group_id = int(options.get("deployment_group_id", -1))
	visual_transition = String(options.get("visual_transition", ""))
	death_replacement_charges_override = int(options.get("death_replacement_charges_override", -1))
	built_on_tower_ruin = bool(options.get("built_on_tower_ruin", false))
	active_skill_card_id_override = String(options.get("active_skill_card_id_override", ""))
	position_resolved = bool(options.get("position_resolved", false))
