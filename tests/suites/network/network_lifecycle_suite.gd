extends "res://tests/suites/battle_suite.gd"
## 真实压缩/序列化数据与 RPC 生命周期事件重放，状态由独立协议实例持有。
const SNAP = preload("res://scripts/battle/network_snapshot_system.gd")
class CountingSnapshot extends NetworkSnapshotSystem:
	var decodes := 0
	var public_captures := 0
	func decode_validated(bytes: PackedByteArray) -> DecodedSnapshot:
		decodes += 1
		return super.decode_validated(bytes)
	func capture_public_frame() -> Array:
		public_captures += 1
		return super.capture_public_frame()

var _system: NetworkSnapshotSystem

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var saved_mode: String = main.runtime.mode
	var saved_mode_team: int = main.runtime.local_team
	var saved_system: NetworkSnapshotSystem = main._snapshot_system
	var saved_audio: GameAudioManager = main._audio_manager
	var saved_view = main._battle_presentation
	var saved_tick: int = main._authoritative_server_tick
	var saved_estimated: int = main._estimated_server_tick
	var saved_fraction: float = main._estimated_server_tick_fraction
	var saved_has_estimate: bool = main._has_estimated_server_tick
	var saved_received: int = main._snapshots_received
	var saved_elixir: float = main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir
	var saved_time: float = main.runtime._match_rules.time_left
	var saved_overtime: bool = main.runtime._match_rules.overtime
	main.runtime.mode = "client"
	main.runtime.local_team = 1
	main._audio_manager = null
	main._battle_presentation = null
	_system = SNAP.new(main, main._projectile_system)
	main._snapshot_system = _system
	_check_decoded_pipeline()
	_check_payload_contract()
	_check_tower_stasis()
	_check_building_health_decay()
	_check_hit_haste_visual_snapshot()
	_check_soft_control_snapshot()
	_check_teleport_snapshot()
	_check_dynamic_action_clock()
	_check_bleeding_projection()
	_check_true_death_projection()
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
	var resting: Unit = main.world.replica_units_snapshot()[76000]
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
	_expect(main.world.replica_units_snapshot()[76000] == resting and resting.hp == 2400 and resting.get_form_index() == 1 and not resting.death_form.waiting(), "复生形态快照保持身份，迟到零血快照不可回滚")
	main._projectile_system.apply_client_targets({1: {"pos": Vector2.ZERO, "visual_offset": Vector2.ZERO}})
	_system.reset_session("one")
	_expect(main._projectile_system.client_snapshot().is_empty(), "新会话由弹体所有者清除上一局客户端状态")
	var payload := _payload("ashe", 70001, 101)
	payload[SNAP.U_SPAWN].args[13] = Vector2(200, 900)
	_deliver(90, [])
	_spawn(payload)
	var original: Unit = main.world.replica_units_snapshot()[70001]
	_expect(original.summon_visual_origin == Vector2(200, 900), "可靠生成往返保留召唤门心，不由客户端猜测")
	_deliver(100, [])
	_expect(main.world.replica_units_snapshot().get(70001) == original, "Spawn101 先于 Snapshot100：旧快照不能删除新生实体")
	_deliver(102, [payload])
	_spawn(payload)
	_expect(main.world.replica_units_snapshot().size() == 1 and main.world.replica_units_snapshot().get(70001) == original, "重复 Spawn 不重建、不重复注册主动或导航")
	# 快照先到，可靠 Spawn 晚到。
	_system.reset_session("two")
	_deliver(102, [payload])
	var reconstructed: Unit = main.world.replica_units_snapshot().get(70001)
	_expect(reconstructed.summon_visual_origin == Vector2(200, 900), "快照先到重建保留相同出生来源")
	_expect(is_instance_valid(reconstructed) and reconstructed.card_id == "ashe" and is_equal_approx(reconstructed._deploy_timer, 0.35), "未知实体由快照重建完整卡牌和剩余部署状态")
	_spawn(payload)
	_expect(main.world.replica_units_snapshot().get(70001) == reconstructed, "快照先于 Spawn：迟到生成事件幂等")
	var delayed_descriptor: Dictionary = payload[SNAP.U_SPAWN].duplicate(true)
	delayed_descriptor.args[7] = 93
	main.runtime._commands.enqueue_deployment(1, "ashe", Vector2.ZERO, 2.0, -1, 93)
	_system.receive_spawn("two", delayed_descriptor)
	_expect(main.runtime._commands.inspect_deployments().is_empty() and main.world.replica_units_snapshot().get(70001) == reconstructed, "迟到出生事实清理旧部署提示，即使实体已由快照建立")
	_deliver(104, [payload]) # 丢失 103 不影响收敛。
	_expect(_system.lifecycle.snapshot_tick == 104 and main.world.replica_units_snapshot().size() == 1, "丢一份快照后实体集合仍收敛")
	main._rpc_unit_died(70001, true, "two", 106)
	main._rpc_unit_died(70001, true, "two", 106)
	_deliver(105, [payload])
	_spawn(payload)
	_expect(main.world.replica_units_snapshot().is_empty(), "可靠死亡先于旧快照、重复销毁与迟到 Spawn 均不能复活实体")
	# 无本地 Spawn 的死亡事件也必须留下屏障。
	var unborn := _payload("garen", 70002, 110)
	main._rpc_unit_died(70002, false, "two", 111)
	_spawn(unborn)
	_deliver(110, [unborn])
	_expect(main.world.replica_units_snapshot().is_empty(), "Death 先于 Spawn/快照：保留销毁标记，不生成已死对象")
	_system.reset_session("three")
	_deliver(112, [])
	_spawn(unborn)
	_expect(main.world.replica_units_snapshot().is_empty(), "全量快照已越过生存窗口时拒绝迟到 Spawn")
	_deliver(113, [payload], "two")
	_spawn(payload, "two")
	_expect(main.world.replica_units_snapshot().is_empty() and _system.lifecycle.snapshot_tick == 112, "上一局快照与 Spawn 不污染本局")
	# 新局复用实体 id 与小 Tick，不受上一局时钟和墓碑污染。
	_system.reset_session("four")
	var fresh := _payload("garen", 70001, 1)
	_deliver(2, [fresh])
	main._rpc_unit_died(70001, false, "two", 999)
	_expect(main.world.replica_units_snapshot().has(70001) and main.world.replica_units_snapshot()[70001].card_id == "garen" and main.get_authoritative_server_tick() == 2, "新局 id 复用、时钟归零且旧局死亡事件无效")
	_deliver(3, [])
	_deliver(2, [fresh])
	_expect(main.world.replica_units_snapshot().is_empty(), "缺席新快照确认销毁后，旧快照不能回退集合")
	# 建筑重建保留基座和编队身份，重复消息不多注册导航阻挡。
	var building := _payload("sun_disc", 70003, 4)
	building[SNAP.U_SPAWN].args[8] = 12
	building[SNAP.U_SPAWN].args[11] = true
	_deliver(5, [building])
	var unit: Unit = main.world.replica_units_snapshot()[70003]
	var cells := unit.nav_cells.duplicate()
	_spawn(building)
	_expect(unit.is_building and unit.built_on_tower_ruin and unit.deployment_group_id == 12 and not cells.is_empty() and unit.nav_cells == cells, "快照重建建筑保留塔墟/编队信息，重复 Spawn 不重复占位")
	_deliver(6, [])
	_expect(unit.nav_cells.is_empty() and main.world.replica_units_snapshot().is_empty(), "快照销毁建筑统一释放导航占位")
	_system.reset_session("same_tick")
	var same_tick := _payload("ashe", 70004, 10)
	same_tick[SNAP.U_SPAWN].birth_revision = 2
	_spawn(same_tick)
	_deliver(10, [], "", 1)
	_expect(main.world.replica_units_snapshot().has(70004), "同 Tick 旧快照的生命周期序号较小，不能删除随后出生的实体")
	_deliver(10, [same_tick], "", 2)
	_expect(_system.lifecycle.snapshot_revision == 2 and main.world.replica_units_snapshot().has(70004), "同 Tick 较新生命周期全量快照仍可接受")
	_deliver(10, [], "", 1)
	_expect(main.world.replica_units_snapshot().has(70004), "同 Tick 较旧生命周期快照不能覆盖新集合")
	_system.reset_session("structure_rush")
	var herald := _payload("rift_herald", 71000, 1)
	herald[SNAP.U_DEPLOY_LEFT] = 0.0
	herald[SNAP.U_ACTION_SERIAL] = 3
	herald[SNAP.U_ACTION_NAME] = "rush_dash"
	herald[SNAP.U_ACTION_DURATION] = 0.5
	herald[SNAP.U_ACTION_TIME_LEFT] = 0.3
	herald[SNAP.U_ACTION_PERMISSIONS] = 0
	_deliver(2, [herald])
	var replica: Unit = main.world.replica_units_snapshot()[71000]
	_expect(replica.get_visual_action_name() == &"rush_dash" and is_equal_approx(replica.get_visual_action_time_left(), 0.3) and replica.is_structure_rushing() and replica.is_active_skill_rush_locked(), "先锋客户端只读冲撞窗口并锁住主动技能")
	var collision: Array = [herald.duplicate(true)]
	collision[0][SNAP.U_HP] = 1260
	collision[0][SNAP.U_ACTION_SERIAL] = 4
	collision[0][SNAP.U_ACTION_NAME] = "rush_hit"
	for index in 6: collision.append(_payload("voidmite", 71001 + index, 3))
	_deliver(4, collision)
	_deliver(4, collision)
	_spawn(collision[1])
	_expect(main.world.replica_units_snapshot().size() == 7 and replica.hp == 1260 and replica.get_visual_action_serial() == 4, "撞击快照恢复先锋自伤和六只蠕虫，重复快照/出生不重复召唤")
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
	var group_entry: Dictionary = main.runtime._active_skills.entry(72000)
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
	var stopped: Unit = main.world.replica_units_snapshot()[73000]
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
	var effects = main._skill_presentation
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
	var first_unit: Unit = main.world.replica_units_snapshot()[74000]
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
	main.runtime.mode = saved_mode
	main.runtime.local_team = saved_mode_team
	main._audio_manager = saved_audio
	main._battle_presentation = saved_view
	main._authoritative_server_tick = saved_tick
	main._estimated_server_tick = saved_estimated
	main._estimated_server_tick_fraction = saved_fraction
	main._has_estimated_server_tick = saved_has_estimate
	main._snapshots_received = saved_received
	main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir = saved_elixir
	main.runtime._match_rules.time_left = saved_time
	main.runtime._match_rules.overtime = saved_overtime
	main._update_timer_label()

func _payload(card: String, id: int, birth: int) -> Array:
	var unit := Unit.new()
	unit.card_id = card
	unit.setup(1, CardDB.get_unit_stats(card), card)
	unit.position = Vector2(240, 360)
	unit._deploy_timer = 0.35
	var data := preload("res://tests/fixtures/network_fixture.gd").snapshot_payload(_system, id, unit)
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
	var packet := preload("res://tests/fixtures/network_fixture.gd").packet(_system, units, [], preload("res://tests/fixtures/network_fixture.gd").tower_payloads(_system), 5.0, 180.0, false)
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
	var deck: Array = _main.runtime._deck.duplicate()
	_main.runtime._deck[0] = "gnar"
	var tick := 2
	for phase in ["deploy", "transform", "cast", "freeze", "stun", "rush", "recovery", "ready"]:
		projected[SNAP.U_DEPLOY_LEFT] = 0.5 if phase == "deploy" else 0.0
		projected[SNAP.U_FROZEN] = 1 if phase == "freeze" else 0
		projected[SNAP.U_STUN] = 1 if phase == "stun" else 0
		projected[SNAP.U_ACTION_PERMISSIONS] = ControlState.ALL_PERMISSIONS if phase == "ready" else ControlState.EXTERNAL_MOTION
		_deliver(tick, [projected])
		var unit: Unit = _main.world.replica_units_snapshot()[73500]
		unit.active_skill_cast_timer = 100.0 if phase == "ready" else 0.0
		unit.form_transition_timer = 100.0 if phase == "ready" else 0.0
		_main._sync_active_skill_deployment_readiness()
		_expect(_main.runtime._can_submit_active_skill(73500, 1) == (phase != "deploy") and _main._active_skill_bar._buttons[0].disabled == (phase == "deploy"), "客户端按钮/提交只读基础资格，临时权限不阻止入队 " + phase)
		_expect(((unit.action_permissions() & ControlState.START_SKILL) != 0) == (phase == "ready"), "快照权限投影 " + phase)
		tick += 1
	var saved_session: MatchSession = _main.runtime.session
	_main.runtime.session = MatchSession.new()
	_main.runtime.session.opponent_id = 1
	_main.runtime.session.session_id = "skill-receipts"
	_main.runtime.session.phase = MatchSession.Phase.RUNNING
	_main._client_inputs.skill(73500, 3)
	_main._sync_active_skill_deployment_readiness()
	_expect(not _main.runtime._can_submit_active_skill(73500, 1), "客户端等待回执时不可重复提交")
	var accepted := {"id": 9001, "kind": "skill", "team": 1, "card_id": "gnar", "ability_id": 73500, "pos": Vector2(300, 800), "input_tick": 0, "execute_tick": 10}
	_main._rpc_command_scheduled(_main.runtime.session.session_id, accepted)
	_main._rpc_active_skill_used(_main.runtime.session.session_id, 73500, 1, 0.0)
	_expect(not _main._client_inputs.has_skill(73500) and not _main.runtime._can_submit_active_skill(73500, 1), "已受理排程接手等待状态，技能结果通知不能提前解除pending")
	_main._rpc_command_finished(_main.runtime.session.session_id, 9001, "executed")
	_expect(not _main._active_skill_bar.is_pending(73500) and _main.runtime._can_submit_active_skill(73500, 1), "正式完成通知解除pending，不遗留永久禁用")
	_main._active_skill_bar.set_pending(73500, true)
	_main._client_inputs.skill(73500, 4)
	_main._rpc_active_skill_rejected(_main.runtime.session.session_id, 73500, 4)
	_expect(not _main._active_skill_bar.is_pending(73500) and _main.runtime._can_submit_active_skill(73500, 1), "客户端拒绝回执恢复提交资格")
	_main.runtime.session = saved_session
	var invalid := projected.duplicate(true)
	invalid[SNAP.U_ACTION_PERMISSIONS] = 64
	_deliver(tick, [invalid])
	_expect(_system.lifecycle.snapshot_tick == tick - 1, "未知权限位拒绝整份快照")
	_deliver(tick - 2, [invalid])
	_expect((_main.world.replica_units_snapshot()[73500].action_permissions() & ControlState.START_SKILL) != 0, "旧快照不能回拨已解除技能权限")
	_main.runtime._deck = deck

func _check_payload_contract() -> void:
	_system.reset_session("payload-contract")
	var data := _payload("gwen", 79000, 1)
	data[SNAP.U_TARGET_PROTECTION] = [Vector2(360, 900), 120.0, 3.5, 2]
	data[SNAP.U_HP] = 321.0
	data[SNAP.U_GROWTH] = Vector2(150.0, 1.3)
	data[SNAP.U_SACRIFICE_EMPOWERMENT] = Vector2(1.5, 1.25)
	data[SNAP.U_SACRIFICE_STATS] = Vector3(33.0, 1.25, 1.2)
	data[SNAP.U_DEATH_SPAWN_STATE] = Vector2(1.75, 3.0)
	data[SNAP.U_LIFESTEAL_VISUAL_STATE] = Vector2(5, 1)
	data[SNAP.U_BUFF_VISUAL_CLOCK] = Vector2(2, 3)
	data[SNAP.U_RESTORATION_SHIELD_STATE] = Vector2(1.75, 2)
	data[SNAP.U_STRUCTURE_HASTE] = true
	data[SNAP.U_STRUCTURE_HASTE_STATE] = Vector2(5.5, 3)
	data[SNAP.U_STEALTH] = true
	data[SNAP.U_STUN] = 1
	data[SNAP.U_DEPLOY_LEFT] = 0.2
	data[SNAP.U_SKILL_RESOURCE_RATIO] = 0.5
	var packet := preload("res://tests/fixtures/network_fixture.gd").packet(_system, [data], [], preload("res://tests/fixtures/network_fixture.gd").tower_payloads(_system), 5.0, 180.0, false)
	packet[SNAP.S_SERVER_TICK] = 2
	packet[SNAP.S_LIFECYCLE_REVISION] = 2
	for delta in [-1, 1]:
		var malformed := packet.duplicate(true)
		if delta < 0: malformed[SNAP.S_UNITS][0].pop_back()
		else: malformed[SNAP.S_UNITS][0].insert(7, 0)
		_expect(not _system.apply_decoded(_system.decode_validated(var_to_bytes(malformed).compress(FileAccess.COMPRESSION_DEFLATE))) and _main.world.replica_units_snapshot().is_empty(), "单位载荷增减字段均拒绝，不产生错位实体")
	for invalid_protection in [[Vector2(INF, 0), 120.0, 4.0, 1], [Vector2.ZERO, -1.0, 4.0, 1], [Vector2.ZERO, 120.0, "bad", 1], []]:
		var invalid_packet := packet.duplicate(true)
		invalid_packet[SNAP.S_UNITS][0][SNAP.U_TARGET_PROTECTION] = invalid_protection
		_expect(not _system.apply_decoded(_system.decode_validated(var_to_bytes(invalid_packet).compress(FileAccess.COMPRESSION_DEFLATE))), "非法圣霭载荷拒绝整份快照")
	for invalid_growth in [Vector2(INF, 1.3), Vector2(100, 0.0), "bad"]:
		var invalid_packet := packet.duplicate(true)
		invalid_packet[SNAP.S_UNITS][0][SNAP.U_GROWTH] = invalid_growth
		_expect(not _system.apply_decoded(_system.decode_validated(var_to_bytes(invalid_packet).compress(FileAccess.COMPRESSION_DEFLATE))), "非法成长载荷拒绝整份快照")
	for invalid in [Vector2(INF, 1.25), Vector2(1.5, NAN), Vector2(0.5, 1.25), Vector2(1.5, 0), "bad"]:
		var malformed := packet.duplicate(true)
		malformed[SNAP.S_UNITS][0][SNAP.U_SACRIFICE_EMPOWERMENT] = invalid
		_expect(not _system.apply_decoded(_system.decode_validated(var_to_bytes(malformed).compress(FileAccess.COMPRESSION_DEFLATE))), "非法牺牲强化倍率拒绝整份快照")
	for invalid in [Vector3(INF, 1.25, 1.2), Vector3(-1, 1.25, 1.2), Vector3(33, 0, 1.2), Vector3(33, 1.25, 0), "bad"]:
		var malformed := packet.duplicate(true)
		malformed[SNAP.S_UNITS][0][SNAP.U_SACRIFICE_STATS] = invalid
		_expect(not _system.apply_decoded(_system.decode_validated(var_to_bytes(malformed).compress(FileAccess.COMPRESSION_DEFLATE))), "非法牺牲强化属性拒绝快照")
	for invalid in [Vector2(INF, 3), Vector2(1, NAN), Vector2(-1, 3), Vector2(4, 3), Vector2(0, 3), Vector2(1, 0), "bad"]:
		var malformed := packet.duplicate(true)
		malformed[SNAP.S_UNITS][0][SNAP.U_DEATH_SPAWN_STATE] = invalid
		_expect(not _system.apply_decoded(_system.decode_validated(var_to_bytes(malformed).compress(FileAccess.COMPRESSION_DEFLATE))), "再生窗口拒绝非法快照")
	for field in [SNAP.U_LIFESTEAL_VISUAL_STATE, SNAP.U_BUFF_VISUAL_CLOCK]:
		for invalid in [Vector2(INF, 1), Vector2(-1, 1), Vector2(1, 0), Vector2(0, -1), "bad"]:
			var malformed := packet.duplicate(true)
			malformed[SNAP.S_UNITS][0][field] = invalid
			_expect(not _system.apply_decoded(_system.decode_validated(var_to_bytes(malformed).compress(FileAccess.COMPRESSION_DEFLATE))), "技能表现时钟拒绝非法快照")
	for invalid in [Vector2(INF, 2), Vector2(1, NAN), Vector2(-1, 2), Vector2(3, 2), Vector2(0, 2), Vector2(1, 0), "bad"]:
		var malformed := packet.duplicate(true)
		malformed[SNAP.S_UNITS][0][SNAP.U_RESTORATION_SHIELD_STATE] = invalid
		_expect(not _system.apply_decoded(_system.decode_validated(var_to_bytes(malformed).compress(FileAccess.COMPRESSION_DEFLATE))), "黄沙盾拒绝非法表现状态")
	var invalid_stealth := packet.duplicate(true)
	invalid_stealth[SNAP.S_UNITS][0][SNAP.U_STEALTH] = 1
	_expect(not _system.apply_decoded(_system.decode_validated(var_to_bytes(invalid_stealth).compress(FileAccess.COMPRESSION_DEFLATE))), "隐身载荷拒绝非布尔值")
	var old := packet.duplicate(true)
	old[SNAP.S_VERSION] = MatchSession.PROTOCOL_VERSION - 1
	_expect(not _system.apply_decoded(_system.decode_validated(var_to_bytes(old).compress(FileAccess.COMPRESSION_DEFLATE))), "旧版快照不解码；双进程另验握手拒绝")
	for invalid in [Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1.5), Vector2(INF, 1), Vector2(1, 0), Vector2(0, 1), "bad"]:
		var malformed := packet.duplicate(true)
		malformed[SNAP.S_UNITS][0][SNAP.U_STRUCTURE_HASTE_STATE] = invalid
		_expect(not _system.apply_decoded(_system.decode_validated(var_to_bytes(malformed).compress(FileAccess.COMPRESSION_DEFLATE))), "被动层数与倒计时拒绝非法快照")
	_expect(_system.apply_decoded(_system.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE))) and data.size() == SNAP.UNIT_PAYLOAD_SIZE, "新载荷压缩编码、解码与未知格温重建成功")
	var replica: Unit = _main.world.replica_units_snapshot()[79000]
	_expect(replica.restoration_shield_state_visual() == Vector2(1.75, 2) and replica.shields.restoration_visual_state() == Vector2.ZERO, "客户端恢复黄沙盾表现但不授予护盾玩法")
	_expect(replica.lifesteal_state_visual() == Vector2(5, 1) and replica.active_buff_clock_visual() == Vector2(2, 3) and replica.attack_lifesteal_ratio == 0.0, "快照恢复光流进度但不授予吸血玩法")
	_expect(replica.death_spawn_state_visual() == Vector2(1.75, 3.0) and replica.buffs.remaining(&"death_spawn") == 0.0, "再生状态快照恢复仅用于表现，不授予客户端再生Buff")
	_expect(replica.growth_health_bonus == 150.0 and is_equal_approx(replica.growth_body_scale, 1.3) and replica.max_hp == float(CardDB.get_card("gwen").hp) + 183.0, "成长与牺牲强化快照恢复最大生命与体型")
	_expect(replica.net_stealth_hidden and replica.visible_to_team(0) and replica.visible_to_team(1) and not replica.perceived_by_team(0), "隐身快照保留双方玩家可见和敌方单位感知门禁")
	_expect(replica.sacrifice_empowerment == Vector2(1.5, 1.25), "快照往返保留永久牺牲伤害与表现缩放")
	_expect(replica.sacrifice_stats == Vector3(33, 1.25, 1.2), "快照恢复永久生命碰撞与移速属性")
	var grown_radius := replica.body_radius
	_system._apply_units([data])
	_expect(is_equal_approx(replica.body_radius, grown_radius) and replica.hp == 321.0, "重复成长快照不叠加半径、不额外加血")
	_expect(replica.target_protection.snapshot() == data[SNAP.U_TARGET_PROTECTION], "未知实体恢复完整结界中心、半径、寿命与代次")
	_expect(replica.structure_haste_state_visual() == Vector2(5.5, 3), "客户端往返保留被动3层与5.5秒，仅显示不结算叠层")
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
	var deck: Array = _main.runtime._deck.duplicate()
	_main.runtime._deck[0] = "darius"
	_deliver(2, [data])
	var unit: Unit = _main.world.replica_units_snapshot()[76003]
	_expect(unit.bleeding.total_stacks() == 4 and unit.blood_rage_time_left_visual() == 3.5, "客户端恢复流血层数及血怒剩余时间")
	_expect(_main.runtime._active_skills.cost(76003) == 0.0 and _main.runtime._can_submit_active_skill(76003, 1), "客户端零付费次数/CD中免费追斩可用")
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
	bad = data.duplicate(true)
	bad[SNAP.U_CONTINUOUS_TARGET_AIR_ID] = -2
	_deliver(3, [bad])
	_expect(_system.lifecycle.snapshot_tick == 2, "非法空中吐息目标 ID 快照被拒绝")
	data[SNAP.U_BLOOD_RAGE] = 0.0
	data[SNAP.U_BLEED_STACKS] = 0
	data[SNAP.U_FREE_RECAST] = false
	_deliver(4, [data])
	_expect(unit.blood_rage_time_left_visual() == 0.0 and unit.bleeding.total_stacks() == 0 and not _main.runtime._can_submit_active_skill(76003, 1), "权威到期清除表现且免费资格消费后不可用")
	_main.runtime._deck = deck

func _check_hit_haste_visual_snapshot() -> void:
	_system.reset_session("hit-haste-visual")
	var data := _payload("kayle_ranged", 79101, 1)
	data[SNAP.U_HIT_HASTE_FULL] = true
	data[SNAP.U_ACTIVE_ATTACK_SPEED_MULTIPLIER] = 0.5
	_deliver(1, [data])
	var replica: Unit = _main.world.replica_units_snapshot()[79101]
	_expect(replica.hit_haste_full_visual(), "客户端以专属满层位点亮，减攻速不抹除满层")
	replica.buffs.advance(20.0)
	_expect(replica.hit_haste_full_visual(), "客户端不自行倒数被动特效")
	var bad := data.duplicate(true)
	bad[SNAP.U_HIT_HASTE_FULL] = 1
	_deliver(2, [bad])
	_expect(_system.lifecycle.snapshot_tick == 1, "非布尔满层状态拒绝整份快照")
	data[SNAP.U_HIT_HASTE_FULL] = false
	data[SNAP.U_ACTIVE_ATTACK_SPEED_MULTIPLIER] = 2.0
	_deliver(3, [data])
	_expect(not replica.hit_haste_full_visual(), "权威到期关闭特效，其他攻速不伪造满层")
	data[SNAP.U_HIT_HASTE_FULL] = true
	_deliver(2, [data])
	_expect(not replica.hit_haste_full_visual(), "旧快照不重新点亮已到期被动")

func _check_soft_control_snapshot() -> void:
	_system.reset_session("soft-control-visual")
	var data := _payload("anivia", 79102, 1)
	data[SNAP.U_SLOW] = 1
	data[SNAP.U_STUN] = 1
	data[SNAP.U_ATTACK_SPEED_SLOW] = true
	data[SNAP.U_BLIND] = true
	data[SNAP.U_ACTIVE_ATTACK_SPEED_MULTIPLIER] = 1.4
	_deliver(2, [data])
	var unit: Unit = _main.world.replica_units_snapshot()[79102]
	_expect(unit.movement_slow_visual() and unit.attack_speed_slow_visual(), "客户端独立恢复两种软控提示，不依赖最终攻速")
	_expect(unit.stun_visual() and not unit.movement_slow_effect_visible(), "客户端眩晕显示漩涡且静止时隐藏减速拖痕")
	_expect(unit.blind_visual(), "客户端显示权威致盲标识")
	var bad_blind := data.duplicate(true)
	bad_blind[SNAP.U_BLIND] = 1
	_deliver(3, [bad_blind])
	_expect(_system.lifecycle.snapshot_tick == 2, "非布尔致盲状态拒绝应用")
	var invalid := data.duplicate(true)
	invalid[SNAP.U_ATTACK_SPEED_SLOW] = 1
	_deliver(3, [invalid])
	_expect(_system.lifecycle.snapshot_tick == 2, "非布尔减攻速表现载荷拒绝应用")
	data[SNAP.U_SLOW] = 0
	data[SNAP.U_STUN] = 0
	data[SNAP.U_ATTACK_SPEED_SLOW] = false
	data[SNAP.U_BLIND] = false
	_deliver(4, [data])
	_expect(not unit.stun_visual() and not unit.movement_slow_visual() and not unit.attack_speed_slow_visual(), "新快照清除眩晕与两类软控提示")
	_expect(not unit.blind_visual(), "权威清除致盲后移除图标")
	_system.reset_session("")

func _check_dynamic_action_clock() -> void:
	_system.reset_session("dynamic-action")
	var data := _payload("kayn_slayer", 79103, 1)
	data[SNAP.U_ACTION_SERIAL] = 5
	data[SNAP.U_ACTION_NAME] = "active"
	data[SNAP.U_ACTION_DURATION] = 1.0
	data[SNAP.U_ACTION_TIME_LEFT] = 0.8
	data[SNAP.U_ACTION_CLOCK] = Vector2(1.0, 0.5)
	_deliver(2, [data])
	var replica: Unit = _main.world.replica_units_snapshot()[79103]
	_expect(replica.get_visual_action_clock() == Vector2(1.0, 0.5) and is_equal_approx(replica.get_visual_action_time_left(), 0.8), "晚到快照恢复动态技能归一进度和减速倍率")
	var invalid := data.duplicate(true)
	invalid[SNAP.U_ACTION_CLOCK] = Vector2(1.0, NAN)
	_deliver(3, [invalid])
	_expect(_system.lifecycle.snapshot_tick == 2, "非法动态时钟拒绝整份快照")
	data[SNAP.U_ACTION_TIME_LEFT] = 0.56
	data[SNAP.U_ACTION_CLOCK] = Vector2(1.0, 1.0)
	_deliver(4, [data])
	_expect(replica.get_visual_action_clock() == Vector2(1.0, 1.0) and is_equal_approx(replica.get_visual_action_time_left(), 0.56), "撞边界后同一动作序号跳至后段并恢复1倍速")
	data[SNAP.U_CANCELLATION] = {"serial": 1, "reason": "freeze", "attack": 0, "action": 1, "form": 0, "cancelled_action": 1, "cancelled_deployment": false}
	_deliver(5, [data])
	_expect(replica.get_visual_action_clock() == Vector2(1.0, 1.0), "旧取消事件不能清掉新动态施法时钟")
	var camera := Camera3D.new()
	camera.position = Vector3(0, 20, 30)
	_main.add_child(camera)
	camera.look_at(Vector3.ZERO)
	var view := UnitModel3D.new()
	view.material_states = ModelVisualResources.tool_material_states()
	_main.add_child(view)
	var stats := CardDB.get_card("kayn_slayer")
	var ready := view.setup(replica, load(stats.visual_scene_path), camera, stats.visual_animations, 0.0)
	_expect(ready and view._animation_player.assigned_animation == "Spell1_Stop", "客户端晚到模型直接进入权威Stop段")
	data[SNAP.U_ACTION_TIME_LEFT] = 0.25
	_deliver(6, [data])
	view._sync_visual(false, 0.05)
	_expect(view._animation_player.assigned_animation == "Spell1_Circle" and view._animation_player.speed_scale == 1.0, "客户端同序号跳段进入Circle且不继承突进倍率")
	data[SNAP.U_ACTION_CLOCK] = Vector2(0.0, 1.0)
	data[SNAP.U_ACTION_TIME_LEFT] = 0.0
	_deliver(7, [data])
	view._sync_visual(false, 0.05)
	_expect(not view._playing_visual_action, "客户端权威动态动作结束立即释放表现锁")
	view.free()
	camera.free()
	_system.reset_session("")

func _check_building_health_decay() -> void:
	_system.reset_session("building-health-decay")
	var aged_payloads: Array = []
	for card_id in CardDB.all():
		var stats: Dictionary = CardDB.get_card(card_id)
		if stats.get("type") != "building": continue
		for team in [0, 1]:
			var source := Unit.new()
			source.card_id = card_id
			source.setup(team, stats, stats.name)
			source._deploy_timer = 0.0
			for tick in roundi(source.lifespan / 0.05 / 2.0): source._tick_building_lifetime(0.05)
			var payload := preload("res://tests/fixtures/network_fixture.gd").snapshot_payload(_system, 79500 + aged_payloads.size(), source)
			aged_payloads.append(payload)
			source.free()
	_deliver(100, aged_payloads)
	for payload: Array in aged_payloads:
		var replica: Unit = _main.world.replica_units_snapshot()[payload[SNAP.U_ID]]
		_expect(replica.hp == replica.max_hp * 0.5 and is_equal_approx(replica.presentation_state().health_ratio, 0.5), "%s 阵营%d客户端首次见到已老化建筑就显示半血" % [replica.card_id, replica.team])
	var damaged_payloads := aged_payloads.duplicate(true)
	for payload: Array in damaged_payloads: payload[SNAP.U_HP] -= 10.0
	_deliver(101, damaged_payloads)
	_deliver(100, aged_payloads)
	for payload: Array in damaged_payloads:
		var replica: Unit = _main.world.replica_units_snapshot()[payload[SNAP.U_ID]]
		replica._process(1.0)
		_expect(replica.hp == float(payload[SNAP.U_HP]) and is_equal_approx(replica.presentation_state().health_ratio, replica.hp / replica.max_hp), "%s 阵营%d伤害快照继续从半血扣除，旧快照和表现帧不回满血" % [replica.card_id, replica.team])

func _check_tower_stasis() -> void:
	_system.reset_session("tower-stasis")
	var saved: Array = _main.world.towers_snapshot().map(func(t): return _system._tower_snapshot_payload(t))
	var payloads: Array = saved.duplicate(true)
	for payload: Array in payloads: payload[SNAP.T_STASIS] = true
	var packet := preload("res://tests/fixtures/network_fixture.gd").packet(_system, [], [], payloads, 5, 180, false)
	packet[SNAP.S_SERVER_TICK] = 1
	packet[SNAP.S_LIFECYCLE_REVISION] = 1
	_expect(_system.apply_decoded(_system.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE))), "7项塔载荷通过真实压缩快照接收")
	for tower: Tower in _main.world.towers_snapshot():
		_expect(CombatInteraction.in_stasis(tower) == not tower.is_king, "副本双方塔复制凝滞，水晶始终免疫")
		var timer := tower.control.stasis_timer
		tower._process(5)
		_expect(tower.control.stasis_timer == timer, "副本塔不按本地表现时间解除凝滞")
	packet[SNAP.S_SERVER_TICK] = 2
	packet[SNAP.S_LIFECYCLE_REVISION] = 2
	payloads[0][SNAP.T_STASIS] = 1
	_expect(not _system.apply_decoded(_system.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE))), "塔凝滞字段拒绝非布尔载荷")
	packet[SNAP.S_TOWERS] = saved
	_expect(_system.apply_decoded(_system.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE))), "权威解除快照恢复塔状态")
	_expect(_main.world.towers_snapshot().all(func(t): return not CombatInteraction.in_stasis(t)), "解除后所有塔不保留旧金身标志")


func _check_true_death_projection() -> void:
	_system.reset_session("true-death-results")
	var sion := _payload("sion", 78001, 1)
	sion[SNAP.U_HP] = 0
	sion[SNAP.U_DEATH_FORM] = [true, 40]
	sion[SNAP.U_ACTION_PERMISSIONS] = 0
	var soldier := _payload("sand_soldier", 78002, 2)
	var dragon := _payload("aurelionsol", 78003, 1)
	dragon[SNAP.U_SKILL_RESOURCE_ENABLED] = 1
	dragon[SNAP.U_SKILL_RESOURCE_RATIO] = 0.2
	_deliver(2, [sion, soldier, dragon])
	_spawn(soldier)
	_expect(_main.world.replica_units_snapshot().size() == 3 and _main.world.replica_units_snapshot()[78001].death_form.waiting() and is_equal_approx(_main.world.replica_units_snapshot()[78003].get_skill_resource_ratio(), 0.2), "本体真死快照同时保留赛恩、投影一层充能与单个新沙兵；迟到Spawn幂等")
	sion[SNAP.U_HP] = 2400
	sion[SNAP.U_FORM] = 1
	sion[SNAP.U_FORM_CHANGE_SERIAL] = 1
	sion[SNAP.U_DEATH_FORM] = [true, 0]
	_deliver(42, [sion, soldier, dragon])
	_main._rpc_unit_died(78001, true, "true-death-results", 43)
	_deliver(43, [soldier, dragon])
	_expect(_main.world.replica_units_snapshot().size() == 2 and is_equal_approx(_main.world.replica_units_snapshot()[78003].get_skill_resource_ratio(), 0.2), "狂暴退出仅删除实体，不在客户端追加收益或召唤")
	var egg := _payload("anivia_egg", 78004, 44)
	_spawn(egg)
	_main._rpc_unit_died(78004, false, "true-death-results", 45)
	var bird := _payload("anivia", 78005, 45)
	_spawn(bird)
	_spawn(egg)
	_deliver(46, [soldier, dragon, bird])
	_expect(not _main.world.replica_units_snapshot().has(78004) and _main.world.replica_units_snapshot().has(78005) and _main.world.replica_units_snapshot().size() == 3, "孵化删除蛋并生成冰鸟，迟到蛋Spawn不复活或生成额外转化物")

func _check_teleport_snapshot() -> void:
	_system.reset_session("teleport")
	var data := _payload("kassadin", 79140, 1)
	_deliver(2,[data])
	var replica: Unit = _main.world.replica_units_snapshot()[79140]
	data[SNAP.U_X] = 400.0
	data[SNAP.U_Y] = 640.0
	data[SNAP.U_TELEPORT_SERIAL] = 1
	_deliver(3,[data])
	_expect(replica.position == Vector2(400,640) and replica.teleport_serial == 1,"瞬移快照直接应用位置与序号")
	data[SNAP.U_X] = 403.0
	_deliver(4,[data])
	_expect(replica.position == Vector2(400,640) and replica.net_target_pos == Vector2(403,640),"同序号普通移动保留插值")
	data[SNAP.U_TELEPORT_SERIAL] = -1
	_deliver(5,[data])
	_expect(_system.lifecycle.snapshot_tick == 4,"负瞬移序号拒绝整包")
	data[SNAP.U_TELEPORT_SERIAL] = 1.5
	_deliver(5,[data])
	_expect(_system.lifecycle.snapshot_tick == 4,"非整数瞬移序号拒绝整包")
	_system.reset_session("")

func _assert_bad_packet_atomic(packet: Array, label: String, as_terminal: bool = false) -> void:
	var tick: int = _main._authoritative_server_tick
	var estimated: int = _main._estimated_server_tick
	var fraction: float = _main._estimated_server_tick_fraction
	var has_estimate: bool = _main._has_estimated_server_tick
	var revision := _system.lifecycle.snapshot_revision
	var ids := _system.lifecycle.snapshot_ids.duplicate()
	var entities: Dictionary = _main.world.replica_units_snapshot().duplicate()
	var health := {}
	for id in entities: health[id] = entities[id].hp
	var wallet: float = _main.runtime.account(0 if _main.runtime.mode == "server" else _main.runtime.local_team).elixir
	var growth: Dictionary = _main.runtime._card_growth.snapshot()
	var timer: float = _main.runtime._match_rules.time_left
	var received: int = _main._snapshots_received
	var queued: int = _main._network_playback.size()
	var projectiles: Dictionary = _main._projectile_system.client_snapshot()
	var projectile_view: Dictionary = _main._projectile_system.visible_view()
	var terminal: bool = _system.terminal_applied
	var candidate := packet.duplicate(true)
	candidate[SNAP.S_SERVER_TICK] = tick + 1
	candidate[SNAP.S_LIFECYCLE_REVISION] = revision + 1
	candidate[SNAP.S_CLIENT_ELIXIR] = 2.0 if _system._finite_number(candidate[SNAP.S_CLIENT_ELIXIR]) else candidate[SNAP.S_CLIENT_ELIXIR]
	if not candidate[SNAP.S_UNITS].is_empty() and _system._finite_number(candidate[SNAP.S_UNITS][0][SNAP.U_HP]): candidate[SNAP.S_UNITS][0][SNAP.U_HP] = 101.0
	var bytes := var_to_bytes(candidate).compress(FileAccess.COMPRESSION_DEFLATE)
	if as_terminal:
		_expect(not _system.apply_decoded(_system.decode_validated(bytes), true, int(candidate[SNAP.S_SERVER_TICK])), "可靠终态同样拒绝坏包：" + label)
	else:
		_main._rpc_snapshot(bytes)
	var unchanged: bool = _main._authoritative_server_tick == tick and _main._estimated_server_tick == estimated and _main._estimated_server_tick_fraction == fraction and _main._has_estimated_server_tick == has_estimate and _system.lifecycle.snapshot_revision == revision and _system.lifecycle.snapshot_ids == ids and _main.world.replica_units_snapshot() == entities and _main.runtime.account(0 if _main.runtime.mode == "server" else _main.runtime.local_team).elixir == wallet and _main.runtime._card_growth.snapshot() == growth and _main.runtime._match_rules.time_left == timer and _main._snapshots_received == received and _main._network_playback.size() == queued and _main._projectile_system.client_snapshot() == projectiles and is_same(projectile_view, _main._projectile_system.visible_view()) and _system.terminal_applied == terminal
	for id in entities: unchanged = unchanged and entities[id].hp == health[id]
	_expect(unchanged, "完整解码拒绝坏包且实体/时钟/生命周期/经济/成长/排程无副作用：" + label)

func _check_decoded_pipeline() -> void:
	var previous := _system
	var counting := CountingSnapshot.new(_main, _main._projectile_system)
	_system = counting
	_main._snapshot_system = counting
	_system.reset_session("decoded-pipeline")
	var unit := _payload("garen", 79500, 1)
	var packet := preload("res://tests/fixtures/network_fixture.gd").packet(_system, [unit], [], preload("res://tests/fixtures/network_fixture.gd").tower_payloads(_system), 5.0, 180.0, false)
	packet[SNAP.S_SERVER_TICK] = 2
	packet[SNAP.S_LIFECYCLE_REVISION] = 2
	var bytes := var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE)
	var decoded := _system.decode_validated(bytes)
	_expect(decoded != null and decoded.packet.is_read_only() and decoded.packet[SNAP.S_UNITS].is_read_only() and decoded.packet[SNAP.S_UNITS][0].is_read_only() and decoded.packet[SNAP.S_UNITS][0][SNAP.U_SPAWN].args.is_read_only() and decoded.unit_ids.is_read_only(), "解码后的完整包/载荷/出生描述/身份集合递归只读")
	_expect(_main.world.replica_units_snapshot().is_empty() and _system.lifecycle.snapshot_tick == -1, "解码校验本身不创建实体或推进快照屏障")
	_expect(_system.apply_decoded(decoded) and not _system.apply_decoded(decoded), "已解码包首次应用成功，重复应用保持幂等")
	for field in [SNAP.U_X, SNAP.U_HP, SNAP.U_FACING_DIRECTION_Y, SNAP.U_ACTIVE_SKILL_COOLDOWN]:
		for invalid in ["bad", NAN, INF, -INF]:
			var bad := packet.duplicate(true)
			bad[SNAP.S_UNITS].append(unit.duplicate(true))
			bad[SNAP.S_UNITS][1][SNAP.U_ID] = 79501
			bad[SNAP.S_UNITS][1][SNAP.U_SPAWN].args[3] = 79501
			bad[SNAP.S_UNITS][1][field] = invalid
			_assert_bad_packet_atomic(bad, "尾部单位字段%d" % field)
	for field in [SNAP.S_CLIENT_ELIXIR, SNAP.S_MATCH_TIMER, SNAP.S_OVERTIME]:
		var bad := packet.duplicate(true)
		bad[field] = "bad"
		_assert_bad_packet_atomic(bad, "主包字段%d" % field)
	for field in [SNAP.U_FROZEN, SNAP.U_ATTACK_SERIAL, SNAP.U_ACTION_NAME]:
		var bad := packet.duplicate(true)
		bad[SNAP.S_UNITS][0][field] = true
		_assert_bad_packet_atomic(bad, "单位字段类型%d" % field)
	var projectile := [1, -10.0, 20.0, Color.WHITE, 4.0, "orb", 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0, {}, 320.0]
	for field in [SNAP.P_X, SNAP.P_RADIUS, SNAP.P_COLOR, SNAP.P_VISUAL_PATH]:
		var bad := packet.duplicate(true)
		bad[SNAP.S_PROJECTILES] = [projectile.duplicate(true)]
		bad[SNAP.S_PROJECTILES][0][field] = "bad"
		_assert_bad_packet_atomic(bad, "弹体字段%d" % field)
	var tower := _system._tower_snapshot_payload(_main.world.towers_snapshot()[0])
	for field in [SNAP.T_HP, SNAP.T_ACTIVATED, SNAP.T_SHIELD_RATIO]:
		var bad := packet.duplicate(true)
		bad[SNAP.S_TOWERS] = []
		for _index in 6: bad[SNAP.S_TOWERS].append(tower.duplicate())
		bad[SNAP.S_TOWERS][1][field] = INF
		_assert_bad_packet_atomic(bad, "尾部塔字段%d" % field)
	var path := {"start": Vector2(-10, 20), "end": Vector2(800, 20), "origin_offset": Vector2.ZERO, "progress": 2.0, "contact_radius": 4.0, "wave": false, "source": {"unit": true, "id": -1, "local_id": 1, "team": 0, "position": Vector2.ZERO}, "target": {"unit": false, "king": true, "team": 1, "position": Vector2(800, 20)}}
	projectile[SNAP.P_VISUAL_PATH] = path
	var with_path := packet.duplicate(true)
	with_path[SNAP.S_PROJECTILES] = [projectile]
	_expect(_system.decode_validated(var_to_bytes(with_path).compress(FileAccess.COMPRESSION_DEFLATE)) != null, "合法场外坐标、零方向、未到达实体描述与progress>1仍可解码")
	_expect(SNAP.P_SPEED == 14 and SNAP.PROJECTILE_PAYLOAD_SIZE == 15 and MatchSession.PROTOCOL_VERSION > 115, "弹体速度是追加第15字段并与旧协议115隔离")
	for positive in [1, 0.125, 937.5]:
		var valid_speed := with_path.duplicate(true)
		valid_speed[SNAP.S_PROJECTILES][0][SNAP.P_SPEED] = positive
		_expect(_system.decode_validated(var_to_bytes(valid_speed).compress(FileAccess.COMPRESSION_DEFLATE)) != null, "弹体速度接受真实正数，不依赖卡牌基础速度：" + str(positive))
	for invalid in [null, true, "320", [], {}, NAN, INF, -INF, 0, -1.0]:
		var invalid_speed := with_path.duplicate(true)
		var tail: Array = projectile.duplicate(true)
		tail[SNAP.P_ID] = 2
		tail[SNAP.P_SPEED] = invalid
		invalid_speed[SNAP.S_PROJECTILES].append(tail)
		_assert_bad_packet_atomic(invalid_speed, "尾部弹体速度类型/有限值/正数域：" + str(invalid))
		_assert_bad_packet_atomic(invalid_speed, "尾部弹体速度类型/有限值/正数域：" + str(invalid), true)
	var legacy_projectile := with_path.duplicate(true)
	legacy_projectile[SNAP.S_PROJECTILES][0].pop_back()
	_assert_bad_packet_atomic(legacy_projectile, "缺速度的旧14字段弹体")
	_assert_bad_packet_atomic(legacy_projectile, "缺速度的旧14字段弹体", true)
	var extra_projectile := with_path.duplicate(true)
	extra_projectile[SNAP.S_PROJECTILES][0].append(320.0)
	_assert_bad_packet_atomic(extra_projectile, "多余第16字段弹体")
	_assert_bad_packet_atomic(extra_projectile, "多余第16字段弹体", true)
	var legacy_protocol := with_path.duplicate(true)
	legacy_protocol[SNAP.S_VERSION] = 115
	_assert_bad_packet_atomic(legacy_protocol, "旧协议115即使携带新弹体字段也拒绝")
	_assert_bad_packet_atomic(legacy_protocol, "旧协议115即使携带新弹体字段也拒绝", true)
	for invalid in [[], {"start": Vector2(NAN, 0)}, {"source": "bad"}, {"source": {"team": "bad"}}]:
		var bad := with_path.duplicate(true)
		if invalid is Dictionary: bad[SNAP.S_PROJECTILES][0][SNAP.P_VISUAL_PATH].merge(invalid, true)
		else: bad[SNAP.S_PROJECTILES][0][SNAP.P_VISUAL_PATH] = invalid
		_assert_bad_packet_atomic(bad, "弹体路径嵌套类型/有限值")
	var duplicate_projectile := with_path.duplicate(true)
	duplicate_projectile[SNAP.S_PROJECTILES].append(projectile.duplicate(true))
	_assert_bad_packet_atomic(duplicate_projectile, "重复弹体身份")
	var saved_peer: ENetMultiplayerPeer = _main._network_peer
	var saved_session: MatchSession = _main.runtime.session
	_main._network_peer = ENetMultiplayerPeer.new()
	_main.runtime.session = MatchSession.new()
	_main.runtime.session.session_id = "decoded-pipeline"
	_main.runtime.session.opponent_id = 1
	_main.runtime.session.phase = MatchSession.Phase.RUNNING
	packet[SNAP.S_SERVER_TICK] = 3
	unit[SNAP.U_HP] = 123.0
	bytes = var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE)
	var decodes := counting.decodes
	_main._rpc_snapshot(bytes)
	_expect(counting.decodes == decodes + 1 and _main._network_playback.snapshot_count() == 1, "真实RPC仅解码一次后持有已验证对象入队")
	var ready: Array[Dictionary] = _main._network_playback.advance(5.0)
	for event in ready: _main.callv(event.method, event.args)
	_expect(counting.decodes == decodes + 1 and _main.world.replica_units_snapshot()[79500].hp == 123.0 and _main._network_playback.snapshot_bytes() == 0, "出队应用不再次解码，队列移交后归还字节预算")
	ready.clear()
	_main._network_peer = saved_peer
	_main.runtime.session = saved_session
	var stale := _system.decode_validated(bytes)
	_expect(not _system.apply_decoded(stale), "等待期间已被更新的快照不能回拨")
	packet[SNAP.S_SERVER_TICK] = 4
	var future := _system.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE))
	_main._authoritative_server_tick = 5
	_expect(not _system.apply_decoded(future) and _system.lifecycle.snapshot_tick == 3, "出队重新检查权威时钟，拒绝已落后包且不改变生命周期")
	_main._authoritative_server_tick = 3
	_main.runtime.game_over = true
	_expect(not _system.apply_decoded(future), "等待期间终局禁止应用旧解码对象")
	_main.runtime.game_over = false
	_system.terminal_applied = true
	_expect(not _system.apply_decoded(future), "可靠终态屏障禁止应用队列残留")
	_system.terminal_applied = false
	_system.receive_death("decoded-pipeline", 79500, 4, false)
	_expect(_system.apply_decoded(future) and not _main.world.replica_units_snapshot().has(79500), "解码后收到真实死亡事件，应用时重新查墓碑而不复活")
	_expect(not _system.apply_decoded(future, true, 5) and not _system.terminal_applied, "最终Tick不匹配不改变终态屏障")
	_expect(_system.apply_decoded(future, true, 4) and _system.terminal_applied, "同Tick同revision的可靠终态可以覆盖普通快照")
	_system.reset_session("next-epoch")
	_expect(not _system.apply_decoded(future) and _main.world.replica_units_snapshot().is_empty(), "换会话后外部仍持有的旧只读包不能应用")
	_check_terminal_projectile_queue(counting, with_path)
	_check_snapshot_queue_budget(counting, packet)
	_system.reset_session("")
	_system = previous
	_main._snapshot_system = previous

func _check_terminal_projectile_queue(counting: CountingSnapshot, template: Array) -> void:
	_system.reset_session("terminal-projectile-speed")
	var terminal := template.duplicate(true)
	terminal[SNAP.S_SESSION] = "terminal-projectile-speed"
	terminal[SNAP.S_SERVER_TICK] = 20
	terminal[SNAP.S_LIFECYCLE_REVISION] = 20
	terminal[SNAP.S_PROJECTILES][0][SNAP.P_SPEED] = 937.5
	var pending := terminal.duplicate(true)
	pending[SNAP.S_SERVER_TICK] = 21
	pending[SNAP.S_LIFECYCLE_REVISION] = 21
	pending[SNAP.S_PROJECTILES][0][SNAP.P_SPEED] = 1337.0
	var decoded := counting.decode_validated(var_to_bytes(pending).compress(FileAccess.COMPRESSION_DEFLATE))
	var held: WeakRef = weakref(decoded)
	_expect(decoded != null and _main._network_playback.enqueue_snapshot(decoded), "终局前队列持有完整15字段的未来弹体包")
	decoded = null
	_expect(_main.world.replica_units_snapshot().is_empty() and _system.apply_decoded(_system.decode_validated(var_to_bytes(terminal).compress(FileAccess.COMPRESSION_DEFLATE)), true, 20), "可靠终态可首次恢复未知实体和新15字段弹体")
	var visible: Dictionary = _main._projectile_system.visible_view()
	_expect(_system.terminal_applied and _main._authoritative_server_tick == 20 and _main.world.replica_units_snapshot().has(79500) and visible.has(1) and is_equal_approx(float(visible[1].speed), 937.5), "终态恢复保留权威出膛速度并建立屏障")
	var decodes := counting.decodes
	var ready: Array[Dictionary] = _main._network_playback.advance(24.0)
	_expect(ready.size() == 1 and _main._network_playback.snapshot_count() == 0 and _main._network_playback.snapshot_bytes() == 0 and held.get_ref() != null, "终态后出队归还字节预算，返回数组仍持有解码对象")
	if ready.size() == 1: _main.callv(ready[0].method, ready[0].args)
	_expect(counting.decodes == decodes and _main._authoritative_server_tick == 20 and is_equal_approx(float(_main._projectile_system.visible_view()[1].speed), 937.5), "终态屏障阻止队列残留覆盖速度/时钟，且不重复解码")
	ready.clear()
	_expect(held.get_ref() == null, "释放出队数组后最后一份终态残留解码引用释放")
	_system.reset_session("next-epoch")

func _budget_member(template: Array, index: int) -> Array:
	var member := template.duplicate(true)
	member[SNAP.U_ID] = 80000 + index
	member[SNAP.U_SPAWN].args[3] = member[SNAP.U_ID]
	var position := Vector2(240, 900) if index == 0 else Vector2(600, 360) if index == 1 else Vector2(240, 360)
	member[SNAP.U_X] = position.x
	member[SNAP.U_Y] = position.y
	member[SNAP.U_SPAWN].args[2] = position
	if index == 0: member[SNAP.U_SPAWN].args[1] = 0
	return member

func _budget_projectile(id: int) -> Array:
	var start := Vector2(240, 900)
	var end := Vector2(600, 360)
	return _system._projectile_snapshot_payload(id, {
		"pos": start.lerp(end, 0.25), "direction": start.direction_to(end), "speed": 937.5,
		"color": Color.WHITE, "radius": 4.0, "visual": CardDB.get_unit_stats("ashe").get("projectile_visual", "orb"),
		"visual_height": 30.0, "visual_scale": 1.0, "visual_offset": Vector2(0, -30),
		"effects": {"first_strike": true}, "visual_path": {
			"start": start, "end": end, "origin_offset": Vector2.ZERO,
			"start_model_offset": Vector2(0, -30), "end_model_offset": Vector2(0, -30),
			"progress": 0.25, "contact_radius": 24.0, "wave": false,
			"source": {"unit": true, "id": 80000, "local_id": 0, "team": 0, "position": start},
			"target": {"unit": true, "id": 80001, "local_id": 0, "team": 1, "position": end},
		},
	})

func _weak_alive(reference: WeakRef) -> bool:
	# 将 get_ref 的临时强引用限制在本调用内；不能让测试 VM 栈延长被测对象寿命。
	return reference.get_ref() != null

func _check_snapshot_queue_budget(counting: CountingSnapshot, packet: Array) -> void:
	var playback := NetworkPlayback.new()
	var decoded := counting.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE))
	var complete := true
	for index in NetworkPlayback.MAX_QUEUED - 1: complete = playback.enqueue_snapshot(decoded) and complete
	complete = playback.enqueue(1, &"event", []) and complete
	_expect(complete and playback.size() == 4096 and playback.snapshot_count() == 4095 and not playback.enqueue_snapshot(decoded) and not playback.enqueue(1, &"event", []), "混合普通事件与快照共用4096项总上限")
	var held: WeakRef = weakref(decoded)
	decoded = null
	playback.clear()
	_expect(held.get_ref() == null and playback.size() == 0 and playback.snapshot_count() == 0 and playback.snapshot_bytes() == 0, "清队列释放最后一份解码对象引用及全部字节/数量预算")
	# 正式单位+16条真实15字段弹体，覆盖新增speed后的混合包；不加padding或伪造raw_bytes_size。
	var large := packet.duplicate(true)
	var template := _payload("ashe", 80000, 1)
	large[SNAP.S_UNITS] = []
	large[SNAP.S_PROJECTILES] = []
	for index in 16: large[SNAP.S_PROJECTILES].append(_budget_projectile(90000 + index))
	_expect(large[SNAP.S_PROJECTILES].all(func(row): return row.size() == 15 and is_equal_approx(float(row[SNAP.P_SPEED]), 937.5)), "预算夹具通过正式序列化器生成含真实速度的15字段弹体")
	var empty_size := var_to_bytes(large).size()
	var member_size := var_to_bytes(template).size()
	var target_count := maxi(1, floori(float(SNAP.MAX_DECODED_BYTES - empty_size) / float(member_size)))
	for index in target_count:
		large[SNAP.S_UNITS].append(_budget_member(template, index))
	var raw := var_to_bytes(large)
	# Variant编码边界大小以实际序列化结果为准，保证每包合法且尽量贴近单包上限。
	while raw.size() > SNAP.MAX_DECODED_BYTES:
		large[SNAP.S_UNITS].pop_back()
		raw = var_to_bytes(large)
	while raw.size() + member_size <= SNAP.MAX_DECODED_BYTES:
		large[SNAP.S_UNITS].append(_budget_member(template, large[SNAP.S_UNITS].size()))
		raw = var_to_bytes(large)
	_expect(raw.size() <= SNAP.MAX_DECODED_BYTES and raw.size() > SNAP.MAX_DECODED_BYTES - member_size * 2, "唯一单位/出生身份+15字段弹体的混合快照贴近1MiB上限，没有额外padding")
	var oversized := large.duplicate(true)
	oversized[SNAP.S_UNITS].append(_budget_member(template, oversized[SNAP.S_UNITS].size()))
	_expect(var_to_bytes(oversized).size() > SNAP.MAX_DECODED_BYTES, "再增加一个正式单位即越过1MiB；尺寸依据完整序列化而非旧协议估值")
	oversized.clear()
	var all_accepted := true
	var independent := true
	var identities := {}
	var held_large: Array[WeakRef] = []
	var raw_total := 0
	for index in 16:
		large[SNAP.S_SERVER_TICK] = 100 + index
		decoded = counting.decode_validated(var_to_bytes(large).compress(FileAccess.COMPRESSION_DEFLATE))
		all_accepted = decoded != null and all_accepted
		if decoded != null:
			independent = not identities.has(decoded.get_instance_id()) and independent
			identities[decoded.get_instance_id()] = true
			held_large.append(weakref(decoded))
			raw_total += decoded.raw_bytes_size
			all_accepted = playback.enqueue_snapshot(decoded) and all_accepted
	decoded = null
	_expect(all_accepted and independent and identities.size() == 16 and playback.snapshot_count() == 16 and playback.snapshot_bytes() == raw_total and raw_total <= NetworkPlayback.MAX_SNAPSHOT_BYTES, "8份播放窗口加8份余量的16个近最大116混合包均独立解码并入队")
	large[SNAP.S_SERVER_TICK] = 116
	decoded = counting.decode_validated(var_to_bytes(large).compress(FileAccess.COMPRESSION_DEFLATE))
	_expect(decoded != null and raw_total + decoded.raw_bytes_size > NetworkPlayback.MAX_SNAPSHOT_BYTES and not playback.enqueue_snapshot(decoded) and playback.snapshot_count() == 16, "下一份真实近最大包超过16MiB原始字节预算时明确拒绝且不增加持有量")
	var rejected: WeakRef = weakref(decoded)
	print("[SNAPSHOT_BURST_BUDGET] ", {"protocol": SNAP.SNAPSHOT_PROTOCOL_VERSION, "projectile_fields": SNAP.PROJECTILE_PAYLOAD_SIZE, "projectiles_per_packet": large[SNAP.S_PROJECTILES].size(), "units_per_packet": large[SNAP.S_UNITS].size(), "raw_bytes_per_packet": raw.size(), "compressed_bytes_per_packet": var_to_bytes(large).compress(FileAccess.COMPRESSION_DEFLATE).size(), "accepted": playback.snapshot_count(), "queued_raw_bytes": playback.snapshot_bytes(), "budget_raw_bytes": NetworkPlayback.MAX_SNAPSHOT_BYTES})
	playback.clear()
	_expect(held_large.all(func(reference: WeakRef): return reference.get_ref() == null), "清理预算突发时16份独立解码对象全部释放")
	_expect(playback.snapshot_bytes() == 0 and playback.enqueue_snapshot(decoded), "预算溢出清理后被拒的合法116包可以正常重新入队")
	decoded = null
	var ready: Array[Dictionary] = playback.advance(120.0)
	_expect(ready.size() == 1 and playback.snapshot_count() == 0 and playback.snapshot_bytes() == 0 and _weak_alive(rejected), "出队归还混合包全部raw预算，ready仍拥有解码引用")
	playback.clear()
	_expect(_weak_alive(rejected), "清空已空队列不销毁调用方仍持有的ready内容")
	ready.clear()
	_expect(not _weak_alive(rejected), "调用方释放ready后近最大116包最终释放")
