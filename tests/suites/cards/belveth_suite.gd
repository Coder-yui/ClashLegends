extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	for team in [0, 1]:
		_dash(team)
		_death(team)
	_scatter_boundary()
	_controls()
	_schema()
	_dash_target_modes()
	_ultimate_visual()

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
	_expect(air.hp == 900, "突进命中敌方空军一次，不重复伤害")
	_expect(ground.hp == 900 and friend.hp == 1000 and outside.hp == 1000, "突进命中地面敌人一次，路径外及友方不受伤害")
	_expect(source.position.distance_to(origin + direction * 3.0 * ArenaRules.TILE_SIZE) < 0.01, "双方突进准确推进3格")
	_expect(dash.finished and not source.skill_dash_active and source.active_skill_cast_timer == 0, "突进正常结束释放动作锁")
	_expect(source.building_only and source.is_air and not source._target_is_attackable(air) and not source._target_is_attackable(ground), "本体飞行且普通攻击拒绝空中和地面单位")
	var tower: Tower = _main._towers[(1-team)*2]
	var tower_hp: float = tower.hp
	dash._hit(source, tower.position, tower.position, false)
	_expect(tower.hp == tower_hp - 100, "突进可伤害路径上的敌方建筑")
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
	for unit in fish:
		_expect(unit.is_air and unit.can_attack_air and not unit.building_only and unit.max_hp == 110 and unit.damage == 26, "虚空鱼为独立对地对空弱小单位")
		_expect(unit.position.distance_to(center) < 0.01, "八只虚空鱼从死亡点出生")
	for index in fish.size():
		_expect(fish[index].get_visual_facing_direction().is_equal_approx(Unit.SPAWN_DIRECTIONS[index]), "散开时面朝外侧")
	for tick in 9:
		for unit in fish: unit.sim_tick(0.05)
		_main._movement.tick(0.05)
		if tick == 0:
			for unit in fish:
				_expect(unit.position.distance_to(center) > 1.0 and unit.position.distance_to(center) < 30.0, "散开经过中间位置，不瞬移到终点")
	var positions: Dictionary = {}
	for index in fish.size():
		var unit := fish[index]
		positions[unit.position] = true
		_expect(unit.position.distance_to(center) > 95.0 and unit.position.distance_to(center) < 115.0, "散开半径约100像素")
		_expect(unit.position.direction_to(center).dot(-Unit.SPAWN_DIRECTIONS[index]) > 0.98, "八方向散开轨迹正确")
		_expect(unit._deploy_timer == 0.0 and unit._knockback_timer < 0.000001, "散开按时结束，不留额外部署锁定")
	_expect(positions.size() == 8, "八个散开位置互异")
	for unit in fish: unit.free()
	if is_instance_valid(source) and not source.is_queued_for_deletion(): source.free()

func _scatter_boundary() -> void:
	var source := _make("belveth", 0, Vector2(26, 26))
	source.take_damage(100000)
	var fish: Array[Unit] = []
	for unit in _main.get_tree().get_nodes_in_group("combatants"):
		if unit is Unit and unit.card_id == "voidfish": fish.append(unit)
	for tick in 10:
		for unit in fish: unit.sim_tick(0.05)
		_main._movement.tick(0.05)
	for unit in fish:
		_expect(unit.position.x >= unit.body_radius - 0.01 and unit.position.y >= unit.body_radius - 0.01, "死亡散开在场边停止，不越界")
		_expect(unit._knockback_timer == 0.0, "场边撞停后散开计时正常结束")
		unit.free()
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

	for field in ["death_spawn_spread", "death_spawn_duration"]:
		for value in [0.0, -1.0, "invalid"]:
			invalid = CardDB.all().duplicate(true)
			invalid.belveth[field] = value
			_expect(not CardDB.VALIDATOR.validate_all(invalid, false).is_empty(), "死亡散开参数拒绝无效值")
	invalid = CardDB.all().duplicate(true)
	invalid.belveth.death_spawn_count = 0
	_expect(not CardDB.VALIDATOR.validate_all(invalid, false).is_empty(), "死亡散开需要正数召唤数量")
	invalid = CardDB.all().duplicate(true)
	invalid.belveth.erase("death_spawn_duration")
	_expect(not CardDB.VALIDATOR.validate_all(invalid, false).is_empty(), "死亡散开距离与时间必须成对配置")
	invalid = CardDB.all().duplicate(true)
	invalid.belveth.death_spawn_id = "tombstone"
	_expect(not CardDB.VALIDATOR.validate_all(invalid, false).is_empty(), "死亡散开不能召唤建筑")

func _ultimate_visual() -> void:
	var source: Node3D = load("res://assets/units/belveth/source/belveth.glb").instantiate()
	var view: Node3D = load("res://assets/units/belveth/belveth_view.tscn").instantiate()
	view.prepare_visual_animations()
	var source_mesh: MeshInstance3D = source.find_children("*", "MeshInstance3D", true, false)[0]
	var visible_mesh: MeshInstance3D = view.find_children("*", "MeshInstance3D", true, false)[0]
	_expect(source_mesh.mesh.get_surface_count() == 2 and visible_mesh.mesh.get_surface_count() == 1, "大招隐藏人形头部，原始共享网格保留")
	var material: StandardMaterial3D = visible_mesh.mesh.surface_get_material(0)
	_expect(material.albedo_texture.resource_path.ends_with("ultimate_body.png"), "大招身体使用原生大招贴图")
	var player: AnimationPlayer = view.find_child("AnimationPlayer", true, false)
	var stats: Dictionary = CardDB.get_unit_stats("belveth")
	for index in [1, 2]:
		var name := "AttackSwipe%d_anm" % index
		var attack: Animation = player.get_animation(name)
		_expect(stats.visual_animations.attack_hit[index-1] == name and stats.visual_animations.attack[index-1] == "AttackSwipe%d_in_anm" % index, "映射原生大招起手与挥击完整片段")
		_expect(is_equal_approx(attack.length, 3.0), "原生普攻保持完整3秒时长")
		_expect(is_equal_approx(0.3 / (attack.length + 0.3) * stats.interval, stats.first_hit), "原生9帧节点整体等比映射到权威前摇")
	_expect(not player.has_animation("AttackUlt1") and not player.has_animation("AttackUlt2"), "不再创建拆分重排的普攻动画")
	view.free()
	source.free()

func _dash_target_modes() -> void:
	# 同一通用DashStrikeState以配置选择目标层，不依赖英雄身份或普攻目标。
	for mode in [{}, {"ground_only": true}, {"air_only": true}, {"ground_only": false}]:
		var source := _make("belveth", 0, Vector2(360, 900))
		var air := _make("anivia", 1, Vector2(360, 840))
		var ground := _make("garen", 1, Vector2(360, 840))
		var building := _make("tombstone", 1, Vector2(360, 840))
		var friend := _make("garen", 0, Vector2(360, 840))
		for target in [air, ground, building, friend]: target.hp = 1000
		var skill: Dictionary = CardDB.active_skills_for("belveth")[0].duplicate(true)
		skill.erase("ground_only")
		skill.erase("air_only")
		skill.merge(mode, true)
		var dash := DashStrikeState.new(source, skill)
		var tower: Tower = _main._towers[2]
		var tower_hp := tower.hp
		for repeat in 2:
			dash._hit(source, source.position, Vector2(360, 780), false)
			dash._hit(source, tower.position, tower.position, false)
		var air_only := bool(mode.get("air_only", false))
		var hit_air := air_only or not bool(mode.get("ground_only", true))
		_expect(air.hp == (900 if hit_air else 1000), "通用突进模式%s：空中筛选与单次命中" % str(mode))
		_expect(ground.hp == (1000 if air_only else 900), "通用突进模式%s：地面筛选与单次命中" % str(mode))
		_expect(building.hp == (1000 if air_only else 900) and tower.hp == tower_hp - (0 if air_only else 100), "通用突进模式%s：建筑卡与防御塔按地面目标处理" % str(mode))
		_expect(friend.hp == 1000, "通用突进不伤友方")
		for unit in [source, air, ground, building, friend]: unit.free()
	var invalid := CardDB.all().duplicate(true)
	invalid.belveth.active_skills[0].air_only = true
	invalid.belveth.active_skills[0].ground_only = true
	_expect(not CardDB.VALIDATOR.validate_all(invalid, false).is_empty(), "拒绝同时仅对地与仅对空的矛盾配置")
