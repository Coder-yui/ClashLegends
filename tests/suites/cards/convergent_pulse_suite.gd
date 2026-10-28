extends RefCounted
var _harness
var _main: Node2D
var _spells: SpellSystem

func run(harness, main: Node2D) -> void:
	_harness = harness
	_main = main
	_spells = main.get("_spell_system")
	var stats := CardDB.get_card("convergent_pulse")
	var center := Vector2(360, 800)
	var ground := _unit("garen", center + Vector2(70, 0))
	var air := _unit("anivia", center + Vector2(-70, 0))
	var outer := _unit("garen", center + Vector2(150, 0))
	var middle := _unit("garen", center)
	var building := _unit("target_dummy", center + Vector2(0, 70))
	var ally := _unit("garen", center, 0)
	_spells.cast(0, stats, center)
	var impact: int = _spells.pulse_casts[0].impact_tick
	_expect(impact - main.get_authoritative_server_tick() == 13, "蓄能13Tick")
	_tick(impact - 1)
	_expect(ground.hp == ground.max_hp and ground.knockback.remaining == 0, "结算前无伤害位移")
	_tick(impact)
	_expect(ground.hp == ground.max_hp - 180 and air.hp == air.max_hp - 180, "空地敌军各命中一次")
	_expect(outer.hp == outer.max_hp and ally.hp == ally.max_hp, "范围外与友军不命中")
	_expect(middle.hp == middle.max_hp - 180 and middle.knockback.remaining == 0, "中心受伤不产生反向位移")
	_expect(building.hp == building.max_hp - 180 and building.knockback.remaining == 0, "建筑受伤不拉动")
	_expect(ground.knockback.velocity.x < 0 and air.knockback.velocity.x > 0, "两侧目标均朝中心")
	_expect(ground.knockback.collisionless and air.knockback.collisionless, "空地目标进入无碰撞强制位移")
	_expect(is_equal_approx(ground.knockback.original_distance, 80.0) and is_equal_approx(air.knockback.original_distance, 80.0), "不同质量均固定拉拢80像素")
	_expect(ground.knockback.endpoint.x < center.x and air.knockback.endpoint.x > center.x, "两侧目标终点越过中心")
	_expect(is_equal_approx(ground.knockback.original_duration, 0.4), "普通基础位移时间0.4秒")
	_tick(impact + 1)
	_expect(ground.hp == ground.max_hp - 180, "重复Tick不重伤")
	_spells.cast(0, stats, center, true)
	_expect(float(_spells.pulse_casts[0].radius) == 130, "强化扩大权威半径")
	_tick(_spells.pulse_casts[0].impact_tick)
	_expect(outer.hp == outer.max_hp - 270, "强化命中普通圈外目标并提高伤害")
	_expect(is_equal_approx(ground.knockback.original_distance, 100.0) and is_equal_approx(ground.knockback.original_duration, 0.5), "强化实际使用100像素与0.5秒")
	ground.knockback.cancel(&"test")
	ground.buffs.apply(&"effect_shield", &"test", 5.0, {})
	var hp := ground.hp
	_spells.cast(0, stats, center)
	_tick(_spells.pulse_casts[0].impact_tick)
	_expect(ground.hp == hp and ground.knockback.remaining == 0, "同次法术盾同时阻止伤害与拉拢")
	ground.apply_stasis(2.0)
	_spells.cast(0, stats, center)
	_tick(_spells.pulse_casts[0].impact_tick)
	_expect(ground.hp == hp and ground.knockback.remaining == 0, "凝滞拒绝命中")
	for unit in [ground, air, outer, middle, building, ally]: unit.free()
	# 同层目标真实移动时互穿，抵达后恢复碰撞并获得合法落点。
	var left := _unit("garen", center + Vector2(-50, 0))
	var right := _unit("garen", center + Vector2(50, 0))
	_spells.cast(0, stats, center)
	_tick(_spells.pulse_casts[0].impact_tick)
	for frame in 8:
		left.sim_tick(0.05)
		right.sim_tick(0.05)
		_main._movement.tick(0.05)
	_expect(left.position.x > center.x and right.position.x < center.x, "同层两单位穿过彼此和中心")
	_expect(not left.knockback.in_transit and not right.knockback.in_transit, "抵达后结束无碰撞运动")
	_expect(UnitLandingQuery.displacement_legal(left, left.position) and UnitLandingQuery.displacement_legal(right, right.position), "结束落在合法位置")
	left.free()
	right.free()
	for tower in main.world.towers_snapshot():
		var before: float = tower.hp
		_spells.cast(1 - tower.team, stats, tower.position)
		_tick(_spells.pulse_casts[0].impact_tick)
		_expect(tower.hp == before - 54, "防御塔与水晶30%伤害")
	_spells.cast(0, stats, center)
	_spells.clear()
	_tick(main.get_authoritative_server_tick() + 30)
	_expect(_spells.pulse_casts.is_empty(), "清场取消待结算法术")
	_spells.show_flight(999, "convergent_pulse", center, center, 130, 0, 13, 1)
	_expect(_spells.pulse_casts.is_empty() and _spells.pulse_effects.size() == 1, "客户端表现事件不创建权威结算")
	_spells.clear()
	for field in ["radius", "damage", "spell_windup", "duration", "pull_distance"]:
		var bad := stats.duplicate(true)
		bad[field] = NAN
		_expect(not CardDB.VALIDATOR.validate_all({"convergent_pulse": bad}, false).is_empty(), "拒绝非法" + field)

func _unit(card: String, pos: Vector2, team: int = 1) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, card, pos, {"deploy_time_override": 0.0}))
func _tick(tick: int) -> void:
	_main.runtime.set("_sim_tick_id", tick)
	_main.combat_service().begin_batch(tick, "pulse_test")
	_spells.tick(0.05)
	_main.combat_service().commit_batch()
func _expect(ok: bool, message: String) -> void:
	_harness._expect(ok, "聚合脉冲：" + message)
