extends RefCounted
var _harness
var _main: Node2D
var _spells: SpellSystem
var _units: Array[Unit] = []
func run(harness, main: Node2D) -> void:
	_harness = harness
	_main = main
	_spells = main.get("_spell_system")
	_check_presentation_arrival()
	var stats := CardDB.get_card("mega_inferno_bomb")
	var center := Vector2(360, 800)
	var a := _unit("garen", center)
	var b := _unit("anivia", center + Vector2(135, 0))
	var outside := _unit("garen", center + Vector2(210, 0))
	var ally := _unit("garen", center, 0)
	a.add_shield(1000, 10)
	_spells.cast(0, stats, center)
	var arrival: int = _spells.spell_flights[0].impact_tick
	_expect(arrival - main.get_authoritative_server_tick() >= 16, "至少16Tick飞行")
	_tick(arrival - 1)
	_expect(a.hp == 3000 and a.shield_hp == 1000, "抵达前不结算")
	_tick(arrival)
	_expect(a.hp == 3000 and a.shield_hp == 400 and a.grievous_wounds_visual() == false, "普通版护盾正常吸收600")
	_expect(b.hp == 2640 and outside.hp == 3000 and ally.hp == 3000, "外围360对空有效，排除范围外和友方")
	a.add_restoration_shield(900, 1)
	a.add_shield(700, 8, false, &"explosive", {}, {"damage":100})
	_spells.cast(0, stats, center, true)
	_tick(_spells.spell_flights[0].impact_tick)
	_expect(a.hp == 2400 and a.shield_hp == 0 and a.shields.expired_effects.is_empty(), "强化先清所有盾层再伤害，不触发自然到期")
	_expect(a.grievous_wounds_visual() == true and b.grievous_wounds_visual() == true, "内外圈同样施加永久重伤")
	a.heal(200)
	a.apply_attack_lifesteal(1.0, 2.0)
	a._try_attack_lifesteal(100)
	a._restore_shield_health()
	a.heal_with_overflow(1000, 1.0, 5.0, &"test")
	_expect(a.hp == 2400 and a.shield_hp == 0, "治疗、吸血、恢复盾及过量转盾全部阻止")
	a._change_max_health(3300, 300)
	_expect(a.hp == 2700 and a.max_hp == 3300, "最大生命增加补偿不受重伤影响")
	a.buffs.advance(300.0)
	a.heal(100)
	_expect(a.hp == 2700, "经过300秒仍禁止回复")
	a.buffs.clear_family(&"grievous_wounds")
	a.heal(100)
	_expect(a.hp == 2700 and a.grievous_wounds_visual(), "清除有时限Buff不移除永久重伤")
	a.grievous_wounds = false
	a.hp = 3000
	_spells.cast(0, stats, center, true)
	var next_impact: int = _spells.spell_flights[0].impact_tick
	_main.runtime.set("_sim_tick_id", next_impact)
	_main.combat_service().begin_batch(next_impact, "same_tick_heal")
	a.heal(500)
	_spells.tick(0.05)
	_main.combat_service().commit_batch()
	_expect(a.hp == 2400 and a.grievous_wounds_visual() == true, "先提交的同批治疗收益也被新重伤阻止")
	a.buffs.advance(2.0)
	_spells.cast(0, stats, center, true)
	_tick(_spells.spell_flights[0].impact_tick)
	_expect(a.grievous_wounds_visual() == true, "重复命中保留重伤，不叠加")
	a.grievous_wounds = false
	a.hp = 3000
	a.add_shield(800, 5)
	a.buffs.apply(&"effect_shield", &"test", 5.0, {})
	_spells.cast(0, stats, center, true)
	_tick(_spells.spell_flights[0].impact_tick)
	_expect(a.hp == 3000 and a.shield_hp == 800 and a.grievous_wounds_visual() == false, "梦魇效果盾挡住伤害、破盾和重伤")
	a.apply_stasis(5)
	_spells.cast(0, stats, center, true)
	_tick(_spells.spell_flights[0].impact_tick)
	_expect(a.hp == 3000 and a.shield_hp == 800 and a.grievous_wounds_visual() == false, "凝滞拒绝整次效果")
	var mortal := _unit("garen", center + Vector2(240, 0))
	mortal.grievous_wounds = true
	mortal._die()
	_expect(not mortal.grievous_wounds, "死亡清除重伤")
	_units.erase(mortal)
	for u in _units: u.free()
	_units.clear()
	var building := _unit("target_dummy", center)
	building.add_shield(1000, 5)
	_spells.cast(0, stats, center, true)
	_tick(_spells.spell_flights[0].impact_tick)
	_expect(building.hp == 2400 and building.shield_hp == 0 and building.grievous_wounds_visual() == false, "建筑卡全额受伤破盾但不重伤")
	building.free()
	_units.clear()
	for tower in main.world.towers_snapshot():
		var before: float = tower.hp
		tower.add_shield(1000, 5)
		_spells.cast(1-tower.team, stats, tower.position, true)
		_tick(_spells.spell_flights[0].impact_tick)
		_expect(tower.hp == before - 180 and tower.shield_hp == 0, "防御塔及水晶清盾并受30%伤害")
		tower.hp = before
	_spells.cast(0, stats, center, true)
	_spells.clear()
	_tick(main.get_authoritative_server_tick() + 100)
	_expect(_spells.spell_flights.is_empty() and _spells.bomb_effects.is_empty(), "清场取消飞行和表现")
	_spells.show_flight(999, "mega_inferno_bomb", center, center, 160, 1, 20)
	_expect(_spells.spell_flights.is_empty() and _spells.bomb_effects.size() == 1, "客户端事件只创建表现")
	_spells.clear()
	for field in ["inner_radius", "inner_damage", "flight_speed", "tower_damage_multiplier"]:
		var bad := stats.duplicate(true)
		bad[field] = -1
		_expect(not CardDB.VALIDATOR.validate_all({"mega_inferno_bomb":bad}, false).is_empty(), "拒绝非法" + field)
	var timed_skill := stats.duplicate(true)
	timed_skill.active_skills[0]["duration"] = 5.0
	_expect(not CardDB.VALIDATOR.validate_all({"mega_inferno_bomb":timed_skill}, false).is_empty(), "拒绝给永久重伤配置时限")
	var layout_script = preload("res://scripts/presentation/unit_bar_layout.gd")
	for ratios in [Vector2(0.5, 0), Vector2(0.5, 0.3), Vector2(1.4, 1.0)]:
		var layout: Dictionary = layout_script.calculate(48, ratios.x, ratios.y)
		var icon_x := maxf(48, layout.background_width) + 10
		_expect(icon_x - 7 > layout.background_width and icon_x - 7 > 48, "重伤图标不遮盖基础、溢出或护盾血条")
func _unit(id: String, pos: Vector2, team: int = 1) -> Unit:
	var unit: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, id, pos, {"deploy_time_override": 0.0}))
	unit.max_hp = 3000
	unit.hp = 3000
	_units.append(unit)
	return unit
func _tick(tick: int) -> void:
	_main.runtime.set("_sim_tick_id", tick)
	_main.combat_service().begin_batch(tick, "bomb_test")
	_spells.tick(0.05)
	_main.combat_service().commit_batch()
func _expect(ok: bool, message: String) -> void:
	_harness._expect(ok, "终极爆弹：" + message)

func _check_presentation_arrival() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	_main.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.set_meta("uniform_ground", true)
	camera.position = Vector3(0, sin(deg_to_rad(54.0)), cos(deg_to_rad(54.0))) * 24.0
	camera.look_at(Vector3.ZERO)
	var view = preload("res://scripts/presentation/mega_inferno_bomb_3d.gd").new()
	viewport.add_child(view)
	var effect := {"id": 991, "origin": Vector2(360,1160), "pos": Vector2(210,300), "radius":160.0, "team":0, "start_tick":0, "impact_tick":26, "progress":0.93, "impacted":false, "duration":5.0, "timer":5.0}
	var state := SpellSystem.new(_main)
	state.bomb_effects.append(effect)
	view.sync_effects(state, camera)
	var missile = view._views[991].missile
	for t in [0.0, 0.25, 0.5, 1.0]:
		var pose: Transform3D = view._flight_pose(camera, effect, t*1.3, 1.3)
		var ground := preload("res://scripts/presentation/spell_effect_projection.gd").ground(camera, effect.origin.lerp(effect.pos,t))
		var offset := BattleGroundProjection.unproject(camera, pose.origin)-BattleGroundProjection.unproject(camera, ground)
		var audio_point := preload("res://scripts/presentation/mega_inferno_bomb_motion.gd").canvas_position(effect.origin,effect.pos,t)
		_expect((audio_point-effect.origin.lerp(effect.pos,t)).distance_to(offset)<0.01, "飞行声轨迹与实际3D投影一致")
	effect.impacted = true
	view.sync_effects(state, camera)
	_expect(is_equal_approx(missile._age,1.3), "抵达不受滞后一帧progress影响而回退采样")
	var landing := preload("res://scripts/presentation/spell_effect_projection.gd").ground(camera,effect.pos)
	_expect(missile.global_position.distance_to(landing)<0.001, "抵达根节点精确落在目标")
	var bomb_hidden := true
	for i in missile._data.emitters.size():
		if missile._data.emitters[i].name == "Bomb":
			for item in missile._pools[i]: bomb_hidden = bomb_hidden and not item.visible
	_expect(bomb_hidden, "同一采样帧停发立即隐藏Bomb网格")
	for kind in ["warning_ally", "warning_enemy", "impact"]:
		_expect(view._views[991][kind].scale.is_equal_approx(missile.scale), "全阶段使用相同整体等比缩放")
	viewport.free()
