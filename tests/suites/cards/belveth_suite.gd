extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	for team in [0, 1]:
		_dash(team)
		_death(team)
	_controls()
	_schema()

func _make(id: String, team: int, point: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, id, point, {"deploy_time_override": 0.0}))

func _dash(team: int) -> void:
	var origin := Vector2(360, 900 if team == 0 else 380)
	var direction := Vector2.UP if team == 0 else Vector2.DOWN
	var source := _make("belveth", team, origin)
	var air := _make("anivia", 1-team, origin + direction * 65.0)
	var ground := _make("garen", 1-team, origin + direction * 65.0)
	var friend := _make("anivia", team, origin + direction * 65.0)
	var outside := _make("anivia", 1-team, origin + direction * 65.0 + Vector2(100,0))
	for target in [air, ground, friend, outside]: target.hp = 1000
	source.active_skill_cast_facing = direction
	var skill: Dictionary = CardDB.active_skills_for("belveth")[0]
	var dash := DashStrikeState.new(source, skill)
	for tick in 16:
		_main._combat.begin_batch(tick, "belveth_dash")
		dash.tick(0.05)
		_main._combat.commit_batch()
	_expect(air.hp == 900, "突进只命中敌方空军一次，收势不重复伤害")
	_expect(ground.hp == 1000 and friend.hp == 1000 and outside.hp == 1000, "路径外、友方及地面单位不受突进伤害")
	_expect(source.position.distance_to(origin + direction * 3.0 * ArenaRules.TILE_SIZE) < 0.01, "双方突进准确推进3格")
	_expect(dash.finished and not source.skill_dash_active and source.active_skill_cast_timer == 0, "突进正常结束释放动作锁")
	_expect(source.building_only and source.is_air and not source._target_is_attackable(air) and not source._target_is_attackable(ground), "本体飞行且普通攻击拒绝空中和地面单位")
	var tower: Tower = _main._towers[(1-team)*2]
	var tower_hp: float = tower.hp
	dash._hit(source, tower.position, tower.position, false)
	_expect(tower.hp == tower_hp, "空中突进不伤害路径上的建筑")
	for unit in [source, air, ground, friend, outside]: unit.free()

func _death(team: int) -> void:
	var source := _make("belveth", team, Vector2(360, 800))
	var center := source.position
	source.take_damage(100000)
	source.take_damage(100000)
	var fish: Array[Unit] = []
	for unit in _main.get_tree().get_nodes_in_group("combatants"):
		if unit is Unit and unit.card_id == "voidfish" and unit.team == team: fish.append(unit)
	_expect(fish.size() == 8, "死亡恰好生成8只虚空鱼，重复伤害不重复召唤")
	var positions: Dictionary = {}
	for unit in fish:
		positions[unit.position] = true
		_expect(unit.is_air and unit.can_attack_air and not unit.building_only and unit.max_hp == 110 and unit.damage == 26, "虚空鱼为独立对地对空弱小单位")
		_expect(unit.position.distance_to(center) > source.body_radius, "虚空鱼从本体周围分散出生")
	_expect(positions.size() == 8, "八个分散出生位置互异")
	for unit in fish: unit.free()
	if is_instance_valid(source) and not source.is_queued_for_deletion(): source.free()

func _controls() -> void:
	var source := _make("belveth", 0, Vector2(360, 700))
	var skill: Dictionary = CardDB.active_skills_for("belveth")[0]
	source.active_skill_cast_facing = Vector2.UP
	var dash := DashStrikeState.new(source, skill)
	for tick in 8: dash.tick(0.05)
	_expect(source.position.y < ArenaRules.RIVER_Y, "空军突进可以跨越河道")
	dash._finish(source)
	source.active_skill_cast_serial += 1
	source.active_skill_cast_facing = Vector2.UP
	dash = DashStrikeState.new(source, skill)
	source.freeze(1.0)
	var before := source.position
	_expect(not dash.tick(0.05) and source.position == before and not source.skill_dash_active, "冰冻取消突进，无延后补伤害")
	source.free()
	source = _make("belveth", 0, Vector2(360, 30))
	source.active_skill_cast_facing = Vector2.UP
	dash = DashStrikeState.new(source, skill)
	for tick in 16: dash.tick(0.05)
	_expect(source.position.y >= source.body_radius and dash.finished, "场地边界提前停止仍正常结束")
	source.free()

func _schema() -> void:
	for field in ["air_only", "dash_spin"]:
		var invalid := CardDB.all().duplicate(true)
		invalid.belveth.active_skills[0][field] = "true"
		_expect(not CardDB.VALIDATOR.validate_all(invalid, false).is_empty(), "突进选项拒绝字符串布尔值")
		invalid = CardDB.all().duplicate(true)
		invalid.garen.active_skills[0][field] = true
		_expect(not CardDB.VALIDATOR.validate_all(invalid, false).is_empty(), "突进选项拒绝没有读取方的技能")
	var invalid := CardDB.all().duplicate(true)
	invalid.belveth.active_skills[0].cast_duration = 0.1
	_expect(not CardDB.VALIDATOR.validate_all(invalid, false).is_empty(), "拒绝施法时间短于突进")
