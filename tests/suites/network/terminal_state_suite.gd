extends RefCounted
## 两个独立 Main 场景，经正式命中/终局与真实编码数据验证可靠终态。
class CountingSnapshot extends NetworkSnapshotSystem:
	var public_captures := 0
	func capture_public_frame() -> Array:
		public_captures += 1
		return super.capture_public_frame()

class ObservedClientSnapshot extends NetworkSnapshotSystem:
	var applied_projectiles: Dictionary = {}
	func _apply_projectiles(payloads: Array) -> void:
		super._apply_projectiles(payloads)
		# 记录正式应用到终局清场之间的只读结果，不补字段或改变输入。
		applied_projectiles = _projectile_system.visible_view()

func run(harness: Object) -> void:
	var host = load("res://scenes/main.tscn").instantiate()
	var client = load("res://scenes/main.tscn").instantiate()
	harness.root.add_child(host)
	harness.root.add_child(client)
	host._start_local()
	client._start_local()
	host.set_process(false)
	client.set_process(false)
	host._ai.enabled = false
	client._ai.enabled = false
	var snapshots := CountingSnapshot.new(host, host._projectile_system)
	host._snapshot_system = snapshots
	client._snapshot_system = ObservedClientSnapshot.new(client, client._projectile_system)
	host._snapshot_system.reset_session("terminal")
	host.runtime.mode = "server"
	client.runtime.mode = "client"
	client.runtime.local_team = 1
	client._snapshot_system.reset_session("terminal")
	client.runtime.session.session_id = "terminal"
	client.runtime.session.opponent_id = 1
	client.runtime.session.phase = MatchSession.Phase.RUNNING
	host.runtime.bind_account(1, ElixirManager.new())
	host.add_child(host.runtime.account(1))
	_check_public_frame(harness, host, snapshots)
	var cancelled_units: Array[Unit] = []
	for _reason in ActionCancellation.REASONS:
		var source: Unit = host._spawn_unit(UnitSpawnRequest.new(0, "garen", Vector2(100 + cancelled_units.size() * 50, 900), {"deploy_time_override": 0.0}))
		cancelled_units.append(source)
	# 先复制出生，再经真实 RPC 接收每种生产取消载荷；快照随后重复交付仍应幂等。
	client._rpc_snapshot(host._snapshot_system.capture())
	for index in cancelled_units.size():
		var source := cancelled_units[index]
		var reason: StringName = ActionCancellation.REASONS[index]
		source.cancel_basic_attack(reason)
		harness._expect(Unit.valid_action_cancellation(source.last_action_cancellation), "生产取消合同接受：" + String(reason))
		client._rpc_action_cancelled("terminal", source.net_id, bytes_to_var(var_to_bytes(source.last_action_cancellation)))
		var replica: Unit = client.world.replica_units_snapshot()[source.net_id]
		harness._expect(replica.last_action_cancellation == source.last_action_cancellation, "即时取消 RPC 字节往返：" + String(reason))
		source.cancel_basic_attack(reason)
	host.runtime._sim_tick_id = 100
	var before: PackedByteArray = host._snapshot_system.capture()
	client._rpc_snapshot(before)
	for source in cancelled_units:
		var replica: Unit = client.world.replica_units_snapshot()[source.net_id]
		harness._expect(replica.action_cancel_serial == 2 and replica.last_action_cancellation == source.last_action_cancellation, "普通快照取消往返：" + String(source.last_action_cancellation.reason))
		var malformed: Dictionary = source.last_action_cancellation.duplicate(true)
		malformed.reason = "unregistered_reason"
		malformed.serial = 100
		client._rpc_action_cancelled("terminal", source.net_id, malformed)
		harness._expect(replica.action_cancel_serial == 2 and not Unit.valid_action_cancellation(malformed), "即时取消拒绝未知原因且不污染序号")
		source.cancel_basic_attack(ActionCancellation.REASONS[cancelled_units.find(source)])
	var malformed_packet: Array = bytes_to_var(before.decompress_dynamic(1024 * 1024, FileAccess.COMPRESSION_DEFLATE))
	malformed_packet[NetworkSnapshotSystem.S_SERVER_TICK] = 101
	malformed_packet[NetworkSnapshotSystem.S_UNITS][0][NetworkSnapshotSystem.U_CANCELLATION].reason = "unregistered_reason"
	harness._expect(not client._snapshot_system.apply_decoded(client._snapshot_system.decode_validated(var_to_bytes(malformed_packet).compress(FileAccess.COMPRESSION_DEFLATE))), "普通快照整体拒绝未知取消原因")
	var initial_hp: float = client.world.king(1).hp
	var cues: Array[StringName] = []
	var listener := func(card: String, cue: StringName, _pos: Vector2):
		if card == "match": cues.append(cue)
	client._audio_manager.cue_played.connect(listener)
	# 双方动作/Buff、区域、飞行声与排程同时在场；终局必须统一收尾。
	for main in [host, client]:
		var unit := Unit.new()
		unit.card_id = "masteryi"
		unit.setup(0, CardDB.get_card("masteryi"), "终局音轨")
		main.add_child(unit)
		main._audio_manager.attach_unit(unit, CardDB.get_card("masteryi"))
		main._audio_manager._start_sustain(unit, main._audio_manager._unit_entries[unit.get_instance_id()], &"active_buff", &"buff")
		main._audio_manager.start_zone_audio(100, "anivia", 0, "frost_storm", Vector2(360, 640), 30.0)
		main._audio_manager.start_projectile_launch(100, {"card_id": "gnar", "form": 0, "serial": 1}, Vector2(360, 640))
		main._skill_presentation.frontal_effects.append({"timer": 30.0})
		main.runtime._commands.enqueue_card(0, "garen", Vector2(300, 800), 1000)
		main.runtime._commands.enqueue_deployment(0, "", Vector2.ZERO, 10.0, -1, -1, -1.0)
		main.runtime._commands.enqueue_impact(unit, {}, 10.0, &"impact", -1)
		harness._expect(not main._audio_manager._sustain_players.is_empty() and not main._audio_manager._zone_players.is_empty() and not main._audio_manager._projectile_launch_players.is_empty(), "终局测试开始时确实同时存在 Buff、区域和飞行音轨")
	# 快照刚发出后，下一 Tick 的真实弹体击杀水晶。
	host.runtime._sim_tick_id = 101
	# 本枚强化弹体未出现在任何普通快照中，来源释放后仅由可靠终态首次恢复。
	var speed_source: Unit = host._spawn_unit(UnitSpawnRequest.new(0, "anivia", Vector2(90, 1120), {"deploy_time_override": 0.0}))
	var speed_target: Unit = host._spawn_unit(UnitSpawnRequest.new(1, "garen", Vector2(600, 1120), {"deploy_time_override": 0.0}))
	speed_source.buffs.apply(&"ranged_attack", speed_source.status_source("terminal_speed"), 2.0, {"projectile_speed_multiplier": 1.75})
	var expected_speed: float = speed_source.projectile_speed * 1.75
	harness._expect(host.launch_attack(speed_source, speed_target, 5.0, speed_source.projectile_speed, 0.0, 0.0, Color.WHITE), "终态测试经真实发射入口创建强化速度弹体")
	var flight_id: int = host._projectile_system.projectiles.keys().back()
	speed_source.buffs.advance(2.0)
	speed_source.free()
	harness._expect(not client._projectile_system.client_snapshot().has(flight_id), "终态前客户端完全未知该在途弹体")
	var captures_before_end: int = snapshots.public_captures
	host.launch_attack(host.world.towers_snapshot()[0], host.world.king(1), 100000.0, 100000.0, 0.0, 0.0, Color.WHITE)
	host._tick_projectiles(0.05)
	host.runtime._tick_match_rules(0.05)
	harness._expect(host.runtime.game_over and host.world.king(1).hp == 0.0 and client.world.king(1).hp == initial_hp, "致胜一击发生在上次普通快照之后，客户端尚未知道伤害")
	harness._expect(snapshots.public_captures == captures_before_end + 1, "终局清场前公共单位/弹体/塔/时钟只采集一次")
	var terminal: Dictionary = bytes_to_var(var_to_bytes(host._terminal_result))
	_check_terminal_speed_rejection(harness, client, terminal, flight_id)
	var invalid_terminal: Dictionary = terminal.duplicate(true)
	var invalid_final: Array = bytes_to_var(invalid_terminal.terminal_state.decompress_dynamic(1024 * 1024, FileAccess.COMPRESSION_DEFLATE))
	invalid_final[NetworkSnapshotSystem.S_UNITS][0][NetworkSnapshotSystem.U_CANCELLATION].reason = "unregistered_reason"
	invalid_terminal.terminal_state = var_to_bytes(invalid_final).compress(FileAccess.COMPRESSION_DEFLATE)
	client._rpc_end(invalid_terminal)
	harness._expect(not client.runtime.game_over and not client._snapshot_system.terminal_applied, "终局快照整体拒绝未知取消原因，仍可接收合法终态")
	client._rpc_end(terminal)
	harness._expect(client._snapshot_system.applied_projectiles.has(flight_id) and client._snapshot_system.applied_projectiles[flight_id].speed == expected_speed and client._snapshot_system.applied_projectiles[flight_id].visual_path.progress > 0.0, "可靠终态正式应用首次恢复未知已飞弹体的原强化速度，随后才清场")
	for source in cancelled_units:
		var replica: Unit = client.world.replica_units_snapshot()[source.net_id]
		harness._expect(replica.action_cancel_serial == 3 and replica.last_action_cancellation == source.last_action_cancellation, "终局快照取消往返：" + String(source.last_action_cancellation.reason))
	harness._expect(client.runtime.game_over and client.world.king(1).hp == host.world.king(1).hp and client.world.king(1).nav_cells.is_empty(), "可靠终态在结束 UI 前应用最终生命与塔摧毁/导航状态")
	harness._expect(terminal.winner_team == 0 and terminal.reason == "nexus" and terminal.final_tick == 101 and cues.is_empty(), "结果使用队伍/原因/最终 Tick，客户端爆炸第五秒前不播失败")
	for main in [host, client]:
		harness._expect(main._audio_manager._nexus_players.size() == 1, "主客各自保留本地水晶爆炸实例")
		var player: AudioStreamPlayer2D = main._audio_manager._nexus_players.values()[0]
		harness._expect(player.playing, "终局清理不停止当前水晶爆炸")
		main._audio_manager._tick_terminal_audio(5.0)
		player.finished.emit() # 第五秒播报后，爆炸自然结束不重复播报。
		player.finished.emit()
	harness._expect(cues == [&"defeat"], "爆炸第五秒只触发一次本地阵营失败播报")
	var child_count: int = client.get_child_count()
	client._rpc_end(terminal)
	client._rpc_snapshot(before)
	client._sim_step(0.05)
	harness._expect(client.get_child_count() == child_count and cues.size() == 1 and client.world.king(1).hp == 0.0 and client.get_authoritative_server_tick() == 101, "重复终局与旧快照不重复 UI/声音、不复活塔、不推进模拟")
	for main in [host, client]:
		harness._expect(main.runtime._commands.inspect_cards().is_empty() and main.runtime._commands.inspect_deployments().is_empty() and main.runtime._commands.inspect_impacts().is_empty() and main._projectile_system.projectiles.is_empty() and main._projectile_system.client_snapshot().is_empty() and main._skill_presentation.frontal_effects.is_empty(), "终局清理所有待执行命令、区域和在途弹体")
		main._audio_manager._process(1.0)
		main._audio_manager.start_zone_audio(101, "anivia", 0, "frost_storm", Vector2.ZERO, 30.0)
		main._audio_manager.start_projectile_launch(101, {"card_id": "gnar", "form": 0, "serial": 1}, Vector2.ZERO)
		harness._expect(main._audio_manager.battle_audio_stopped(), "终局持续声、区域声、飞行声与建筑待机全部停止，轮询和迟到事件不重启")
		harness._expect(not main.play_card(0, "garen", Vector2(300, 800), {"immediate": true}), "终局后公共出牌入口拒绝新命令")
	# 终态必须覆盖相同 Tick 已收到的普通快照；最终 Tick/会话不匹配则拒绝。
	client.runtime.game_over = false
	client.runtime._match_rules.finished = false
	client._snapshot_system.reset_session("terminal2")
	client._audio_manager.begin_battle()
	var final_packet: Array = bytes_to_var(terminal.terminal_state.decompress_dynamic(1024 * 1024, FileAccess.COMPRESSION_DEFLATE))
	final_packet[NetworkSnapshotSystem.S_SESSION] = "terminal2"
	var old_packet: Array = final_packet.duplicate(true)
	old_packet[NetworkSnapshotSystem.S_TOWERS][-1][NetworkSnapshotSystem.T_HP] = 10.0
	client._rpc_snapshot(var_to_bytes(old_packet).compress(FileAccess.COMPRESSION_DEFLATE))
	terminal.session_id = "terminal2"
	terminal.terminal_state = var_to_bytes(final_packet).compress(FileAccess.COMPRESSION_DEFLATE)
	var mismatched := terminal.duplicate(true)
	mismatched.final_tick = 102
	client._rpc_end(mismatched)
	harness._expect(not client.runtime.game_over, "终态信封与快照 Tick 不一致时整体拒绝")
	client._rpc_end(terminal)
	harness._expect(client.runtime.game_over and client._snapshot_system.terminal_applied, "相同 Tick 的可靠最终状态仍能覆盖普通快照")
	host.free()
	client.free()
	# 新场景与真实菜单重载相同生命周期：终局音频屏障不会污染下一局。
	var next = load("res://scenes/main.tscn").instantiate()
	harness.root.add_child(next)
	next._start_local()
	next.set_process(false)
	harness._expect(not next.runtime.game_over and not next.runtime._match_rules.finished and next._terminal_result.is_empty() and not next._snapshot_system.terminal_applied and not next._audio_manager._battle_ended, "退出后新局重建比赛、网络与音频生命周期")
	next.free()

func _check_terminal_speed_rejection(harness: Object, client, terminal: Dictionary, flight_id: int) -> void:
	var packet: Array = bytes_to_var(terminal.terminal_state.decompress_dynamic(NetworkSnapshotSystem.MAX_DECODED_BYTES, FileAccess.COMPRESSION_DEFLATE))
	var rows: Array = packet[NetworkSnapshotSystem.S_PROJECTILES]
	var index := -1
	for row_index in rows.size():
		if int(rows[row_index][NetworkSnapshotSystem.P_ID]) == flight_id:
			index = row_index
			break
	harness._expect(index >= 0 and rows[index].size() == 15 and float(rows[index][NetworkSnapshotSystem.P_SPEED]) > 0.0, "终局清场前真实采集保留15字段在途弹体")
	if index < 0: return
	var clock := [client._authoritative_server_tick, client._estimated_server_tick, client._estimated_server_tick_fraction, client._has_estimated_server_tick]
	var lifecycle := [client._snapshot_system.lifecycle.snapshot_tick, client._snapshot_system.lifecycle.snapshot_revision, client._snapshot_system.lifecycle.snapshot_ids.duplicate(), client._snapshot_system.lifecycle.spawns.duplicate(true)]
	var units: Dictionary = client.world.replica_units_snapshot().duplicate()
	var health := {}
	for id in units: health[id] = units[id].hp
	var towers: Array = client.world.towers_snapshot().map(func(tower): return tower.hp)
	var wallet: float = client.runtime.account(0 if client.runtime.mode == "server" else client.runtime.local_team).elixir
	var growth: Dictionary = client.runtime._card_growth.snapshot()
	var timer: float = client.runtime._match_rules.time_left
	var projectiles: Dictionary = client._projectile_system.client_snapshot()
	var observed: Dictionary = client._snapshot_system.applied_projectiles
	# 完整类型/有限值/正数域矩阵由NetworkLifecycle维护；这里保留真实终局入口的代表边界。
	for invalid in ["320", INF, 0.0, "legacy14", "legacy115"]:
		var bad := packet.duplicate(true)
		if invalid is String and invalid == "legacy14": bad[NetworkSnapshotSystem.S_PROJECTILES][index].pop_back()
		elif invalid is String and invalid == "legacy115": bad[NetworkSnapshotSystem.S_VERSION] = 115
		else: bad[NetworkSnapshotSystem.S_PROJECTILES][index][NetworkSnapshotSystem.P_SPEED] = invalid
		var envelope := terminal.duplicate(true)
		envelope.terminal_state = var_to_bytes(bad).compress(FileAccess.COMPRESSION_DEFLATE)
		client._rpc_end(envelope)
		var unchanged: bool = not client.runtime.game_over and not client._snapshot_system.terminal_applied and client._terminal_result.is_empty() and client.world.replica_units_snapshot() == units and client.runtime.account(0 if client.runtime.mode == "server" else client.runtime.local_team).elixir == wallet and client.runtime._card_growth.snapshot() == growth and client.runtime._match_rules.time_left == timer and client.world.towers_snapshot().map(func(tower): return tower.hp) == towers and client._projectile_system.client_snapshot() == projectiles and is_same(client._snapshot_system.applied_projectiles, observed)
		unchanged = unchanged and [client._authoritative_server_tick, client._estimated_server_tick, client._estimated_server_tick_fraction, client._has_estimated_server_tick] == clock and [client._snapshot_system.lifecycle.snapshot_tick, client._snapshot_system.lifecycle.snapshot_revision, client._snapshot_system.lifecycle.snapshot_ids, client._snapshot_system.lifecycle.spawns] == lifecycle
		for id in units: unchanged = unchanged and units[id].hp == health[id]
		harness._expect(unchanged, "真实终局RPC整体拒绝速度/旧格式且实体、塔、时钟、经济、成长、终态无部分写入：" + str(invalid))

func _check_public_frame(harness: Object, host, snapshots: CountingSnapshot) -> void:
	var captures := snapshots.public_captures
	snapshots.send()
	harness._expect(snapshots.public_captures == captures, "没有真实接收端时send不采集公共世界")
	var saved_growth: Dictionary = host.runtime._card_growth.snapshot()
	var blue_wallet: ElixirManager = host.runtime.account(0)
	var red_wallet: ElixirManager = host.runtime.account(1)
	var blue_elixir: float = blue_wallet.elixir
	var red_elixir: float = red_wallet.elixir
	blue_wallet.elixir = 3.0
	red_wallet.elixir = 8.0
	host.runtime._card_growth.replace_replica({0: {"kayn": {"ranged": 1, "melee": 2, "unlocked": "kayn"}}, 1: {"kayn": {"ranged": 2, "melee": 3, "unlocked": "kayn"}}})
	var frame := snapshots.capture_public_frame()
	var fixed_frame := var_to_bytes(frame)
	var blue: Array = bytes_to_var(snapshots.encode_frame(frame, 0).decompress_dynamic(NetworkSnapshotSystem.MAX_DECODED_BYTES, FileAccess.COMPRESSION_DEFLATE))
	var red: Array = bytes_to_var(snapshots.encode_frame(frame, 1).decompress_dynamic(NetworkSnapshotSystem.MAX_DECODED_BYTES, FileAccess.COMPRESSION_DEFLATE))
	harness._expect(snapshots.public_captures == captures + 1 and frame.is_read_only() and frame[NetworkSnapshotSystem.S_UNITS].is_read_only() and frame[NetworkSnapshotSystem.S_CLIENT_ELIXIR] == null and frame[NetworkSnapshotSystem.S_CARD_GROWTH] == null and var_to_bytes(frame) == fixed_frame, "双端编码共享一份冻结公共帧，私有占位不被写回")
	harness._expect(blue[NetworkSnapshotSystem.S_CLIENT_ELIXIR] == 3.0 and red[NetworkSnapshotSystem.S_CLIENT_ELIXIR] == 8.0 and blue[NetworkSnapshotSystem.S_CARD_GROWTH].keys() == [0] and red[NetworkSnapshotSystem.S_CARD_GROWTH].keys() == [1], "同一公共帧分别投影本方钱包与成长，不泄露对手私有状态")
	for field in [NetworkSnapshotSystem.S_UNITS, NetworkSnapshotSystem.S_PROJECTILES, NetworkSnapshotSystem.S_TOWERS, NetworkSnapshotSystem.S_SERVER_TICK, NetworkSnapshotSystem.S_SESSION, NetworkSnapshotSystem.S_LIFECYCLE_REVISION, NetworkSnapshotSystem.S_MATCH_TIMER, NetworkSnapshotSystem.S_OVERTIME]:
		harness._expect(blue[field] == red[field] and blue[field] == frame[field], "两端公共世界/时钟完全相同：%d" % field)
	blue_wallet.elixir = blue_elixir
	red_wallet.elixir = red_elixir
	host.runtime._card_growth.replace_replica(saved_growth)
