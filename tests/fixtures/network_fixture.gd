extends RefCounted
## 白盒表现回放也走正式会话门禁，临时身份不会泄漏到后续套件。
static func deliver(main: Node, method: StringName, args: Array) -> void:
	var previous = main.runtime.session
	var session := MatchSession.new()
	session.join("presentation-fixture")
	session.phase = MatchSession.Phase.RUNNING
	main.runtime.session = session
	main.callv(method, [session.session_id] + args)
	main.runtime.session = previous

## 与出牌排序无关的机制测试显式安装固定牌序；随机开局另由镜像套件覆盖。
static func fixed_cycle(main: Node, team: int, deck: Array) -> void:
	if main.is_net_client():
		main._client_hand.clear()
		main.runtime._authoritative_card_cycles.clear()
		main._apply_client_hand_state(CardCycle.new(deck, false).visible_state(0, {}))
		return
	main.runtime._authoritative_card_cycles[team] = CardCycle.new(deck, false)
	main._sync_card_cycle_ui(team)

## 单字段快照测试显式提供合成出生事实；不把它藏进生产编码器。
## 不注册生命周期、不改单位ID；完整网络路径仍使用真实spawn记录。
static func snapshot_payload(system: NetworkSnapshotSystem, id: int, unit: Unit, continuous: bool = false, endpoint: Vector2 = Vector2.ZERO, facing: Vector2 = Vector2.ZERO) -> Array:
	var skill_card := unit.active_skill_card_id if not unit.active_skill_card_id.is_empty() else unit.card_id
	var descriptor := {"birth_tick": 0, "birth_revision": 0, "args": [unit.card_id, unit.team, unit.global_position, id, unit.deploy_time, unit.active_ability_id, unit.active_ability_slot, -1, unit.deployment_group_id, String(unit.visual_spawn_transition), unit.death_replacement_charges, unit.built_on_tower_ruin, skill_card, unit.summon_visual_origin]}
	return system._unit_snapshot_payload(id, unit, descriptor, continuous, endpoint, facing)

## 测试包明确提供当前协议全部字段；可传畸形塔数组来测试拒绝，生产不自动补齐。
static func packet(system: NetworkSnapshotSystem, units: Array, projectiles: Array, towers: Array, coins: float, remaining: float, overtime: bool, team: int = 1) -> Array:
	return [system.SNAPSHOT_PROTOCOL_VERSION, system._controller.runtime._sim_tick_id, units, projectiles, towers, coins, remaining, overtime, system.lifecycle.session_id, system.lifecycle.revision, system._controller.runtime.growth_snapshot(team)]

static func tower_payloads(system: NetworkSnapshotSystem) -> Array:
	return system._controller.world.towers_snapshot().map(func(t): return system._tower_snapshot_payload(t))

## Arena与轻量专项共用同一纯快照时钟场景；有效包必须有真实六塔载荷。
static func clock_snapshot_window(main: Node2D, expected_estimate: int) -> Dictionary:
	var system := NetworkSnapshotSystem.new(main, main._projectile_system)
	system.lifecycle.reset(main._snapshot_system.lifecycle.session_id)
	var newer := packet(system, [], [], tower_payloads(system), 0.0, 180.0, false)
	newer[system.S_SERVER_TICK] = 102
	var applied := system.apply_decoded(system.decode_validated(var_to_bytes(newer).compress(FileAccess.COMPRESSION_DEFLATE)))
	var survives: bool = main._authoritative_server_tick == 102 and main.get_estimated_server_tick() == expected_estimate
	var incompatible := newer.duplicate(true)
	incompatible[system.S_VERSION] -= 1
	incompatible[system.S_SERVER_TICK] = 103
	var rejected_version := not system.apply_decoded(system.decode_validated(var_to_bytes(incompatible).compress(FileAccess.COMPRESSION_DEFLATE)))
	var version_keeps_tick: bool = main._authoritative_server_tick == 102
	var stale := newer.duplicate(true)
	stale[system.S_SERVER_TICK] = 101
	var rejected_stale := not system.apply_decoded(system.decode_validated(var_to_bytes(stale).compress(FileAccess.COMPRESSION_DEFLATE)))
	return {"newer_applied": applied, "estimate_survives": survives, "incompatible_rejected": rejected_version and version_keeps_tick, "stale_rejected": rejected_stale and main._authoritative_server_tick == 102}
