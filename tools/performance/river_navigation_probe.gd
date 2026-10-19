extends SceneTree
## 同场景冷缓存逐Tick基准；不加载表现资源，不把耗时断言混入机制套件。
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rows: Array[Dictionary] = []
	for repeat in 3:
		for team in [0, 1]:
			for card in ["garen", "jax", "rift_herald"]:
				var main = load("res://tests/fixtures/authority_battle.gd").new()
				root.add_child(main)
				await process_frame
				var direction := 1.0 if team == 0 else -1.0
				var dummy := Unit.new()
				dummy.setup(1 - team, CardDB.training_dummy_stats(), "dummy")
				dummy.position = Vector2(360, ArenaRules.RIVER_Y - direction * 60.0)
				main.add_child(dummy)
				main.world.register_dynamic_building(dummy)
				var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(team, card, Vector2(360, ArenaRules.RIVER_Y + direction * 100.0), {"deploy_time_override": 0}))
				var movers: Array[Unit] = [unit]
				var times: Array[int] = []
				var legal := true
				var longest_stall := 0
				var stall := 0
				for tick in 700:
					var before := unit.position
					var started := Time.get_ticks_usec()
					unit.sim_tick(0.05)
					main._movement._apply_unit_movement(0.05, movers)
					times.append(Time.get_ticks_usec() - started)
					legal = legal and unit.is_walkable_at(unit.position)
					# 仅追击过程计停顿，准备/攻击本来就应站定。
					var chasing := not unit.structure_rush.locked() and unit._target_gap(dummy) > unit.attack_range
					stall = stall + 1 if chasing and unit.position.distance_to(before) < 0.01 else 0
					longest_stall = maxi(longest_stall, stall)
					if dummy.hp < dummy.max_hp: break
				var first_us := times[0]
				times.sort()
				var row := {"card":card,"team":team,"repeat":repeat,"ticks":times.size(),"first_us":first_us,"max_us":times[-1],"p95_us":times[int(times.size()*0.95)],"hit":dummy.hp<dummy.max_hp,"legal":legal,"longest_chase_stall_ticks":longest_stall,"rush_searches":unit.structure_rush.search_count}
				rows.append(row)
				print("RIVER_PROBE ", JSON.stringify(row))
				main.free()
	print("RIVER_RESULT ",JSON.stringify(rows))
	quit(0 if rows.all(func(row): return row.hit and row.legal and row.longest_chase_stall_ticks < 10) else 1)
