extends "res://tests/suites/battle_suite.gd"
## 真实压缩/序列化数据与 RPC 生命周期事件重放，状态由独立协议实例持有。
const SNAP = preload("res://scripts/battle/network_snapshot_system.gd")
var _system: NetworkSnapshotSystem

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var saved_mode: String = main.mode
	var saved_system: NetworkSnapshotSystem = main._snapshot_system
	var saved_audio: GameAudioManager = main._audio_manager
	var saved_view = main._battle_presentation
	var saved_tick: int = main._authoritative_server_tick
	var saved_estimated: int = main._estimated_server_tick
	var saved_fraction: float = main._estimated_server_tick_fraction
	var saved_has_estimate: bool = main._has_estimated_server_tick
	var saved_received: int = main._snapshots_received
	var saved_elixir: float = main._elixir.elixir
	var saved_time: float = main._match_rules.time_left
	var saved_overtime: bool = main._match_rules.overtime
	main.mode = "client"
	main._audio_manager = null
	main._battle_presentation = null
	_system = SNAP.new(main, main._projectile_system)
	main._snapshot_system = _system
	main._projectile_system.apply_client_targets({1: {"pos": Vector2.ZERO, "visual_offset": Vector2.ZERO}})
	_system.reset_session("one")
	_expect(main._projectile_system.client_snapshot().is_empty(), "新会话由弹体所有者清除上一局客户端状态")
	var payload := _payload("ashe", 70001, 101)
	_deliver(90, [])
	_spawn(payload)
	var original: Unit = main._client_units[70001]
	_deliver(100, [])
	_expect(main._client_units.get(70001) == original, "Spawn101 先于 Snapshot100：旧快照不能删除新生实体")
	_deliver(102, [payload])
	_spawn(payload)
	_expect(main._client_units.size() == 1 and main._client_units.get(70001) == original, "重复 Spawn 不重建、不重复注册主动或导航")
	# 快照先到，可靠 Spawn 晚到。
	_system.reset_session("two")
	_deliver(102, [payload])
	var reconstructed: Unit = main._client_units.get(70001)
	_expect(is_instance_valid(reconstructed) and reconstructed.card_id == "ashe" and is_equal_approx(reconstructed._deploy_timer, 0.35), "未知实体由快照重建完整卡牌和剩余部署状态")
	_spawn(payload)
	_expect(main._client_units.get(70001) == reconstructed, "快照先于 Spawn：迟到生成事件幂等")
	_deliver(104, [payload]) # 丢失 103 不影响收敛。
	_expect(_system.lifecycle.snapshot_tick == 104 and main._client_units.size() == 1, "丢一份快照后实体集合仍收敛")
	main._rpc_unit_died(70001, true, "two", 106)
	main._rpc_unit_died(70001, true, "two", 106)
	_deliver(105, [payload])
	_spawn(payload)
	_expect(main._client_units.is_empty(), "可靠死亡先于旧快照、重复销毁与迟到 Spawn 均不能复活实体")
	# 无本地 Spawn 的死亡事件也必须留下屏障。
	var unborn := _payload("garen", 70002, 110)
	main._rpc_unit_died(70002, false, "two", 111)
	_spawn(unborn)
	_deliver(110, [unborn])
	_expect(main._client_units.is_empty(), "Death 先于 Spawn/快照：保留销毁标记，不生成已死对象")
	_system.reset_session("three")
	_deliver(112, [])
	_spawn(unborn)
	_expect(main._client_units.is_empty(), "全量快照已越过生存窗口时拒绝迟到 Spawn")
	_deliver(113, [payload], "two")
	_spawn(payload, "two")
	_expect(main._client_units.is_empty() and _system.lifecycle.snapshot_tick == 112, "上一局快照与 Spawn 不污染本局")
	# 新局复用实体 id 与小 Tick，不受上一局时钟和墓碑污染。
	_system.reset_session("four")
	var fresh := _payload("garen", 70001, 1)
	_deliver(2, [fresh])
	main._rpc_unit_died(70001, false, "two", 999)
	_expect(main._client_units.has(70001) and main._client_units[70001].card_id == "garen" and main.get_authoritative_server_tick() == 2, "新局 id 复用、时钟归零且旧局死亡事件无效")
	_deliver(3, [])
	_deliver(2, [fresh])
	_expect(main._client_units.is_empty(), "缺席新快照确认销毁后，旧快照不能回退集合")
	# 建筑重建保留基座和编队身份，重复消息不多注册导航阻挡。
	var building := _payload("sun_disc", 70003, 4)
	building[SNAP.U_SPAWN].args[8] = 12
	building[SNAP.U_SPAWN].args[11] = true
	_deliver(5, [building])
	var unit: Unit = main._client_units[70003]
	var cells := unit.nav_cells.duplicate()
	_spawn(building)
	_expect(unit.is_building and unit.built_on_tower_ruin and unit.deployment_group_id == 12 and not cells.is_empty() and unit.nav_cells == cells, "快照重建建筑保留塔墟/编队信息，重复 Spawn 不重复占位")
	_deliver(6, [])
	_expect(unit.nav_cells.is_empty() and main._client_units.is_empty(), "快照销毁建筑统一释放导航占位")
	_system.reset_session("same_tick")
	var same_tick := _payload("ashe", 70004, 10)
	same_tick[SNAP.U_SPAWN].birth_revision = 2
	_spawn(same_tick)
	_deliver(10, [], "", 1)
	_expect(main._client_units.has(70004), "同 Tick 旧快照的生命周期序号较小，不能删除随后出生的实体")
	_deliver(10, [same_tick], "", 2)
	_expect(_system.lifecycle.snapshot_revision == 2 and main._client_units.has(70004), "同 Tick 较新生命周期全量快照仍可接受")
	_deliver(10, [], "", 1)
	_expect(main._client_units.has(70004), "同 Tick 较旧生命周期快照不能覆盖新集合")
	_system.reset_session("structure_rush")
	var herald := _payload("rift_herald", 71000, 1)
	herald[SNAP.U_DEPLOY_LEFT] = 0.0
	herald[SNAP.U_ACTION_SERIAL] = 3
	herald[SNAP.U_ACTION_NAME] = "rush_dash"
	herald[SNAP.U_ACTION_DURATION] = 0.5
	herald[SNAP.U_ACTION_TIME_LEFT] = 0.3
	_deliver(2, [herald])
	var replica: Unit = main._client_units[71000]
	_expect(replica.get_visual_action_name() == &"rush_dash" and is_equal_approx(replica.get_visual_action_time_left(), 0.3) and replica.is_structure_rushing(), "先锋客户端只读冲撞窗口并锁住主动技能")
	var collision: Array = [herald.duplicate(true)]
	collision[0][SNAP.U_HP] = 1260
	collision[0][SNAP.U_ACTION_SERIAL] = 4
	collision[0][SNAP.U_ACTION_NAME] = "rush_hit"
	for index in 6: collision.append(_payload("voidmite", 71001 + index, 3))
	_deliver(4, collision)
	_deliver(4, collision)
	_spawn(collision[1])
	_expect(main._client_units.size() == 7 and replica.hp == 1260 and replica.get_visual_action_serial() == 4, "撞击快照恢复先锋自伤和六只蠕虫，重复快照/出生不重复召唤")
	_system.reset_session("")
	main._snapshot_system = saved_system
	main.mode = saved_mode
	main._audio_manager = saved_audio
	main._battle_presentation = saved_view
	main._authoritative_server_tick = saved_tick
	main._estimated_server_tick = saved_estimated
	main._estimated_server_tick_fraction = saved_fraction
	main._has_estimated_server_tick = saved_has_estimate
	main._snapshots_received = saved_received
	main._elixir.elixir = saved_elixir
	main._match_rules.time_left = saved_time
	main._match_rules.overtime = saved_overtime
	main._update_timer_label()

func _payload(card: String, id: int, birth: int) -> Array:
	var unit := Unit.new()
	unit.card_id = card
	unit.setup(1, CardDB.get_unit_stats(card), card)
	unit.position = Vector2(240, 360)
	unit._deploy_timer = 0.35
	var data := _system._unit_snapshot_payload(id, unit)
	data[SNAP.U_SPAWN].birth_tick = birth
	data[SNAP.U_SPAWN].birth_revision = birth
	unit.free()
	return data

func _spawn(payload: Array, session: String = "") -> void:
	var args: Array = payload[SNAP.U_SPAWN].args.duplicate(true)
	args.append(_system.lifecycle.session_id if session.is_empty() else session)
	args.append(payload[SNAP.U_SPAWN].birth_tick)
	args.append(payload[SNAP.U_SPAWN].birth_revision)
	# 对 RPC 参数也做字节往返，防止测试仅修改本地引用。
	_main._rpc_spawn_unit.callv(bytes_to_var(var_to_bytes(args)))

func _deliver(tick: int, units: Array, session: String = "", revision: int = -1) -> void:
	var packet := _system._snapshot_packet(units, [], [], 5.0, 180.0, false)
	packet[SNAP.S_SERVER_TICK] = tick
	packet[SNAP.S_LIFECYCLE_REVISION] = tick if revision < 0 else revision
	packet[SNAP.S_SESSION] = _system.lifecycle.session_id if session.is_empty() else session
	_main._rpc_snapshot(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE))
