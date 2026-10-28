extends RefCounted
var h
var m: Node2D
var s: SpellSystem
func run(harness, main: Node2D) -> void:
	h = harness
	m = main
	s = m.get("_spell_system")
	var stats := CardDB.get_card("final_spark")
	var origin := Vector2(360, 1000)
	var ground := unit("garen", Vector2(360, 750))
	var air := unit("anivia", Vector2(360, 600))
	var outside := unit("garen", Vector2(440, 750))
	var behind := unit("garen", Vector2(360, 1080))
	var ally := unit("garen", Vector2(360, 750), 0)
	var building := unit("target_dummy", Vector2(360, 800))
	s.cast(0, stats, origin, true)
	var impact: int = s.spark_casts[0].impact_tick
	check(impact - m.get_authoritative_server_tick() == 20, "预警20Tick")
	tick(impact - 1)
	check(ground.hp == ground.max_hp and ground.blind_attack_charges == 0, "预警不结算")
	tick(impact)
	check(ground.hp == ground.max_hp - 300 and air.hp == air.max_hp - 300, "空地同时命中")
	check(s.spark_effects.size() == 1, "命中多个目标不生成受击特效")
	check(ground.blind_attack_charges == 1 and air.blind_attack_charges == 1, "强化只施加一次致盲")
	check(outside.hp == outside.max_hp and behind.hp == behind.max_hp and ally.hp == ally.max_hp, "范围外、背后、友军不命中")
	check(building.hp == building.max_hp - 300 and building.blind_attack_charges == 0, "建筑受伤但不致盲")
	tick(impact + 1)
	check(ground.hp == ground.max_hp - 300 and s.spark_casts.is_empty(), "仅结算一次")
	check(ground._consume_blind_for_strike({}) and ground.blind_attack_charges == 0, "下一次普攻消费一次致盲")
	check(not ground._consume_blind_for_strike({}), "再下一次攻击正常")
	ground.buffs.apply(&"effect_shield", &"test", 5.0, {})
	var hp: float = ground.hp
	s.cast(0, stats, origin, true)
	tick(s.spark_casts[0].impact_tick)
	check(ground.hp == hp and ground.blind_attack_charges == 0, "法术盾拒绝伤害和致盲")
	ground.apply_stasis(2.0)
	s.cast(0, stats, origin, true)
	tick(s.spark_casts[0].impact_tick)
	check(ground.hp == hp and ground.blind_attack_charges == 0, "凝滞拒绝伤害和致盲")
	var ai := AIOpponent.new()
	ai.enabled = false
	ai._main = m
	m.add_child(ai)
	var aim := ai._spell_position("final_spark", stats)
	check(aim.is_finite() and m.runtime.is_card_deploy_position_valid(1, "final_spark", aim), "AI使用合法己方半场起点")
	ai.free()
	for u in [ground, air, outside, behind, ally, building]: u.free()
	var normal := unit("garen", Vector2(360, 750), 0)
	s.cast(1, stats, Vector2(360, 400))
	tick(s.spark_casts[0].impact_tick)
	check(normal.hp == normal.max_hp - 300 and normal.blind_attack_charges == 0, "红方方向与普通槽无致盲")
	normal.free()
	# Keep both targets inside battlefield bounds, so spawn clamping cannot move the outside probe into the beam.
	var distant := unit("garen", Vector2(360, 350))
	var past_end := unit("garen", Vector2(360, 240))
	s.cast(0, stats, Vector2(360, 1100))
	tick(s.spark_casts[0].impact_tick)
	check(distant.hp == distant.max_hp - 300 and past_end.hp == past_end.max_hp, "750像素命中，860像素不命中")
	distant.free()
	past_end.free()
	for tower in main.world.towers_snapshot():
		var before: float = tower.hp
		var team := 1 - int(tower.team)
		var pos: Vector2 = tower.position - (Vector2.UP if team == 0 else Vector2.DOWN) * 100.0
		s.cast(team, stats, pos, true)
		tick(s.spark_casts[0].impact_tick)
		check(tower.hp == before - 90, "塔和水晶90伤害")
	check(SpellSystem.final_spark_intersects(origin, origin + Vector2.UP * 800, 40, origin + Vector2(30, -300), 10), "身体擦边命中")
	check(not SpellSystem.final_spark_intersects(origin, origin + Vector2.UP * 800, 40, origin + Vector2(31, -300), 10), "身体离开边界不命中")
	check(not SpellSystem.final_spark_intersects(origin, origin + Vector2.UP * 800, 40, origin + Vector2(29, -809), 10), "端点拐角使用圆矩形距离")
	check(main.runtime.is_card_deploy_position_valid(0, "final_spark", Vector2(360, 1000)), "己方部署合法")
	check(not main.runtime.is_card_deploy_position_valid(0, "final_spark", Vector2(360, 300)), "敌半场禁止部署")
	s.cast(0, stats, origin)
	s.clear()
	tick(main.get_authoritative_server_tick() + 30)
	check(s.spark_casts.is_empty(), "清场取消延迟结算")
	s.show_flight(999, "final_spark", origin, origin + Vector2.UP * 800, 20, 0, 20, 0)
	check(s.spark_casts.is_empty() and s.spark_effects.size() == 1, "客户端只创建表现")
	s.clear()
	for field in ["radius", "wave_width", "range", "damage", "spell_windup", "duration"]:
		var bad := stats.duplicate(true)
		bad[field] = NAN
		check(not CardDB.VALIDATOR.validate_all({"final_spark": bad}, false).is_empty(), "拒绝非法" + field)
func unit(card: String, pos: Vector2, team: int = 1) -> Unit:
	return m._spawn_unit(UnitSpawnRequest.new(team, card, pos, {"deploy_time_override": 0.0}))
func tick(value: int) -> void:
	m.runtime.set("_sim_tick_id", value)
	m.combat_service().begin_batch(value, "spark_test")
	s.tick(0.05)
	m.combat_service().commit_batch()
func check(ok: bool, message: String) -> void:
	h._expect(ok, "终极闪光：" + message)
