class_name NetworkSnapshotSystem
extends RefCounted
## 20Hz 单位/塔/弹体快照的序列化与客户端应用。RPC 端点仍保留在 Main。

const SNAPSHOT_PROTOCOL_VERSION := MatchSession.PROTOCOL_VERSION
const S_VERSION := 0
const S_SERVER_TICK := 1
const S_UNITS := 2
const S_PROJECTILES := 3
const S_TOWERS := 4
const S_CLIENT_ELIXIR := 5
const S_MATCH_TIMER := 6
const S_OVERTIME := 7
const S_SESSION := 8
const S_LIFECYCLE_REVISION := 9
const SNAPSHOT_PACKET_SIZE := 10

## 当前版本使用固定长度载荷；协议变更必须同步提高 SNAPSHOT_PROTOCOL_VERSION。
const U_ID := 0
const U_X := 1
const U_Y := 2
const U_HP := 3
const U_FROZEN := 4
const U_VISUAL_STATE := 5
const U_ATTACK_SERIAL := 6
const U_SHROUD := 7
const U_HAS_CONTINUOUS_TARGET := 8
const U_CONTINUOUS_X := 9
const U_CONTINUOUS_Y := 10
const U_SLOW := 11
const U_FORM := 12
const U_STUN := 13
const U_ACTION_SERIAL := 14
const U_ACTION_NAME := 15
const U_FACING_DIRECTION_X := 16
const U_FACING_DIRECTION_Y := 17
const U_ATTACKING_STRUCTURE := 18
const U_FORM_CHANGE_SERIAL := 19
const U_ACTION_DURATION := 20
const U_ACTION_TIME_LEFT := 21
const U_LOCOMOTION := 22
const U_EMPOWERED_READY := 23
const U_EMPOWERED_ATTACK_SERIAL := 24
const U_SKILL_RESOURCE_RATIO := 25
const U_SKILL_RESOURCE_ENABLED := 26
const U_ACTIVE_SPEED_MULTIPLIER := 27
const U_ACTIVE_ATTACK_SPEED_MULTIPLIER := 28
const U_ACTIVE_SKILL_USES_REMAINING := 29
const U_ACTIVE_SKILL_COOLDOWN := 30
const U_SHIELD_RATIO := 31
const U_SHIELD_CAPACITY_RATIO := 32
const U_ACTIVE_BUFF_ACTIVE := 33
const U_ATTACK_FIRST_STRIKE := 34
const U_ATTACK_ELAPSED := 35
const U_MOVEMENT_RATE := 36
const U_ACTION_PERMISSIONS := 37
const U_SPAWN := 38
const U_DEPLOY_LEFT := 39
const UNIT_PAYLOAD_SIZE := 40

const P_ID := 0
const P_X := 1
const P_Y := 2
const P_COLOR := 3
const P_RADIUS := 4
const P_VISUAL := 5
const P_DIRECTION_X := 6
const P_DIRECTION_Y := 7
const P_VISUAL_HEIGHT := 8
const P_VISUAL_OFFSET_X := 9
const P_VISUAL_OFFSET_Y := 10
const P_VISUAL_SCALE := 11
const P_FIRST_STRIKE := 12
const PROJECTILE_PAYLOAD_SIZE := 13

const T_HP := 0
const T_ACTIVATED := 1
const T_STUNNED := 2
const T_SHIELD_RATIO := 3
const T_SHIELD_CAPACITY_RATIO := 4
const TOWER_PAYLOAD_SIZE := 5

var terminal_applied := false
var lifecycle := NetworkEntityLifecycle.new()
var _controller: Node2D
var _projectile_system: ProjectileSystem


func _init(controller: Node2D, projectile_system: ProjectileSystem) -> void:
	_controller = controller
	_projectile_system = projectile_system


func reset_session(session_id: String) -> void:
	for id in _controller.client_unit_ids():
		_controller.remove_network_unit(id, false)
	_projectile_system.clear_client()
	terminal_applied = false
	lifecycle.reset(session_id)
	_controller.reset_network_clock()

func register_spawn(args: Array) -> Dictionary:
	lifecycle.host_spawn(int(args[3]), _controller.get_authoritative_server_tick(), args)
	return lifecycle.spawns[int(args[3])]

func receive_spawn(session_id: String, descriptor: Dictionary, snapshot_payload: Array = []) -> void:
	if _controller.mode != "client" or terminal_applied or _controller.game_over or not lifecycle.accepts_session(session_id) or not _valid_spawn(descriptor):
		return
	var args: Array = descriptor.args.duplicate(true)
	var id := int(args[3])
	var birth := int(descriptor.birth_tick)
	var birth_revision := int(descriptor.birth_revision)
	if not lifecycle.accepts_spawn(id, birth_revision):
		return
	var existing = _controller.find_client_unit(id)
	if is_instance_valid(existing):
		return
	lifecycle.register_spawn(id, birth, birth_revision, args)
	if not snapshot_payload.is_empty():
		args[2] = Vector2(snapshot_payload[U_X], snapshot_payload[U_Y])
		args[4] = float(snapshot_payload[U_DEPLOY_LEFT])
	_controller.create_network_unit.callv(args)

func receive_death(session_id: String, id: int, tick: int, play_death_visual: bool) -> void:
	if _controller.mode != "client" or terminal_applied or _controller.game_over or not lifecycle.accepts_session(session_id) or tick < 0:
		return
	lifecycle.mark_destroyed(id, tick)
	_controller.remove_network_unit(id, play_death_visual)

func _valid_spawn(descriptor: Dictionary) -> bool:
	if not descriptor.get("birth_tick") is int or int(descriptor.birth_tick) < 0:
		return false
	if not descriptor.get("birth_revision") is int or int(descriptor.birth_revision) < 0:
		return false
	var args = descriptor.get("args")
	if not args is Array or args.size() != 12:
		return false
	if not args[0] is String or CardDB.get_unit_stats(args[0]).is_empty():
		return false
	for index in [1, 3, 5, 6, 7, 8, 10]:
		if not args[index] is int:
			return false
	if args[1] not in [0, 1] or int(args[3]) < 0 or not args[2] is Vector2 or not args[2].is_finite():
		return false
	return typeof(args[4]) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(args[4])) and args[9] is String and args[11] is bool


func apply(snapshot_bytes: PackedByteArray, terminal: bool = false, expected_tick: int = -1) -> bool:
	if _controller.mode != "client" or terminal_applied or _controller.game_over:
		return false
	var raw_bytes := snapshot_bytes.decompress_dynamic(1024 * 1024, FileAccess.COMPRESSION_DEFLATE)
	if raw_bytes.is_empty():
		return false
	var decoded = bytes_to_var(raw_bytes)
	if not decoded is Array or decoded.size() != SNAPSHOT_PACKET_SIZE:
		return false
	if not decoded[S_VERSION] is int or int(decoded[S_VERSION]) != SNAPSHOT_PROTOCOL_VERSION:
		return false
	if not decoded[S_SESSION] is String or not lifecycle.accepts_session(decoded[S_SESSION]):
		return false
	if not decoded[S_SERVER_TICK] is int or not decoded[S_LIFECYCLE_REVISION] is int or int(decoded[S_LIFECYCLE_REVISION]) < 0:
		return false
	if not decoded[S_UNITS] is Array or not decoded[S_PROJECTILES] is Array or not decoded[S_TOWERS] is Array:
		return false
	if terminal and int(decoded[S_SERVER_TICK]) != expected_tick:
		return false
	var units_data: Array = decoded[S_UNITS]
	var projectiles_data: Array = decoded[S_PROJECTILES]
	var towers_data: Array = decoded[S_TOWERS]
	if not _payloads_have_size(units_data, UNIT_PAYLOAD_SIZE):
		return false
	if not _payloads_have_size(projectiles_data, PROJECTILE_PAYLOAD_SIZE):
		return false
	if not _payloads_have_size(towers_data, TOWER_PAYLOAD_SIZE):
		return false
	var ids := {}
	for payload: Array in units_data:
		if not payload[U_ID] is int or ids.has(payload[U_ID]) or not payload[U_SPAWN] is Dictionary or not _valid_spawn(payload[U_SPAWN]):
			return false
		if int(payload[U_SPAWN].args[3]) != int(payload[U_ID]) or int(payload[U_SPAWN].birth_tick) > int(decoded[S_SERVER_TICK]) or int(payload[U_SPAWN].birth_revision) > int(decoded[S_LIFECYCLE_REVISION]):
			return false
		ids[payload[U_ID]] = true
	if not terminal and not lifecycle.snapshot_is_new(int(decoded[S_SERVER_TICK]), int(decoded[S_LIFECYCLE_REVISION])):
		return false
	if terminal and (int(decoded[S_SERVER_TICK]) < lifecycle.snapshot_tick or int(decoded[S_LIFECYCLE_REVISION]) < lifecycle.snapshot_revision):
		return false
	# 可靠 RPC 仍可能在不同发送周期交错到达；较早 tick 不能回拨客户端命令时钟。
	if not _controller._accept_authoritative_server_tick(int(decoded[S_SERVER_TICK])):
		return false

	lifecycle.accept_snapshot(int(decoded[S_SERVER_TICK]), int(decoded[S_LIFECYCLE_REVISION]), ids)
	_apply_units(units_data)
	_apply_projectiles(projectiles_data)
	_apply_towers(towers_data)
	_controller.apply_network_match_snapshot(float(decoded[S_CLIENT_ELIXIR]), float(decoded[S_MATCH_TIMER]), bool(decoded[S_OVERTIME]))

	terminal_applied = terminal
	return true

func _payloads_have_size(payloads: Array, expected_size: int) -> bool:
	for payload in payloads:
		if not payload is Array or payload.size() != expected_size:
			return false
	return true


func _apply_units(units_data: Array) -> void:
	var seen := {}
	for d: Array in units_data:
		seen[d[U_ID]] = true
		if lifecycle.destroyed.has(d[U_ID]):
			continue
		var u = _controller.find_client_unit(d[U_ID])
		if not is_instance_valid(u):
			receive_spawn(lifecycle.session_id, d[U_SPAWN], d)
			u = _controller.find_client_unit(d[U_ID])
		if not is_instance_valid(u):
			continue
		u._deploy_timer = maxf(float(d[U_DEPLOY_LEFT]), 0.0)
		_controller.sync_network_unit_skill(u, int(d[U_SPAWN].args[5]), int(d[U_SPAWN].args[6]))
		u.net_target_pos = Vector2(d[U_X], d[U_Y])
		u.sync_network_form(int(d[U_FORM]), int(d[U_FORM_CHANGE_SERIAL]))
		u.hp = BattleNumbers.quantity(float(d[U_HP]))
		u.net_visual_state = int(d[U_VISUAL_STATE])
		u.net_attack_visual_serial = int(d[U_ATTACK_SERIAL])
		u.net_attack_visual_first_strike = int(d[U_ATTACK_FIRST_STRIKE]) == 1
		u.net_shroud_active = int(d[U_SHROUD]) == 1
		u.net_has_continuous_target = int(d[U_HAS_CONTINUOUS_TARGET]) == 1
		u.net_continuous_target_pos = Vector2(d[U_CONTINUOUS_X], d[U_CONTINUOUS_Y])
		if _controller._auto_test and not _controller._auto_continuous_target_seen and u.net_has_continuous_target:
			_controller._auto_continuous_target_seen = true
			print("[测试] 客户端已收到持续吐息目标端点")
		u.net_slow_active = int(d[U_SLOW]) == 1
		u.net_stun_active = int(d[U_STUN]) == 1
		u.control.apply_replica_flags(int(d[U_FROZEN]) == 1, u.net_stun_active)
		var action_serial := int(d[U_ACTION_SERIAL])
		if action_serial >= u.net_visual_action_serial:
			u.net_visual_action_serial = action_serial
			u.net_visual_action_name = StringName(d[U_ACTION_NAME])
		u.net_facing_direction = Vector2(d[U_FACING_DIRECTION_X], d[U_FACING_DIRECTION_Y])
		u.net_attacking_structure = int(d[U_ATTACKING_STRUCTURE]) == 1
		# 时长和剩余时间让晚到客户端从权威进度开始播放。
		u.net_visual_action_duration = maxf(float(d[U_ACTION_DURATION]), 0.0)
		u.net_visual_action_time_left = clampf(float(d[U_ACTION_TIME_LEFT]), 0.0, u.net_visual_action_duration)
		u.net_locomotion_state = int(d[U_LOCOMOTION])
		u.net_empowered_attack_ready = int(d[U_EMPOWERED_READY]) == 1
		u.net_empowered_attack_visual_serial = int(d[U_EMPOWERED_ATTACK_SERIAL])
		u.net_skill_resource_ratio = clampf(float(d[U_SKILL_RESOURCE_RATIO]), 0.0, 1.0)
		u.net_skill_resource_enabled = int(d[U_SKILL_RESOURCE_ENABLED]) == 1
		u.net_active_speed_multiplier = maxf(float(d[U_ACTIVE_SPEED_MULTIPLIER]), 1.0)
		u.net_active_attack_speed_multiplier = maxf(float(d[U_ACTIVE_ATTACK_SPEED_MULTIPLIER]), 0.01)
		u.net_attack_elapsed = maxf(float(d[U_ATTACK_ELAPSED]), 0.0)
		u.net_action_permissions = int(d[U_ACTION_PERMISSIONS])
		u.net_movement_rate = maxf(float(d[U_MOVEMENT_RATE]), 0.01)
		u.net_active_buff_active = int(d[U_ACTIVE_BUFF_ACTIVE]) == 1
		_controller.apply_network_skill_state(u, int(d[U_ACTIVE_SKILL_USES_REMAINING]), float(d[U_ACTIVE_SKILL_COOLDOWN]))
		u.net_shield_ratio = clampf(float(d[U_SHIELD_RATIO]), 0.0, 1.0)
		u.net_shield_capacity_ratio = maxf(float(d[U_SHIELD_CAPACITY_RATIO]), 0.0)
		if (
			_controller._auto_test and not _controller._auto_gnar_form_seen and u.card_id == "gnar"
			and u.form_index == 1 and u.net_visual_action_name == &"transform_active"
			and u.net_facing_direction.length_squared() > 0.001
		):
			_controller._auto_gnar_form_seen = true
			print("[测试] 客户端已收到纳尔大形态、主动变形动作与完整朝向快照")
		if (
			_controller._auto_test and not _controller._auto_gnar_revert_seen and u.card_id == "gnar"
			and u.form_index == 0 and u.net_form_change_serial >= 2
			and u.net_visual_action_name == &"revert"
		):
			_controller._auto_gnar_revert_seen = true
			print("[测试] 客户端已收到纳尔回到小形态的递增序号与变小动作快照")
		u.queue_redraw()

	var gone := []
	for id in _controller.client_unit_ids():
		if not seen.has(id) and lifecycle.snapshot_can_remove(id):
			gone.append(id)
	for id in gone:
		lifecycle.mark_destroyed(id, lifecycle.snapshot_tick)
		_controller.remove_network_unit(id, true)


func _apply_projectiles(projectiles_data: Array) -> void:
	var targets := {}
	if _controller._auto_test and not _controller._auto_projectile_seen and not projectiles_data.is_empty():
		_controller._auto_projectile_seen = true
		print("[测试] 客户端已收到弹道快照")
	for d: Array in projectiles_data:
		targets[d[P_ID]] = {
			"pos": Vector2(d[P_X], d[P_Y]),
			"target_pos": Vector2(d[P_X], d[P_Y]),
			"color": d[P_COLOR], "radius": d[P_RADIUS], "visual": StringName(d[P_VISUAL]),
			"direction": Vector2(d[P_DIRECTION_X], d[P_DIRECTION_Y]),
			"visual_height": float(d[P_VISUAL_HEIGHT]),
			"visual_offset": Vector2(d[P_VISUAL_OFFSET_X], d[P_VISUAL_OFFSET_Y]),
			"target_visual_offset": Vector2(d[P_VISUAL_OFFSET_X], d[P_VISUAL_OFFSET_Y]),
			"visual_scale": float(d[P_VISUAL_SCALE]), "first_strike": int(d[P_FIRST_STRIKE]) == 1,
		}
	_projectile_system.apply_client_targets(targets)

func _apply_towers(towers_data: Array) -> void:
	for i in range(mini(towers_data.size(), _controller._towers.size())):
		var tower_data: Array = towers_data[i]
		_controller._towers[i].apply_network_state(
			float(tower_data[T_HP]), int(tower_data[T_ACTIVATED]) == 1,
			int(tower_data[T_STUNNED]) == 1, float(tower_data[T_SHIELD_RATIO]),
			float(tower_data[T_SHIELD_CAPACITY_RATIO]))


func send() -> void:
	_controller._rpc_snapshot.rpc_id(_controller.network_opponent_id(), capture())

func capture() -> PackedByteArray:
	var units_data := []
	var units: Dictionary = _controller.authoritative_units_snapshot()
	for id in units:
		# 非类型化读取：单位可能已 queue_free，类型化赋值会先于有效性检查报错。
		var u = units.get(id)
		if u == null or not is_instance_valid(u) or u.hp <= 0.0:
			continue
		units_data.append(_unit_snapshot_payload(
			id,
			u,
			u.has_continuous_visual_target(),
			u.get_continuous_visual_target_position(),
			u.get_visual_facing_direction(),
		))

	var projectiles_data := []
	var authoritative_projectiles := _projectile_system.authoritative_snapshot()
	for id in authoritative_projectiles:
		var projectile: Dictionary = authoritative_projectiles[id]
		projectiles_data.append(_projectile_snapshot_payload(id, projectile))

	var towers_data := []
	for tower in _controller._towers:
		towers_data.append(_tower_snapshot_payload(tower))
	var match_state: Dictionary = _controller.network_match_snapshot()
	var snapshot_bytes := var_to_bytes(_snapshot_packet(
		units_data,
		projectiles_data,
		towers_data,
		match_state.elixir,
		match_state.time_left,
		match_state.overtime,
	)).compress(FileAccess.COMPRESSION_DEFLATE)
	return snapshot_bytes


func _snapshot_packet(units_data: Array, projectiles_data: Array, towers_data: Array, client_elixir: float, match_timer: float, overtime: bool) -> Array:
	return [
		SNAPSHOT_PROTOCOL_VERSION,
		_controller._sim_tick_id,
		units_data,
		projectiles_data,
		towers_data,
		client_elixir,
		match_timer,
		overtime,
		lifecycle.session_id,
		lifecycle.revision,
	]


func _tower_snapshot_payload(tower: Tower) -> Array:
	return [
		tower.hp,
		1 if tower.activated else 0,
		1 if tower.control.stun_timer > 0.0 else 0,
		tower.get_shield_ratio(),
		tower.get_shield_capacity_ratio(),
	]


## 弹体载荷集中构造，确保新增纯表现字段在主机和客户端使用同一固定顺序。
func _projectile_snapshot_payload(id: int, projectile: Dictionary) -> Array:
	var visual_offset: Vector2 = projectile.get("visual_offset", Vector2.ZERO)
	var direction: Vector2 = projectile.get("direction", Vector2.UP)
	var position: Vector2 = projectile.get("pos", Vector2.ZERO)
	return [
		id, position.x, position.y, projectile.get("color", Color.WHITE), projectile.get("radius", 4.0),
		String(projectile.get("visual", &"orb")), direction.x, direction.y,
		projectile.get("visual_height", 0.0), visual_offset.x, visual_offset.y,
		projectile.get("visual_scale", 1.0), 1 if bool(projectile.get("effects", {}).get("first_strike", false)) else 0,
	]


## 单位载荷集中构造；读写两端共用当前固定字段表。
func _unit_snapshot_payload(id: int, u: Unit, has_continuous_target: bool = false, continuous_target_pos: Vector2 = Vector2.ZERO, facing_direction: Vector2 = Vector2.ZERO) -> Array:
	if facing_direction.is_zero_approx():
		facing_direction = u.get_visual_facing_direction()
	var active_skill_state: Dictionary = _controller.get_active_skill_snapshot(u.active_ability_id)
	var descriptor: Dictionary = lifecycle.spawns.get(id, {"birth_tick": 0, "birth_revision": 0, "args": [u.card_id, u.team, u.global_position, id, u.deploy_time, u.active_ability_id, u.active_ability_slot, -1, u.deployment_group_id, String(u.visual_spawn_transition), u.death_replacement_charges, u.built_on_tower_ruin]}).duplicate(true)
	# 主动资格会转交/被新部署替换；重建必须使用当前资格而非原始出生资格。
	descriptor.args[5] = u.active_ability_id
	descriptor.args[6] = u.active_ability_slot
	descriptor.args[10] = u.death_replacement_charges
	return [
		id, u.global_position.x, u.global_position.y, u.hp,
		1 if u.control.frozen_timer > 0.0 else 0,
		u.get_visual_state_code(), u.get_attack_visual_serial(),
		1 if u._shroud_active else 0,
		1 if has_continuous_target else 0, continuous_target_pos.x, continuous_target_pos.y,
		1 if u.control.slow_timer > 0.0 else 0,
		u.form_index, 1 if u.control.stun_timer > 0.0 else 0,
		u.get_visual_action_serial(), String(u.get_visual_action_name()),
		facing_direction.x, facing_direction.y,
		1 if u.is_attacking_structure_visual() else 0,
		u.form_change_serial,
		u.get_visual_action_duration(), u.get_visual_action_time_left(),
		u.get_locomotion_visual_state_code(),
		1 if u.is_empowered_attack_ready_visual() else 0, u.get_empowered_attack_visual_serial(),
		u.get_skill_resource_ratio(),
		1 if u.skill_resource_enabled else 0, u.active_speed_multiplier, u.get_active_attack_speed_multiplier_visual(),
		active_skill_state.get("uses_remaining", 0), active_skill_state.get("cooldown_left", 0.0),
		u.get_shield_ratio(),
		u.get_shield_capacity_ratio(),
		1 if u.active_buff_timer > 0.0 else 0,
		1 if u.is_attack_visual_first_strike() else 0,
		u.get_attack_elapsed_visual(), u.get_effective_movement_rate_visual(), u.get_action_permissions_visual(),
		descriptor,
		u._deploy_timer,
	]
