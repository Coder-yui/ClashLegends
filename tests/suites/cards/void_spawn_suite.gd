extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_explosion()
	_check_group()
	_check_deployment_lanes()
	_check_empower()
	_check_tower_budget()
	_check_independent_and_phasing()
	_check_schema()
	_check_effect_lifecycle()
	_check_target_contract()
	_check_continuous_replica()
	_check_native_layer_placement()
	_check_empowered_aura()

func _spawn(id: String, team: int, pos: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, id, pos, {"deploy_time_override": 0.0}))

func _clean() -> void:
	_main._active_skill_effect_system.clear()
	_main._skill_presentation.clear()
	_main._projectile_system.clear_all()
	for actor in _main.get_tree().get_nodes_in_group("combatants"):
		if actor is Unit: actor.free()

func _check_explosion() -> void:
	for team in [0, 1]:
		_clean()
		var tower := _spawn("target_dummy", 1 - team, Vector2(300, 900))
		var source := _spawn("void_spawn", team, Vector2(300, 970))
		var enemy := _spawn("garen", 1 - team, Vector2(340, 922))
		var ally := _spawn("garen", team, Vector2(280, 922))
		var air := _spawn("voidfish", 1 - team, Vector2(300, 922))
		var frozen := _spawn("garen", 1 - team, Vector2(310, 922))
		frozen.apply_stasis(3.0)
		source.global_position = tower.global_position + Vector2(0, 60)
		var collateral := _spawn("target_dummy", 1 - team, tower.global_position + Vector2(5, 0))
		var before := [tower.hp, enemy.hp, ally.hp, air.hp, frozen.hp, collateral.hp]
		source.sim_tick(0.05)
		_expect(source.hp == 0.0 and source.is_queued_for_deletion() and not source.is_in_group("combatants"), "双方起跳立即真实死亡并退出战斗集合")
		_expect(source.get_attack_visual_serial() == 0, "牺牲动作不启动普通攻击")
		_expect(_main._active_skill_effect_system.sacrifice_results.size() == 1, "起跳只创建一个独立结果")
		source.free()
		for tick in 15: _main._active_skill_effect_system.tick_effects(0.05)
		_expect(tower.hp == before[0], "第15Tick仍不提前爆炸")
		_main._active_skill_effect_system.tick_effects(0.05)
		_expect(tower.hp == before[0] - 240 and enemy.hp == before[1] and collateral.hp == before[5], "来源已释放第16Tick只伤锁定建筑，不伤邻近单位及建筑")
		_expect(ally.hp == before[2] and air.hp == before[3] and frozen.hp == before[4], "爆炸排除友军空军和凝滞目标")
		_main._active_skill_effect_system.tick_effects(0.05)
		_expect(tower.hp == before[0] - 240, "爆炸不重复")
	_clean()
	var tower := _spawn("target_dummy", 1, Vector2(300, 900))
	var source := _spawn("void_spawn", 0, Vector2(300, 970))
	source.freeze(0.2)
	source.sim_tick(0.05)
	_expect(source.hp > 0.0 and _main._active_skill_effect_system.sacrifice_results.is_empty(), "起跳前硬控阻止牺牲")
	source.control.clear_on_death()
	source.sim_tick(0.05)
	_main._active_skill_effect_system.clear()
	for tick in 30: _main._active_skill_effect_system.tick_effects(0.05)
	_expect(tower.hp == tower.max_hp, "清场取消尚未爆炸结果")
	_clean()

func _check_group() -> void:
	_clean()
	var old_deck: Array = _main._deck.duplicate()
	_main._deck[0] = "void_spawn"
	var members: Array = _main._spawn_card_units(0, "void_spawn", Vector2(340, 1040), 0.0, 0)
	_expect(members.size() == 2 and is_equal_approx(members[0].position.distance_to(members[1].position), 48.0), "两只横向并排中心间隔1.2格")
	_expect(CardDB.active_skills_for("void_spawn").size() == 1, "编队具有一次强化技能")
	_expect(not members[0].ignores_unit_collision() and members[0].active_speed_multiplier == 1.0, "默认保持正常碰撞与移速")
	var wounded := _spawn("void_spawn", 0, Vector2(250, 1000))
	wounded.hp = 100.0
	var skill: Dictionary = CardDB.active_skills_for("void_spawn")[0]
	_main._active_skill_effect_system.apply(wounded, skill)
	_expect(wounded.hp == 133.0 and wounded.max_hp == 199.0, "受伤强化只补新增生命，不清除已有损伤")
	_main._active_skill_effect_system.apply(wounded, skill)
	_expect(wounded.hp == 133.0 and wounded.max_hp == 199.0 and wounded.body_radius == 18.75, "重复效果不叠加生命碰撞")
	var events: Dictionary = CardDB.get_card("void_spawn").audio.events
	_expect(events["deploy:start"].pool.size() == 1 and events["active:cast"].pool.size() == 1 and events["deploy:start"].pool[0] != events["active:cast"].pool[0], "部署技能各使用一个独立声音")
	_main._deck = old_deck
	_clean()

func _check_deployment_lanes() -> void:
	_clean()
	var towers := _main.get_tree().get_nodes_in_group("combatants").filter(func(actor): return actor is Tower)
	var attack_flags: Array[bool] = []
	for tower in towers:
		attack_flags.append(tower.can_attack)
		tower.can_attack = false
	for team in [0, 1]:
		for column in [7, 8, 9, 10]:
			_clean()
			var center := Vector2((column + 0.5) * ArenaRules.TILE_SIZE, 860.0 if team == 0 else 420.0)
			var expected_left := 2 if column == 7 else 0 if column == 10 else 1
			var members: Array[Unit] = _main._spawn_card_units(team, "void_spawn", center)
			var spawn_ok: bool = members.size() == 2 and _main.is_card_deploy_position_valid(team, "void_spawn", center)
			var targets_left := 0
			for member in members:
				spawn_ok = spawn_ok and absf(member.position.x - center.x) == 24.0 and absf(member.position.x - ArenaRules.FIELD_W * 0.5) >= 4.0
				var target := member._find_nearest_tower()
				spawn_ok = spawn_ok and target is Tower and not target.is_king
				if is_instance_valid(target) and target.position.x < ArenaRules.FIELD_W * 0.5: targets_left += 1
			_expect(spawn_ok and targets_left == expected_left, "虚空兽阵营%d第%d列：相邻中线格左右分路，再外一格同路；预设成员不踩中线" % [team, column])
			var crossings := {}
			for tick in 180:
				_run_main_ticks(1)
				for index in members.size():
					var member := members[index]
					if not is_instance_valid(member) or crossings.has(index): continue
					if (team == 0 and member.position.y < ArenaRules.RIVER_Y) or (team == 1 and member.position.y > ArenaRules.RIVER_Y):
						crossings[index] = member.position.x < ArenaRules.FIELD_W * 0.5
				if crossings.size() == 2: break
			_expect(crossings.size() == 2 and crossings.values().count(true) == expected_left, "虚空兽阵营%d第%d列：实际过桥保持预期分路" % [team, column])
	_clean()
	for index in towers.size(): towers[index].can_attack = attack_flags[index]

func _check_tower_budget() -> void:
	for team in [0, 1]:
		_clean()
		for actor in _main.get_tree().get_nodes_in_group("combatants"):
			if actor is Tower:
				actor.hp = actor.max_hp
				actor._target = null
		var source := _spawn("void_spawn", team, Vector2(ArenaRules.BRIDGE_X_LEFT, 700.0 if team == 0 else 580.0))
		var last_hp := source.hp
		var started := false
		for tick in 240:
			if not is_instance_valid(source) or source.hp <= 0.0: break
			last_hp = source.hp
			_run_main_ticks(1)
			if not _main._active_skill_effect_system.sacrifice_results.is_empty():
				started = true
				break
		print("[虚空兽冲塔] team=%d started=%s 起跳前生命=%s" % [team, started, last_hp])
		_expect(started and last_hp > 0.0 and last_hp <= CardDB.PRINCESS_TOWER_STATS.damage, "单只桥头冲塔成功且再承受一次塔伤即死")
	_clean()

func _check_schema() -> void:
	var attributes := CardDetails.attributes(CardDB.get_card("void_spawn"))
	_expect(CardDetails.target_name(CardDB.get_card("void_spawn")) == "建筑（牺牲攻击）", "卡牌详情显示牺牲建筑目标")
	_expect(attributes.any(func(row): return row.name == "爆炸伤害" and row.value == "240") and not attributes.any(func(row): return row.name in ["攻击间隔", "爆炸半径"]), "详情显示爆炸数值，不伪装为周期普通攻击")
	for field in ["sacrifice_damage", "sacrifice_delay"]:
		var stats := CardDB.get_card("void_spawn").duplicate(true)
		stats[field] = -1.0
		_expect(not CardDB.VALIDATOR.validate_all({"void_spawn": stats}, false).is_empty(), "牺牲字段拒绝非法值 " + field)

func _check_independent_and_phasing() -> void:
	_clean()
	var target := _spawn("target_dummy", 1, Vector2(300, 900))
	var source := _spawn("void_spawn", 0, Vector2(300, 970))
	_main.begin_sacrifice(source, target)
	var effect: Dictionary = _main._skill_presentation.frontal_effects.back().duplicate(true)
	var center: Vector2 = _main._active_skill_effect_system.sacrifice_results[0].center
	target.free()
	source.free()
	var arriving := _spawn("garen", 1, center + Vector2(100, 0))
	arriving.global_position = center
	var before := arriving.hp
	for tick in 16: _main._active_skill_effect_system.tick_effects(0.05)
	_expect(arriving.hp == before, "原建筑消失只播爆炸，不伤后来进入者")
	var replica := SkillEffectPresentation.new(_main)
	effect.erase("source_ref")
	var packet: Dictionary = bytes_to_var(var_to_bytes(effect))
	replica.show_skill_effect(9001, packet)
	replica.show_skill_effect(9001, packet)
	_expect(replica.frontal_effects.size() == 1 and replica.frontal_effects[0].end_position == center, "可靠起跳载荷往返保留落点，重复事件幂等")
	replica.tick_visuals(3.1)
	_expect(replica.frontal_effects.is_empty() and arriving.hp == before, "客户端表现到期只清理代理，不追加伤害")
	_clean()
	var a := _spawn("void_spawn", 0, Vector2(300, 1000))
	var b := _spawn("garen", 1, Vector2(400, 1000))
	b.global_position = a.global_position + Vector2(10, 0)
	var movement := MovementSystem.new()
	var units: Array[Unit] = [a, b]
	var normal := movement._collect_unit_contacts(units)
	_expect((normal[movement._unit_order_key(a)] as Vector2).length() > 0, "普通接触产生分离")
	a.buffs.apply(&"unit_phasing", &"test", 1.0, {"enabled": true})
	var phased := movement._collect_unit_contacts(units)
	_expect((phased[movement._unit_order_key(a)] as Vector2).is_zero_approx() and (phased[movement._unit_order_key(b)] as Vector2).is_zero_approx(), "疾步敌我两侧均不产生体积分离")
	a.apply_stasis(0.5)
	_expect(not a.ignores_unit_collision(), "凝滞抑制穿行，恢复不可推挤实体")
	movement.free()
	_clean()

func _check_effect_lifecycle() -> void:
	var sampled: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/void_spawn/burst/sampled.json"))
	_expect(sampled.emitters.size() == 7, "牺牲爆裂保留原版攻击建筑七个发射层")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/void_spawn/burst/source_manifest.json"))
	_expect(String(manifest.definition).ends_with("Jade_VoidSpawn_Base_TurretDeath"), "爆炸必须来自虚空兽攻击建筑定义")
	var events: Dictionary = CardDB.get_card("void_spawn").audio.events
	_expect(events.has("deploy:start") and events.has("death") and events.has("sacrifice:start") and events.has("sacrifice:impact") and not events.has("active_buff:sustain"), "原版生命周期音频齐全且无疾步循环")

	var remaining := 0
	for particles in sampled.frames.back(): remaining += particles.size()
	_expect(remaining == 0, "原版爆裂结束帧没有残留粒子")
	_clean()
	var target := _spawn("target_dummy", 1, Vector2(300, 900))
	var source := _spawn("void_spawn", 0, Vector2(300, 960))
	source.sim_tick(0.05)
	source.free()
	for tick in 16: _main._active_skill_effect_system.tick_effects(0.05)
	var burst_count := 0
	for effect in _main._skill_presentation.frontal_effects:
		if effect.shape == &"sacrifice_burst":
			burst_count += 1
			_expect(float(effect.duration) >= float(sampled.duration), "爆裂表现覆盖完整素材尾帧")
	_expect(burst_count == 1, "来源已释放仍只生成一次原版爆裂")
	_main._skill_presentation.tick_visuals(3.1)
	_expect(_main._skill_presentation.frontal_effects.is_empty(), "爆裂尾迹结束清理表现事件")
	_clean()

func _check_target_contract() -> void:
	for invalidation in ["freed", "dead", "allied", "stasis"]:
		_clean()
		var target := _spawn("target_dummy", 1, Vector2(300, 900))
		var source := _spawn("void_spawn", 0, Vector2(300, 960))
		_main.begin_sacrifice(source, target)
		source.free()
		var before := target.hp
		match invalidation:
			"freed": target.free()
			"dead": target.hp = 0.0
			"allied": target.team = 0
			"stasis": target.apply_stasis(2.0)
		var neighbor := _spawn("target_dummy", 1, Vector2(300, 900))
		var neighbor_hp := neighbor.hp
		for tick in 16: _main._active_skill_effect_system.tick_effects(0.05)
		_expect(neighbor.hp == neighbor_hp and (not is_instance_valid(target) or target.hp == (0.0 if invalidation == "dead" else before)), "目标失效/保护不改打邻居：" + invalidation)
		_expect(_main._active_skill_effect_system.sacrifice_results.is_empty(), "目标失效仍正常完成独立结果：" + invalidation)
	_clean()
	var source := _spawn("void_spawn", 0, Vector2(300, 960))
	var enemy := _spawn("garen", 1, Vector2(300, 900))
	_main.begin_sacrifice(source, enemy)
	_expect(source.hp > 0.0 and _main._active_skill_effect_system.sacrifice_results.is_empty(), "直接入口也拒绝非建筑目标")
	_clean()

func _check_continuous_replica() -> void:
	_clean()
	var source := _spawn("void_spawn", 0, Vector2(300, 960))
	var target := _spawn("target_dummy", 1, Vector2(300, 900))
	_main.begin_sacrifice(source, target)
	var leap: Dictionary = _main._skill_presentation.frontal_effects.back().duplicate(true)
	leap.erase("source_ref")
	var id := int(leap.sacrifice_id)
	var replica := SkillEffectPresentation.new(_main)
	replica.show_skill_effect(7001, bytes_to_var(var_to_bytes(leap)))
	var renderer = load("res://scripts/presentation/sacrifice_leap_3d.gd").new()
	_main.add_child(renderer)
	var camera: Camera3D = _main._battle_presentation._camera
	renderer.sync_effects(replica, camera)
	var model: Node3D = renderer._views[id].model
	_expect(not model.has_method("advance_deployment_visual") and not model._effects.has("spawn"), "包装无部署特效入口和实例")
	var model_id := model.get_instance_id()
	replica.tick_visuals(0.8)
	renderer.sync_effects(replica, camera)
	_expect(not model._impact_started and target.hp == target.max_hp, "客户端到达预测时刻不擅自爆炸或伤害")
	source.free()
	for tick in 16: _main._active_skill_effect_system.tick_effects(0.05)
	var impact: Dictionary = _main._skill_presentation.frontal_effects.back().duplicate(true)
	impact.erase("source_ref")
	_expect(int(impact.sacrifice_id) == id and is_equal_approx(float(leap.impact_delay), 0.8), "可靠起跳与抵达共享身份和16Tick爆炸节点")
	replica.show_skill_effect(7002, bytes_to_var(var_to_bytes(impact)))
	replica.show_skill_effect(7002, bytes_to_var(var_to_bytes(impact)))
	renderer.sync_effects(replica, camera)
	_expect(renderer._views[id].model.get_instance_id() == model_id and model._impact_started and not model.get_node("Model").visible, "抵达在同一代理接爆炸并隐藏身体")
	_expect(not model._effects.energy.visible and not model._effects.glow.visible, "爆炸接替附体蓄能，不留下持续充能光")
	_expect(replica.frontal_effects.size() == 2 and model._effects.has("burst") and renderer._bursts.is_empty(), "可靠抵达重复去重，不生成第二套爆炸")
	var paired_pose: Transform3D = model._effects.burst.global_transform
	_expect(model.sacrifice_impact_basis().z.dot(Vector3.FORWARD) > 0.999, "原版channel骨骼的180度朝向被保留")
	replica.tick_visuals(2.3)
	renderer.sync_effects(replica, camera)
	_expect(renderer._views.is_empty() and renderer._bursts.is_empty(), "动作与粒子尾迹一起清理")
	replica.show_skill_effect(7003, impact)
	renderer.sync_effects(replica, camera)
	_expect(renderer._bursts.size() == 1, "迟到的真实抵达在无起跳代理时仍能显示")
	_expect(renderer._bursts[id].global_transform.is_equal_approx(paired_pose), "缺少起跳时爆炸仍使用相同高度、缩放和原版挂点朝向")
	replica.clear()
	renderer.sync_effects(replica, camera)
	_expect(renderer._bursts.is_empty(), "清场释放迟到抵达表现")
	renderer.free()
	_clean()

func _check_native_layer_placement() -> void:
	var particles = load("res://assets/effects/void_spawn/player.gd")
	for kind in ["burst", "death"]:
		var view = particles.new()
		_main.add_child(view)
		view.load_kind(kind)
		view.setup_native(particles.native_scale(kind))
		view.position = Vector3(2.0, 1.8, 3.0)
		view.rotation.y = PI * 0.7
		view.seek(0.05)
		var floor_count := 0
		var body_count := 0
		for i in view._data.emitters.size():
			var emitter: Dictionary = view._data.emitters[i]
			for item in view._pools[i]:
				if not item.visible: continue
				if String(emitter.name) in particles.GROUND_PLANES:
					floor_count += 1
					_expect(absf(item.global_position.y - 0.09) < 0.001, "原版地面层不随高处撞击骨骼悬空")
				else:
					body_count += 1
					_expect(absf(item.global_position.y - 1.8) < 0.001, "原版主体层保留撞击挂点高度")
		_expect(body_count > 0 and (floor_count == 0 if kind == "burst" else floor_count > 0), "攻城保留原片撞击平面，普通死亡保留地面层")
		view.seek(2.2)
		var active := 0
		for pool in view._pools:
			for item in pool:
				if item.visible: active += 1
		_expect(active == 0, "原版所有层完整淡出后无残留")
		view.free()

func _check_empower() -> void:
	var old_deck: Array = _main._deck.duplicate()
	_main._deck[0] = "void_spawn"
	for lose_leader in [false, true]:
		_clean()
		var outsiders: Array = _main._spawn_card_units(0, "void_spawn", Vector2(200, 1100), 0.0)
		var members: Array = _main._spawn_card_units(0, "void_spawn", Vector2(340, 1000), 0.0, 0)
		var ability: int = members[0].active_ability_id
		var skill: Dictionary = CardDB.active_skills_for("void_spawn")[0]
		_expect(skill.cost == 1 and skill.max_uses == 1 and skill.icon_path == "res://assets/skills/void_spawn_0.png", "强化1金币每组一次，使用云顶fixed图标")
		_main._elixir.elixir = 10.0
		_expect(_main.use_active_skill(ability, 0) and _main._elixir.elixir == 9.0, "正式技能请求扣除1金币")
		if lose_leader: members[0].take_damage(9999.0)
		_main._sim_tick_id += 10
		_main._tick_pending_active_skills(0.05)
		_expect(_main._active_skills.entry(ability).uses_remaining == 0 and not _main.use_active_skill(ability, 0), "强化次数消耗且不能重复使用")
		for member in members:
			if member.hp <= 0:
				_expect(member.sacrifice_empowerment == Vector2.ONE, "死亡成员不复活或获得强化")
				continue
			_expect(member.sacrifice_empowerment == Vector2(1.5, 1.25) and is_equal_approx(member.active_speed_multiplier, 1.2), "所有存活成员永久强化并获得永久20%移速")
			_expect(member.body_radius == 18.75 and member.hp == 199.0 and member.max_hp == 199.0 and not member.ignores_unit_collision(), "变大增加碰撞和最大生命，仍不穿人")
			for tick in 239: member._tick_active_statuses(0.05)
			_expect(is_equal_approx(member.active_speed_multiplier, 1.2), "239Tick时仍有移速加成")
			member._tick_active_statuses(0.05)
			_expect(is_equal_approx(member.active_speed_multiplier, 1.2) and member.sacrifice_empowerment == Vector2(1.5, 1.25), "240Tick后永久移速与爆炸强化保留")
		for outsider in outsiders: _expect(outsider.sacrifice_empowerment == Vector2.ONE and outsider.active_buff_timer == 0.0, "其他部署批次不受影响")
		var target := _spawn("target_dummy", 1, Vector2(340, 900))
		var neighbor := _spawn("target_dummy", 1, Vector2(350, 910))
		var before := target.hp
		_main.begin_sacrifice(members[1], target)
		var leap: Dictionary = _main._skill_presentation.frontal_effects.back()
		_expect(leap.visual_scale == 1.25 and members[1].hp == 0, "强化起跳仍立即死亡，独立动作保留体型")
		members[1].free()
		for tick in 15: _main._active_skill_effect_system.tick_effects(0.05)
		_expect(target.hp == before, "强化不会提前结算")
		_main._active_skill_effect_system.tick_effects(0.05)
		_expect(target.hp == before - 360 and neighbor.hp == neighbor.max_hp, "强化只对锁定建筑造成360伤害，仍无范围伤害")
		var impact: Dictionary = _main._skill_presentation.frontal_effects.back()
		_expect(impact.forward == leap.forward and impact.visual_scale == leap.visual_scale, "抵达载荷保留起跳方向与强化体型")
	_clean()
	var members: Array = _main._spawn_card_units(0, "void_spawn", Vector2(340, 1000), 0.0, 0)
	var target := _spawn("target_dummy", 1, Vector2(340, 900))
	_main.begin_sacrifice(members[0], target)
	_main._active_skill_effect_system.apply(members[1], CardDB.active_skills_for("void_spawn")[0])
	_expect(_main._active_skill_effect_system.sacrifice_results[0].damage == 240.0 and members[1].sacrifice_empowerment.x == 1.5, "已起跳成员的独立结果不被后续强化追溯修改")
	for field in ["damage_multiplier", "health_bonus_ratio", "body_scale_multiplier", "speed_multiplier", "visual_scale_multiplier"]:
		var stats := CardDB.get_card("void_spawn").duplicate(true)
		stats.active_skills[0][field] = 0.0
		_expect(not CardDB.VALIDATOR.validate_all({"void_spawn": stats}, false).is_empty(), "强化拒绝非法字段 " + field)
	var wounded := _spawn("void_spawn", 0, Vector2(250, 1000))
	wounded.hp = 100.0
	var skill: Dictionary = CardDB.active_skills_for("void_spawn")[0]
	_main._active_skill_effect_system.apply(wounded, skill)
	_expect(wounded.hp == 133.0 and wounded.max_hp == 199.0, "受伤强化只补新增生命，不清除已有损伤")
	_main._active_skill_effect_system.apply(wounded, skill)
	_expect(wounded.hp == 133.0 and wounded.max_hp == 199.0 and wounded.body_radius == 18.75, "重复效果不叠加生命碰撞")
	var events: Dictionary = CardDB.get_card("void_spawn").audio.events
	_expect(events["deploy:start"].pool.size() == 1 and events["active:cast"].pool.size() == 1 and events["deploy:start"].pool[0] != events["active:cast"].pool[0], "部署技能各使用一个独立声音")
	_main._deck = old_deck
	_clean()

func _check_empowered_aura() -> void:
	_clean()
	var source := _spawn("void_spawn", 0, Vector2(300, 850))
	var proxy := UnitModel3D.new()
	_main.add_child(proxy)
	proxy._source = source
	proxy._state = UnitPresentationState.new(source)
	var aura: ActiveBuffVisual3D = load("res://assets/effects/void_spawn/empowered.tscn").instantiate()
	proxy.add_child(aura)
	aura.configure(source.visual_radius, 0)
	proxy._active_buff_visual = aura
	proxy._update_active_buff_visual(0.1)
	_expect(not aura.active, "普通虚空兽不显示强化附体")
	source.sacrifice_empowerment = Vector2(1.5, 1.25)
	proxy._update_active_buff_visual(0.1)
	_expect(aura.active and aura.visible, "永久强化状态开启附体，无需临时加速状态")
	for tick in 41: source._tick_active_statuses(0.05)
	proxy._update_active_buff_visual(2.1)
	_expect(aura.active and source.active_speed_multiplier == 1.0, "加速到期仍保留强化附体")
	proxy._dying = true
	proxy._update_active_buff_visual(0.1)
	_expect(not aura.active and not aura.visible, "死亡和起跳结束活体附体表现")
	proxy.free()
	_clean()
