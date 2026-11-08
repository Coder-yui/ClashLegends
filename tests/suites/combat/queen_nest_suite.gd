extends "res://tests/suites/battle_suite.gd"
func run(harness: Object) -> void:
	_harness = harness
	var definition := CardDB.get_card("queen_nest")
	var full_audio := PresentationConfig.audio_for(definition, 0, 0)
	var empty_audio := PresentationConfig.audio_for(definition, 0, 1)
	_expect(empty_audio.events.death == full_audio.events.death, "睡眠巢穴与空巢均绑定同一洞穴死亡音效")
	_expect(String(full_audio.events["active:cast"].pool[0]).ends_with("w_burrow_voice.wav"), "主动使用用户选择的1.68秒W遁地强化语音")

	var spawn_audio := PresentationConfig.audio_for(CardDB.get_card("nest_reksai"), 0, 0)
	var reksai_audio := PresentationConfig.audio_for(CardDB.get_card("reksai"), 0, 0)
	_expect(spawn_audio.events["deploy:start"] == reksai_audio.events["deploy:start"], "死亡出巢复用雷克塞完整W破土声音池")
	_expect(not spawn_audio.events.has("deploy:hit") and not spawn_audio.events.has("deploy:voice"), "Respawn不播放W命中声或额外语音")

	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	var placement := DeploymentRules.new()
	var obstacle := _spawn_ready_unit("target_dummy", 1, Vector2(340, 900))
	obstacle.body_radius = 90.0
	placement.combatants = func(): return [obstacle]
	var summon_stats := CardDB.get_unit_stats("enraged_reksai")
	for side in [-1.0, 1.0]:
		obstacle.position = Vector2(360.0 + side * 20.0, 900)
		var desired := Vector2(360.0 + side, 900)
		var ordinary := summon_stats.duplicate(true)
		ordinary.erase("summon_prefer_outward")
		var closest := placement.resolve_summoned_spawn(0, "enraged_reksai", ordinary, desired)
		var preferred := placement.resolve_summoned_spawn(0, "enraged_reksai", summon_stats, desired, Vector2.INF, 0.0, desired)
		_expect((closest.x - 360.0) * side < 0.0, "障碍夹具全场最近落点位于相反半区")
		_expect(preferred.is_finite() and (preferred.x - 360.0) * side >= -0.001, "前方受阻优先原左右半区合法位置")
		var free_point := Vector2(360.0 + side * 250.0, 950)
		_expect(placement.resolve_summoned_spawn(0, "enraged_reksai", summon_stats, free_point, Vector2.INF, 0.0, free_point) == free_point, "合法前方请求位置不偏移")
	obstacle.position = Vector2(0, 640)
	obstacle.body_radius = 730.0
	var fallback := placement.resolve_summoned_spawn(0, "enraged_reksai", summon_stats, Vector2(100, 900), Vector2.INF, 0.0, Vector2(100, 950))
	_expect(fallback.is_finite() and fallback.x > 360.0, "原半区全部受阻才退回另一半区")
	obstacle.free()
	# 实际主动技能链路：障碍偏外侧，使旧全半场搜索落在巢穴内侧。
	for team in [0, 1]:
		for side in [-1.0, 1.0]:
			var origin := Vector2(360.0 + side * 140.0, 900 if team == 0 else 380)
			var nest := _spawn_ready_unit("queen_nest", team, origin)
			var blocker := _spawn_ready_unit("target_dummy", 1-team, origin + Vector2(side * 20.0, -50.0 if team == 0 else 50.0))
			blocker.body_radius = 60.0
			_main._active_skill_effect_system.activate_summon(nest, CardDB.get_card("queen_nest").active_skills[0])
			var spawned := _units("enraged_reksai", team)
			_expect(spawned.size() == 1, "前方受阻主动仍生成一只雷克塞")
			if not spawned.is_empty():
				_expect((spawned[0].global_position.x - origin.x) * side >= -0.001, "双方左右场主动受阻均优先巢穴外侧而非仅同半场")
				spawned[0].free()
			nest.free()
			blocker.free()
	for team in [0, 1]:
		var pos := Vector2(220, 900 if team == 0 else 380)
		var nest := _spawn_ready_unit("queen_nest", team, pos)
		var center := nest.global_position
		nest.take_damage(99999.0)
		var children := _units("nest_reksai", team)
		_expect(children.size() == 1, "巢穴双方击毁只生成一只普通雷克塞")
		if not children.is_empty():
			var child: Unit = children[0]
			_expect(child.global_position.distance_to(center) < 1.0, "死亡释放占位后原处出巢")
			_expect(child.hp == 900.0 and not child.is_deployed(), "出巢满血且等待Respawn部署")
			for tick in 21: child.sim_tick(0.05)
			_expect(not child.is_deployed(), "Respawn第21Tick仍部署")
			child.sim_tick(0.05)
			_expect(child.is_deployed(), "Respawn第22Tick完成部署")
			child.free()
		var active := _spawn_ready_unit("queen_nest", team, pos)
		active.hp = 300.0
		var cells := active.nav_cells.duplicate()
		_main._active_skill_effect_system.activate_summon(active, CardDB.get_card("queen_nest").active_skills[0])
		_expect(active.hp == 300.0 and active.is_building and active.nav_cells == cells and active.form_index == 1, "主动保留原巢穴生命和占地并切换空巢")
		_expect(active.death_spawn_count == 0, "出巢后永久清除死亡召唤")
		active.take_damage(99999.0)
		_expect(_units("nest_reksai", team).is_empty(), "空巢被摧毁不再召唤普通雷克塞")
		var angry := _units("enraged_reksai", team)
		_expect(angry.size() == 1, "主动只产生一只暴怒雷克塞")
		if not angry.is_empty():
			var child: Unit = angry[0]
			_expect(child.is_deployed() and child.hp == 900.0 and child.damage == 90.0 and child.splash_radius == 60.0, "暴怒满血即刻部署且永久90伤害范围攻击")
			child.free()
		var expiry := _spawn_ready_unit("queen_nest", team, pos)
		for tick in 499: expiry._building_tick(0.05)
		_expect(expiry.hp > 0.0 and _units("nest_reksai", team).is_empty(), "25秒前不提前出巢")
		expiry._building_tick(0.05)
		_expect(_units("nest_reksai", team).size() == 1, "25秒自然衰血死亡正常出巢")
		for child in _units("nest_reksai", team): child.free()
	var attacker := _spawn_ready_unit("enraged_reksai", 0, Vector2(300, 900))
	attacker.move_speed = 0.0
	var primary := _spawn_ready_unit("target_dummy", 1, Vector2(300, 850))
	var nearby := _spawn_ready_unit("target_dummy", 1, Vector2(315, 850))
	var airborne := _spawn_ready_unit("target_dummy", 1, Vector2(305, 855))
	airborne.is_air = true
	for target in [primary, nearby, airborne]:
		target.max_hp = 5000.0
		target.hp = 5000.0
		target.can_attack = false
		target.lifespan = 0.0
		target.lifespan_hp_decay = false
	_run_main_ticks(150)
	_expect(attacker._attack_swing_count >= 5, "永久Q超过原三次强化限制持续攻击")
	_expect(primary.hp <= 4550.0 and nearby.hp == primary.hp, "连续Q对主目标与附近地面敌人造成同额90伤害")
	_expect(airborne.hp == 5000.0, "永久Q不会借地面主目标伤害空军")
	for unit in [attacker, primary, nearby, airborne]: unit.free()
	await harness.process_frame
	_main.queue_free()
	await harness.process_frame
func _units(id: String, team: int) -> Array:
	return _main.get_tree().get_nodes_in_group("combatants").filter(func(unit): return unit is Unit and unit.card_id == id and unit.team == team and unit.hp > 0.0)
