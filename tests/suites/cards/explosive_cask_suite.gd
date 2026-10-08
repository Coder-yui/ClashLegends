extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var spells: SpellSystem = main.get("_spell_system")
	var center := Vector2(360, 900)
	var units: Array[Unit] = []
	for pair in [["garen", 1, Vector2(40, 0)], ["garen", 1, Vector2(-40, 0)], ["anivia", 1, Vector2(0, -50)], ["garen", 0, Vector2(0, 40)], ["garen", 1, Vector2(190, 0)], ["tombstone", 1, Vector2(0, 80)]]:
		units.append(main._spawn_unit(UnitSpawnRequest.new(pair[1], pair[0], center + pair[2], {"deploy_time_override": 0.0})))
	var hp: Array = units.map(func(u): return u.hp)
	spells.cast(0, CardDB.get_card("explosive_cask"), center)
	var impact := int(spells.spell_flights[0].impact_tick)
	main.set("_sim_tick_id", impact - 1)
	main.combat_service().begin_batch(main.get_authoritative_server_tick(), "cask_test")
	spells.tick(FixedStepClock.STEP)
	main.combat_service().commit_batch()
	_expect(units[0].hp == hp[0], "酒桶抵达前不造成伤害")
	# 抵达重新查询目标：离开范围的对象不命中。
	units[4].position = center + Vector2(0, -90)
	main.set("_sim_tick_id", impact)
	main.combat_service().begin_batch(main.get_authoritative_server_tick(), "cask_test")
	spells.tick(FixedStepClock.STEP)
	main.combat_service().commit_batch()
	for i in [0, 1, 2, 4, 5]: _expect(units[i].hp == hp[i] - 180, "酒桶抵达伤害地面空中建筑及新入圈目标")
	_expect(units[3].hp == hp[3], "酒桶不伤友方")
	_expect(units[0].knockback.velocity.x > 0 and units[1].knockback.velocity.x < 0 and units[2].knockback.velocity.y < 0, "酒桶击退方向从爆心向外")
	_expect(units[5].knockback.remaining == 0, "建筑受到伤害但不被击退")
	_expect(spells.cask_effects[0].impacted, "抵达事件切换爆炸表现")
	units[1].apply_stasis(3.0)
	var protected_hp := units[1].hp
	var old_hp := units[0].hp
	spells.cast(0, CardDB.get_card("explosive_cask"), center, true)
	main.set("_sim_tick_id", int(spells.spell_flights[0].impact_tick))
	main.combat_service().begin_batch(main.get_authoritative_server_tick(), "cask_test")
	spells.tick(FixedStepClock.STEP)
	main.combat_service().commit_batch()
	_expect(units[0].hp == old_hp - 270, "强化伤害270")
	_expect(units[1].hp == protected_hp, "凝滞拒绝酒桶伤害和新击退")
	for target in main.get_tree().get_nodes_in_group("combatants"):
		if not target is Tower or target.team != 1: continue
		var before: float = target.hp
		spells.cast(0, CardDB.get_card("explosive_cask"), target.position)
		main.set("_sim_tick_id", int(spells.spell_flights[0].impact_tick))
		main.combat_service().begin_batch(main.get_authoritative_server_tick(), "cask_test")
		spells.tick(FixedStepClock.STEP)
		main.combat_service().commit_batch()
		_expect(target.hp == before - 54, "酒桶对塔和水晶只造成30%伤害")
	units[0].add_shield(1000, 10.0)
	units[0].knockback.cancel(&"test")
	var shielded_hp := units[0].hp
	spells.cast(0, CardDB.get_card("explosive_cask"), center)
	main.set("_sim_tick_id", int(spells.spell_flights[0].impact_tick))
	main.combat_service().begin_batch(main.get_authoritative_server_tick(), "cask_shield")
	spells.tick(FixedStepClock.STEP)
	_expect(units[0].knockback.remaining == 0.0, "收集伤害阶段不提前击退")
	main.combat_service().commit_batch()
	_expect(units[0].hp == shielded_hp and units[0].knockback.remaining > 0, "全盾吸收仍在批次提交后击退")
	units[0].knockback.cancel(&"test")
	units[0].buffs.apply(&"effect_shield", &"cask_test", 1.5, {})
	var blocked_hp := units[0].hp
	spells.cast(0, CardDB.get_card("explosive_cask"), center)
	main.set("_sim_tick_id", int(spells.spell_flights[0].impact_tick))
	main.combat_service().begin_batch(main.get_authoritative_server_tick(), "cask_effect_shield")
	spells.tick(FixedStepClock.STEP)
	main.combat_service().commit_batch()
	_expect(units[0].hp == blocked_hp and units[0].knockback.remaining == 0.0, "法术盾同时抵挡爆桶伤害与击退")
	_expect(units[0].buffs.remaining(&"effect_shield") == 0.0, "爆桶只消费一次法术盾")
	var saved_deck: Array = main._deck.duplicate()
	main._deck = ["explosive_cask", "garen", "ashe", "teemo", "xin", "heal", "freeze", "zap"]
	_expect(main.card_cost_for_team(0, "explosive_cask") == 4, "主动槽酒桶3+1金币")
	main._deck = saved_deck
	spells.clear()
	spells.show_flight(99, "explosive_cask", Vector2.ZERO, center, 105, 0, 10)
	spells.tick_visuals(5.0)
	_expect(not spells.cask_effects[0].impacted and spells.spell_flights.is_empty(), "客户端表现不创建权威结果或提前爆炸")
	spells.show_arrival(99)
	spells.tick_visuals(2.2)
	_expect(spells.cask_effects.is_empty(), "爆炸结束清理表现")
	spells.cast(0, CardDB.get_card("explosive_cask"), center)
	spells.clear()
	_expect(spells.cask_effects.is_empty() and spells.spell_flights.is_empty(), "清场取消在途酒桶")
	for u in units:
		u.remove_from_group("combatants")
		u.queue_free()
	var stats := CardDB.get_card("explosive_cask").duplicate(true)
	stats.active_skills[0].damage = 100
	_expect(not CardDB.VALIDATOR.validate_all({"bad_cask": stats}, false).is_empty(), "拒绝低于基础伤害的强化配置")
	_check_effect_projection(main)

func _check_effect_projection(main: Node2D) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	main.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0
	camera.position = Vector3(0, 24, 24)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var effect := preload("res://scripts/presentation/explosive_cask_3d.gd").new()
	viewport.add_child(effect)
	var preview := SpellSystem.new(main)
	preview.show_flight(1, "explosive_cask", Vector2(360,1100), Vector2(360,650), 50.0, 0, 20)
	preview.show_flight(2, "explosive_cask", Vector2(360,1100), Vector2(360,650), 180.0, 0, 20)
	for entry in preview.cask_effects: entry.progress = 0.4
	effect.sync_effects(preview, camera)
	var flight = effect._views[1].player
	_expect(is_equal_approx(flight._factor, effect._views[2].player._factor), "爆桶弹体尺度不随AOE半径变化")
	var birth_error := 0.0
	for particle in flight._particles:
		birth_error = maxf(birth_error, particle.origin.distance_to(flight.position_at.call(particle.birth)))
	_expect(birth_error < 0.0001, "飞行粒子按各自出生时刻锚定，而非当前弹体位置")
	_expect(flight._trails.size() == 2 and flight._trails[0].points.size() > 2, "原版两层CameraTrail仍为连续世界空间带状网格")
	var held_time: float = flight._time
	var held_points: int = flight._trails[0].points.size()
	effect.sync_effects(preview, camera)
	_expect(flight._time == held_time and flight._trails[0].points.size() == held_points, "暂停不推进飞行或追加拖尾")
	preview.show_arrival(1)
	effect.sync_effects(preview, camera)
	_expect(is_instance_valid(effect._views[1].tail), "抵达保留独立粒子与拖尾的剩余寿命")
	var bound_left := false
	for particle in effect._views[1].tail._particles:
		bound_left = bound_left or float(flight.sample(particle.c.bind, 0.0)) >= 1.0
	_expect(not bound_left, "抵达时移除绑定弹体与光晕")
	var impact = effect._views[1].player
	impact.seek(0.2)
	for index in impact._data.emitters.size():
		if impact._data.emitters[index].name == "Ring_":
			var mat: ShaderMaterial = impact._pools[index][0].material_override
			_expect(not mat.get_shader_parameter("ground_layer"), "圆柱实际材质保留原版Y运动而不压平")
	_expect(impact.basis.x.length() == impact.basis.z.length(), "爆炸节点只作等比单位换算")
	_expect(impact.projection_basis.y.is_equal_approx(Vector3.UP), "爆炸高度保持世界竖直原尺度")
	for name in ["Sand_Burst", "Verticalline", "wood", "Splashes_IN"]:
		_expect(impact.shape_basis_for(name).is_equal_approx(Basis.IDENTITY), "散射粒子与射线本体不被范围拉伸")
	for name in ["shadow", "DistortFAST", "PierceBubble", "Pool"]:
		_expect(impact.shape_basis_for(name).is_equal_approx(impact.projection_basis), "贴地范围和中央穹顶按职责映射底座")
	preview.cask_effects[0].timer = preview.cask_effects[0].duration - 0.41
	effect.sync_effects(preview, camera)
	_expect(not is_instance_valid(effect._views[1].tail), "抵达后按原始最大0.4秒寿命清理飞行余迹")
	preview.clear()
	effect.sync_effects(preview, camera)
	_expect(effect._views.is_empty() and effect.get_child_count() == 0, "清场同时释放爆炸、在途酒桶和余迹")
	viewport.free()
