extends RefCounted
## 限定故障注入：无UI、音频、模型、资源预热、端口或自动模拟。
const FIXTURE = preload("res://tests/fixtures/network_fixture.gd")
const SNAP = preload("res://scripts/battle/network_snapshot_system.gd")
var _h: Object

class BlockedWorld extends "res://scripts/battle/battle_world.gd":
	func is_ground_position_walkable(_pos: Vector2, _radius: float, _excluded: Node = null, _edge: bool = false, _ignore: bool = false) -> bool:
		return false

class ContractProbe extends "res://tests/fixtures/authority_battle.gd":
	var overlays: Array[Dictionary] = []
	var reject_spawns := false
	var spawn_attempts := 0
	var publications: Array[StringName] = []
	func _broadcast(endpoint: Callable, _args: Array) -> void:
		publications.append(endpoint.get_method()) # 不创建peer或发送网络数据。
	func _show_stop_overlay(message: String, overlay_name: String) -> void:
		overlays.append({"message": message, "name": overlay_name})
	func create_network_unit(card_id: String, p_team: int, pos: Vector2, net_id: int, deploy_time_override: float = -1.0, active_ability_id: int = -1, active_ability_slot: int = -1, pre_deploy_id: int = -1, deployment_group_id: int = -1, visual_transition: String = "", death_replacement_charges_override: int = -1, built_on_tower_ruin: bool = false, active_skill_card_id: String = "", summon_visual_origin: Vector2 = Vector2.INF) -> void:
		spawn_attempts += 1
		if reject_spawns: return # 只注入工厂失败；正常路径调用正式实现。
		super.create_network_unit(card_id, p_team, pos, net_id, deploy_time_override, active_ability_id, active_ability_slot, pre_deploy_id, deployment_group_id, visual_transition, death_replacement_charges_override, built_on_tower_ruin, active_skill_card_id, summon_visual_origin)

class EncodingProbe extends "res://scripts/battle/network_snapshot_system.gd":
	var encodes := 0
	func encode_frame(frame: Array, team: int = 1) -> PackedByteArray:
		encodes += 1
		return super.encode_frame(frame, team)

func _new_main() -> ContractProbe:
	var main := ContractProbe.new()
	main.server_auto_restart = false
	_h.root.add_child(main)
	return main

func _expect(ok: bool, label: String) -> void:
	_h._expect(ok, label)

func run(harness: Object) -> void:
	_h = harness
	var main := _new_main()
	var properties: Array = main.get_property_list().map(func(p): return p.name)
	for name in ["nav", "_towers", "_king_player", "_king_enemy", "_net_units", "_client_units", "_session", "_match_started", "mode", "local_team", "game_over", "_elixir", "_elixir_p1"]:
		_expect(name not in properties, "Main不再暴露迁移期状态别名: " + name)
	for method in ["_build_nav", "is_ground_position_walkable", "find_ground_path", "unblock_nav_cells", "find_client_unit", "_arena_tile_center", "_register_dynamic_building", "_rpc_frontal_skill_fx"]:
		_expect(not main.has_method(method), "旧代理删除，消费者直达所有者: " + method)
	_expect(not main._snapshot_system.has_method("apply") and not main._snapshot_system.has_method("packet_tick") and not main._snapshot_system.has_method("_snapshot_packet"), "快照没有旧检查/字节应用/测试构包接口")
	var probe := Unit.new()
	_expect(not probe.has_method("mark_skill_resource_combat_activity"), "旧战斗活动别名删除")
	probe.free()
	_configuration(main)
	_snapshot(main)
	main.free()
	_missing_birth()
	_failed_replica()
	_missing_world()
	_missing_reward_account()
	_no_landing()
	_missing_projectile_field()
	_failure_stops_tick()
	_authority_topology()
	_reliable_spawn_failure()
	_clock_snapshots()

func _configuration(main: Node2D) -> void:
	_expect(CardDB.validate_all(false).is_empty(), "迁移后的77卡当前配置合同有效，无资源加载")
	var resources := MatchResources.new()
	resources._collect_only = true
	resources._prepare_card("garen")
	var art_path: String = CardDB.get_card("garen").card_art.path
	_expect(art_path == "res://assets/cards/garen_loading.jpg" and (resources._pending.has(art_path) or resources.resources.has(art_path)), "旧命名卡面已显式声明并进入资源集合")
	resources._prepare_card("unknown-strict-contract")
	_expect("unknown-strict-contract" in "；".join(resources.errors), "未知依赖不再静默跳过")
	resources.errors.clear()
	var missing := "res://assets/cards/" + "strict_missing.png"
	resources._collect({"card_art": {"path": missing}})
	_expect("不存在" in "；".join(resources.errors) and missing in "；".join(resources.errors), "已声明卡面缺失保留具体路径错误")
	resources._accept("injected-scene", Resource.new(), &"PackedScene")
	resources._accept("injected-audio", null, &"AudioStream")
	_expect(resources.errors.size() == 3 and not resources.resources.has("injected-scene") and not resources.resources.has("injected-audio"), "资源加载及类型失败均拒绝加入强引用集合")
	main._fail_preparation(resources.errors)
	_expect(main.runtime.game_over and main.overlays.size() == 1 and main.overlays[0].name == "StartupFailure" and missing in main.overlays[0].message and main._terminal_result.is_empty(), "坏资源传播到启动失败，不生成比分/终态快照")
	# 空card_art/audio域有明确无素材语义，不在本批强制新增艺术资源。
	var optional := CardDB.all().duplicate(true)
	optional.garen.card_art = {}
	optional.garen.audio = {}
	_expect(CardDB.VALIDATOR.validate_all(optional, false).is_empty(), "设计允许无卡面/无音效；只拒绝损坏的显式资源")
	var audio := GameAudioManager.new()
	_expect(audio.prepare_audio({}), "无音效的合法空配置仍成功")
	_expect(not audio.prepare_audio({"pool": [missing]}) and missing in "；".join(audio.preparation_errors) and audio._stream_pool_cache.is_empty(), "声明音轨缺失明确失败，不缓存部分/空声音池")
	audio.free()

func _snapshot(_finished: Node2D) -> void:
	var host := _new_main()
	host.runtime._sim_tick_id = 12
	var source: Unit = host._spawn_unit(UnitSpawnRequest.new(0, "garen", Vector2(360, 900), {"deploy_time_override": 0.0}))
	var frame: Array = host._snapshot_system.capture_public_frame()
	var birth: Dictionary = frame[SNAP.S_UNITS][0][SNAP.U_SPAWN]
	_expect(birth.birth_tick == 12 and birth.birth_revision == 1 and birth.args.size() == 14 and birth.args[3] == source.net_id, "正式编码使用真实出生Tick/修订/当前描述")
	var bytes := host._snapshot_system.encode_frame(frame, 0)
	_expect(host._snapshot_system.decode_validated(bytes) != null, "完整当前快照可解码")
	for count in [0, 5, 7]:
		var packet := frame.duplicate(true)
		packet[SNAP.S_CLIENT_ELIXIR] = 5.0
		packet[SNAP.S_CARD_GROWTH] = host.runtime.growth_snapshot(0)
		packet[SNAP.S_TOWERS].resize(count)
		_expect(host._snapshot_system.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE)) == null, "缺失/多余塔行必须拒绝: %d" % count)
	var old_birth := birth.duplicate(true)
	old_birth.args.pop_back()
	_expect(not host._snapshot_system._valid_spawn(old_birth), "旧13字段出生描述拒绝，不追加兼容字段")
	var client := _new_main()
	client.runtime.mode = "client"
	client._snapshot_system.reset_session("")
	_expect(client._snapshot_system.apply_decoded(client._snapshot_system.decode_validated(bytes)) and client.world.find_replica_unit(source.net_id) != null, "唯一decode/apply入口仍恢复真实副本")
	client.free()
	host.free()

func _missing_birth() -> void:
	var main := _new_main()
	var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "garen", Vector2(360, 900), {"deploy_time_override": 0.0}))
	main._snapshot_system.lifecycle.spawns.erase(unit.net_id)
	var bytes := main._snapshot_system.capture()
	_expect(bytes.is_empty() and main.runtime.game_over and main._terminal_result.is_empty(), "缺出生事实停止对局并返回空失败结果，不补造出生快照")
	_expect(main.overlays.size() == 1 and main.overlays[0].name == "ContractFailure" and "id=1000" in main.overlays[0].message, "内部契约失败单独显示可定位错误")
	main._fail_contract("repeat")
	_expect(main.overlays.size() == 1, "重复错误收尾幂等")
	main.free()

func _failed_replica() -> void:
	var main := _new_main()
	main.runtime.mode = "client"
	main.reject_spawns = true
	var unit := Unit.new()
	unit.card_id = "garen"
	unit.setup(0, CardDB.get_unit_stats("garen"), "garen")
	var row: Array = FIXTURE.snapshot_payload(main._snapshot_system, 7001, unit)
	var packet: Array = FIXTURE.packet(main._snapshot_system, [row], [], FIXTURE.tower_payloads(main._snapshot_system), 5, 60, false)
	unit.free()
	var decoded = main._snapshot_system.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE))
	_expect(decoded != null and not main._snapshot_system.apply_decoded(decoded), "通过静态校验但工厂失败的包返回false")
	_expect(main.runtime.game_over and main._snapshots_received == 0 and main._terminal_result.is_empty() and "id=7001" in main.overlays[0].message, "创建失败不算成功快照，不推进经济/比赛副本或伪造平局")
	main.free()

func _missing_world() -> void:
	var main := _new_main()
	main.runtime.mode = "client"
	var packet: Array = FIXTURE.packet(main._snapshot_system, [], [], FIXTURE.tower_payloads(main._snapshot_system), 5, 60, false)
	var decoded = main._snapshot_system.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE))
	main.world.clear_towers()
	_expect(not main._snapshot_system.apply_decoded(decoded) and main.runtime.game_over and main._snapshots_received == 0 and "6座塔" in main.overlays[0].message, "本地战场缺塔明确停止，不能mini截断应用成功")
	main.free()

func _missing_reward_account() -> void:
	var main := _new_main()
	main._workbench.enabled = true
	main.battle_context.grant_team_elixir(0, 1.0)
	_expect(not main.runtime.game_over, "工作台明确无账户，仍可预览收益")
	main._workbench.enabled = false
	main.battle_context.grant_team_elixir(0, 1.0)
	_expect(main.runtime.game_over and main.overlays.size() == 1 and "奖励账户缺失 team=0" in main.overlays[0].message and main._terminal_result.is_empty(), "权威收益缺必需账户停止，不静默丢弃金币或伪造成功")
	main.free()

func _no_landing() -> void:
	var main := _new_main()
	var source: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "garen", Vector2(360, 900), {"deploy_time_override": 0.0}))
	var blocked := BlockedWorld.new(main)
	main.world = blocked
	main.runtime.world = blocked
	var requested := Vector2(360, 850)
	_expect(blocked.nearest_valid_ground_spawn(requested, 14, 0) == Vector2.INF, "无合法落点返回失败哨兵，不返回原始非法点")
	_expect(not main.runtime.schedule_summon_flight(source, "melee_minion", requested, 0.5, 0.0) and main.runtime._commands.inspect_summons().is_empty(), "无解召唤飞行明确拒绝，不排程非法坐标或伪造表现")
	var count: int = main.get_child_count()
	var result: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "garen", requested))
	_expect(result == null and main.runtime.game_over and main.get_child_count() == count and "合法地面落点" in main.overlays[0].message, "原始生成契约无解停止并不创建非法实体")
	main.free()

func _missing_projectile_field() -> void:
	var main := _new_main()
	main._projectile_system.projectiles[99] = {"direction": Vector2.UP, "color": Color.WHITE, "radius": 4.0, "visual": &"orb", "speed": 320.0}
	_expect(main._snapshot_system.capture().is_empty() and main.runtime.game_over and main.overlays.size() == 1 and "id=99 field=pos" in main.overlays[0].message, "弹体缺必需位置显式失败，不补零坐标编码")
	main.free()

func _failure_stops_tick() -> void:
	var main := _new_main()
	var building: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "tombstone", Vector2(360, 900), {"deploy_time_override": 0.0}))
	var hp := building.hp
	var finished: Array = []
	main.runtime.world_step_finished.connect(func(_dt): finished.append(true))
	main._combat.defer_benefit(func(): main._fail_contract("injected phase failure"))
	main.runtime.step(0.05)
	_expect(main.runtime.game_over and not main.runtime._sim_step_active and not main._combat.collecting and not main._combat.committing, "契约失败仍完成当前事务收尾，归还Tick/提交权限")
	_expect(main._combat._phase == "skill_impacts" and finished.is_empty() and building.hp == hp, "首阶段失败不推进后续阶段、自然衰血或世界完成事件")
	_expect(main._spawn_unit(UnitSpawnRequest.new(0, "garen", Vector2(300, 900))) == null, "错误终止后原始工厂也拒绝新增实体")
	main.free()

func _authority_topology() -> void:
	for boundary in ["frame", "capture", "send", "terminal"]:
		var main := _new_main()
		var system := EncodingProbe.new(main, main._projectile_system)
		main._snapshot_system = system
		main.world._towers.pop_back() # 单个缺席，仍保留其他5座及HP0塔的正常索引语义。
		var empty := true
		match boundary:
			"frame": empty = system.capture_public_frame().is_empty()
			"capture": empty = system.capture().is_empty()
			"send": system.send()
			"terminal": main._end_game(-1, "timeout")
		_expect(empty and main.runtime.game_over and main.overlays.size() == 1 and main.overlays[0].name == "ContractFailure" and "实际5座" in main.overlays[0].message, "权威缺一塔明确失败：" + boundary)
		_expect(system.encodes == 0 and main._terminal_result.is_empty() and &"_rpc_end" not in main.publications and &"_rpc_snapshot" not in main.publications, "缺塔不编码/保存/发布普通或终局状态：" + boundary)
		main.free()
	var valid := _new_main()
	valid.world.towers_snapshot()[0].take_damage(100000.0)
	var frame: Array = valid._snapshot_system.capture_public_frame()
	_expect(not valid.runtime.game_over and frame[SNAP.S_TOWERS].size() == 6 and frame[SNAP.S_TOWERS][0][SNAP.T_HP] == 0.0, "合法摧毁的零血塔仍占固定索引，公共帧保持有效")
	valid._end_game(-1, "timeout")
	_expect(valid.overlays.size() == 1 and valid.overlays[0].name == "MatchResult" and valid._snapshot_system.decode_validated(valid._terminal_result.terminal_state) != null, "含零血塔的合法终局仍保存可解码完整快照")
	valid.free()

func _reliable_spawn_failure() -> void:
	var unit := Unit.new()
	unit.card_id = "garen"
	unit.setup(0, CardDB.get_unit_stats("garen"), "garen")
	var main := _new_main()
	main.runtime.mode = "client"
	main.reject_spawns = true
	var birth: Dictionary = FIXTURE.snapshot_payload(main._snapshot_system, 8001, unit)[SNAP.U_SPAWN]
	birth.birth_revision = 1
	var rpc_args: Array = birth.args.duplicate(true)
	rpc_args.append_array(["", birth.birth_tick, birth.birth_revision])
	main._rpc_spawn_unit.callv(rpc_args)
	_expect(main.runtime.game_over and main.spawn_attempts == 1 and main.overlays.size() == 1 and "id=8001" in main.overlays[0].message, "合法可靠出生RPC工厂失败立即进入契约错误，无需等待后续快照")
	main._snapshot_system.receive_death("", 8001, 10, false)
	_expect(main.world.find_replica_unit(8001) == null and not main._snapshot_system.lifecycle.spawns.has(8001) and main.overlays.size() == 1, "失败出生不残留虚假出生事实，随后死亡不能掩盖错误")
	main.free()
	var ignored := _new_main()
	ignored.runtime.mode = "client"
	ignored.reject_spawns = true
	ignored._snapshot_system.lifecycle.mark_destroyed(8001, 10)
	ignored._snapshot_system.receive_spawn("", birth)
	_expect(not ignored.runtime.game_over and ignored.spawn_attempts == 0, "死亡后迟到出生继续正常拒绝，不误停")
	ignored._snapshot_system.lifecycle.reset("")
	ignored._snapshot_system.lifecycle.accept_snapshot(10, 2, {})
	ignored._snapshot_system.receive_spawn("", birth)
	_expect(not ignored.runtime.game_over and ignored.spawn_attempts == 0, "快照屏障拒绝陈旧出生，不误停")
	ignored._snapshot_system.lifecycle.reset("")
	ignored.reject_spawns = false
	ignored._snapshot_system.receive_spawn("", birth)
	var existing = ignored.world.find_replica_unit(8001)
	ignored.reject_spawns = true
	ignored._snapshot_system.receive_spawn("", birth)
	_expect(is_instance_valid(existing) and existing == ignored.world.find_replica_unit(8001) and ignored.spawn_attempts == 1 and not ignored.runtime.game_over, "已有实体的重复可靠出生保持身份且不重进工厂")
	ignored.free()
	unit.free()

func _clock_snapshots() -> void:
	var main := _new_main()
	main.runtime.mode = "client"
	main._authoritative_server_tick = 100
	main._estimated_server_tick = 100
	main._estimated_server_tick_fraction = 0.0
	main._has_estimated_server_tick = true
	main._advance_estimated_server_tick(0.23)
	var checks: Dictionary = FIXTURE.clock_snapshot_window(main, main.get_estimated_server_tick())
	_expect(checks.newer_applied and checks.estimate_survives, "复用Arena当前六塔有效包：102权威Tick接收但不回拨已估计时钟")
	_expect(checks.incompatible_rejected and checks.stale_rejected and main._snapshots_received == 1, "复用Arena当前入口：旧协议和101旧Tick不改变副本或增加成功快照")
	main.free()
