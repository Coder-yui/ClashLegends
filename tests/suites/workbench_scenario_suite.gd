extends RefCounted

func run(harness: Object, main: Node2D) -> void:
	var old_mode: bool = main._workbench.enabled
	var old_selection: String = main._workbench.selection
	var old_team: int = main._workbench.team
	main._workbench.enabled = false
	var before := main.get_tree().get_nodes_in_group("combatants").size()
	await main._load_workbench_preset("surrounded")
	harness._expect(main.get_tree().get_nodes_in_group("combatants").size() == before, "经典场景入口在正式比赛中不可用")
	main._workbench.enabled = true
	main._workbench.selection = "garen"
	main._workbench.team = 0
	await main._load_workbench_preset("surrounded")
	var center: Unit = main._art_dev_selected_unit()
	var count := _units(main).size()
	harness._expect(center != null and center.card_id == "garen" and count == 9, "敌人包围布置当前卡与八名敌军，保留当前技能控制对象")
	main._towers[0].take_damage(100000.0)
	await main._load_workbench_preset("surrounded")
	harness._expect(_units(main).size() == count and not is_instance_valid(center), "重建经典场景清掉上轮对象，不重复累积单位")
	harness._expect(main._towers[0].hp == main._towers[0].max_hp and not main._towers[0].nav_cells.is_empty(), "重建场景恢复被摧毁的塔和导航占地，保持实验起点一致")
	var blue: Vector2 = main._art_dev_selected_unit().position
	main._workbench.team = 1
	await main._load_workbench_preset("surrounded")
	var red: Unit = main._art_dev_selected_unit()
	harness._expect(red.team == 1 and is_equal_approx(red.position.y, ArenaRules.FIELD_H-blue.y), "红方场景镜像布置并保持当前卡与阵营选择")
	for team in [0, 1]:
		main._workbench.team = team
		await main._load_workbench_preset("bridge_crowd")
		harness._expect(_units(main).size() == 19, "拥挤过桥生成当前卡、十二名友军和六名对岸敌军")
		var walkable := true
		for tick in 600:
			main._sim_step(main.SIM_DT)
			for unit in _units(main):
				if unit.hp > 0.0 and not unit.is_walkable_at(unit.position):
					if walkable:
						print("[过桥非法位置] team=", team, " tick=", tick, " card=", unit.card_id, " pos=", unit.position)
					walkable = false
		harness._expect(walkable, "双方过桥场景推进 600 Tick，存活单位保持合法位置（阵营 %d）" % team)
	main._workbench.selection = "freeze"
	await main._load_workbench_preset("crossfire")
	harness._expect(main._spell_system.freeze_effects.size() > 0 and main._workbench.selection == "freeze", "经典场景支持当前法术并经正式出牌生成效果")
	await main._load_workbench_preset("duel")
	harness._expect(_units(main).size() == 1 and main._spell_system.freeze_effects.size() == 1, "重建法术场景清掉旧效果后重新施放")
	main._clear_art_dev_units()
	await main.get_tree().process_frame
	main._workbench.enabled = old_mode
	main._workbench.selection = old_selection
	main._workbench.team = old_team

func _units(main: Node2D) -> Array[Unit]:
	var result: Array[Unit] = []
	for node in main.get_tree().get_nodes_in_group("combatants"):
		if node is Unit and not node.is_queued_for_deletion():
			result.append(node)
	return result
