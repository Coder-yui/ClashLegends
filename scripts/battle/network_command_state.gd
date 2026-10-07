class_name NetworkCommandState
extends RefCounted
## 服务器已接受命令的公开排程；本地只保存准备信息，不按它生成单位或施法。
const MAX_PENDING := 256
var _next_id := 1
var _last_received := 0
var _pending: Dictionary = {}

func create(kind: String, team: int, card_id: String, ability_id: int, pos: Vector2, input_tick: int, execute_tick: int) -> Dictionary:
	var command := {"id": _next_id, "kind": kind, "team": team, "card_id": card_id,
		"ability_id": ability_id, "pos": pos, "input_tick": input_tick, "execute_tick": execute_tick}
	_next_id += 1
	command.make_read_only()
	_pending[command.id] = command
	return command.duplicate(true)

func receive(command: Dictionary) -> bool:
	if not valid(command) or int(command.id) <= _last_received or _pending.size() >= MAX_PENDING: return false
	_last_received = int(command.id)
	var owned := command.duplicate(true)
	owned.make_read_only()
	_pending[command.id] = owned
	return true

static func valid(command: Dictionary) -> bool:
	for key in ["id", "team", "ability_id", "input_tick", "execute_tick"]:
		if not command.get(key) is int: return false
	return command.id > 0 and command.team in [0, 1] and command.get("kind") in ["card", "skill"] \
		and command.get("card_id") is String and CardDB.has_card(command.card_id) \
		and command.get("pos") is Vector2 and command.pos.is_finite() \
		and command.input_tick >= 0 and command.execute_tick == command.input_tick + CommandSchedule.BUFFER_TICKS \
		and (command.kind != "skill" or command.ability_id >= 0)

func finish(id: int) -> Dictionary:
	var command: Dictionary = _pending.get(id, {})
	_pending.erase(id)
	return command

func inspect() -> Array:
	return _pending.values().duplicate(true)

func visit(visitor: Callable) -> void:
	for command in _pending.values(): visitor.call(command)

func has_skill(ability_id: int) -> bool:
	for command in _pending.values():
		if command.kind == "skill" and int(command.ability_id) == ability_id: return true
	return false

func clear() -> void:
	_pending.clear()
	_last_received = 0
	_next_id = 1
