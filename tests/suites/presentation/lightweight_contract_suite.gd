extends RefCounted
## 小型投递/属性/契约验证：无模型、UI、预热、端口或自动模拟。
## 音频只读取约367KiB的三个已导入强化片段，headless Dummy不代表试听。
var _h: Object

class StartupProbe extends "res://scripts/main.gd":
	var overlays: Array[Dictionary] = []
	func has_presentation() -> bool: return false
	func _show_menu() -> void: pass
	func _ready() -> void:
		super._ready()
		set_process(false)
	func _show_stop_overlay(message: String, overlay_name: String) -> void:
		overlays.append({"message": message, "name": overlay_name})
	func _bind_server_peer(_peer: ENetMultiplayerPeer) -> Error:
		return ERR_CANT_CREATE # 不监听端口。

func run(harness: Object) -> void:
	_h = harness
	_configuration()
	var main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(main)
	_effect_delivery(main)
	await _audio_properties(main)
	main.free()
	for failure in ["resources", "config", "bind", "network_loading"]:
		_startup_failure(failure)
	_normal_result()

func _expect(ok: bool, message: String) -> void:
	_h._expect(ok, message)

func _configuration() -> void:
	var validator = CardDB.VALIDATOR
	_expect(validator.validate_all(CardDB.all(), false).is_empty(), "当前卡库在无资源校验下有效")
	# 整表形状预检与引用字段无关：首字段保留五种坏形状及双顺序，其余字段保留双顺序准入。
	for field in ["death_spawn_id", "assist_conversion_unit_id", "assist_conversion_building_id", "growth_ranged_id", "growth_melee_id", "deployment_upgrade_id"]:
		var invalid_shapes: Array = [42, null, [], {"type": []}, {"cost": []}] if field == "death_spawn_id" else [42]
		for invalid in invalid_shapes:
			var source: Dictionary = CardDB.get_card("garen").duplicate(true)
			source[field] = "bad_target"
			if field == "death_spawn_id":
				source.death_spawn_spread = 20.0
				source.death_spawn_duration = 1.0
				source.death_spawn_count = 1
			for target_first in [false, true]:
				var registry := {"bad_target": invalid, "garen": source} if target_first else {"garen": source, "bad_target": invalid}
				var errors: PackedStringArray = validator.validate_all(registry, false)
				_expect(not errors.is_empty() and "bad_target" in "；".join(errors), "整表形状预检安全返回路径：%s / %s / %s" % [field, str(invalid), target_first])
	var registry: Dictionary = CardDB.all().duplicate(true)
	registry.garen.deploy_zone = "global_no_river"
	_expect("global_no_river 已退役" in "；".join(validator.validate_all(registry, false)), "旧部署区域明确拒绝并提示迁移")
	registry.garen.deploy_zone = "global"
	_expect(validator.validate_all(registry, false).is_empty(), "global迁移保留有效全场部署案例")
	registry = CardDB.all().duplicate(true)
	registry.garen.active_skills.append({"name": "范围测试", "kind": "nova", "radius": 80.0, "damage": 20.0, "cost": 0, "cooldown": 1.0, "max_uses": 1})
	_expect(validator.validate_all(registry, false).is_empty(), "已实现nova伤害仍合法：" + "；".join(validator.validate_all(registry, false)))
	for value in [0.0, 1.0]:
		registry.garen.active_skills.back().stun_duration = value
		_expect("nova 未实现眩晕" in "；".join(validator.validate_all(registry, false)), "即使零值也拒绝未消费nova眩晕字段")
	registry.garen.active_skills.back().erase("stun_duration")
	_expect(validator.validate_all(registry, false).is_empty(), "删除未支持字段后nova合法")
	var wave: Dictionary = CardDetails.passives(CardDB.get_card("kayle_ranged")).filter(func(item): return item.name == "焰浪")[0]
	_expect("空中、地面单位及建筑、塔和水晶" in wave.description and "同类别" not in wave.description, "详情与既有跨空地焰浪规则一致")

func _payload(unit: Unit, fixed: bool = false) -> Dictionary:
	return {"net_id": unit.net_id, "fixed_position": fixed, "pos": unit.position, "shape": "continuous_area", "timer": 2.0, "duration": 2.0, "cast_serial": 2, "action_serial": 3}

func _deliver(main: Node2D, id: int, payload: Dictionary) -> void:
	main._rpc_skill_fx("fx-test", id, payload)

func _effect_delivery(main: Node2D) -> void:
	var source: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "garen", Vector2(300, 900), {"deploy_time_override": 0.0}))
	main.runtime.mode = "client"
	main.runtime.session.open("fx-test")
	main.runtime.session.opponent_id = 1
	main.runtime.session.phase = MatchSession.Phase.RUNNING
	main._snapshot_system.reset_session("fx-test")
	main.world.register_replica_unit(source)
	var fx = main._skill_presentation
	var payload := _payload(source)
	var frontal := _payload(source)
	frontal.merge({"forward": Vector2.DOWN, "length": 100.0, "width": 20.0, "shape": "fan_shared"}, true)
	main._rpc_skill_fx("fx-test", 0, frontal)
	_expect(fx.frontal_effects.size() == 1 and fx.frontal_effects[0].forward == Vector2.DOWN, "统一表现RPC使用有效来源仍能投递")
	fx.clear()
	_deliver(main, 1, payload)
	_deliver(main, 1, payload)
	_expect(fx.frontal_effects.size() == 1, "真实Main投递入口可靠事件去重")
	_deliver(main, 2, _payload(source, true))
	main._snapshot_system.lifecycle.accept_snapshot(10, 1, {})
	main._snapshot_system._apply_units([]) # 实际快照补删分支，无需建立网络或完整对局。
	_expect(fx.frontal_effects.size() == 1 and fx.frontal_effects[0].fixed_position, "网络删除即时移除依附表现且保留独立区域")
	_deliver(main, 3, payload)
	_expect(fx.frontal_effects.size() == 1, "销毁后迟到依附事件不能退回起始点")
	fx.tick_visuals(0.5)
	_expect(is_equal_approx(fx.frontal_effects[0].timer, 1.5), "固定区域继续本来寿命")
	_deliver(main, 4, _payload(source, true))
	_expect(fx.frontal_effects.size() == 2, "固定独立事件可在来源删除后到达")
	fx.tick_visuals(2.0)
	_expect(fx.frontal_effects.is_empty(), "独立区域按自身寿命正常结束")
	main.runtime.mode = "server"
	var caster: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "garen", Vector2(320, 920), {"deploy_time_override": 0.0}))
	main.runtime.mode = "client"
	main.world.register_replica_unit(caster)
	caster.cancelled_skill_cast_serial = 2
	_deliver(main, 5, _payload(caster))
	_expect(fx.frontal_effects.is_empty(), "取消屏障拒绝旧施法迟到效果")
	caster.cancelled_skill_cast_serial = -1
	caster.cancelled_visual_serial = 3
	_deliver(main, 6, _payload(caster))
	_expect(fx.frontal_effects.is_empty(), "动作取消屏障拒绝旧动作效果")
	caster.cancelled_visual_serial = -1
	_deliver(main, 7, _payload(caster))
	caster.hp = 0.0
	fx.tick_visuals(0.05)
	_expect(fx.frontal_effects.is_empty(), "已存在依附效果在来源死亡时清理")
	caster.hp = 100.0
	caster.control.apply_replica_flags(true, false)
	_deliver(main, 8, _payload(caster))
	_expect(fx.frontal_effects.is_empty(), "冻结来源拒绝迟到依附效果")
	caster.control.apply_replica_flags(false, false)
	_deliver(main, 9, _payload(caster))
	main._rpc_unit_died(caster.net_id, false, "fx-test", 11)
	_expect(fx.frontal_effects.is_empty(), "可靠销毁RPC同样即时清理依附效果")
	# 新本地弱引用独立覆盖无网络索引的释放。
	main.runtime.mode = "server"
	caster = main._spawn_unit(UnitSpawnRequest.new(0, "garen", Vector2(320, 920), {"deploy_time_override": 0.0}))
	fx.add_frontal_effect(caster, {"shape": "rectangle"}, 1.0, Vector2.UP)
	main.world.forget_replica_unit(caster.net_id)
	caster.free()
	fx.tick_visuals(0.05)
	_expect(fx.frontal_effects.is_empty(), "本地弱引用失效也清理依附效果")
	main.runtime.mode = "server"

func _audio_properties(main: Node2D) -> void:
	var manager := GameAudioManager.new()
	main.add_child(manager)
	manager.set_process(false)
	manager.begin_battle()
	var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "yorick", Vector2(300, 900), {"deploy_time_override": 0.0}))
	var event: Dictionary = CardDB.get_card("yorick").audio.events["empowered_buff:sustain"]
	var paths := PackedStringArray(event.pool)
	for path in paths:
		var original := load(path) as AudioStreamWAV
		_expect(original.loop_mode == AudioStreamWAV.LOOP_DISABLED, "真实导入强化音轨未自带循环")
	manager.prepare_audio({"events": {"empowered_buff:sustain": event}})
	manager.attach_unit(unit, {"audio": {"events": {"empowered_buff:sustain": event}}})
	unit.prepare_empowered_attack(1.0)
	manager._tick_attached_units()
	var key := manager._sustain_key(unit.get_instance_id(), &"empowered")
	var player: AudioStreamPlayer2D = manager._sustain_players.get(key)
	_expect(player != null, "准备强化状态启动持续层")
	if player == null:
		manager.free()
		unit.free()
		return
	var stream := player.stream as AudioStreamRandomizer
	for index in stream.streams_count:
		var wav := stream.get_stream(index) as AudioStreamWAV
		_expect(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "播放与预准备共用明确循环策略")
	unit.position += Vector2(60, -30)
	manager._tick_attached_units()
	_expect(player.global_position == unit.get_visual_screen_position(), "强化持续层随来源移动")
	await _h.process_frame # AudioServer下一帧才建立实际播放实例。
	manager.set_battle_paused(true)
	_expect(player.stream_paused, "工作台暂停冻结持续层")
	manager.set_battle_paused(false)
	_expect(not player.stream_paused, "解除暂停恢复原层")
	manager._on_action_cancelled({"attack": 100, "cancelled_action": 100}, unit.get_instance_id())
	_expect(manager._sustain_players.get(key) == player, "动作取消不结束独立强化状态")
	unit.empowered_attack_ready = false
	manager._tick_attached_units()
	_expect(not manager._sustain_players.has(key), "强化消费结束持续层")
	unit.prepare_empowered_attack(1.0)
	manager._tick_attached_units()
	manager._on_unit_death(unit.get_instance_id())
	_expect(manager._sustain_players.is_empty(), "来源死亡统一清理强化层")
	for path in paths:
		_expect((load(path) as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED, "循环副本未改写共享原音轨")
	manager.end_battle()
	_expect(manager.battle_audio_stopped(), "终局不残留声音")
	manager.free()
	unit.free()

func _startup_failure(failure: String) -> void:
	var main := StartupProbe.new()
	_h.root.add_child(main)
	main.server_auto_restart = false
	main.runtime.mode = "local"
	main.runtime._match_started = true
	main._skill_presentation.add_fixed_area_effect(Vector2.ZERO, 1.0, 2.0, 2.0, 0, &"target_circle")
	match failure:
		"resources": main._fail_preparation(PackedStringArray(["缺失素材：probe.tscn"]))
		"config": main._fail_startup("卡牌配置校验失败：probe.radius")
		"bind": main._start_server()
		"network_loading":
			main.runtime.mode = "client"
			main.runtime.session.phase = MatchSession.Phase.LOADING
			main._network_failed("本局资源准备失败：remote_probe.tscn")
	_expect(main.runtime.game_over and not main.can_advance_simulation(), "启动失败停止权威门禁：" + failure)
	_expect(main._resources._cancelled and main._skill_presentation.frontal_effects.is_empty() and main.runtime._commands.inspect_cards().is_empty(), "失败取消准备并清理表现和命令：" + failure)
	_expect(main._terminal_result.is_empty() and main.runtime.session.phase == MatchSession.Phase.DISCONNECTED, "启动失败不创建比赛结果快照：" + failure)
	_expect(main.overlays.size() == 1 and main.overlays[0].name == "StartupFailure" and main._startup_failure_message in main.overlays[0].message and "平局" not in main.overlays[0].message, "玩家可见失败原因且不是比分：" + failure)
	main._fail_startup("重复失败")
	main._end_game(-1, "timeout")
	_expect(main.overlays.size() == 1 and main._terminal_result.is_empty(), "重复失败和迟到终局幂等：" + failure)
	_expect(main._network_peer == null, "未创建peer的注入初态保持null（不证明真实关闭）：" + failure)
	main.free()

func _normal_result() -> void:
	var main := StartupProbe.new()
	_h.root.add_child(main)
	main.runtime.mode = "local"
	main.runtime.local_team = 0
	main.runtime._match_started = true
	main._create_towers()
	main.world.build_navigation()
	main._end_game(-1, "timeout")
	_expect(main.runtime.game_over and not main._terminal_result.is_empty() and main.runtime.session.phase == MatchSession.Phase.FINISHED, "正常终局仍保存比赛快照")
	_expect(main.overlays.size() == 1 and main.overlays[0].name == "MatchResult" and "平局" in main.overlays[0].message, "真正平局保留比分结果")
	main._end_game(0, "nexus")
	_expect(main.overlays.size() == 1, "正常终局同样幂等")
	main.free()

## 选择性入口：只验证_network_failed状态分流；不执行本文件其他检查或读取音轨。
class NetworkFailureProbe extends StartupProbe:
	var publications: Array[Dictionary] = []
	var close_requests := 0
	var reset_requests := 0
	var result_calls := 0
	var startup_calls := 0
	func _broadcast(endpoint: Callable, args: Array) -> void:
		publications.append({"endpoint": endpoint.get_method(), "args": args.duplicate(true)})
	func _close_network() -> void:
		close_requests += 1
		super._close_network() # peer从未创建；只能证明走到关闭入口。
	func _schedule_server_reset() -> void:
		reset_requests += 1 # 只记录请求，不定时、不重载场景、不建服务器。
	func _end_game(winner_team: int, reason: String) -> void:
		result_calls += 1
		super._end_game(winner_team, reason)
	func _fail_startup(message: String) -> void:
		startup_calls += 1
		super._fail_startup(message)

func check_network_failures(harness: Object) -> void:
	_h = harness
	for initial_phase in [MatchSession.Phase.LOBBY, MatchSession.Phase.LOADING, MatchSession.Phase.RUNNING]:
		for network_mode in ["client", "server"]:
			_network_failure_phase(initial_phase, network_mode)

func _network_failure_phase(initial_phase: MatchSession.Phase, network_mode: String) -> void:
	var main := NetworkFailureProbe.new()
	_h.root.add_child(main)
	main.runtime.mode = network_mode
	main.runtime.local_team = 0
	main.runtime._match_started = initial_phase != MatchSession.Phase.LOBBY
	main.runtime.session.open("boundary-old")
	main.runtime.session.phase = initial_phase
	if initial_phase == MatchSession.Phase.RUNNING:
		main._create_towers()
		main.world.build_navigation()
	main._snapshot_system.reset_session("boundary-old")
	main._skill_presentation.add_fixed_area_effect(Vector2.ZERO, 1.0, 2.0, 2.0, 0, &"target_circle")
	var tag := "%s/%s" % [network_mode, MatchSession.Phase.keys()[initial_phase]]
	var message := "注入网络失败：" + tag
	_expect(main._network_peer == null, "无端口夹具从未创建peer：" + tag)
	main._network_failed(message)
	_expect(main.runtime.game_over and main.runtime.session.phase == MatchSession.Phase.DISCONNECTED and not main.can_advance_simulation(), "失败关闭会话与模拟门禁：" + tag)
	_expect(main._skill_presentation.frontal_effects.is_empty(), "分流均保留已有表现清理：" + tag)
	if initial_phase == MatchSession.Phase.RUNNING:
		_expect(main.result_calls == 1 and main.startup_calls == 0 and main._startup_failure_message.is_empty(), "RUNNING只进入正常disconnect终态：" + tag)
		_expect(main.overlays.size() == 1 and main.overlays[0].name == "MatchResult" and "连接已断开" in main.overlays[0].message, "RUNNING显示断线结果而非启动失败：" + tag)
		if network_mode == "server":
			_expect(main._terminal_result.get("reason") == "disconnect" and main._terminal_result.get("winner_team") == -1 and not main._terminal_result.get("terminal_state", PackedByteArray()).is_empty(), "权威运行期断线保留最终快照：" + tag)
		else:
			_expect(main._terminal_result.is_empty(), "客户端断线不伪造权威结果快照：" + tag)
	else:
		_expect(main.startup_calls == 1 and main.result_calls == 0 and main._terminal_result.is_empty(), "LOBBY/LOADING只进入启动失败：" + tag)
		_expect(main.overlays.size() == 1 and main.overlays[0].name == "StartupFailure" and message in main.overlays[0].message, "准备失败显示原始原因：" + tag)
		_expect(main._resources._cancelled, "准备失败取消资源任务：" + tag)
	_expect(main.close_requests == (1 if network_mode == "client" else 0) and main.reset_requests == (1 if network_mode == "server" else 0), "请求既有客户端关闭/服务器重建入口（未执行真实连接）：" + tag)
	_expect(main.publications.size() == (1 if network_mode == "server" else 0), "服务端只发一次中止事件：" + tag)
	if network_mode == "server":
		_expect(main.publications[0].endpoint == "_rpc_abort" and main.publications[0].args == ["boundary-old", message], "中止事件保持原会话与原因：" + tag)
	var terminal := main._terminal_result.duplicate(true)
	var publications := main.publications.duplicate(true)
	var overlay_count := main.overlays.size()
	for duplicate in 2:
		main._network_failed("重复失败")
	_expect(main._terminal_result == terminal and main.publications == publications and main.overlays.size() == overlay_count and main.result_calls + main.startup_calls == 1, "重复失败不重发事件或终态：" + tag)
	_expect(main.close_requests + main.reset_requests == 1, "重复失败不重复请求收尾：" + tag)
	# 旧会话不可续接；这里只验证新MatchSession按既有规则准备，不执行真实场景重建。
	_expect(not main.runtime.session.start() and not main.runtime.session.join("boundary-new"), "失败会话不能直接复用或恢复RUNNING：" + tag)
	var fresh := MatchSession.new()
	if network_mode == "server":
		fresh.open("boundary-new")
		var bound := fresh.bind_player(2) == 0 and fresh.bind_player(3) == 1
		var decks := fresh.confirm_deck(2, "boundary-new") and fresh.confirm_deck(3, "boundary-new")
		_expect(bound and decks and fresh.begin_loading(), "新服务器会话可按原规则绑定并准备（无ENet）：" + tag)
		fresh.local_ready = true
		_expect(fresh.mark_remote_ready(2, "boundary-new") and fresh.mark_remote_ready(3, "boundary-new") and fresh.start(), "新会话就绪门禁可达RUNNING：" + tag)
	else:
		_expect(fresh.join("boundary-new"), "新客户端会话可重新进入准备：" + tag)
		fresh.deck_confirmed = true
		fresh.local_ready = true
		_expect(fresh.mark_remote_ready(1, "boundary-new") and fresh.start(), "新客户端会话就绪门禁仍有效：" + tag)
	_expect(not fresh.accepts(2 if network_mode == "server" else 1, "boundary-old", MatchSession.Phase.RUNNING), "新会话拒绝旧会话身份：" + tag)
	main.free()
