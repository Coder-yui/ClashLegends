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
	_check_payload_contract()
	_check_bleeding_projection()
	_system.reset_session("death-form")
	var dormant := _payload("sion", 76000, 1)
	dormant[SNAP.U_CANCELLATION] = {"serial": 1, "reason": "death_form", "attack": 0, "action": 0, "form": 0, "cancelled_action": 0, "cancelled_deployment": false}
	dormant[SNAP.U_HP] = 0
	dormant[SNAP.U_DEATH_FORM] = [true, 39]
	dormant[SNAP.U_ACTION_PERMISSIONS] = 0
	dormant[SNAP.U_ACTION_SERIAL] = 1
	dormant[SNAP.U_ACTION_NAME] = "death_form"
	dormant[SNAP.U_ACTION_DURATION] = 2.0
	dormant[SNAP.U_ACTION_TIME_LEFT] = 1.95
	_deliver(2, [dormant])
	var resting: Unit = main._client_units[76000]
	_expect(resting.hp == 0 and resting.death_form.waiting() and not resting.presentation_state().dead, "复生零血快照重建保留模型与同一实体")
	var half_reborn: Array = dormant.duplicate(true)
	half_reborn[SNAP.U_DEATH_FORM] = [true, 20]
	half_reborn[SNAP.U_ACTION_TIME_LEFT] = 1.0
	_deliver(20, [half_reborn])
	resting.presentation_state().advance_health_bar(0.0)
	_expect(resting.hp == 0 and is_equal_approx(resting.presentation_state().health_ratio, 0.5), "客户端按权威复生快照显示半血，真实生命仍为零")
	var awakened: Array = dormant.duplicate(true)
	awakened[SNAP.U_HP] = 2400
	awakened[SNAP.U_FORM] = 1
	awakened[SNAP.U_FORM_CHANGE_SERIAL] = 1
	awakened[SNAP.U_DEATH_FORM] = [true, 0]
	awakened[SNAP.U_ACTION_TIME_LEFT] = 0.0
	awakened[SNAP.U_ACTION_PERMISSIONS] = ControlState.ALL_PERMISSIONS & ~ControlState.START_SKILL
	_deliver(21, [awakened])
	_deliver(2, [dormant])
	_expect(main._client_units[76000] == resting and resting.hp == 2400 and resting.get_form_index() == 1 and not resting.death_form.waiting(), "复生形态快照保持身份，迟到零血快照不可回滚")
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
	herald[SNAP.U_ACTION_PERMISSIONS] = 0
	_deliver(2, [herald])
	var replica: Unit = main._client_units[71000]
	_expect(replica.get_visual_action_name() == &"rush_dash" and is_equal_approx(replica.get_visual_action_time_left(), 0.3) and replica.is_structure_rushing() and replica.is_active_skill_rush_locked(), "先锋客户端只读冲撞窗口并锁住主动技能")
	var collision: Array = [herald.duplicate(true)]
	collision[0][SNAP.U_HP] = 1260
	collision[0][SNAP.U_ACTION_SERIAL] = 4
	collision[0][SNAP.U_ACTION_NAME] = "rush_hit"
	for index in 6: collision.append(_payload("voidmite", 71001 + index, 3))
	_deliver(4, collision)
	_deliver(4, collision)
	_spawn(collision[1])
	_expect(main._client_units.size() == 7 and replica.hp == 1260 and replica.get_visual_action_serial() == 4, "撞击快照恢复先锋自伤和六只蠕虫，重复快照/出生不重复召唤")
	var awaiting_reprepare: Array = collision[0].duplicate(true)
	awaiting_reprepare[SNAP.U_ACTION_SERIAL] = 5
	awaiting_reprepare[SNAP.U_ACTION_NAME] = ""
	awaiting_reprepare[SNAP.U_ACTION_DURATION] = 0.0
	awaiting_reprepare[SNAP.U_ACTION_TIME_LEFT] = 0.0
	awaiting_reprepare[SNAP.U_ACTION_PERMISSIONS] = 0
	_deliver(5, [awaiting_reprepare])
	_expect(not replica.is_structure_rushing() and replica.is_active_skill_rush_locked(), "客户端跳过准备取消帧时仍按主机权限锁定等待重备")
	var restarted: Array = awaiting_reprepare.duplicate(true)
	restarted[SNAP.U_ACTION_SERIAL] = 6
	restarted[SNAP.U_ACTION_NAME] = "rush_prepare"
	restarted[SNAP.U_ACTION_DURATION] = 2.5
	restarted[SNAP.U_ACTION_TIME_LEFT] = 2.5
	_deliver(6, [restarted])
	_expect(replica.is_structure_rushing() and replica.is_active_skill_rush_locked(), "客户端收到新序号的同名准备后重新识别冲撞锁")
	# 已有成员接过编队技能时，快照必须先更新来源卡，再注册技能。
	_system.reset_session("deployment-skill")
	var member := _payload("melee_minion", 72001, 1)
	member[SNAP.U_SPAWN].args[8] = 55
	_deliver(2, [member])
	member[SNAP.U_SPAWN].args[5] = 72000
	member[SNAP.U_SPAWN].args[6] = 0
	member[SNAP.U_SPAWN].args[12] = "minion_squad"
	member[SNAP.U_ACTIVE_SKILL_USES_REMAINING] = 1
	_deliver(3, [member])
	var group_entry: Dictionary = main._active_skills.entry(72000)
	_expect(group_entry.get("card_id") == "minion_squad" and group_entry.get("skill", {}).get("target_scope") == &"deployment_group", "快照转交使用编队技能而非成员自身技能")
	_system.reset_session("cancellation")
	var cancelled := _payload("garen", 73000, 1)
	cancelled[SNAP.U_DEPLOY_LEFT] = 0.0
	cancelled[SNAP.U_ATTACK_SERIAL] = 4
	cancelled[SNAP.U_VISUAL_STATE] = 3
	cancelled[SNAP.U_ACTION_SERIAL] = 7
	cancelled[SNAP.U_ACTION_NAME] = "judgment"
	cancelled[SNAP.U_ACTION_DURATION] = 3.0
	cancelled[SNAP.U_ACTION_TIME_LEFT] = 2.0
	cancelled[SNAP.U_CANCELLATION] = {"serial": 2, "reason": "stun", "attack": 4, "action": 7, "form": 0, "cancelled_action": 7}
	var malformed: Dictionary = cancelled[SNAP.U_CANCELLATION].duplicate(true)
	malformed["cancelled_action"] = {}
	_expect(not Unit.valid_action_cancellation(malformed), "取消屏障拒绝非整数动作身份")
	malformed["cancelled_action"] = 7
	malformed["cancelled_deployment"] = "false"
	_expect(not Unit.valid_action_cancellation(malformed), "取消屏障拒绝非布尔部署标记")
	_deliver(2, [cancelled])
	var stopped: Unit = main._client_units[73000]
	_expect(stopped.get_visual_action_time_left() == 0 and stopped.get_visual_state_code() != 3 and stopped.action_cancel_serial == 2, "未知实体快照重建携带累计取消；短冰冻已结束也不能恢复旧攻击/技能")
	var notifications := [0]
	stopped.action_cancelled.connect(func(_payload): notifications[0] += 1)
	stopped.apply_action_cancellation({"serial": 1, "reason": "freeze", "attack": 4, "action": 7, "form": 0})
	stopped.apply_action_cancellation(cancelled[SNAP.U_CANCELLATION])
	_expect(notifications[0] == 0, "重复和逆序动作取消不重播表现")
	cancelled[SNAP.U_ATTACK_SERIAL] = 5
	cancelled[SNAP.U_ACTION_SERIAL] = 8
	_deliver(3, [cancelled])
	_expect(stopped.get_attack_visual_serial() == 5 and stopped.get_visual_action_time_left() == 2, "取消屏障允许后续新身份动作")
	var effects = main._active_skill_effect_system
	effects.clear()
	var star := {"fixed_position": true, "pos": Vector2(360, 600), "shape": "target_circle", "timer": 1.0, "duration": 1.0, "team": 0}
	effects.show_skill_effect(100, star)
	effects.show_skill_effect(100, star)
	effects.tick_visuals(0.2)
	_expect(effects.frontal_effects.size() == 1 and is_equal_approx(effects.frontal_effects[0].timer, 0.8), "独立星辰重复事件仅创建一次，来源不参与推进")
	effects.clear()
	effects.show_skill_effect(100, star)
	_expect(effects.frontal_effects.size() == 1, "两局清场释放效果去重身份")
	effects.clear()
	_check_permission_projection()
	# 实际快照首次同时带技能和眩晕；代理尚未消费动作序号。
	main._battle_presentation = saved_view
	main._audio_manager = saved_audio
	_system.reset_session("first-render-stun")
	var first_action := _payload("sett", 74000, 1)
	first_action[SNAP.U_DEPLOY_LEFT] = 0.0
	first_action[SNAP.U_ACTION_SERIAL] = 1
	first_action[SNAP.U_ACTION_NAME] = "active"
	first_action[SNAP.U_ACTION_DURATION] = 1.4
	first_action[SNAP.U_ACTION_TIME_LEFT] = 0.9
	first_action[SNAP.U_STUN] = 1
	first_action[SNAP.U_ACTION_PERMISSIONS] = ControlState.CONTINUE_SKILL | ControlState.EXTERNAL_MOTION
	_deliver(2, [first_action])
	var first_unit: Unit = main._client_units[74000]
	var first_view: UnitModel3D
	for child in saved_view._world_root.get_children():
		if child is UnitModel3D and child._source == first_unit: first_view = child
	first_view._process(0.0)
	_expect(first_view._playing_visual_action and first_view._active_action_name == &"active" and first_view._animation_player.speed_scale > 0, "客户端首次技能快照同时眩晕，立即按已过0.5秒播放动作")
	first_action[SNAP.U_CANCELLATION] = {"serial": 1, "reason": "freeze", "attack": 0, "action": 1, "form": 0, "cancelled_action": 1}
	first_action[SNAP.U_FROZEN] = 1
	_deliver(3, [first_action])
	first_view._process(0.0)
	_deliver(2, [first_action])
	first_action[SNAP.U_FROZEN] = 0
	_deliver(4, [first_action])
	first_view._process(0.0)
	_expect(not first_view._playing_visual_action and first_unit.get_visual_action_time_left() == 0, "冰冻取消与旧动作快照交错不恢复旧技能")
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

func _check_permission_projection() -> void:
	_system.reset_session("permission-projection")
	var projected := _payload("gnar", 73500, 1)
	projected[SNAP.U_SPAWN].args[5] = 73500
	projected[SNAP.U_SPAWN].args[6] = 0
	projected[SNAP.U_ACTIVE_SKILL_USES_REMAINING] = 1
	var deck: Array = _main._deck.duplicate()
	_main._deck[0] = "gnar"
	var tick := 2
	for phase in ["deploy", "transform", "cast", "freeze", "stun", "rush", "recovery", "ready"]:
		projected[SNAP.U_DEPLOY_LEFT] = 0.5 if phase == "deploy" else 0.0
		projected[SNAP.U_FROZEN] = 1 if phase == "freeze" else 0
		projected[SNAP.U_STUN] = 1 if phase == "stun" else 0
		projected[SNAP.U_ACTION_PERMISSIONS] = ControlState.ALL_PERMISSIONS if phase == "ready" else ControlState.EXTERNAL_MOTION
		_deliver(tick, [projected])
		var unit: Unit = _main._client_units[73500]
		unit.active_skill_cast_timer = 100.0 if phase == "ready" else 0.0
		unit.form_transition_timer = 100.0 if phase == "ready" else 0.0
		_main._sync_active_skill_deployment_readiness()
		_expect(_main._can_submit_active_skill(73500, 1) == (phase != "deploy") and _main._active_skill_bar._buttons[0].disabled == (phase == "deploy"), "客户端按钮/提交只读基础资格，临时权限不阻止入队 " + phase)
		_expect(((unit.action_permissions() & ControlState.START_SKILL) != 0) == (phase == "ready"), "快照权限投影 " + phase)
		tick += 1
	var saved_session: MatchSession = _main._session
	_main._session = MatchSession.new()
	_main._session.opponent_id = 1
	_main._session.session_id = "skill-receipts"
	_main._session.phase = MatchSession.Phase.RUNNING
	_main._active_skill_bar.set_pending(73500, true)
	_expect(not _main._can_submit_active_skill(73500, 1), "客户端等待回执时不可重复提交")
	_main._rpc_active_skill_used(_main._session.session_id, 73500, 1, 0.0)
	_expect(not _main._active_skill_bar.is_pending(73500) and _main._can_submit_active_skill(73500, 1), "客户端成功回执解除pending，不遗留永久禁用")
	_main._active_skill_bar.set_pending(73500, true)
	_main._rpc_active_skill_rejected(_main._session.session_id, 73500)
	_expect(not _main._active_skill_bar.is_pending(73500) and _main._can_submit_active_skill(73500, 1), "客户端拒绝回执恢复提交资格")
	_main._session = saved_session
	var invalid := projected.duplicate(true)
	invalid[SNAP.U_ACTION_PERMISSIONS] = 64
	_deliver(tick, [invalid])
	_expect(_system.lifecycle.snapshot_tick == tick - 1, "未知权限位拒绝整份快照")
	_deliver(tick - 2, [invalid])
	_expect((_main._client_units[73500].action_permissions() & ControlState.START_SKILL) != 0, "旧快照不能回拨已解除技能权限")
	_main._deck = deck

func _check_payload_contract() -> void:
	_system.reset_session("payload-contract")
	var data := _payload("gwen", 79000, 1)
	data[SNAP.U_TARGET_PROTECTION] = [Vector2(360, 900), 120.0, 3.5, 2]
	data[SNAP.U_HP] = 321.0
	data[SNAP.U_STUN] = 1
	data[SNAP.U_DEPLOY_LEFT] = 0.2
	data[SNAP.U_SKILL_RESOURCE_RATIO] = 0.5
	var packet := _system._snapshot_packet([data], [], [], 5.0, 180.0, false)
	packet[SNAP.S_SERVER_TICK] = 2
	packet[SNAP.S_LIFECYCLE_REVISION] = 2
	for delta in [-1, 1]:
		var malformed := packet.duplicate(true)
		if delta < 0: malformed[SNAP.S_UNITS][0].pop_back()
		else: malformed[SNAP.S_UNITS][0].insert(7, 0)
		_expect(not _system.apply(var_to_bytes(malformed).compress(FileAccess.COMPRESSION_DEFLATE)) and _main._client_units.is_empty(), "单位载荷增减字段均拒绝，不产生错位实体")
	for invalid_protection in [[Vector2(INF, 0), 120.0, 4.0, 1], [Vector2.ZERO, -1.0, 4.0, 1], [Vector2.ZERO, 120.0, "bad", 1], []]:
		var invalid_packet := packet.duplicate(true)
		invalid_packet[SNAP.S_UNITS][0][SNAP.U_TARGET_PROTECTION] = invalid_protection
		_expect(not _system.apply(var_to_bytes(invalid_packet).compress(FileAccess.COMPRESSION_DEFLATE)), "非法圣霭载荷拒绝整份快照")
	var old := packet.duplicate(true)
	old[SNAP.S_VERSION] = MatchSession.PROTOCOL_VERSION - 1
	_expect(not _system.apply(var_to_bytes(old).compress(FileAccess.COMPRESSION_DEFLATE)), "旧版快照不解码；双进程另验握手拒绝")
	_expect(_system.apply(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE)) and data.size() == SNAP.UNIT_PAYLOAD_SIZE, "新载荷压缩编码、解码与未知格温重建成功")
	var replica: Unit = _main._client_units[79000]
	_expect(replica.target_protection.snapshot() == data[SNAP.U_TARGET_PROTECTION], "未知实体恢复完整结界中心、半径、寿命与代次")
	replica.target_protection.advance(10.0, Vector2.ZERO)
	_expect(replica.target_protection.active() and replica.target_protection.remaining() == 3.5, "客户端不能自行推进或因插值位置清除权威结界")
	_expect(replica.hp == 321.0 and replica.is_stunned() and is_equal_approx(replica._deploy_timer, 0.2) and is_equal_approx(replica.net_skill_resource_ratio, 0.5), "移除旧字段后控制、部署、资源索引仍往返一致")
	_system.reset_session("")

func _check_bleeding_projection() -> void:
	_system.reset_session("bleeding-projection")
	var data := _payload("darius", 76003, 1)
	data[SNAP.U_SPAWN].args[5] = 76003
	data[SNAP.U_SPAWN].args[6] = 0
	data[SNAP.U_DEPLOY_LEFT] = 0.0
	data[SNAP.U_ACTIVE_SKILL_USES_REMAINING] = 0
	data[SNAP.U_ACTIVE_SKILL_COOLDOWN] = 11.5
	data[SNAP.U_FREE_RECAST] = true
	data[SNAP.U_BLEED_STACKS] = 4
	data[SNAP.U_BLOOD_RAGE] = 3.5
	var deck: Array = _main._deck.duplicate()
	_main._deck[0] = "darius"
	_deliver(2, [data])
	var unit: Unit = _main._client_units[76003]
	_expect(unit.bleeding.total_stacks() == 4 and unit.blood_rage_time_left_visual() == 3.5, "客户端恢复流血层数及血怒剩余时间")
	_expect(_main._active_skills.cost(76003) == 0.0 and _main._can_submit_active_skill(76003, 1), "客户端零付费次数/CD中免费追斩可用")
	unit.sim_tick(2.0)
	_expect(unit.bleeding.total_stacks() == 4 and unit.blood_rage_time_left_visual() == 3.5, "客户端不自行推进流血与血怒权威状态")
	var bad: Array = data.duplicate(true)
	bad[SNAP.U_BLEED_STACKS] = -1
	_deliver(3, [bad])
	_expect(_system.lifecycle.snapshot_tick == 2, "负流血层数快照被拒绝")
	bad = data.duplicate(true)
	bad[SNAP.U_FREE_RECAST] = 1
	_deliver(3, [bad])
	_expect(_system.lifecycle.snapshot_tick == 2, "非布尔免费资格快照被拒绝")
	data[SNAP.U_BLOOD_RAGE] = 0.0
	data[SNAP.U_BLEED_STACKS] = 0
	data[SNAP.U_FREE_RECAST] = false
	_deliver(4, [data])
	_expect(unit.blood_rage_time_left_visual() == 0.0 and unit.bleeding.total_stacks() == 0 and not _main._can_submit_active_skill(76003, 1), "权威到期清除表现且免费资格消费后不可用")
	_main._deck = deck
