class_name NetworkSnapshotSystem
extends RefCounted
## 20Hz 单位/塔/弹体快照的序列化与客户端应用。RPC 端点仍保留在 Main，协议载荷不变。

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
	if not decoded is Array or decoded.size() < 7:
		return
	var units_data: Array = decoded[0]
	var projectiles_data: Array = decoded[1]
	var towers_data: Array = decoded[2]
	var _e0 := float(decoded[3])
	var e1 := float(decoded[4])
	var mt := float(decoded[5])
	var ot := bool(decoded[6])
	var seen := {}
	for d in units_data:
		seen[d[0]] = true
		var u: Unit = _controller._client_units.get(d[0])
		if u == null or not is_instance_valid(u):
			continue
		u.net_target_pos = Vector2(d[1], d[2])
		if d.size() >= 23:
			u.sync_network_form(int(d[15]), int(d[22]))
		elif d.size() >= 16:
			u.sync_network_form(int(d[15]))
		u.hp = d[3]
		u.frozen_timer = 0.15 if d[4] == 1 else 0.0
		u._charged = d[5] == 1
		if d.size() >= 8:
			u.net_visual_state = d[6]
			u.net_facing_x = d[7]
		if d.size() >= 9:
			u.net_attack_visual_serial = d[8]
		if d.size() >= 10:
			u.net_shroud_active = d[9] == 1
		if d.size() >= 13:
			u.net_has_continuous_target = d[10] == 1
			u.net_continuous_target_pos = Vector2(d[11], d[12])
			if _controller._auto_test and not _controller._auto_continuous_target_seen and u.net_has_continuous_target:
				_controller._auto_continuous_target_seen = true
				print("[测试] 客户端已收到持续吐息目标端点")
		if d.size() >= 15:
			u.net_shield_active = d[13] == 1
			u.net_slow_active = d[14] == 1
		if d.size() >= 19:
			u.net_stun_active = d[16] == 1
			u.stun_timer = 0.15 if u.net_stun_active else 0.0
			var action_serial := int(d[17])
			if action_serial >= u.net_visual_action_serial:
				u.net_visual_action_serial = action_serial
				u.net_visual_action_name = StringName(d[18])
		if d.size() >= 21:
			u.net_facing_direction = Vector2(d[19], d[20])
		if d.size() >= 22:
			u.net_attacking_structure = d[21] == 1
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
	# 快照中消失的单位 = 已死亡
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
	var seen_projectiles := {}
	if _controller._auto_test and not _controller._auto_projectile_seen and not projectiles_data.is_empty():
		_controller._auto_projectile_seen = true
		print("[测试] 客户端已收到弹道快照")
	for d in projectiles_data:
		seen_projectiles[d[0]] = true
		var projectile: Dictionary = _controller._client_projectiles.get(d[0], {
			"pos": Vector2(d[1], d[2]),
			"target_pos": Vector2(d[1], d[2]),
			"color": d[3],
			"radius": d[4],
			"visual": StringName(d[5]) if d.size() >= 6 else &"orb",
			"direction": Vector2(d[6], d[7]) if d.size() >= 8 else Vector2.UP,
			"visual_height": float(d[8]) if d.size() >= 9 else 0.0,
			"visual_offset": Vector2(d[9], d[10]) if d.size() >= 11 else Vector2.ZERO,
			"target_visual_offset": Vector2(d[9], d[10]) if d.size() >= 11 else Vector2.ZERO,
		})
		projectile.target_pos = Vector2(d[1], d[2])
		projectile.color = d[3]
		projectile.radius = d[4]
		if d.size() >= 6:
			projectile.visual = StringName(d[5])
		if d.size() >= 8:
			projectile.direction = Vector2(d[6], d[7])
		if d.size() >= 9:
			projectile.visual_height = float(d[8])
		if d.size() >= 11:
			projectile.target_visual_offset = Vector2(d[9], d[10])
		_controller._client_projectiles[d[0]] = projectile
	var gone_projectiles := []
	for id in _controller._client_projectiles:
		if not seen_projectiles.has(id):
			gone_projectiles.append(id)
	for id in gone_projectiles:
		_controller._client_projectiles.erase(id)
	for i in range(mini(towers_data.size(), _controller._towers.size())):
		var tower_was_alive: bool = _controller._towers[i].hp > 0.0
		_controller._towers[i].hp = towers_data[i][0]
		_controller._towers[i].activated = towers_data[i][1] == 1
		if towers_data[i].size() >= 3:
			_controller._towers[i].stun_timer = 0.15 if towers_data[i][2] == 1 else 0.0
		if tower_was_alive and _controller._towers[i].hp <= 0.0:
			_controller._towers[i].notify_visual_destroyed()
		if _controller._towers[i].hp <= 0.0 and not _controller._towers[i].nav_cells.is_empty():
			_controller.unblock_nav_cells(_controller._towers[i].nav_cells)
			_controller._towers[i].nav_cells = []
		_controller._towers[i].queue_redraw()
	# 客户端玩家是 team1，金币显示 e1
	# team0 金币仍保留在协议中供载荷向后兼容；客户端界面显示 team1 的 e1。
	_controller._elixir.elixir = e1
	_controller._match_timer = mt
	_controller._overtime = ot
	_controller._update_timer_label()
	_controller._update_elixir_rate()
	_controller._snapshots_received += 1
	if _controller._auto_test and _controller._snapshots_received % 40 == 0:
		print("[测试] 客户端已收快照 ", _controller._snapshots_received, " 份，单位数=", _controller._client_units.size(), " 弹道数=", _controller._client_projectiles.size())


func send() -> void:
	var units_data := []
	var dead := []
	for id in _controller._net_units:
		# 非类型化读取：单位可能已 queue_free，类型化赋值会先于有效性检查报错
		var u = _controller._net_units.get(id)
		if u == null or not is_instance_valid(u) or u.hp <= 0.0:
			dead.append(id)
			continue
		var has_continuous_target: bool = u.has_continuous_visual_target()
		var continuous_target_pos: Vector2 = u.get_continuous_visual_target_position()
		var facing_direction: Vector2 = u.get_visual_facing_direction()
		units_data.append([
			id, u.global_position.x, u.global_position.y, u.hp,
			1 if u.frozen_timer > 0.0 else 0, 1 if u.is_charged() else 0,
			u.get_visual_state_code(), u.get_facing_x(), u.get_attack_visual_serial(),
			1 if u._shroud_active else 0,
			1 if has_continuous_target else 0, continuous_target_pos.x, continuous_target_pos.y,
			1 if u.shield_hp > 0.0 else 0, 1 if u.slow_timer > 0.0 else 0,
			u.form_index, 1 if u.stun_timer > 0.0 else 0,
			u.get_visual_action_serial(), String(u.get_visual_action_name()),
			facing_direction.x, facing_direction.y,
			1 if u.is_attacking_structure_visual() else 0,
			u.form_change_serial,
		])
	for id in dead:
		_controller._net_units.erase(id)
	var towers_data := []
	for t in _controller._towers:
		# [血量, 国王塔是否已激活, 是否眩晕]
		towers_data.append([t.hp, 1 if t.activated else 0, 1 if t.stun_timer > 0.0 else 0])
	var projectiles_data := []
	for id in _controller._projectiles:
		var projectile: Dictionary = _controller._projectiles[id]
		var visual_offset: Vector2 = projectile.get("visual_offset", Vector2.ZERO)
		projectiles_data.append([
			id, projectile.pos.x, projectile.pos.y, projectile.color, projectile.radius,
			String(projectile.visual), projectile.direction.x, projectile.direction.y,
			projectile.get("visual_height", 0.0), visual_offset.x, visual_offset.y,
		])
	var snapshot_bytes := var_to_bytes([
		units_data, projectiles_data, towers_data,
		_controller._elixir.elixir, _controller._elixir_p1.elixir, _controller._match_timer, _controller._overtime,
	]).compress(FileAccess.COMPRESSION_DEFLATE)
	_controller._rpc_snapshot.rpc(snapshot_bytes)
