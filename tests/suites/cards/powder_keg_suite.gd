extends "res://tests/suites/battle_suite.gd"

func _clear() -> void:
	for unit in _main.get_tree().get_nodes_in_group("combatants"):
		if unit is Unit and is_instance_valid(unit):
			unit.remove_from_group("combatants")
			unit.queue_free()

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var stats := CardDB.get_card("powder_keg")
	_expect(stats.cost == 4 and stats.lifespan == 20.0 and stats.footprint_tiles == Vector2i(2, 2), "4费、20秒、2×2建筑")
	_expect(not stats.can_attack and stats.damage == 0, "火药桶不主动攻击")
	for field in ["death_burst_radius", "death_burst_damage", "death_burst_reward"]:
		for bad in [-1, 0, INF, "wrong"]:
			var invalid := stats.duplicate(true)
			invalid[field] = bad
			_expect(not CardDB.VALIDATOR.validate_all({"powder_keg": invalid}, false).is_empty(), "拒绝非法爆炸字段 " + field)
	for bad in [-1.0, 0.0, 1.0, INF, "wrong"]:
		var invalid := stats.duplicate(true)
		invalid.active_skills[0].execute_health_ratio = bad
		_expect(not CardDB.VALIDATOR.validate_all({"powder_keg": invalid}, false).is_empty(), "拒绝非法斩杀阈值")
	var center := Vector2(360, 950)
	var keg := _spawn_ready_unit("powder_keg", 0, center)
	var target := _spawn_ready_unit("garen", 1, center + Vector2(60, 0))
	var ally := _spawn_ready_unit("garen", 0, center + Vector2(0, 60))
	var air := _spawn_ready_unit("anivia", 1, center + Vector2(0, -60))
	var outside := _spawn_ready_unit("garen", 1, center + Vector2(220, 0))
	var boundary := _spawn_ready_unit("garen",1,center)
	boundary.position=center+Vector2(0,140.0+boundary.body_radius-0.5)
	var beyond := _spawn_ready_unit("garen",1,center)
	beyond.position=center-Vector2(0,140.0+beyond.body_radius+0.5)
	var boundary_hp:=boundary.hp
	var beyond_hp:=beyond.hp
	var hp := target.hp
	var ally_hp := ally.hp
	var air_hp := air.hp
	var outside_hp := outside.hp
	keg.take_damage(10000)
	_expect(target.hp == hp - 300, "普通死亡立即爆炸造成300伤害")
	_expect(boundary.hp == boundary_hp-300 and beyond.hp == beyond_hp,"140像素爆炸按目标身体边缘判定，边界内命中、边界外不命中")
	_expect(ally.hp == ally_hp and air.hp == air_hp and outside.hp == outside_hp, "不伤友军、空军或范围外目标")
	keg._die(true)
	_expect(target.hp == hp - 300, "重复死亡不重复引爆")
	_clear()
	# 阈值按伤害后判断，严格小于15%；普通死亡没有斩杀。
	for active in [false, true]:
		keg = _spawn_ready_unit("powder_keg", 0, center)
		target = _spawn_ready_unit("garen", 1, center + Vector2(60, 0))
		target.max_hp = 1000
		target.hp = 449
		if active: main._active_skill_effect_system.apply(keg, stats.active_skills[0])
		else: keg.take_damage(10000)
		_expect(target.hp == (0.0 if active else 149.0), "只有主动爆炸斩杀伤后低于15%的单位")
		_clear()
	keg = _spawn_ready_unit("powder_keg", 0, center)
	target = _spawn_ready_unit("garen", 1, center + Vector2(60, 0))
	target.max_hp = 1000
	target.hp = 450
	main._active_skill_effect_system.apply(keg, stats.active_skills[0])
	_expect(target.hp == 150.0, "恰好15%不斩杀")
	_clear()
	# 自然寿命与受击共用死亡路径。
	keg = _spawn_ready_unit("powder_keg", 0, center)
	target = _spawn_ready_unit("garen", 1, center + Vector2(60, 0))
	hp = target.hp
	keg._tick_building_lifetime(19.95)
	_expect(keg.hp > 0.0 and target.hp == hp, "寿命到期前不爆炸")
	keg._tick_building_lifetime(0.05)
	_expect(target.hp == hp - 300, "自然衰减归零引爆")
	_clear()
	# 正式批次死亡触发新的范围批次，不能污染或重复外层死亡列表。
	keg = _spawn_ready_unit("powder_keg", 0, center)
	var enemy_keg := _spawn_ready_unit("powder_keg", 1, center + Vector2(60, 0))
	enemy_keg.hp = 200
	target = _spawn_ready_unit("garen", 0, center + Vector2(0, 60))
	hp = target.hp
	var resolver: CombatResolver = main.combat_service()
	resolver.begin_batch(1, "keg_regression")
	resolver.resolve_damage_hit(keg, 10000, enemy_keg, 1, center)
	resolver.commit_batch()
	_expect(keg.hp == 0 and enemy_keg.hp == 0 and target.hp == hp - 300, "批次死亡支持敌桶连锁且只伤害一次")
	_expect(not resolver.collecting and not resolver.committing, "连锁后批次完整退出")
	_clear()
	# 金币每次爆炸至多一次，沿用原金币位置提示。
	keg = _spawn_ready_unit("powder_keg", 0, center)
	for offset in [Vector2(60, 0), Vector2(0, 60)]:
		var victim := _spawn_ready_unit("garen", 1, center + offset)
		victim.hp = 100
	var before: int = main._skill_presentation.frontal_effects.size()
	main._active_skill_effect_system.apply(keg, stats.active_skills[0])
	var rewards := 0
	for effect in main._skill_presentation.frontal_effects.slice(before):
		if String(effect.get("shape", "")) == "gold_reward":
			rewards += 1
			_expect(effect.pos == center and effect.length == 1.0, "金币提示在桶位置且金额为1")
	_expect(rewards == 1, "双杀只奖励一次")
	_clear()
	_expect(CardDetails.passives(stats).size() == 1, "详情列出爆炸赏金被动")
	# 各种保护不能因斩杀绕过初始命中资格。
	for protection in ["stasis", "effect_shield", "shield", "undying", "building"]:
		keg = _spawn_ready_unit("powder_keg", 0, center)
		target = _spawn_ready_unit("target_dummy" if protection == "building" else "garen", 1, center + Vector2(60, 0))
		target.max_hp = 1000
		target.hp = 400
		match protection:
			"stasis": target.control.hard.apply(&"stasis", &"test", 2.0, {})
			"effect_shield": target.buffs.apply(&"effect_shield", &"test", 2.0, {})
			"shield":
				target.hp = 100
				target.add_shield(500, 5.0, false, &"test")
			"undying": target.buffs.apply(&"undying", &"test", 2.0, {"health_floor": 1.0})
		hp = target.hp
		main._active_skill_effect_system.apply(keg, stats.active_skills[0])
		_expect(target.hp == (100.0 if protection in ["undying", "building"] else hp), "主动爆炸尊重保护/建筑边界 " + protection)
		_clear()
	# 非真死亡（冰鸟蛋）不返金币。
	keg = _spawn_ready_unit("powder_keg", 0, center)
	target = _spawn_ready_unit("garen", 1, center + Vector2(60, 0))
	target.death_replacement_id = "anivia_egg"
	target.death_replacement_charges = 1
	target.hp = 100
	before = main._skill_presentation.frontal_effects.size()
	keg.take_damage(10000)
	rewards = 0
	for effect in main._skill_presentation.frontal_effects.slice(before):
		if String(effect.get("shape", "")) == "gold_reward": rewards += 1
	_expect(rewards == 0, "死亡替身不发击杀赏金")
	_clear()
	keg = _spawn_ready_unit("powder_keg", 0, center)
	keg.freeze(1.0)
	_expect(not keg.can_start_active_skill(stats.active_skills[0]), "被冻结时不能主动引爆")
	keg.control.hard.clear_family(&"freeze")
	_expect(keg.can_start_active_skill(stats.active_skills[0]), "解除冻结恢复释放权限")
	_clear()
	var ai := AIOpponent.new()
	main.add_child(ai)
	keg = _spawn_ready_unit("powder_keg", 1, center)
	_expect(not ai._skill_useful(keg, stats.active_skills[0]), "AI不空爆")
	target = _spawn_ready_unit("garen", 0, center + Vector2(90, 0))
	target.hp = 100
	_expect(ai._skill_useful(keg, stats.active_skills[0]), "AI按爆炸范围判断击杀机会")
	target.position += Vector2(300, 0)
	_expect(not ai._skill_useful(keg, stats.active_skills[0]), "AI不引爆范围外目标")
	ai.queue_free()
	_clear()
	var fx := SkillEffectPresentation.new(main)
	var payload := {"shape": "powder_keg_burst", "pos": center, "length": 140.0, "width": 140.0, "duration": 2.0, "timer": 2.0, "team": 0, "fixed_position": true, "net_id": -1}
	fx.show_skill_effect(98991, payload)
	fx.show_skill_effect(98991, payload)
	_expect(fx.frontal_effects.size() == 1, "可靠爆炸事件重复到达只显示一次")
	fx.tick_visuals(2.1)
	_expect(fx.frontal_effects.is_empty(), "独立爆炸按事件寿命清理")

	_check_burst_projection()

func _check_burst_projection() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	_main.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 32.0
	camera.set_meta("uniform_ground", true)
	camera.position = Vector3(0, sin(deg_to_rad(54.0)), cos(deg_to_rad(54.0))) * 34.0
	camera.look_at(Vector3.ZERO)
	var effects := SkillEffectPresentation.new(_main)
	var renderer := preload("res://scripts/presentation/powder_keg_effect_3d.gd").new()
	viewport.add_child(renderer)
	for flipped in [false, true]:
		if flipped: camera.rotate_object_local(Vector3.BACK, PI)
		for point in [Vector2(210,800), Vector2(510,400)]:
			effects.frontal_effects.clear()
			effects.add_fixed_area_effect(point,140.0,140.0,2.0,0,&"powder_keg_burst")
			renderer.sync_effects(effects,camera)
			var view: Node3D = renderer._views.values()[0]
			_expect(BattleGroundProjection.unproject(camera,view.position).distance_to(point)<0.01,"爆炸中心匹配权威坐标（含反向视角）")
			_expect(is_equal_approx(view.scale.x,0.0125),"140像素范围不改变固定0.0125特效缩放")
			_expect(is_equal_approx(view.scale.x,view.scale.y) and is_equal_approx(view.scale.y,view.scale.z),"爆炸保留统一XYZ比例")
			for i in view._data.emitters.size():
				var emitter: Dictionary = view._data.emitters[i]
				if emitter.name in ["aoe_outerring", "smoke"]:
					_expect(int(view._materials[i].get_shader_parameter("alpha_lock")) == (2 if emitter.name == "aoe_outerring" else 1),"原版环/烟雾锁定透明度UV")
		effects.frontal_effects.clear()
		renderer.sync_effects(effects,camera)
		_expect(renderer._views.is_empty(),"爆炸事件移除后清理所有粒子实例")
	viewport.free()
