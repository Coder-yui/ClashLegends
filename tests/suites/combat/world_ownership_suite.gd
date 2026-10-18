extends "res://tests/suites/battle_suite.gd"
## 无表现、无资源、无端口：只覆盖World迁移的集合/身份/占位与直接消费者。
func run(harness: Object) -> void:
	_harness = harness
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	await _check_authority()
	_check_conversion()
	_main.free()
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	_main.runtime.mode = "client"
	harness.root.add_child(_main)
	_check_replica()
	_main.runtime.mode = "server"
	var effects = preload("res://tests/suites/presentation/lightweight_contract_suite.gd").new()
	effects._h = _harness
	effects._effect_delivery(_main)
	_main.free()
	_main = null

func _spawn(card: String, pos: Vector2, resolved: bool = true) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(0, card, pos, {"position_resolved": resolved, "deploy_time_override": 0.0}))

func _check_authority() -> void:
	var world = _main.world
	var towers: Array = world.towers_snapshot()
	var next_view: Array = world.towers_snapshot()
	_expect(towers.size() == 6 and towers == next_view and not is_same(towers, next_view) and towers.is_read_only(), "塔集合仅World持有，每次查询返回独立只读容器")
	_expect(towers[4] == world.king(0) and towers[5] == world.king(1) and towers[0].position == Vector2(140, 1020) and towers[3].position == Vector2(580, 260), "塔顺序、阵营、水晶引用及地图位置保持")
	_expect(towers.map(func(t): return t.combat_source_id) == [1, 2, 3, 4, 5, 6] and towers.all(func(t): return t.get_parent() == _main), "塔仍直接挂Main，来源ID按原节点顺序分配")
	_main.runtime._sim_tick_id = 41
	_main.runtime._sim_step_active = true
	var grown := _spawn("garen", towers[0].position + Vector2(0, -80))
	_main.runtime._sim_step_active = false
	var building := _spawn("tombstone", Vector2(360, 900))
	_expect(grown.net_id == 1000 and building.net_id == 1001 and grown.combat_source_id == 7 and building.combat_source_id == 8, "主机网络ID从1000开始，与combat来源ID分开保持顺序")
	_expect(grown.lifecycle_birth_tick == 41 and building.lifecycle_birth_tick == -1 and grown.get_parent() == _main, "生成仍使用原出生Tick与节点父子布局")
	var units: Dictionary = _main.world.authoritative_units_snapshot()
	_expect(units.is_read_only() and units.size() == 2 and _main.world.replica_units_snapshot().is_empty(), "权威与副本索引分开，Main无可独立写入的镜像")
	_expect(world.combatants().filter(func(actor): return actor is Unit) == [grown, building], "combatants仍按场景组快照遍历，无另一套排序注册表")
	var river_nav: NavGrid = world.navigation_for_river()
	_expect(not building.nav_cells.is_empty() and not world.nav.is_walkable(building.position) and not river_nav.is_walkable(building.position), "正式生成共用World建筑占位，普通/跨河导航均阻挡")
	var before := grown.position
	grown.apply_permanent_growth(0.3, 1.3)
	_expect(grown.position != before and world.is_ground_position_walkable(grown.position, grown.body_radius, grown) and _main.resize_requests == 1, "成长直接进入World并完成安全体型交接")
	_expect(grown._prev_pos == grown.position and grown.net_target_pos == grown.position, "成长保留插值/路径收尾")
	building.take_damage(100000.0)
	_expect(building.nav_cells.is_empty() and not world.authoritative_units_snapshot().has(building.net_id) and world.nav.is_walkable(building.position), "建筑正式死亡同时释放占位与权威索引")
	var updated: NavGrid = world.navigation_for_river()
	_expect(updated != river_nav and updated.is_walkable(building.position), "建筑死亡使跨河导航按revision重建")
	world.release_structure_footprint(building)
	_expect(world.nav.is_walkable(building.position), "重复空间收尾不二次递减导航引用计数")
	var waiting := _spawn("sion", Vector2(420, 900))
	waiting.take_damage(100000.0)
	_expect(waiting.hp == 0.0 and waiting.death_form.waiting() and world.authoritative_units_snapshot().get(waiting.net_id) == waiting and not waiting.is_queued_for_deletion(), "零血等待复生保持原实体、ID和生命周期")
	var unset_death := _spawn("garen", Vector2(500, 900))
	unset_death.hp = 0.0
	_expect(world.authoritative_units_snapshot().has(unset_death.net_id), "索引查询不凭HP代替正式死亡提交")
	var public_frame: Array = _main._snapshot_system.capture_public_frame()
	_expect(public_frame[NetworkSnapshotSystem.S_UNITS].filter(func(payload): return payload[NetworkSnapshotSystem.U_ID] in [grown.net_id, waiting.net_id, unset_death.net_id]).map(func(payload): return payload[NetworkSnapshotSystem.U_ID]) == [grown.net_id, waiting.net_id], "快照沿原登记顺序编码，等待者保留，未提交零血不伪造活体载荷")
	var direct_id := unset_death.net_id
	unset_death.free()
	_expect(not world.authoritative_units_snapshot().has(direct_id), "节点直接退出也移除登记，不残留失效对象")
	var shared := _spawn("tombstone", Vector2(360, 900))
	var overlap := _spawn("tombstone", shared.position)
	world.remove_unit(shared)
	_expect(not world.nav.is_walkable(overlap.position) and not overlap.nav_cells.is_empty(), "重叠建筑移除一份只释放自己的导航引用")
	# 原完整Tick塔收尾阶段，不提早在伤害回调激活水晶。
	world.king(0).can_attack = true
	towers[0].take_damage(100000.0)
	_expect(not world.king(0).activated, "公主塔死亡不在伤害回调提前激活水晶")
	world.finish_tower_step()
	_expect(towers[0].nav_cells.is_empty() and world.towers_snapshot().size() == 6 and world.king(0).activated, "塔死亡释放空间，保留固定塔索引供比分/网络使用")
	_main.clear_preview_battle()
	_main.clear_preview_battle()
	_expect(world.authoritative_units_snapshot().is_empty() and world.replica_unit_ids().is_empty() and world.combatants().all(func(actor): return actor is Tower), "工作台重复清场同步移除单位/双索引/战斗组，塔保留")
	_expect(overlap.nav_cells.is_empty() and world.nav.is_walkable(overlap.position), "清场释放全部动态占地，没有延迟双减")
	var after_clear := _spawn("garen", Vector2(360, 900))
	_expect(after_clear.net_id > overlap.net_id and after_clear.combat_source_id > overlap.combat_source_id, "清场不回滚网络或来源ID分配器")
	var probe = preload("res://tools/performance/benchmark_main.gd").BenchmarkWorld.new(_main)
	probe.is_ground_position_walkable(Vector2(360, 900), 14.0)
	probe.find_ground_path(Vector2(360, 900), Vector2(360, 850), null)
	_expect(probe._navigation_count == 1 and probe.authoritative_units_snapshot().values() == [after_clear], "性能采样在真实World查询入口计数，诊断快照保留本地单位负载")
	world.clear_units()
	var previous_tower_id: int = towers[0].get_instance_id()
	var previous_source_id: int = after_clear.combat_source_id
	await _main._rebuild_workbench_arena()
	_expect(world.towers_snapshot().size() == 6 and world.king(0) == world.towers_snapshot()[4] and world.towers_snapshot()[0].get_instance_id() != previous_tower_id, "工作台重建一次性替换塔集合和水晶引用，无旧引用镜像")
	_expect(world.combatants().size() == 6 and world.towers_snapshot()[0].combat_source_id > previous_source_id and not world.nav.is_walkable(world.towers_snapshot()[0].position), "重建保留来源ID单调性，重新建立导航，不遗留旧战斗节点")

func _check_replica() -> void:
	var world = _main.world
	# 服务器位置故意在塔中心；客户端创建/半径接收不得擅自修正。
	var server_position: Vector2 = world.king(0).position
	_main.create_network_unit("garen", 0, server_position, 7001, 0.0)
	var replica: Unit = _main.world.find_replica_unit(7001)
	_expect(replica != null and replica.position == server_position and replica.net_target_pos == server_position and replica.net_id == 7001 and world.authoritative_units_snapshot().is_empty(), "副本使用主机ID/位置，不分配权威ID或修正落点")
	var calls: int = _main.resize_requests
	var payload: Array = preload("res://tests/fixtures/network_fixture.gd").snapshot_payload(_main._snapshot_system, 7001, replica)
	payload[NetworkSnapshotSystem.U_GROWTH] = Vector2(300.0, 1.3)
	_main._snapshot_system._apply_units([payload])
	_expect(replica.position == server_position and _main.resize_requests == calls, "客户端首次更大体型只应用快照，不调用World权威修正")
	world.ensure_unit_form_resize_safe(replica)
	_expect(replica.position == server_position, "直接World空间收尾也拒绝客户端重算")
	_main.create_network_unit("tombstone", 0, Vector2(360, 900), 7002, 0.0)
	var building: Unit = _main.world.find_replica_unit(7002)
	_expect(not building.nav_cells.is_empty() and not world.nav.is_walkable(building.position), "副本建筑登记表现导航占位，不进入权威索引")
	_main.remove_network_unit(7002, false)
	_main.remove_network_unit(7002, false)
	_expect(_main.world.find_replica_unit(7002) == null and building.nav_cells.is_empty() and world.nav.is_walkable(building.position), "可靠移除重复到达只清理一次副本与占位")
	_main.create_network_unit("tombstone", 0, Vector2(360, 900), 7003, 0.0)
	var missing: Unit = _main.world.find_replica_unit(7003)
	_main._snapshot_system.lifecycle.accept_snapshot(10, 1, {})
	_main._snapshot_system._apply_units([])
	_expect(world.replica_unit_ids().is_empty() and missing.nav_cells.is_empty() and world.nav.is_walkable(missing.position), "快照补删走同一World移除与空间收尾")
	var tower: Tower = world.towers_snapshot()[0]
	tower.apply_network_state(0, false, false, 0, 0)
	_expect(tower.nav_cells.is_empty() and world.towers_snapshot().size() == 6, "副本塔死亡释放World占位而不删除塔索引")
	_main.create_network_unit("tombstone", 0, Vector2(360, 900), 7004, 0.0)
	_main.clear_preview_battle()
	_expect(world.replica_unit_ids().is_empty() and world.authoritative_units_snapshot().is_empty() and world.nav.is_walkable(Vector2(360, 900)), "客户端工作台清场也收敛副本登记与空间")

func _check_conversion() -> void:
	var world = _main.world
	var target: Tower = world.towers_snapshot()[0]
	var target_id := target.get_instance_id()
	var source: Unit = _main._spawn_unit(UnitSpawnRequest.new(1, "azir", Vector2(360, 380), {"deploy_time_override": 0.0}))
	_main._combat.begin_batch(_main.runtime._sim_tick_id, "world_structure_conversion")
	target.take_damage(100000.0, source)
	_main._combat.commit_batch()
	var discs: Array = world.combatants().filter(func(actor): return actor is Unit and actor.card_id == "sun_disc")
	_expect(target.hp == 0.0 and target.nav_cells.is_empty() and world.footprint_releases.count(target_id) == 1 and discs.size() == 1 and discs[0].team == 1, "阿兹尔正式致死提交通过World释放旧塔占位，并在原阶段仅生成一个己方圆盘")
	var disc: Unit = discs[0]
	var overlap := _spawn("tombstone", disc.position)
	var cell: Vector2i = world.nav.world_to_cell(disc.position)
	var count_before: int = world.nav._block_counts.get(cell, 0)
	target.assist_conversion.consume(target)
	world.finish_tower_step()
	_main.battle_context.release_structure_footprint(target)
	_main.battle_context.release_structure_footprint(target)
	_expect(count_before == 2 and world.nav._block_counts.get(cell, 0) == count_before and world.footprint_releases.count(target_id) == 1 and world.combatants().filter(func(actor): return actor is Unit and actor.card_id == "sun_disc").size() == 1, "转化/塔Tick/重复释放不二次消费旧塔令牌，也不削减新圆盘与重叠建筑的占位")
	world.remove_unit(disc)
	_main.battle_context.release_structure_footprint(disc)
	_expect(world.nav._block_counts.get(cell, 0) == 1 and not world.nav.is_walkable(overlap.position), "圆盘移除及重复释放只减自身一次，重叠建筑仍阻挡")
	world.remove_unit(overlap)
	_expect(world.nav._block_counts.get(cell, 0) == 0 and world.nav.is_walkable(overlap.position), "最后一个重叠占位移除后恢复通路，没有残留或负计数")
	world.clear_units()
