extends RefCounted

func run(harness: Object) -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	harness.root.add_child(main)
	main._deck = ["tombstone", "sun_disc", "apex_turret", "garen", "xin", "ashe", "freeze", "heal"]
	main._start_local()
	main.set_process(false)
	main._ai.enabled = false
	main._elixir.elixir = 10
	var pos := Vector2(300, 820)
	var accepted: bool = main.play_card(0, "tombstone", pos, {"elixir": main._elixir})
	main._sim_tick_id = 5
	accepted = main.play_card(0, "sun_disc", pos, {"elixir": main._elixir}) and accepted
	var hand: Array = main.get_authoritative_hand(0)
	harness._expect(accepted and main._commands.inspect_cards().size() == 2 and main._elixir.elixir == 3, "0秒 A、0.25秒 B 重叠请求均接受扣费，等待生成不预留占地")
	harness._expect(main.is_card_deploy_position_valid(0, "apex_turret", pos) and main.is_ground_position_walkable(pos, 10), "建筑生成前不阻挡下牌或行军")
	main._sim_tick_id = 10
	main._tick_pending_card_deployments(0.05)
	var buildings: Array = harness.get_nodes_in_group("combatants").filter(func(c): return c is Unit and c.is_building)
	harness._expect(buildings.size() == 1 and buildings[0].global_position == pos and main._commands.inspect_cards().size() == 1, "0.5秒 A 原地生成，B 继续等待")
	harness._expect(not main.is_card_deploy_position_valid(0, "sun_disc", pos), "A 落地后占地才开始生效")
	var expected: Vector2 = main._nearest_valid_building_spawn(0, "sun_disc", pos)
	harness._expect(expected.distance_to(pos) == 120 and main.is_card_deploy_position_valid(0, "sun_disc", expected), "最近合法位置允许共边，3x3 建筑挤开三格")
	main._sim_tick_id = 15
	main._tick_pending_card_deployments(0.05)
	buildings = harness.get_nodes_in_group("combatants").filter(func(c): return c is Unit and c.is_building)
	harness._expect(buildings.size() == 2 and buildings[1].global_position == expected and not main._structure_deployment_rect(buildings[0]).intersects(main._structure_deployment_rect(buildings[1]), false), "0.75秒 B 在最近合法位置生成，不与 A 重叠")
	harness._expect(main._elixir.elixir == 3 and main.get_authoritative_hand(0) == hand, "挪位不退款、不退牌、不重复轮换")
	main._tick_pending_card_deployments(0.05)
	harness._expect(main._commands.inspect_cards().is_empty() and harness.get_nodes_in_group("combatants").filter(func(c): return c is Unit and c.is_building).size() == 2, "到期命令仅兑现一次")
	# 预部署阶段同样在真正生成时重查。
	main._commands.enqueue_deployment(0, "apex_turret", pos, 0.1, -1, -1, -1.0)
	main._tick_pending_card_pre_deployments(0.1)
	buildings = harness.get_nodes_in_group("combatants").filter(func(c): return c is Unit and c.is_building)
	harness._expect(buildings.size() == 3 and buildings[2].global_position != pos, "预部署结束也执行落地挪位")
	# 全场被占满时保留命令，空间恢复后兑现，不丢卡。
	for unit in buildings: unit.free()
	var blocker: Unit = main._spawn_unit(0, "tombstone", Vector2(360, 640))
	blocker.footprint_tiles = Vector2i(100, 100)
	var waiting: Array = main._spawn_card_units(0, "sun_disc", pos)
	harness._expect(waiting.is_empty() and main._commands.inspect_deployments().size() == 1, "全场无合法落点时保留命令等待")
	blocker.free()
	main._tick_pending_card_pre_deployments(0.05)
	harness._expect(main._commands.inspect_deployments().is_empty() and harness.get_nodes_in_group("combatants").filter(func(c): return c is Unit and c.is_building).size() == 1, "空间恢复后自动生成一次")
	for unit in harness.get_nodes_in_group("combatants"):
		if unit is Unit: unit.free()
	var tower: Tower = main._towers[0]
	# 统一入口还保留另一测试场景；暂时排除其同坐标活塔，结束后恢复。
	var tower_health: Dictionary = {}
	for structure in harness.get_nodes_in_group("combatants"):
		if structure is Tower and structure.position.is_equal_approx(tower.position):
			tower_health[structure] = structure.hp
			structure.hp = 0
	var first: Array = main._spawn_card_units(0, "sun_disc", tower.position)
	var second: Array = main._spawn_card_units(0, "sun_disc", tower.position)
	harness._expect(first.size() == 1 and first[0].built_on_tower_ruin and second.size() == 1
		and not second[0].built_on_tower_ruin and second[0].position != tower.position,
		"太阳圆盘按最终落点计算塔墟效果，被挤出塔墟后不保留重建加成")
	for structure in tower_health:
		structure.hp = tower_health[structure]
	main.free()
