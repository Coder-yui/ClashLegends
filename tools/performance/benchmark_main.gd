extends "res://scripts/main.gd"
## 仅基准场景继承编排入口，权威算法不另写一套。
var navigation_ms: Array[float] = []
var path_ms: Array[float] = []
var navigation_calls: Array[float] = []
var _navigation_usec := 0
var _path_usec := 0
var _navigation_count := 0
var _benchmark_ids := {}
var _next_benchmark_id := 1
var tick_ms: Array[float] = []
var movement_ms: Array[float] = []
var collision_ms: Array[float] = []
var snapshot_ms: Array[float] = []
var snapshot_bytes: Array[float] = []
var particle_copy_ms: Array[float] = []
var commands: Array[Dictionary] = []
var drive_match := false
var silent := false
var command_index := 0
var max_combatants := 0

func _setup_battle_presentation() -> void:
	if "--perf-visual=off" not in OS.get_cmdline_user_args(): super._setup_battle_presentation()

func _sim_step(dt: float) -> void:
	if drive_match and _sim_tick_id % 40 == 0: _drive_cards()
	_navigation_usec = 0
	_path_usec = 0
	_navigation_count = 0
	var started := Time.get_ticks_usec()
	super._sim_step(dt)
	tick_ms.append((Time.get_ticks_usec() - started) / 1000.0)
	navigation_ms.append(_navigation_usec / 1000.0)
	path_ms.append(_path_usec / 1000.0)
	navigation_calls.append(float(_navigation_count))
	movement_ms.append(_movement.last_movement_usec / 1000.0)
	collision_ms.append(_movement.last_collision_usec / 1000.0)
	max_combatants = maxi(max_combatants, get_tree().get_nodes_in_group("combatants").size())
	started = Time.get_ticks_usec()
	var snapshot := _snapshot_system.capture()
	snapshot_ms.append((Time.get_ticks_usec() - started) / 1000.0)
	snapshot_bytes.append(float(snapshot.size()))
	started = Time.get_ticks_usec()
	_projectile_system.visible_snapshot()
	particle_copy_ms.append((Time.get_ticks_usec() - started) / 1000.0)

func _drive_cards() -> void:
	for p_team in [0, 1]:
		var hand := get_authoritative_hand(p_team)
		for offset in hand.size():
			var card: String = hand[(command_index + offset) % hand.size()]
			var pos := Vector2(140.0 if command_index % 2 == 0 else 580.0, 900.0 if p_team == 0 else 380.0)
			if play_card(p_team, card, pos, {"elixir": _elixir_for_team(p_team), "require_team_deck": true}):
				commands.append({"tick": _sim_tick_id, "team": p_team, "card": card, "position": [pos.x, pos.y]})
				break
	for id in _active_skills.keys():
		var entry: Dictionary = _active_skills[id]
		use_active_skill(id, entry.team)
	command_index += 1

## 本地基准没有 ENet 对手，但使用实际完整实体载荷测序列化/压缩，不拿空包当负载。
func authoritative_units_snapshot() -> Dictionary:
	var result := {}
	for unit in get_tree().get_nodes_in_group("combatants"):
		if not unit is Unit or unit.hp <= 0.0: continue
		var instance_id := unit.get_instance_id()
		if not _benchmark_ids.has(instance_id):
			_benchmark_ids[instance_id] = _next_benchmark_id
			_next_benchmark_id += 1
		result[_benchmark_ids[instance_id]] = unit
	return result

func is_ground_position_walkable(pos: Vector2, mover_radius: float, excluded: Node = null, allow_deploy_edge_center: bool = false, ignore_structures: bool = false) -> bool:
	var started := Time.get_ticks_usec()
	var result := super.is_ground_position_walkable(pos, mover_radius, excluded, allow_deploy_edge_center, ignore_structures)
	_navigation_usec += Time.get_ticks_usec() - started
	_navigation_count += 1
	return result

func find_ground_path(from: Vector2, goal: Vector2, target: Node2D, mover_radius: float = ArenaRules.NAV_CLEARANCE) -> PackedVector2Array:
	var started := Time.get_ticks_usec()
	var result := super.find_ground_path(from, goal, target, mover_radius)
	_path_usec += Time.get_ticks_usec() - started
	return result

func _present_match_announcement(cue: String) -> void:
	if not silent: super._present_match_announcement(cue)

func _end_game(winner_team: int, reason: String) -> void:
	var audio = _audio_manager
	if silent: _audio_manager = null
	super._end_game(winner_team, reason)
	_audio_manager = audio
