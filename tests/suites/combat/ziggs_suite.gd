extends "res://tests/suites/battle_suite.gd"
class ImpactBattle extends "res://tests/fixtures/authority_battle.gd":
	var landed_visuals: Array[StringName] = []
	func show_projectile_impact(_position: Vector2, _radius: float, _color: Color, visual: StringName) -> void:
		landed_visuals.append(visual)
func run(harness: Object) -> void:
	_harness = harness
	_main = ImpactBattle.new()
	harness.root.add_child(_main)
	for team in 2:
		_check_fixed_landing(team, false)
		_check_fixed_landing(team, true)
	_check_radius(false)
	_check_radius(true)
	_check_effect_lifecycle()
	_check_charges()
	_check_execution()
	_check_network()
	_main.free()
func _check_fixed_landing(team: int, enhanced: bool) -> void:
	var source := _spawn_ready_unit("ziggs", team, Vector2(250, 800))
	var target := _spawn_ready_unit("target_dummy", 1-team, Vector2(400, 800))
	var witness := _spawn_ready_unit("target_dummy", 1-team, Vector2(400, 800))
	var air := _spawn_ready_unit("aurelionsol", 1-team, Vector2(400, 800))
	var ally := _spawn_ready_unit("target_dummy", team, Vector2(400, 800))
	var effects := {"ground_only": true}
	if enhanced: effects.merge({"bounce_count": 3, "bounce_distance": 60.0})
	var system: ProjectileSystem = _main._projectile_system
	system.launch(source, target, 70, 360, source.splash_radius, 0, Color.WHITE, effects)
	var bomb: Dictionary = system.projectiles.values()[-1]
	_expect(bomb.landing == target.global_position and bomb.target == null, "固定初始落点，无目标追踪引用")
	target.global_position += Vector2(0, 200)
	source.free()
	var hp := witness.hp
	for tick in 9: system.tick(0.05)
	_expect(target.hp == target.max_hp, "移动目标可躲过普攻和强化炸弹")
	_expect(witness.hp == hp-70, "原落点命中且施法者死亡不取消炸弹")
	_expect(air.hp == air.max_hp and ally.hp == ally.max_hp, "范围攻击不伤空军和友军")
	if enhanced:
		witness.global_position = Vector2(460, 800)
		for tick in 4: system.tick(0.05)
		_expect(witness.hp == hp-140, "第二落点继续沿固定方向且可再次命中")
		witness.global_position = Vector2(520, 800)
		for tick in 4: system.tick(0.05)
		_expect(witness.hp == hp-210, "第三落点独立结算")
	_expect(system.projectiles.is_empty(), "规定落地次数后销毁弹体")
	for unit in [target, witness, air, ally]: unit.free()
func _check_charges() -> void:
	var source := _spawn_ready_unit("ziggs", 0, Vector2(250, 800))
	var target := _spawn_ready_unit("target_dummy", 1, Vector2(400, 800))
	source.move_speed = 0.0
	target.move_speed = 0.0
	_main._active_skill_effect_system.apply(source, CardDB.active_skills_for("ziggs")[0])
	_expect(source.empowered_attacks_left == 3 and source.empowered_attack_ready, "技能设置三次强化")
	for n in 3:
		source._target = target
		var before := source.basic_attack_sequence
		for tick in 60:
			source.sim_tick(0.05)
			if source.basic_attack_sequence > before: break
		_expect(source.empowered_attacks_left == 2-n, "每次实际投掷消耗一次强化")
		var bomb: Dictionary = _main._projectile_system.projectiles.values()[-1]
		_expect(is_equal_approx(float(bomb.splash), 40.0), "强化炸弹使用40像素爆炸半径")
		_expect(source.is_empowered_attack_ready_visual() == (n < 2), "待发特效状态跟随剩余强化次数")
		_expect(bomb.hops_left == 3, "三次强化均发射三落点炸弹")
	_expect(not source.empowered_attack_ready, "第三次之后恢复普攻")
	_main._projectile_system.clear_all()
	source.free()
	target.free()
func _check_execution() -> void:
	var source := _spawn_ready_unit("ziggs", 0, Vector2(250, 800))
	for tower in _main.world.towers_snapshot():
		if tower.team == 0: continue
		tower.hp = tower.max_hp * 0.1 + 70
		var effects := {"tower_execute_ratio": 0.1, "structure_execute_ratio": 0.15}
		_main._combat.resolve_attack_hit(0, source.position, tower, 70, 0, 0, source, source.position, -1, effects)
		_expect(tower.hp > 0, "塔/水晶恰好10%不斩杀")
		_main._combat.resolve_attack_hit(0, source.position, tower, 1, 0, 0, source, source.position, -1, effects)
		_expect(tower.hp <= 0, "塔/水晶严格低于10%斩杀")
	var building := _spawn_ready_unit("inhibitor", 1, Vector2(400, 800))
	building.hp = building.max_hp * 0.15 + 70
	_main._combat.resolve_attack_hit(0, source.position, building, 70, 0, 0, source, source.position, -1, {"structure_execute_ratio":0.15})
	_expect(building.hp > 0, "建筑恰好15%不斩杀")
	_main._combat.resolve_attack_hit(0, source.position, building, 1, 0, 0, source, source.position, -1, {"structure_execute_ratio":0.15})
	_expect(building.hp <= 0, "建筑低于15%斩杀")
	source.free()
	if is_instance_valid(building): building.free()
func _check_network() -> void:
	var source := _spawn_ready_unit("ziggs", 0, Vector2(250, 800))
	var target := _spawn_ready_unit("target_dummy", 1, Vector2(400, 800))
	var system: ProjectileSystem = _main._projectile_system
	system.launch(source, target, 70, 360, source.splash_radius, 0, Color.WHITE, {"ground_only":true,"bounce_count":3,"bounce_distance":60.0})
	system.tick(0.05)
	var id: int = system.projectiles.keys()[0]
	var payload: Array = _main._snapshot_system._projectile_snapshot_payload(id, system.projectiles[id])
	_expect(not payload.is_empty(), "弹跳快照保留现有协议布局")
	var view: Dictionary = system.visible_view()[id]
	_expect(not view.has("attacker") and not view.has("effects") and not view.has("hops_left"), "客户端只接收弹体表现不携带权威状态")
	_expect(float(view.visual_height) > 0 and view.visual == &"ziggs_bounce", "弹跳弧高与外观进入可见快照")
	system.clear_all()
	source.free()
	target.free()

func _check_radius(enhanced: bool) -> void:
	var source := _spawn_ready_unit("ziggs", 0, Vector2(250, 800))
	var target := _spawn_ready_unit("target_dummy", 1, Vector2(400, 800))
	var edge := _spawn_ready_unit("target_dummy", 1, Vector2(400, 800))
	var outside := _spawn_ready_unit("target_dummy", 1, Vector2(400, 800))
	var radius := 40.0 if enhanced else 30.0
	edge.position.y += radius + edge.body_radius - 1.0
	outside.position.y += radius + outside.body_radius + 1.0
	_main.landed_visuals.clear()
	var audio: Array[String] = []
	var on_audio := func(_source, _kind, _position, phase): audio.append(phase)
	_main._projectile_system.wave_audio.connect(on_audio)
	var effects := {"ground_only":true}
	if enhanced: effects.merge({"bounce_count":3,"bounce_distance":60.0,"splash_radius":40.0})
	_main._projectile_system.launch(source, target, 70, 360, source.splash_radius, 0, Color.WHITE, effects)
	for tick in 20: _main._projectile_system.tick(0.05)
	_expect(edge.hp == edge.max_hp - 70 and outside.hp == outside.max_hp, "普通30/强化40像素圆按身体边缘命中，边界外不受伤")
	_expect(_main.landed_visuals.size() == (3 if enhanced else 1) and _main.landed_visuals.all(func(v): return v == &"ziggs_explosion"), "三次落地仅各有一次爆炸，无弹跳接地层")
	_expect(audio.count("impact" if enhanced else "basic_impact") == (3 if enhanced else 1), "每次地面爆炸仅发一次声音，不随命中目标数重复")
	_expect(not audio.has("bounce"), "爆炸阶段不叠加接地声")
	_main._projectile_system.wave_audio.disconnect(on_audio)
	for unit in [source, target, edge, outside]: unit.free()

func _check_effect_lifecycle() -> void:
	var player = preload("res://assets/effects/ziggs/player.gd").new()
	_harness.root.add_child(player)
	player.load_kind("basic")
	player.setup_native(0.014)
	player.seek_motion(0.2, Vector3.ZERO, Basis.IDENTITY)
	player.stop_emission()
	player.seek_motion(0.25, Vector3(1, 0, 0), Basis.IDENTITY)
	_expect(player._pools[0].all(func(p): return not p.visible), "弹体退场立即隐藏炸弹实体，保留已出生拖尾")
	_expect(player._pools.slice(1).any(func(pool): return pool.any(func(p): return p.visible)), "弹体退场不截断已有烟尘")
	player.seek_motion(player.sample_duration(), Vector3(1, 0, 0), Basis.IDENTITY)
	_expect(player._pools.all(func(pool): return pool.all(func(p): return not p.visible)), "尾段寿命结束后全部隐藏")
	player.free()
	var hit = preload("res://assets/effects/ziggs/player.gd").new()
	_harness.root.add_child(hit)
	hit.load_kind("hit")
	hit.setup_native(0.005)
	hit.seek(2.1)
	_expect(hit._pools.any(func(pool): return pool.any(func(p): return p.visible)), "爆炸2秒后的原版尾段仍可播放")
	hit.free()
