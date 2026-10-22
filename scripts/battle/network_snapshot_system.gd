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
const S_CARD_GROWTH := 10
const SNAPSHOT_PACKET_SIZE := 11
const MAX_DECODED_BYTES := 1024 * 1024

## 只由完整静态校验后的解码入口创建；队列共享递归只读内容，不复制世界。
class DecodedSnapshot extends RefCounted:
	var _packet: Array
	var _unit_ids: Dictionary
	var _raw_bytes_size: int
	var packet: Array:
		get: return _packet
	var unit_ids: Dictionary:
		get: return _unit_ids
	var raw_bytes_size: int:
		get: return _raw_bytes_size
	func _init(value: Array, ids: Dictionary, byte_count: int) -> void:
		_packet = value
		_unit_ids = ids
		_raw_bytes_size = byte_count

## 当前版本使用固定长度载荷；协议变更必须同步提高 SNAPSHOT_PROTOCOL_VERSION。
const U_ID := 0
const U_X := 1
const U_Y := 2
const U_HP := 3
const U_FROZEN := 4
const U_VISUAL_STATE := 5
const U_ATTACK_SERIAL := 6
const U_HAS_CONTINUOUS_TARGET := 7
const U_CONTINUOUS_X := 8
const U_CONTINUOUS_Y := 9
const U_SLOW := 10
const U_FORM := 11
const U_STUN := 12
const U_ACTION_SERIAL := 13
const U_ACTION_NAME := 14
const U_FACING_DIRECTION_X := 15
const U_FACING_DIRECTION_Y := 16
const U_ATTACKING_STRUCTURE := 17
const U_FORM_CHANGE_SERIAL := 18
const U_ACTION_DURATION := 19
const U_ACTION_TIME_LEFT := 20
const U_LOCOMOTION := 21
const U_EMPOWERED_READY := 22
const U_EMPOWERED_ATTACK_SERIAL := 23
const U_SKILL_RESOURCE_RATIO := 24
const U_SKILL_RESOURCE_ENABLED := 25
const U_ACTIVE_SPEED_MULTIPLIER := 26
const U_ACTIVE_ATTACK_SPEED_MULTIPLIER := 27
const U_ACTIVE_SKILL_USES_REMAINING := 28
const U_ACTIVE_SKILL_COOLDOWN := 29
const U_SHIELD_RATIO := 30
const U_SHIELD_CAPACITY_RATIO := 31
const U_ACTIVE_BUFF_ACTIVE := 32
const U_ATTACK_FIRST_STRIKE := 33
const U_ATTACK_ELAPSED := 34
const U_MOVEMENT_RATE := 35
const U_ACTION_PERMISSIONS := 36
const U_SPAWN := 37
const U_DEPLOY_LEFT := 38
const U_CANCELLATION := 39
const U_TARGET_PROTECTION := 40
const U_DEATH_FORM := 41
const U_EXPLOSIVE_SHIELD := 42
const U_FREE_RECAST := 43
const U_BLEED_STACKS := 44
const U_BLOOD_RAGE := 45
const U_CONTINUOUS_TARGET_AIR_ID := 46
const U_HIT_HASTE_FULL := 47
const U_ATTACK_SPEED_SLOW := 48
const U_ACTION_CLOCK := 49
const U_TEAM_ATTACK_BOOST_MULTIPLIER := 50
const U_GROWTH := 51
const U_STEALTH := 52
const U_STASIS := 53
const U_STRUCTURE_HASTE := 54
const U_STRUCTURE_HASTE_STATE := 55
const U_SACRIFICE_EMPOWERMENT := 56
const U_SACRIFICE_STATS := 57
const U_DEATH_SPAWN_STATE := 58
const U_LIFESTEAL_VISUAL_STATE := 59
const U_BUFF_VISUAL_CLOCK := 60
const U_RESTORATION_SHIELD_STATE := 61
const U_BLIND := 62
const U_TELEPORT_SERIAL := 63
const U_DEPLOYMENT_SHIELD := 64
const U_CHARGED := 65
const UNIT_PAYLOAD_SIZE := 66

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
const P_VISUAL_PATH := 13
## 权威出膛速度（世界坐标单位/秒），有限且>0；客户端仅用于表现年龄。
const P_SPEED := 14
const PROJECTILE_PAYLOAD_SIZE := 15

const T_HP := 0
const T_ACTIVATED := 1
const T_STUNNED := 2
const T_SHIELD_RATIO := 3
const T_SHIELD_CAPACITY_RATIO := 4
const T_FROZEN := 5
const T_STASIS := 6
const TOWER_PAYLOAD_SIZE := 7

var terminal_applied := false
var lifecycle := NetworkEntityLifecycle.new()
var _controller: Node2D
var _projectile_system: ProjectileSystem


func _init(controller: Node2D, projectile_system: ProjectileSystem) -> void:
	_controller = controller
	_projectile_system = projectile_system


func reset_session(session_id: String) -> void:
	for id in _controller.world.replica_unit_ids():
		_controller.remove_network_unit(id, false)
	_projectile_system.clear_client()
	terminal_applied = false
	lifecycle.reset(session_id)
	_controller.reset_network_clock()

func register_spawn(args: Array) -> Dictionary:
	lifecycle.host_spawn(int(args[3]), _controller.get_authoritative_server_tick(), args)
	return lifecycle.spawns[int(args[3])]

func receive_spawn(session_id: String, descriptor: Dictionary, snapshot_payload: Array = []) -> void:
	if _controller.runtime.mode != "client" or terminal_applied or _controller.runtime.game_over or not lifecycle.accepts_session(session_id) or not _valid_spawn(descriptor):
		return
	_receive_validated_spawn(descriptor, snapshot_payload)

func _receive_validated_spawn(descriptor: Dictionary, snapshot_payload: Array = []) -> bool:
	var args: Array = descriptor.args.duplicate(true)
	# 快照可能已重建甚至移除实体，可靠预部署/出生事件才到达。
	# 无论是否需要重建，这一出生事实都结束对应的旧部署提示。
	_controller._remove_card_pre_deploy_visual(int(args[7]))
	var id := int(args[3])
	var birth := int(descriptor.birth_tick)
	var birth_revision := int(descriptor.birth_revision)
	if not lifecycle.accepts_spawn(id, birth_revision):
		return true
	var existing = _controller.world.find_replica_unit(id)
	if is_instance_valid(existing):
		return true
	lifecycle.register_spawn(id, birth, birth_revision, args)
	if not snapshot_payload.is_empty():
		args[2] = Vector2(snapshot_payload[U_X], snapshot_payload[U_Y])
		args[4] = float(snapshot_payload[U_DEPLOY_LEFT])
	_controller.create_network_unit.callv(args)
	if not is_instance_valid(_controller.world.find_replica_unit(id)):
		lifecycle.spawns.erase(id)
		_controller._fail_contract("出生应用失败：无法创建单位 id=%s card=%s" % [id, args[0]])
		return false
	return true

func receive_death(session_id: String, id: int, tick: int, play_death_visual: bool) -> void:
	if _controller.runtime.mode != "client" or terminal_applied or _controller.runtime.game_over or not lifecycle.accepts_session(session_id) or tick < 0:
		return
	lifecycle.mark_destroyed(id, tick)
	_controller.remove_network_unit(id, play_death_visual)

func _valid_spawn(descriptor: Dictionary) -> bool:
	if not descriptor.get("birth_tick") is int or int(descriptor.birth_tick) < 0:
		return false
	if not descriptor.get("birth_revision") is int or int(descriptor.birth_revision) < 0:
		return false
	var args = descriptor.get("args")
	if not args is Array or args.size() != 14:
		return false
	if not args[0] is String or CardDB.get_unit_stats(args[0]).is_empty():
		return false
	for index in [1, 3, 5, 6, 7, 8, 10]:
		if not args[index] is int:
			return false
	if args[1] not in [0, 1] or int(args[3]) < 0 or not args[2] is Vector2 or not args[2].is_finite():
		return false
	return typeof(args[4]) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(args[4])) and args[9] is String and args[11] is bool and args[12] is String and CardDB.has_card(args[12]) and args[13] is Vector2 and (args[13].is_finite() or args[13] == Vector2.INF)


func decode_validated(snapshot_bytes: PackedByteArray) -> DecodedSnapshot:
	var raw_bytes := snapshot_bytes.decompress_dynamic(MAX_DECODED_BYTES, FileAccess.COMPRESSION_DEFLATE)
	if raw_bytes.is_empty():
		return null
	var decoded = bytes_to_var(raw_bytes)
	if not decoded is Array or decoded.size() != SNAPSHOT_PACKET_SIZE:
		return null
	if not decoded[S_VERSION] is int or int(decoded[S_VERSION]) != SNAPSHOT_PROTOCOL_VERSION:
		return null
	if not decoded[S_SESSION] is String:
		return null
	if not MatchCardGrowth.valid_snapshot(decoded[S_CARD_GROWTH]): return null
	if not decoded[S_SERVER_TICK] is int or int(decoded[S_SERVER_TICK]) < 0 or not decoded[S_LIFECYCLE_REVISION] is int or int(decoded[S_LIFECYCLE_REVISION]) < 0:
		return null
	if not decoded[S_UNITS] is Array or not decoded[S_PROJECTILES] is Array or not decoded[S_TOWERS] is Array:
		return null
	if not _finite_number(decoded[S_CLIENT_ELIXIR]) or not _finite_number(decoded[S_MATCH_TIMER]) or not decoded[S_OVERTIME] is bool: return null
	if float(decoded[S_CLIENT_ELIXIR]) < 0.0 or float(decoded[S_CLIENT_ELIXIR]) > ElixirManager.MAX_ELIXIR or float(decoded[S_MATCH_TIMER]) < 0.0: return null
	var units_data: Array = decoded[S_UNITS]
	var projectiles_data: Array = decoded[S_PROJECTILES]
	var towers_data: Array = decoded[S_TOWERS]
	if towers_data.size() != 6: return null
	if not _payloads_have_size(units_data, UNIT_PAYLOAD_SIZE):
		return null
	if not _payloads_have_size(projectiles_data, PROJECTILE_PAYLOAD_SIZE):
		return null
	if not _payloads_have_size(towers_data, TOWER_PAYLOAD_SIZE):
		return null
	for payload: Array in towers_data:
		for field in [T_HP, T_SHIELD_RATIO, T_SHIELD_CAPACITY_RATIO]:
			if not _finite_number(payload[field]): return null
		for field in [T_ACTIVATED, T_STUNNED, T_FROZEN]:
			if not payload[field] is int or payload[field] not in [0, 1]: return null
		if not payload[T_STASIS] is bool: return null
		if float(payload[T_HP]) < 0.0 or float(payload[T_SHIELD_RATIO]) < 0.0 or float(payload[T_SHIELD_RATIO]) > 1.0 or float(payload[T_SHIELD_CAPACITY_RATIO]) < 0.0: return null
	var projectile_ids := {}
	for payload: Array in projectiles_data:
		if not payload[P_ID] is int or payload[P_ID] < 0 or projectile_ids.has(payload[P_ID]): return null
		projectile_ids[payload[P_ID]] = true
		for field in [P_X, P_Y, P_RADIUS, P_DIRECTION_X, P_DIRECTION_Y, P_VISUAL_HEIGHT, P_VISUAL_OFFSET_X, P_VISUAL_OFFSET_Y, P_VISUAL_SCALE, P_SPEED]:
			if not _finite_number(payload[field]): return null
		if float(payload[P_RADIUS]) < 0.0 or float(payload[P_VISUAL_HEIGHT]) < 0.0 or float(payload[P_VISUAL_SCALE]) <= 0.0 or float(payload[P_SPEED]) <= 0.0: return null
		if not payload[P_COLOR] is Color or not _finite_value(payload[P_COLOR]): return null
		if not payload[P_VISUAL] is String or not payload[P_FIRST_STRIKE] is int or payload[P_FIRST_STRIKE] not in [0, 1]: return null
		if not payload[P_VISUAL_PATH] is Dictionary or not _valid_visual_path(payload[P_VISUAL_PATH]): return null
	var ids := {}
	for payload: Array in units_data:
		for field in [U_X, U_Y, U_HP, U_CONTINUOUS_X, U_CONTINUOUS_Y, U_FACING_DIRECTION_X, U_FACING_DIRECTION_Y, U_ACTION_DURATION, U_ACTION_TIME_LEFT, U_SKILL_RESOURCE_RATIO, U_ACTIVE_SPEED_MULTIPLIER, U_ACTIVE_ATTACK_SPEED_MULTIPLIER, U_ACTIVE_SKILL_COOLDOWN, U_SHIELD_RATIO, U_SHIELD_CAPACITY_RATIO, U_ATTACK_ELAPSED, U_MOVEMENT_RATE, U_DEPLOY_LEFT]:
			if not _finite_number(payload[field]): return null
		for field in [U_FROZEN, U_HAS_CONTINUOUS_TARGET, U_SLOW, U_STUN, U_ATTACKING_STRUCTURE, U_EMPOWERED_READY, U_SKILL_RESOURCE_ENABLED, U_ACTIVE_BUFF_ACTIVE, U_ATTACK_FIRST_STRIKE, U_CHARGED]:
			if not payload[field] is int or payload[field] not in [0, 1]: return null
		for field in [U_VISUAL_STATE, U_ATTACK_SERIAL, U_FORM, U_ACTION_SERIAL, U_FORM_CHANGE_SERIAL, U_LOCOMOTION, U_EMPOWERED_ATTACK_SERIAL, U_ACTIVE_SKILL_USES_REMAINING]:
			if not payload[field] is int or payload[field] < 0: return null
		if not payload[U_ACTION_NAME] is String: return null
		for field in [U_HP, U_ACTION_DURATION, U_ACTION_TIME_LEFT, U_ACTIVE_SKILL_COOLDOWN, U_SHIELD_CAPACITY_RATIO, U_ATTACK_ELAPSED, U_DEPLOY_LEFT]:
			if float(payload[field]) < 0.0: return null
		for field in [U_SKILL_RESOURCE_RATIO, U_SHIELD_RATIO]:
			if float(payload[field]) < 0.0 or float(payload[field]) > 1.0: return null
		if float(payload[U_ACTIVE_SPEED_MULTIPLIER]) < 1.0 or float(payload[U_ACTIVE_ATTACK_SPEED_MULTIPLIER]) <= 0.0 or float(payload[U_MOVEMENT_RATE]) <= 0.0: return null
		if payload[U_VISUAL_STATE] > 3 or payload[U_LOCOMOTION] > 2 or payload[U_FORM] > 1: return null
		if not payload[U_DEPLOYMENT_SHIELD] is bool: return null
		if not payload[U_STEALTH] is bool or not payload[U_STASIS] is bool: return null
		if not payload[U_HIT_HASTE_FULL] is bool or not payload[U_STRUCTURE_HASTE] is bool: return null
		for field in [U_LIFESTEAL_VISUAL_STATE, U_BUFF_VISUAL_CLOCK]:
			if not payload[field] is Vector2: return null
			var clock: Vector2 = payload[field]
			if not clock.is_finite() or clock.x < 0.0 or clock.y < 0.0: return null
			if clock.y == 0.0 and clock.x != 0.0: return null
			if field == U_LIFESTEAL_VISUAL_STATE and clock.y not in [0.0, 1.0]: return null
			if field == U_BUFF_VISUAL_CLOCK and clock.x > clock.y + 2.1: return null
		if not payload[U_RESTORATION_SHIELD_STATE] is Vector2: return null
		var ward: Vector2 = payload[U_RESTORATION_SHIELD_STATE]
		if not ward.is_finite() or ward.x < 0.0 or ward.y < ward.x or ((ward.x > 0.0) != (ward.y > 0.0)): return null
		if not payload[U_DEATH_SPAWN_STATE] is Vector2: return null
		var regeneration: Vector2 = payload[U_DEATH_SPAWN_STATE]
		if not regeneration.is_finite() or regeneration.x < 0.0 or regeneration.y < regeneration.x: return null
		if (regeneration.x > 0.0) != (regeneration.y > 0.0): return null
		if not payload[U_SACRIFICE_STATS] is Vector3: return null
		var empowered_stats: Vector3 = payload[U_SACRIFICE_STATS]
		if not empowered_stats.is_finite() or empowered_stats.x < 0.0 or empowered_stats.y < 1.0 or empowered_stats.z < 1.0: return null
		if not payload[U_SACRIFICE_EMPOWERMENT] is Vector2: return null
		var empowerment: Vector2 = payload[U_SACRIFICE_EMPOWERMENT]
		if not empowerment.is_finite() or empowerment.x < 1.0 or empowerment.y < 1.0: return null
		if not payload[U_STRUCTURE_HASTE_STATE] is Vector2: return null
		var haste: Vector2 = payload[U_STRUCTURE_HASTE_STATE]
		if not haste.is_finite() or haste.x < 0.0 or haste.y < 0.0 or haste.y != floorf(haste.y): return null
		if (haste.x > 0.0) != (haste.y > 0.0) or bool(payload[U_STRUCTURE_HASTE]) != (haste.x > 0.0): return null
		if not payload[U_BLIND] is bool: return null
		if not payload[U_TELEPORT_SERIAL] is int or payload[U_TELEPORT_SERIAL] < 0: return null
		if not payload[U_ATTACK_SPEED_SLOW] is bool: return null
		if not payload[U_ACTION_CLOCK] is Vector2: return null
		if not (payload[U_TEAM_ATTACK_BOOST_MULTIPLIER] is int or payload[U_TEAM_ATTACK_BOOST_MULTIPLIER] is float): return null
		if not is_finite(float(payload[U_TEAM_ATTACK_BOOST_MULTIPLIER])) or float(payload[U_TEAM_ATTACK_BOOST_MULTIPLIER]) < 1.0: return null
		if not payload[U_GROWTH] is Vector2: return null
		var growth: Vector2 = payload[U_GROWTH]
		if not is_finite(growth.x) or not is_finite(growth.y) or growth.x < 0.0 or growth.y < 1.0: return null
		var action_clock: Vector2 = payload[U_ACTION_CLOCK]
		if not action_clock.is_finite() or action_clock.x not in [0.0, 1.0] or action_clock.y < 0.0: return null
		if not payload[U_EXPLOSIVE_SHIELD] is bool: return null
		if not DeathFormState.valid_snapshot(payload[U_DEATH_FORM]): return null
		if not TargetProtectionState.valid_snapshot(payload[U_TARGET_PROTECTION]): return null
		if not payload[U_FREE_RECAST] is bool or not payload[U_BLEED_STACKS] is int or int(payload[U_BLEED_STACKS]) < 0 or not (payload[U_BLOOD_RAGE] is float or payload[U_BLOOD_RAGE] is int) or not is_finite(float(payload[U_BLOOD_RAGE])) or float(payload[U_BLOOD_RAGE]) < 0.0: return null
		if not payload[U_CONTINUOUS_TARGET_AIR_ID] is int or int(payload[U_CONTINUOUS_TARGET_AIR_ID]) < -1: return null
		if not payload[U_ACTION_PERMISSIONS] is int or int(payload[U_ACTION_PERMISSIONS]) < 0 or (int(payload[U_ACTION_PERMISSIONS]) & ~ControlState.ALL_PERMISSIONS) != 0:
			return null
		if not payload[U_CANCELLATION] is Dictionary or not Unit.valid_action_cancellation(payload[U_CANCELLATION]):
			return null
		if not payload[U_ID] is int or ids.has(payload[U_ID]) or not payload[U_SPAWN] is Dictionary or not _valid_spawn(payload[U_SPAWN]):
			return null
		if int(payload[U_SPAWN].args[3]) != int(payload[U_ID]) or int(payload[U_SPAWN].birth_tick) > int(decoded[S_SERVER_TICK]) or int(payload[U_SPAWN].birth_revision) > int(decoded[S_LIFECYCLE_REVISION]):
			return null
		ids[payload[U_ID]] = true
	_freeze(decoded)
	ids.make_read_only()
	return DecodedSnapshot.new(decoded, ids, raw_bytes.size())

## 包内容已经完整静态验证；这里只重查从入队到播放期间可能改变的会话/终态/时钟。
func apply_decoded(snapshot: DecodedSnapshot, terminal: bool = false, expected_tick: int = -1) -> bool:
	if snapshot == null or _controller.runtime.mode != "client" or terminal_applied or _controller.runtime.game_over:
		return false
	var decoded := snapshot.packet
	if not lifecycle.accepts_session(decoded[S_SESSION]): return false
	if terminal and int(decoded[S_SERVER_TICK]) != expected_tick: return false
	var units_data: Array = decoded[S_UNITS]
	var projectiles_data: Array = decoded[S_PROJECTILES]
	var towers_data: Array = decoded[S_TOWERS]
	var ids := snapshot.unit_ids
	if not terminal and not lifecycle.snapshot_is_new(int(decoded[S_SERVER_TICK]), int(decoded[S_LIFECYCLE_REVISION])):
		return false
	if terminal and (int(decoded[S_SERVER_TICK]) < lifecycle.snapshot_tick or int(decoded[S_LIFECYCLE_REVISION]) < lifecycle.snapshot_revision):
		return false
	# 可靠 RPC 仍可能在不同发送周期交错到达；较早 tick 不能回拨客户端命令时钟。
	if not _controller._accept_authoritative_server_tick(int(decoded[S_SERVER_TICK])):
		return false
	if _controller.world.towers_snapshot().size() != 6:
		_controller._fail_contract("快照应用失败：本地战场必须有6座塔")
		return false

	lifecycle.accept_snapshot(int(decoded[S_SERVER_TICK]), int(decoded[S_LIFECYCLE_REVISION]), ids)
	if not _apply_units(units_data): return false
	_apply_projectiles(projectiles_data)
	_apply_towers(towers_data)
	_controller.runtime.apply_growth_snapshot(decoded[S_CARD_GROWTH])
	_controller.apply_network_match_snapshot(float(decoded[S_CLIENT_ELIXIR]), float(decoded[S_MATCH_TIMER]), bool(decoded[S_OVERTIME]))

	terminal_applied = terminal
	return true

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _finite_value(value: Variant) -> bool:
	if value is float: return is_finite(value)
	if value is Vector2 or value is Vector3: return value.is_finite()
	if value is Color: return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
	if value is Dictionary:
		for key in value:
			if not (key is String or key is int) or not _finite_value(value[key]): return false
		return true
	if value is Array:
		for child in value:
			if not _finite_value(child): return false
		return true
	return value is int or value is bool or value is String

static func _valid_visual_path(path: Dictionary) -> bool:
	if path.is_empty(): return true
	if not _finite_value(path): return false
	for field in ["start", "end", "origin_offset"]:
		if not path.get(field) is Vector2: return false
	for field in ["start_model_offset", "end_model_offset"]:
		if path.has(field) and not path[field] is Vector2: return false
	for field in ["progress", "contact_radius"]:
		if not _finite_number(path.get(field)) or float(path[field]) < 0.0: return false
	if not path.get("wave") is bool: return false
	for field in ["fixed_muzzle", "air"]:
		if path.has(field) and not path[field] is bool: return false
	for field in ["source", "target"]:
		if not path.get(field) is Dictionary: return false
		var entity: Dictionary = path[field]
		if not entity.get("unit") is bool or not entity.get("team") is int or entity.team not in [0, 1] or not entity.get("position") is Vector2: return false
		if entity.unit:
			if not entity.get("id") is int or entity.id < -1 or not entity.get("local_id") is int or entity.local_id < 0: return false
		elif not entity.get("king") is bool: return false
	return true

static func _freeze(value: Variant) -> void:
	if value is Dictionary or value is Array:
		for child in value.values() if value is Dictionary else value: _freeze(child)
		value.make_read_only()


func _payloads_have_size(payloads: Array, expected_size: int) -> bool:
	for payload in payloads:
		if not payload is Array or payload.size() != expected_size:
			return false
	return true


func _apply_units(units_data: Array) -> bool:
	var seen := {}
	for d: Array in units_data:
		seen[d[U_ID]] = true
		if lifecycle.destroyed.has(d[U_ID]):
			continue
		var u = _controller.world.find_replica_unit(d[U_ID])
		if not is_instance_valid(u):
			if not _receive_validated_spawn(d[U_SPAWN], d): return false
			u = _controller.world.find_replica_unit(d[U_ID])
		if not is_instance_valid(u):
			_controller._fail_contract("快照应用失败：无法创建单位 id=%s card=%s" % [d[U_ID], d[U_SPAWN].args[0]])
			return false
		# 单位高风险字段只进入已校验载荷的副本恢复，不调用权威转换。
		u.restore_replica_combat_state({
			"cancellation": d[U_CANCELLATION], "deploy_left": d[U_DEPLOY_LEFT],
			"position": Vector2(d[U_X], d[U_Y]), "teleport": d[U_TELEPORT_SERIAL],
			"form": d[U_FORM], "form_serial": d[U_FORM_CHANGE_SERIAL], "hp": d[U_HP],
			"growth": d[U_GROWTH], "sacrifice_stats": d[U_SACRIFICE_STATS],
			"sacrifice_empowerment": d[U_SACRIFICE_EMPOWERMENT], "team_boost": d[U_TEAM_ATTACK_BOOST_MULTIPLIER],
			"frozen": d[U_FROZEN] == 1, "stunned": d[U_STUN] == 1, "stasis": d[U_STASIS],
			"protection": d[U_TARGET_PROTECTION], "death_form": d[U_DEATH_FORM], "bleed": d[U_BLEED_STACKS],
		})
		u.active_skill_card_id = String(d[U_SPAWN].args[12])
		_controller.sync_network_unit_skill(u, int(d[U_SPAWN].args[5]), int(d[U_SPAWN].args[6]))
		u.net_visual_state = int(d[U_VISUAL_STATE])
		u.net_attack_visual_serial = int(d[U_ATTACK_SERIAL])
		u.net_attack_visual_first_strike = int(d[U_ATTACK_FIRST_STRIKE]) == 1
		u.net_has_continuous_target = int(d[U_HAS_CONTINUOUS_TARGET]) == 1
		u.net_continuous_target_pos = Vector2(d[U_CONTINUOUS_X], d[U_CONTINUOUS_Y])
		u.net_continuous_target_air_id = int(d[U_CONTINUOUS_TARGET_AIR_ID])
		if _controller._auto_test and not _controller._auto_continuous_target_seen and u.net_has_continuous_target:
			_controller._auto_continuous_target_seen = true
			print("[测试] 客户端已收到持续吐息目标端点")
		u.net_slow_active = int(d[U_SLOW]) == 1
		u.net_attack_speed_slow_active = d[U_ATTACK_SPEED_SLOW]
		u.net_blind_active = d[U_BLIND]
		u.net_stun_active = int(d[U_STUN]) == 1
		var action_serial := int(d[U_ACTION_SERIAL])
		if action_serial >= u.net_visual_action_serial:
			u.net_visual_action_serial = action_serial
			u.net_visual_action_name = StringName(d[U_ACTION_NAME])
		u.net_facing_direction = Vector2(d[U_FACING_DIRECTION_X], d[U_FACING_DIRECTION_Y])
		u.net_attacking_structure = int(d[U_ATTACKING_STRUCTURE]) == 1
		# 时长和剩余时间让晚到客户端从权威进度开始播放。
		u.net_visual_action_clock = d[U_ACTION_CLOCK]
		u.net_visual_action_duration = maxf(float(d[U_ACTION_DURATION]), 0.0)
		u.net_visual_action_time_left = clampf(float(d[U_ACTION_TIME_LEFT]), 0.0, u.net_visual_action_duration)
		if not u.last_action_cancellation.is_empty():
			var cancelled: Dictionary = u.last_action_cancellation
			if u.net_attack_visual_serial <= int(cancelled.attack):
				# 新的技能引导端点不属于已取消的旧普攻。
				if not (u.net_visual_action_name == &"channel" and action_serial > u.cancelled_visual_serial and u.net_visual_action_time_left > 0.0):
					u.net_has_continuous_target = false
				if u.net_visual_state == 3: u.net_visual_state = 1
			if action_serial <= u.cancelled_visual_serial:
				u.net_visual_action_time_left = 0.0
				u.net_visual_action_name = &""
				u.net_visual_action_clock = Vector2(0.0, 1.0)
		u.net_locomotion_state = int(d[U_LOCOMOTION])
		u.net_empowered_attack_ready = int(d[U_EMPOWERED_READY]) == 1
		u.net_empowered_attack_visual_serial = int(d[U_EMPOWERED_ATTACK_SERIAL])
		u.net_skill_resource_ratio = clampf(float(d[U_SKILL_RESOURCE_RATIO]), 0.0, 1.0)
		u.net_skill_resource_enabled = int(d[U_SKILL_RESOURCE_ENABLED]) == 1
		u.net_active_speed_multiplier = maxf(float(d[U_ACTIVE_SPEED_MULTIPLIER]), 1.0)
		u.net_active_attack_speed_multiplier = maxf(float(d[U_ACTIVE_ATTACK_SPEED_MULTIPLIER]), 0.01)
		u.net_attack_elapsed = maxf(float(d[U_ATTACK_ELAPSED]), 0.0)
		u.net_action_permissions = int(d[U_ACTION_PERMISSIONS])
		u.net_explosive_shield = d[U_EXPLOSIVE_SHIELD]
		u.net_movement_rate = maxf(float(d[U_MOVEMENT_RATE]), 0.01)
		u.net_stealth_hidden = d[U_STEALTH]
		u.net_active_buff_active = int(d[U_ACTIVE_BUFF_ACTIVE]) == 1
		_controller.apply_network_skill_state(u, int(d[U_ACTIVE_SKILL_USES_REMAINING]), float(d[U_ACTIVE_SKILL_COOLDOWN]), bool(d[U_FREE_RECAST]))
		u.net_blood_rage = float(d[U_BLOOD_RAGE])
		u.net_death_spawn_state = d[U_DEATH_SPAWN_STATE]
		u.net_lifesteal_visual_state = d[U_LIFESTEAL_VISUAL_STATE]
		u.net_buff_visual_clock = d[U_BUFF_VISUAL_CLOCK]
		u.net_hit_haste_full = d[U_HIT_HASTE_FULL]
		u.net_structure_haste = d[U_STRUCTURE_HASTE]
		u.net_structure_haste_state = d[U_STRUCTURE_HASTE_STATE]
		u.net_restoration_shield_state = d[U_RESTORATION_SHIELD_STATE]
		u.net_deployment_shield_active = d[U_DEPLOYMENT_SHIELD]
		u.net_charged = int(d[U_CHARGED]) == 1
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
	for id in _controller.world.replica_unit_ids():
		if not seen.has(id) and lifecycle.snapshot_can_remove(id):
			gone.append(id)
	for id in gone:
		lifecycle.mark_destroyed(id, lifecycle.snapshot_tick)
		_controller.remove_network_unit(id, true)
	return true


func _apply_projectiles(projectiles_data: Array) -> void:
	var targets := {}
	if _controller._auto_test and not _controller._auto_projectile_seen and not projectiles_data.is_empty():
		_controller._auto_projectile_seen = true
		print("[测试] 客户端已收到弹道快照")
	for d: Array in projectiles_data:
		targets[d[P_ID]] = {
			"pos": Vector2(d[P_X], d[P_Y]),
			"target_pos": Vector2(d[P_X], d[P_Y]),
			"visual_path": d[P_VISUAL_PATH].duplicate(true),
			"color": d[P_COLOR], "radius": d[P_RADIUS], "visual": StringName(d[P_VISUAL]),
			"direction": Vector2(d[P_DIRECTION_X], d[P_DIRECTION_Y]),
			"visual_height": float(d[P_VISUAL_HEIGHT]),
			"visual_offset": Vector2(d[P_VISUAL_OFFSET_X], d[P_VISUAL_OFFSET_Y]),
			"target_visual_offset": Vector2(d[P_VISUAL_OFFSET_X], d[P_VISUAL_OFFSET_Y]),
			"visual_scale": float(d[P_VISUAL_SCALE]), "first_strike": int(d[P_FIRST_STRIKE]) == 1,
			"speed": float(d[P_SPEED]),
		}
	_projectile_system.apply_client_targets(targets)

func _apply_towers(towers_data: Array) -> void:
	var towers: Array[Tower] = _controller.world.towers_snapshot()
	for i in towers.size():
		var tower_data: Array = towers_data[i]
		towers[i].apply_network_state(
			float(tower_data[T_HP]), int(tower_data[T_ACTIVATED]) == 1,
			int(tower_data[T_STUNNED]) == 1, float(tower_data[T_SHIELD_RATIO]),
			float(tower_data[T_SHIELD_CAPACITY_RATIO]), int(tower_data[T_FROZEN]) == 1, bool(tower_data[T_STASIS]))


func send() -> void:
	if _controller.runtime.game_over or not _valid_authority_towers(_controller.world.towers_snapshot()): return
	var recipients := {}
	for team in _controller.runtime.session.players:
		var peer: int = _controller.runtime.session.peer_for_team(team)
		if _controller.multiplayer.get_peers().has(peer): recipients[team] = peer
	if recipients.is_empty(): return
	var frame := capture_public_frame()
	if frame.is_empty(): return
	for team in recipients:
		_controller._rpc_snapshot.rpc_id(recipients[team], encode_frame(frame, team))

func capture(receiver_team: int = 1) -> PackedByteArray:
	var frame := capture_public_frame()
	return encode_frame(frame, receiver_team) if not frame.is_empty() else PackedByteArray()

## 清场前采集一次公共世界；私有槽只留占位，不能携带另一席的经济或成长。
func capture_public_frame() -> Array:
	var towers: Array[Tower] = _controller.world.towers_snapshot()
	if not _valid_authority_towers(towers): return []
	var units_data := []
	var units: Dictionary = _controller.world.authoritative_units_snapshot()
	for id in units:
		# 非类型化读取：单位可能已 queue_free，类型化赋值会先于有效性检查报错。
		var u = units.get(id)
		if u == null or not is_instance_valid(u) or (u.hp <= 0.0 and not u.death_form.waiting()):
			continue
		if not lifecycle.spawns.has(id) or not _valid_spawn(lifecycle.spawns[id]) or int(lifecycle.spawns[id].args[3]) != id:
			# 内部事实损坏不能补零出生、压出可传播的错误快照。
			_controller._fail_contract("战场契约失败：单位缺少当前出生描述 id=%s card=%s" % [id, u.card_id])
			return []
		units_data.append(_unit_snapshot_payload(
			id,
			u,
			lifecycle.spawns[id],
			u.has_continuous_visual_target(),
			u.get_continuous_visual_target_position(),
			u.get_visual_facing_direction(),
		))

	var projectiles_data := []
	var authoritative_projectiles := _projectile_system.authoritative_snapshot()
	for id in authoritative_projectiles:
		var projectile: Dictionary = authoritative_projectiles[id]
		for field in ["pos", "direction", "color", "radius", "visual", "speed"]:
			if not projectile.has(field):
				_controller._fail_contract("弹体快照缺少必需字段：id=%s field=%s" % [id, field])
				return []
		projectiles_data.append(_projectile_snapshot_payload(id, projectile))

	var towers_data := []
	for tower in towers:
		towers_data.append(_tower_snapshot_payload(tower))
	var frame: Array = [SNAPSHOT_PROTOCOL_VERSION, _controller.runtime._sim_tick_id, units_data, projectiles_data,
		towers_data, null, _controller.runtime._match_rules.time_left, _controller.runtime._match_rules.overtime,
		lifecycle.session_id, lifecycle.revision, null]
	_freeze(frame)
	return frame

## 固定索引包括已摧毁的塔；HP不决定拓扑。缺席/释放/错序不能变成可发布帧。
func _valid_authority_towers(towers: Array[Tower]) -> bool:
	if towers.size() != 6:
		_controller._fail_contract("权威战场拓扑错误：必须有6座塔，实际%s座" % towers.size())
		return false
	var ids := {}
	for index in towers.size():
		var tower = towers[index]
		if not is_instance_valid(tower) or tower.is_queued_for_deletion():
			_controller._fail_contract("权威战场拓扑错误：塔索引%s已释放或待删除" % index)
			return false
		var expected_team := index / 2 if index < 4 else index - 4
		if ids.has(tower.get_instance_id()) or tower.team != expected_team or tower.is_king != (index >= 4) or (index >= 4 and _controller.world.king(expected_team) != tower):
			_controller._fail_contract("权威战场拓扑错误：塔索引%s重复、错序或水晶引用不一致" % index)
			return false
		ids[tower.get_instance_id()] = true
	return true

func encode_frame(frame: Array, receiver_team: int = 1) -> PackedByteArray:
	# 仅复制11个顶层引用；已固化世界保持共享，每端独立生成自己的私有投影。
	var packet := frame.duplicate()
	packet[S_CLIENT_ELIXIR] = _controller.runtime.network_match_snapshot(receiver_team).elixir
	packet[S_CARD_GROWTH] = _controller.runtime.growth_snapshot(receiver_team)
	return var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE)



func _tower_snapshot_payload(tower: Tower) -> Array:
	return [
		tower.hp,
		1 if tower.activated else 0,
		1 if tower.control.stun_timer > 0.0 else 0,
		tower.get_shield_ratio(),
		tower.get_shield_capacity_ratio(),
		1 if tower.frozen_timer > 0.0 else 0,
		CombatInteraction.in_stasis(tower),
	]


## 弹体载荷集中构造，确保新增纯表现字段在主机和客户端使用同一固定顺序。
func _projectile_snapshot_payload(id: int, projectile: Dictionary) -> Array:
	var visual_offset: Vector2 = projectile.get("visual_offset", Vector2.ZERO)
	var direction: Vector2 = projectile.direction
	var position: Vector2 = projectile.pos
	return [
		id, position.x, position.y, projectile.color, projectile.radius,
		String(projectile.visual), direction.x, direction.y,
		projectile.get("visual_height", 0.0), visual_offset.x, visual_offset.y,
		projectile.get("visual_scale", 1.0), 1 if bool(projectile.get("effects", {}).get("first_strike", false)) else 0,
		projectile.get("visual_path", {}).duplicate(true), float(projectile.speed),
	]


## 单位载荷集中构造；读写两端共用当前固定字段表。
func _unit_snapshot_payload(id: int, u: Unit, birth: Dictionary, has_continuous_target: bool = false, continuous_target_pos: Vector2 = Vector2.ZERO, facing_direction: Vector2 = Vector2.ZERO) -> Array:
	if facing_direction.is_zero_approx():
		facing_direction = u.get_visual_facing_direction()
	var skill_card_id := u.active_skill_card_id if not u.active_skill_card_id.is_empty() else u.card_id
	var active_skill_state: Dictionary = _controller.runtime.get_active_skill_snapshot(u.active_ability_id)
	assert(_valid_spawn(birth) and int(birth.args[3]) == id, "快照编码缺少当前14字段出生事实: id=%s" % id)
	var descriptor: Dictionary = birth.duplicate(true)
	# 主动资格会转交/被新部署替换；重建必须使用当前资格而非原始出生资格。
	descriptor.args[5] = u.active_ability_id
	descriptor.args[6] = u.active_ability_slot
	descriptor.args[10] = u.death_replacement_charges
	descriptor.args[12] = skill_card_id
	return [
		id, u.global_position.x, u.global_position.y, u.hp,
		1 if u.control.frozen_timer > 0.0 else 0,
		u.get_visual_state_code(), u.get_attack_visual_serial(),
		1 if has_continuous_target else 0, continuous_target_pos.x, continuous_target_pos.y,
		1 if u.movement_slow_visual() else 0,
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
		1 if u.get_active_buff_active_visual() else 0,
		1 if u.is_attack_visual_first_strike() else 0,
		u.get_attack_elapsed_visual(), u.get_effective_movement_rate_visual(), u.get_action_permissions_visual(),
		descriptor,
		u._deploy_timer,
		u.last_action_cancellation.duplicate(true),
		u.target_protection.snapshot(),
		u.death_form.snapshot(),
		u.has_explosive_shield(),
		bool(active_skill_state.get("free_recast", false)),
		u.bleeding.total_stacks(),
		u.buffs.remaining(&"blood_rage"),
		u.get_continuous_visual_target_air_id(),
		u.hit_haste_full_visual(),
		u.attack_speed_slow_visual(),
		u.get_visual_action_clock(),
		u.team_attack_boost_multiplier,
		Vector2(u.growth_health_bonus, u.growth_body_scale),
		u.stealth_hidden(),
		CombatInteraction.in_stasis(u),
		u.structure_haste_visual(),
		u.structure_haste_state_visual(),
		u.sacrifice_empowerment, u.sacrifice_stats,
		u.death_spawn_state_visual(),
		u.lifesteal_state_visual(), u.active_buff_clock_visual(),
		u.restoration_shield_state_visual(),
		u.blind_visual(), u.teleport_serial, u.deployment_shield_active_visual(), int(u.is_charged_visual()),
	]
