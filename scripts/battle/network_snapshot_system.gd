class_name NetworkSnapshotSystem
extends RefCounted
## 20Hz 单位/塔/弹体快照的序列化与客户端应用。RPC 端点仍保留在 Main。

const SNAPSHOT_PROTOCOL_VERSION := 12
const S_VERSION := 0
const S_SERVER_TICK := 1
const S_UNITS := 2
const S_PROJECTILES := 3
const S_TOWERS := 4
const S_CLIENT_ELIXIR := 5
const S_MATCH_TIMER := 6
const S_OVERTIME := 7
const SNAPSHOT_PACKET_SIZE := 8

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
const UNIT_PAYLOAD_SIZE := 35

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

var _controller: Node2D


func _init(controller: Node2D) -> void:
	_controller = controller


func apply(snapshot_bytes: PackedByteArray) -> void:
	if _controller.mode != "client":
		return
	var raw_bytes := snapshot_bytes.decompress_dynamic(1024 * 1024, FileAccess.COMPRESSION_DEFLATE)
	if raw_bytes.is_empty():
		return
	var decoded = bytes_to_var(raw_bytes)
	if not decoded is Array or decoded.size() != SNAPSHOT_PACKET_SIZE:
		return
	if not decoded[S_VERSION] is int or int(decoded[S_VERSION]) != SNAPSHOT_PROTOCOL_VERSION:
		return
	if not decoded[S_SERVER_TICK] is int:
		return
	if not decoded[S_UNITS] is Array or not decoded[S_PROJECTILES] is Array or not decoded[S_TOWERS] is Array:
		return
	var units_data: Array = decoded[S_UNITS]
	var projectiles_data: Array = decoded[S_PROJECTILES]
	var towers_data: Array = decoded[S_TOWERS]
	if not _payloads_have_size(units_data, UNIT_PAYLOAD_SIZE):
		return
	if not _payloads_have_size(projectiles_data, PROJECTILE_PAYLOAD_SIZE):
		return
	if not _payloads_have_size(towers_data, TOWER_PAYLOAD_SIZE):
		return
	# 可靠 RPC 仍可能在不同发送周期交错到达；较早 tick 不能回拨客户端命令时钟。
	if not _controller._accept_authoritative_server_tick(int(decoded[S_SERVER_TICK])):
		return

	_apply_units(units_data)
	_apply_projectiles(projectiles_data)
	_apply_towers(towers_data)
	_controller._elixir.elixir = float(decoded[S_CLIENT_ELIXIR])
	_controller._match_timer = float(decoded[S_MATCH_TIMER])
	_controller._overtime = bool(decoded[S_OVERTIME])
	_controller._update_timer_label()
	_controller._update_elixir_rate()
	_controller._snapshots_received += 1
	if _controller._auto_test and _controller._snapshots_received % 40 == 0:
		print("[测试] 客户端已收快照 ", _controller._snapshots_received, " 份，单位数=", _controller._client_units.size(), " 弹道数=", _controller._client_projectiles.size())


func _payloads_have_size(payloads: Array, expected_size: int) -> bool:
	for payload in payloads:
		if not payload is Array or payload.size() != expected_size:
			return false
	return true


func _apply_units(units_data: Array) -> void:
	var seen := {}
	for d: Array in units_data:
		seen[d[U_ID]] = true
		var u: Unit = _controller._client_units.get(d[U_ID])
		if u == null or not is_instance_valid(u):
			continue
		u.net_target_pos = Vector2(d[U_X], d[U_Y])
		u.sync_network_form(int(d[U_FORM]), int(d[U_FORM_CHANGE_SERIAL]))
		u.hp = float(d[U_HP])
		u.frozen_timer = 0.15 if int(d[U_FROZEN]) == 1 else 0.0
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
		u.stun_timer = 0.15 if u.net_stun_active else 0.0
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
		u.net_active_attack_speed_multiplier = maxf(float(d[U_ACTIVE_ATTACK_SPEED_MULTIPLIER]), 1.0)
		u.net_active_buff_active = int(d[U_ACTIVE_BUFF_ACTIVE]) == 1
		if _controller._active_skills.has(u.active_ability_id):
			var active_entry: Dictionary = _controller._active_skills[u.active_ability_id]
			active_entry["uses_remaining"] = maxi(int(d[U_ACTIVE_SKILL_USES_REMAINING]), 0)
			active_entry["cooldown_left"] = maxf(float(d[U_ACTIVE_SKILL_COOLDOWN]), 0.0)
			_controller._active_skills[u.active_ability_id] = active_entry
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
	for id in _controller._client_units:
		if not seen.has(id):
			gone.append(id)
	for id in gone:
		var u: Unit = _controller._client_units[id]
		if is_instance_valid(u):
			if u.is_building and not u.nav_cells.is_empty():
				_controller.unblock_nav_cells(u.nav_cells)
				u.nav_cells = []
			u.notify_visual_death()
			u.queue_free()
		_controller._client_units.erase(id)


func _apply_projectiles(projectiles_data: Array) -> void:
	var seen := {}
	if _controller._auto_test and not _controller._auto_projectile_seen and not projectiles_data.is_empty():
		_controller._auto_projectile_seen = true
		print("[测试] 客户端已收到弹道快照")
	for d: Array in projectiles_data:
		seen[d[P_ID]] = true
		var projectile: Dictionary = _controller._client_projectiles.get(d[P_ID], {
			"pos": Vector2(d[P_X], d[P_Y]),
			"target_pos": Vector2(d[P_X], d[P_Y]),
			"color": d[P_COLOR],
			"radius": d[P_RADIUS],
			"visual": StringName(d[P_VISUAL]),
			"direction": Vector2(d[P_DIRECTION_X], d[P_DIRECTION_Y]),
			"visual_height": float(d[P_VISUAL_HEIGHT]),
			"visual_offset": Vector2(d[P_VISUAL_OFFSET_X], d[P_VISUAL_OFFSET_Y]),
			"target_visual_offset": Vector2(d[P_VISUAL_OFFSET_X], d[P_VISUAL_OFFSET_Y]),
			"visual_scale": float(d[P_VISUAL_SCALE]),
			"first_strike": int(d[P_FIRST_STRIKE]) == 1,
		})
		projectile.target_pos = Vector2(d[P_X], d[P_Y])
		projectile.color = d[P_COLOR]
		projectile.radius = d[P_RADIUS]
		projectile.visual = StringName(d[P_VISUAL])
		projectile.direction = Vector2(d[P_DIRECTION_X], d[P_DIRECTION_Y])
		projectile.visual_height = float(d[P_VISUAL_HEIGHT])
		projectile.target_visual_offset = Vector2(d[P_VISUAL_OFFSET_X], d[P_VISUAL_OFFSET_Y])
		projectile.visual_scale = float(d[P_VISUAL_SCALE])
		projectile.first_strike = int(d[P_FIRST_STRIKE]) == 1
		_controller._client_projectiles[d[P_ID]] = projectile
	var gone := []
	for id in _controller._client_projectiles:
		if not seen.has(id):
			gone.append(id)
	for id in gone:
		_controller._client_projectiles.erase(id)


func _apply_towers(towers_data: Array) -> void:
	for i in range(mini(towers_data.size(), _controller._towers.size())):
		var tower_data: Array = towers_data[i]
		var tower_was_alive: bool = _controller._towers[i].hp > 0.0
		_controller._towers[i].hp = float(tower_data[T_HP])
		_controller._towers[i].activated = int(tower_data[T_ACTIVATED]) == 1
		_controller._towers[i].stun_timer = 0.15 if int(tower_data[T_STUNNED]) == 1 else 0.0
		var shield_ratio := clampf(float(tower_data[T_SHIELD_RATIO]), 0.0, 1.0)
		var shield_capacity_ratio := maxf(float(tower_data[T_SHIELD_CAPACITY_RATIO]), 0.0)
		_controller._towers[i].shield_max_hp = shield_capacity_ratio * _controller._towers[i].max_hp
		_controller._towers[i].shield_hp = shield_ratio * _controller._towers[i].shield_max_hp
		_controller._towers[i].shield_timer = 0.15 if _controller._towers[i].shield_hp > 0.0 else 0.0
		_controller._towers[i].shield_decay_rate = 0.0
		if tower_was_alive and _controller._towers[i].hp <= 0.0:
			_controller._towers[i].notify_visual_destroyed()
		if _controller._towers[i].hp <= 0.0 and not _controller._towers[i].nav_cells.is_empty():
			_controller.unblock_nav_cells(_controller._towers[i].nav_cells)
			_controller._towers[i].nav_cells = []
		_controller._towers[i].queue_redraw()


func send() -> void:
	var units_data := []
	var dead := []
	for id in _controller._net_units:
		# 非类型化读取：单位可能已 queue_free，类型化赋值会先于有效性检查报错。
		var u = _controller._net_units.get(id)
		if u == null or not is_instance_valid(u) or u.hp <= 0.0:
			dead.append(id)
			continue
		units_data.append(_unit_snapshot_payload(
			id,
			u,
			u.has_continuous_visual_target(),
			u.get_continuous_visual_target_position(),
			u.get_visual_facing_direction(),
		))
	for id in dead:
		_controller._net_units.erase(id)

	var projectiles_data := []
	for id in _controller._projectiles:
		var projectile: Dictionary = _controller._projectiles[id]
		projectiles_data.append(_projectile_snapshot_payload(id, projectile))

	var towers_data := []
	for tower in _controller._towers:
		towers_data.append(_tower_snapshot_payload(tower))
	var snapshot_bytes := var_to_bytes(_snapshot_packet(
		units_data,
		projectiles_data,
		towers_data,
		_controller._elixir_p1.elixir,
		_controller._match_timer,
		_controller._overtime,
	)).compress(FileAccess.COMPRESSION_DEFLATE)
	_controller._rpc_snapshot.rpc(snapshot_bytes)


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
	]


func _tower_snapshot_payload(tower: Tower) -> Array:
	return [
		tower.hp,
		1 if tower.activated else 0,
		1 if tower.stun_timer > 0.0 else 0,
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
	return [
		id, u.global_position.x, u.global_position.y, u.hp,
		1 if u.frozen_timer > 0.0 else 0,
		u.get_visual_state_code(), u.get_attack_visual_serial(),
		1 if u._shroud_active else 0,
		1 if has_continuous_target else 0, continuous_target_pos.x, continuous_target_pos.y,
		1 if u.slow_timer > 0.0 else 0,
		u.form_index, 1 if u.stun_timer > 0.0 else 0,
		u.get_visual_action_serial(), String(u.get_visual_action_name()),
		facing_direction.x, facing_direction.y,
		1 if u.is_attacking_structure_visual() else 0,
		u.form_change_serial,
		u.get_visual_action_duration(), u.get_visual_action_time_left(),
		u.get_locomotion_visual_state_code(),
		1 if u.empowered_attack_ready else 0, u.get_empowered_attack_visual_serial(),
		u.get_skill_resource_ratio(),
		1 if u.skill_resource_enabled else 0, u.active_speed_multiplier, u.active_attack_speed_multiplier,
		active_skill_state.get("uses_remaining", 0), active_skill_state.get("cooldown_left", 0.0),
		u.get_shield_ratio(),
		u.get_shield_capacity_ratio(),
		1 if u.active_buff_timer > 0.0 else 0,
		1 if u.is_attack_visual_first_strike() else 0,
	]
