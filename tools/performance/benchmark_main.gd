extends "res://scripts/main.gd"
## 仅基准场景继承编排入口，权威算法不另写一套。
var navigation_ms: Array[float] = []
var path_ms: Array[float] = []
var navigation_calls: Array[float] = []
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

class BenchmarkWorld extends "res://scripts/battle/battle_world.gd":
	var _navigation_usec := 0
	var _path_usec := 0
	var _navigation_count := 0
	## 本地基准显式分配实体身份；快照仍要求真实出生登记。
	func register_authority_unit(unit: Unit, _networked: bool) -> void:
		super.register_authority_unit(unit, true)

	func authoritative_units_snapshot() -> Dictionary:
		var result := {}
		for unit in combatants():
			if unit is Unit and unit.hp > 0.0:
				assert(unit.net_id >= 0, "基准实体未分配身份")
				result[unit.net_id] = unit
		return result

	func is_ground_position_walkable(pos: Vector2, mover_radius: float, excluded: Node = null, allow_deploy_edge_center: bool = false, ignore_structures: bool = false) -> bool:
		var started := Time.get_ticks_usec()
		var result := super.is_ground_position_walkable(pos, mover_radius, excluded, allow_deploy_edge_center, ignore_structures)
		_navigation_usec += Time.get_ticks_usec() - started
		_navigation_count += 1
		return result

	func find_ground_path(from: Vector2, goal: Vector2, target: Node2D, mover_radius: float = ArenaRules.NAV_CLEARANCE, crosses_river: bool = false) -> PackedVector2Array:
		var started := Time.get_ticks_usec()
		var result := super.find_ground_path(from, goal, target, mover_radius, crosses_river)
		_path_usec += Time.get_ticks_usec() - started
		return result

func _init() -> void:
	world = BenchmarkWorld.new(self)

func _ready() -> void:
	super._ready()
	runtime._simulation_clock.step = _sim_step

func _setup_battle_presentation() -> void:
	# 固定双方卡组样本只用于基准；在任何对局资源收集前替换随机对手。
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--perf-remote-deck="):
			runtime._remote_deck = Array(argument.trim_prefix("--perf-remote-deck=").split(","))
			runtime._remote_active_skill_choices.clear()
	if "--perf-visual=off" not in OS.get_cmdline_user_args(): super._setup_battle_presentation()

func _sim_step(dt: float) -> void:
	if drive_match and runtime._sim_tick_id % 40 == 0: _drive_cards()
	world._navigation_usec = 0
	world._path_usec = 0
	world._navigation_count = 0
	var started := Time.get_ticks_usec()
	super._sim_step(dt)
	tick_ms.append((Time.get_ticks_usec() - started) / 1000.0)
	navigation_ms.append(world._navigation_usec / 1000.0)
	path_ms.append(world._path_usec / 1000.0)
	navigation_calls.append(float(world._navigation_count))
	movement_ms.append(_movement.last_movement_usec / 1000.0)
	collision_ms.append(_movement.last_collision_usec / 1000.0)
	max_combatants = maxi(max_combatants, get_tree().get_nodes_in_group("combatants").size())

## 在主采样循环结束后测最终状态；诊断工作不得污染 frame/main_process 分布。
func sample_final_state_diagnostics(samples: int = 20) -> void:
	for sample in samples:
		_sample_state_diagnostics()

func _sample_state_diagnostics() -> void:
	var started := Time.get_ticks_usec()
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
			if play_card(p_team, card, pos, {"elixir": runtime.account(p_team), "require_team_deck": true}):
				commands.append({"tick": runtime._sim_tick_id, "team": p_team, "card": card, "position": [pos.x, pos.y]})
				break
	for id in runtime._active_skills.ids():
		var entry: Dictionary = runtime._active_skills.entry(int(id))
		use_active_skill(id, entry.team)
	command_index += 1

func _present_match_announcement(cue: String) -> void:
	if not silent: super._present_match_announcement(cue)

func _end_game(winner_team: int, reason: String) -> void:
	var audio = _audio_manager
	if silent: _audio_manager = null
	super._end_game(winner_team, reason)
	_audio_manager = audio

## 本地诊断同样显式登记出生，不要求生产编码器替工具编造旧描述。
func _spawn_unit(request: UnitSpawnRequest) -> Unit:
	var unit := super._spawn_unit(request)
	if is_instance_valid(unit) and runtime.mode != "server":
		_snapshot_system.register_spawn([unit.card_id, unit.team, unit.position, unit.net_id, request.deploy_time_override, unit.active_ability_id, unit.active_ability_slot, request.pre_deploy_id, unit.deployment_group_id, String(unit.visual_spawn_transition), unit.death_replacement_charges, unit.built_on_tower_ruin, unit.active_skill_card_id, unit.summon_visual_origin])
	return unit
