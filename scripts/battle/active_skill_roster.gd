class_name ActiveSkillRoster
extends RefCounted
## 技能资格、槽位、次数和冷却的唯一所有者；不接触 UI、RPC 或付款。
var _entries: Dictionary = {}

func register(unit: Unit, card_id: String, p_team: int, carried_skill: Dictionary) -> int:
	if not carried_skill.is_read_only():
		carried_skill = carried_skill.duplicate(true)
		_freeze_definition(carried_skill)
	var ability_id := unit.active_ability_id
	var active_slot := unit.active_ability_slot
	var max_uses := maxi(int(carried_skill.get("max_uses", 1)), 1)
	# 每个主动槽始终只控制最近部署的实例。新实例落地时，旧实例的未用资格立即作废。
	var replaced_id := -1
	for existing_id in _entries:
		var existing: Dictionary = _entries[existing_id]
		if int(existing.team) == p_team and int(existing.slot) == active_slot:
			replaced_id = int(existing_id)
			break
	if replaced_id >= 0:
		var replaced: Dictionary = _entries[replaced_id]
		var replaced_unit = replaced.get("unit")
		if is_instance_valid(replaced_unit) and replaced_unit is Unit:
			var valid_replaced_unit := replaced_unit as Unit
			valid_replaced_unit.active_ability_id = -1
			valid_replaced_unit.active_ability_slot = -1
			valid_replaced_unit.clear_carried_active_skill_resource()
		_entries.erase(replaced_id)
	_entries[ability_id] = {
		"unit": unit,
		"deployment_group_id": unit.deployment_group_id,
		"card_id": card_id,
		"team": p_team,
		"slot": active_slot,
		"skill": carried_skill,
		"max_uses": max_uses,
		"uses_remaining": max_uses,
		"cooldown_left": 0.0,
		"free_recast": false,
	}
	return replaced_id

func ids() -> Array:
	return _entries.keys()

func has(id: int) -> bool:
	return _entries.has(id)

func entry(id: int) -> Dictionary:
	var result: Dictionary = _entries.get(id, {}).duplicate()
	result.make_read_only()
	return result

func remove(id: int) -> void:
	_entries.erase(id)

func clear() -> void:
	_entries.clear()

func tick(dt: float) -> void:
	for entry in _entries.values():
		entry.cooldown_left = maxf(float(entry.get("cooldown_left", 0.0)) - dt, 0.0)

func consume(id: int) -> void:
	var entry: Dictionary = _entries[id]
	if bool(entry.get("free_recast", false)):
		entry.free_recast = false
		return
	entry.uses_remaining = maxi(int(entry.get("uses_remaining", entry.get("max_uses", 1))) - 1, 0)
	entry.cooldown_left = maxf(float(entry.skill.get("cooldown", 0.0)), 0.0)

func grant_recast(id: int) -> void:
	if _entries.has(id) and String(_entries[id].skill.get("kind", "")) == "bleeding_execute":
		_entries[id].free_recast = true

func cost(id: int) -> float:
	if not _entries.has(id): return 0.0
	return 0.0 if bool(_entries[id].get("free_recast", false)) else maxf(float(_entries[id].skill.get("cost", 0.0)), 0.0)

func replace_replica(id: int, uses: int, cooldown: float, free_recast: bool = false) -> void:
	if not _entries.has(id): return
	_entries[id].uses_remaining = maxi(uses, 0)
	_entries[id].cooldown_left = maxf(cooldown, 0.0)
	_entries[id].free_recast = free_recast

func qualified(id: int, expected_team: int, card_allowed: Callable) -> bool:
	if not _entries.has(id): return false
	var entry: Dictionary = _entries[id]
	var unit = entry.get("unit")
	if not is_instance_valid(unit) or not unit is Unit or unit.hp <= 0.0: return false
	if unit.death_form.used: return false
	if expected_team >= 0 and int(entry.team) != expected_team: return false
	if String(entry.skill.get("kind", "")) == "bleeding_execute" and unit.is_empowered_attack_ready_visual(): return false
	if not bool(entry.get("free_recast", false)):
		if int(entry.get("uses_remaining", entry.get("max_uses", 1))) <= 0: return false
		if float(entry.get("cooldown_left", 0.0)) > 0.001: return false
	return card_allowed.call(int(entry.team), String(entry.card_id)) and unit.is_deployed()

func transfer(id: int, members: Callable) -> Unit:
	if not _entries.has(id): return null
	var entry: Dictionary = _entries[id]
	var skill: Dictionary = entry.get("skill", {})
	if StringName(skill.get("target_scope", "self")) != &"deployment_group": return null
	for replacement in members.call(int(entry.get("deployment_group_id", -1)), int(entry.team)):
		replacement.active_ability_id = id
		replacement.active_ability_slot = int(entry.slot)
		replacement.active_skill_card_id = String(entry.get("card_id", replacement.card_id))
		replacement.configure_carried_active_skill(skill)
		entry.unit = replacement
		return replacement
	return null

static func _freeze_definition(value: Variant) -> void:
	if value is Dictionary or value is Array:
		for child in value.values() if value is Dictionary else value:
			_freeze_definition(child)
		value.make_read_only()
