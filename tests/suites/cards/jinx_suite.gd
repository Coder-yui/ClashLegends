extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_animation_routes()
	_check_switch_controls()
	_check_moving_switch()
	_check_gait_continuity()
	_check_haste_placement()
	_check_six_second_haste()
	var source := _spawn("jinx", 0, Vector2(200, 900))
	var ground := _spawn("target_dummy", 1, Vector2(320, 900))
	var air := _spawn("corki", 1, Vector2(325, 925))
	var ally := _spawn("target_dummy", 0, Vector2(325, 880))
	var ground_hp := ground.hp
	var air_hp := air.hp
	var ally_hp := ally.hp
	var resolver: CombatResolver = main.combat_service()
	resolver.resolve_attack_hit(0, source.position, ground, 100, 45, 0, source, source.position, 0)
	_expect(ground.hp == ground_hp - 100 and air.hp == air_hp - 100 and ally.hp == ally_hp, "火箭炮同次命中空地，友军不受伤")
	var projectile: ProjectileSystem = main._projectile_system
	projectile.launch(source, ground, 100, 500, 45, 0, Color.WHITE)
	source.attack_timeline.begin_recovery(1.3, 0.22, 1.0)
	source.toggle_weapon_form()
	_expect(source.form_index == 1 and source.attack_range == 170 and source.splash_radius == 0 and source.attack_interval == 1.0, "切枪替换射程、间隔与溅射")
	_expect(source.attack_timeline.cooldown == 0 and source.attack_timeline.recovery == 0, "切枪立即清空后摇与冷却")
	var flying: Dictionary = projectile.projectiles.values()[0]
	_expect(flying.splash == 45 and flying.source_form_index == 0 and flying.visual == &"jinx_rocket", "在途火箭固化旧形态与溅射")
	source.prepare_action_clocks(0.4)
	source.on_attack_landed(0, 100, 1, 0)
	_expect(source.active_attack_speed_multiplier == 1.0, "旧火箭不叠机枪攻速")
	for i in 5: source.on_attack_landed(1, 100, i, source.form_change_serial)
	_expect(is_equal_approx(source.active_attack_speed_multiplier, 1.45), "机枪每击15%，封顶三层")
	for i in 59: source._tick_active_statuses(0.05)
	_expect(is_equal_approx(source.active_attack_speed_multiplier, 1.45), "59Tick层数未提前消失")
	source._tick_active_statuses(0.05)
	_expect(source.active_attack_speed_multiplier == 1.0, "60Tick攻速层数到期")
	projectile.clear_all()
	# 3秒包含边界；另一来源造成致命伤，原攻击者仍获得收益。
	source.record_structure_attack(ground)
	main._sim_tick_id += 60
	ground.take_damage(99999)
	_expect(source.structure_haste_visual() and is_equal_approx(source.active_speed_multiplier, 2.0), "3秒内队友摧毁建筑触发100%移速")
	_expect(is_equal_approx(source.active_attack_speed_multiplier, 1.3), "被动30%攻速")
	for i in 60: source._tick_active_statuses(0.05)
	_expect(is_equal_approx(source.active_speed_multiplier, 1.5), "3秒后移速加成线性衰减至50%")
	source.toggle_weapon_form()
	_expect(source.structure_haste_visual(), "换形保留罪恶快感")
	for i in 60: source._tick_active_statuses(0.05)
	_expect(source.active_speed_multiplier == 1.0 and source.active_attack_speed_multiplier == 1.0, "6秒加速与攻速到期")
	var late := _spawn("target_dummy", 1, Vector2(400, 1000))
	source.record_structure_attack(late)
	main._sim_tick_id += 61
	late.take_damage(99999)
	_expect(not source.structure_haste_visual(), "超过3秒的建筑击败不算参与")
	var normal := _spawn("ashe", 1, Vector2(400, 1050))
	source.record_structure_attack(normal)
	normal.take_damage(99999)
	_expect(not source.structure_haste_visual(), "击败普通单位不触发")
	var natural := _spawn("target_dummy", 1, Vector2(500, 1100))
	source.record_structure_attack(natural)
	natural._lifespan_left = 0.05
	natural._tick_building_lifetime(0.05)
	_expect(source.structure_haste_visual(), "建筑被命中后3秒内自然到期触发助攻")
	source.buffs.clear_family(&"structure_haste")
	var decay := _spawn("target_dummy", 1, Vector2(500, 1100))
	resolver.resolve_attack_hit(0, source.position, decay, 1, 0, 0, source, source.position, source.form_index)
	main._sim_tick_id += 60
	decay.hp = 1
	decay._tick_building_lifetime(0.05)
	_expect(decay.hp == 0 and source.structure_haste_visual(), "建筑被命中后自然衰血致死触发助攻")
	source.buffs.clear_family(&"structure_haste")
	decay.free()
	for marked in [false, true]:
		var expired := _spawn("target_dummy", 1, Vector2(500, 1100))
		if marked: source.record_structure_attack(expired)
		main._sim_tick_id += 61
		expired._lifespan_left = 0.05
		expired._tick_building_lifetime(0.05)
		_expect(not source.structure_haste_visual(), "未命中或命中超过3秒的建筑自然死亡不触发")
		expired.free()
	for king in [false, true]:
		var tower := Tower.new()
		tower.setup(1, {"hp": 100, "damage": 0, "range": 100.0, "interval": 1.0, "radius": 18.0}, king)
		tower.battle_context = source.battle_context
		main.add_child(tower)
		source.record_structure_attack(tower)
		tower.notify_visual_destroyed()
		_expect(not source.structure_haste_visual(), "纯死亡表现不能发放被动")
		tower.take_damage(100)
		_expect(source.structure_haste_visual(), "防御塔与水晶权威致死均触发")
		var payload: Array = main._snapshot_system._unit_snapshot_payload(source.net_id, source)
		_expect(payload[NetworkSnapshotSystem.U_STRUCTURE_HASTE] == true and payload[NetworkSnapshotSystem.U_ACTIVE_SPEED_MULTIPLIER] == 2.0, "快照携带独立被动窗口与速度")
		source.apply_stasis(0.5)
		_expect(source.active_speed_multiplier == 1.0 and source.active_attack_speed_multiplier == 1.0, "凝滞抑制已有被动属性")
		for i in 10: source._tick_active_statuses(0.05)
		_expect(source.structure_haste_visual(), "凝滞不删除窗口")
		source.control.hard.clear_family(&"stasis")
		source.buffs.suppressed = false
		source.buffs.clear_family(&"structure_haste")
		tower.free()
	if is_instance_valid(natural): natural.free()
	var lethal := _spawn("target_dummy", 1, Vector2(400, 1100))
	resolver.begin_batch(main._sim_tick_id, &"jinx_test")
	resolver.resolve_attack_hit(0, source.position, lethal, 99999, 0, 0, source, source.position, 0)
	resolver.submit_damage(source, 99999, lethal, 1, lethal.position)
	resolver.commit_batch()
	_expect(not source.structure_haste_visual(), "同批互杀不向死亡来源发放被动")
	for unit in [source, ground, air, ally, late, normal, lethal]:
		if is_instance_valid(unit): unit.free()
	var old_deck: Array = main._deck.duplicate()
	main._deck[0] = "jinx"
	var paid: Unit = main._spawn_card_units(0, "jinx", Vector2(250, 1100), 0.0, 0)[0]
	var id := paid.active_ability_id
	main._elixir.elixir = 7.0
	for use in 5:
		_expect(main.use_active_skill(id, 0), "正式入口接受换武器%d" % (use + 1))
		_expect(not main.use_active_skill(id, 0), "排队期间不重复受理")
		main._sim_tick_id += 10
		main._tick_pending_active_skills(0.05)
		var entry: Dictionary = main._active_skills.entry(id)
		_expect(entry.uses_remaining == 4 - use and entry.cooldown_left == 4.0, "真实开始消费次数并启动4秒CD")
		_expect(paid.form_index == (use + 1) % 2, "五次主动交替武器")
		_expect(main._elixir.elixir == 7.0, "换武器费用0")
		_expect(not main.use_active_skill(id, 0), "CD内或耗尽不可换枪")
		main._active_skills.tick(4.0)
		paid.prepare_action_clocks(4.0)
	_expect(not main.use_active_skill(id, 0), "五次用尽")
	main._deck = old_deck
	paid.free()
	for value in [-1, "bad", INF]:
		var cards := CardDB.all().duplicate(true)
		cards.jinx.structure_assist_window = value
		_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "助攻字段拒绝非法数值与类型")

func _spawn(card: String, team: int, pos: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, card, pos, {"deploy_time_override": 0.0}))

func _check_animation_routes() -> void:
	var unit := _spawn("jinx", 0, Vector2(200, 1000))
	var view := _view_for(unit)
	_expect(view != null, "金克丝具有实际3D代理")
	if view != null:
		unit._deploy_timer = 1.0
		view._sync_visual(true, 0.0)
		_expect(view._animation_player.current_animation == "Respawn", "部署使用Respawn")
		unit._deploy_timer = 0.0
		unit.toggle_weapon_form()
		view._sync_visual(false, 0.0)
		_expect(view._animation_player.current_animation == "launcher_spell1_weapon2_anm", "火箭切机枪使用原Launcher起始方向")
		view._play_attack(1)
		_expect(view._animation_player.current_animation == "launcher_spell1_weapon2_anm", "变形优先级阻止普攻打断切枪")
		unit.prepare_action_clocks(0.4)
		unit.toggle_weapon_form()
		view._sync_visual(false, 0.0)
		_expect(view._animation_player.current_animation == "minigun_spell1_weapon2_anm", "机枪切火箭使用原Minigun起始方向")
		unit.prepare_action_clocks(0.4)
		view._clear_visual_action_state()
		view._transition_to_basic_state(2, -1.0, &"idle")
		_expect(view._animation_player.current_animation == "Jinx_Rlauncher_run_in_anm", "火箭入跑使用专用过渡")
		view._transition_to_basic_state(1, -1.0, &"attack")
		_expect(view._animation_player.current_animation == "Rlauncher_Idlein1", "火箭收势进入对应待机")
	unit.free()
	for form in [CardDB.get_card("jinx"), CardDB.get_card("jinx").transformed_stats]:
		_expect(form.audio.events.has("deploy:start") and not form.audio.events.has("deploy:voice"), "两形态只使用Respawn部署音效")
		_expect(not form.visual_animations.has("idle_cycle") and not form.visual_animations.has("haste_move"), "两形态只用一种待机、无加速跑")
	_expect(CardDB.get_card("jinx").transformed_stats.visual_animations.attack == ["Attack1", "Attack2"], "机枪只轮播两组代表动作")
	for duration in [0, -1, INF, "bad"]:
		var cards := CardDB.all().duplicate(true)
		cards.jinx.transform_duration = duration
		_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "切枪时长拒绝无效值")

func _check_switch_controls() -> void:
	for effect in ["none", "stun", "freeze", "stasis", "knockback"]:
		var unit := _spawn("jinx", 0, Vector2(200, 1000))
		var target := _spawn("target_dummy", 1, Vector2(270, 1000))
		unit.toggle_weapon_form()
		var serial := unit.get_visual_action_serial()
		var view := _view_for(unit)
		view._sync_visual(false, 0.0)
		_expect(unit.form_index == 1 and unit.projectile_visual == &"jinx_bullet" and is_equal_approx(unit.form_transition_timer, 0.37), "属性与弹体立即换成新形态，建立0.37秒变形窗口")
		var payload: Array = _main._snapshot_system._unit_snapshot_payload(unit.net_id, unit)
		_expect(payload[NetworkSnapshotSystem.U_ACTION_NAME] == "transform" and (int(payload[NetworkSnapshotSystem.U_ACTION_PERMISSIONS]) & ControlState.BASIC_ATTACK) == 0, "快照同步变形动作和禁攻击权限")
		var owner: Dictionary = _main._audio_manager._event_owner(unit, &"transform:start")
		_expect(owner.kind == "action" and owner.serial == serial, "切枪声音归属可取消的变形动作")
		match effect:
			"stun": unit.stun(0.1)
			"freeze": unit.freeze(0.1)
			"stasis": unit.apply_stasis(0.1)
			"knockback": unit.apply_knockback(unit.position - Vector2(10, 0), 5.0, 0.1)
		view._process(0.0)
		var cancels: bool = effect in ["freeze", "stasis"]
		_expect((unit.cancelled_visual_serial >= serial) == cancels, "冰冻/凝滞取消切枪旧音画，眩晕/击退不取消")
		for tick in 7:
			unit.sim_tick(0.05)
			view._process(0.0)
			view._model_root._process(0.05)
			_expect(unit.is_form_transitioning() and not unit._attacking and (unit.action_permissions() & ControlState.BASIC_ATTACK) == 0, "第%dTick仍受切枪窗口约束：%s" % [tick + 1, effect])
			if cancels: _expect(not view._playing_visual_action, "解控不续播被取消的切枪")
		unit.sim_tick(0.05)
		_expect(not unit.is_form_transitioning() and (unit.action_permissions() & ControlState.BASIC_ATTACK) != 0, "第8Tick结束窗口，硬控不延长转换时间")
		unit.free()
		target.free()

func _check_haste_placement() -> void:
	var effect = load("res://assets/units/jinx/haste_view.tscn").instantiate()
	_main.add_child(effect)
	effect._rng.seed = 17
	effect.status_state = Vector2(6, 1)
	effect.advance_status(true, true, 0.1)
	_expect(not effect._particles.is_empty(), "罪恶快感产生速度线")
	for particle in effect._particles:
		var offset: Vector3 = effect.to_local(particle.node.global_position)
		_expect(absf(offset.x) <= 0.56001 and is_equal_approx(offset.z, -0.112), "速度线从身体略后方出生，保留原版横向分布")
		_expect(offset.y >= 0.56 and offset.y <= 1.68, "速度线覆盖躯干高度")
		_expect((particle.velocity as Vector3).dot(effect.global_basis.z) < 0.0, "速度线向身后运动")
	var first: Dictionary = effect._particles[0]
	var previous: Vector3 = first.node.global_position
	var velocity: Vector3 = first.velocity
	effect.position += Vector3(4, 0, 3)
	effect.rotation.y = PI * 0.5
	effect.advance_status(true, true, 0.05)
	_expect(first.node.global_position.is_equal_approx(previous + velocity * 0.05), "移动转身不拖拽已经发出的世界空间速度线")
	effect._emit_streak()
	var last: Dictionary = effect._particles.back()
	_expect((last.velocity as Vector3).dot(effect.global_basis.z) < 0.0, "转身后新速度线跟随新朝向")
	effect.advance_status(true, false, 0.3)
	_expect(not effect.visible and effect._particles.is_empty(), "凝滞隐藏并清理残留速度线")
	effect.advance_status(true, true, 0.01)
	_expect(effect.visible and not effect._cloud.visible and effect._elapsed > 0.4, "凝滞恢复不重播笑脸或重置特效时间")
	effect.advance_status(false, false, 0.1)
	_expect(effect._particles.is_empty() and not effect.visible, "增益结束立即清理速度线")
	effect.free()
	var unit := _spawn("jinx", 0, Vector2(200, 1000))
	var view := _view_for(unit)
	unit._grant_structure_haste(_main._sim_tick_id)
	view._sync_visual(false, 0.1)
	view._update_active_buff_visual(0.4)
	var original: ActiveBuffVisual3D = view._active_buff_visual
	unit.toggle_weapon_form()
	view._sync_visual(false, 0.0)
	_expect(view._active_buff_visual == original and original._elapsed >= 0.4, "切枪复用罪恶快感特效，位置连续且不重播触发")
	unit.free()

func _check_six_second_haste() -> void:
	var unit := _spawn("jinx", 0, Vector2(200, 1000))
	unit._grant_structure_haste(_main._sim_tick_id)
	_expect(unit.structure_haste_state_visual() == Vector2(6, 1), "首层完整6秒窗口")
	for tick in 60: unit._tick_active_statuses(0.05)
	_expect(is_equal_approx(unit.active_speed_multiplier, 1.5), "6秒线性衰减的中点为50%移速加成")
	unit.attack_timeline.begin_recovery(1.0, 0.2, 1.3)
	var remaining_before := unit.attack_timeline.recovery
	unit._grant_structure_haste(_main._sim_tick_id)
	_expect(unit.structure_haste_state_visual() == Vector2(6, 2), "未结束时再次触发加层并将全部层刷新6秒")
	_expect(is_equal_approx(unit.active_speed_multiplier, 2.0) and is_equal_approx(unit.active_attack_speed_multiplier, 1.6), "移速只重置为100%加成，2层攻速为60%")
	_expect(is_equal_approx(unit.attack_timeline.recovery * 1.6, remaining_before * 1.3), "叠层攻速保留攻击周期归一化进度")
	for tick in 40: unit._tick_active_statuses(0.05)
	unit._grant_structure_haste(_main._sim_tick_id)
	_expect(unit.structure_haste_state_visual() == Vector2(6, 3) and is_equal_approx(unit.active_attack_speed_multiplier, 1.9), "连续触发可达到3层90%，不是最多2层")
	unit.toggle_weapon_form()
	_expect(unit.structure_haste_state_visual() == Vector2(6, 3), "换枪继承所有被动层及新窗口")
	unit.apply_stasis(0.2)
	unit._grant_structure_haste(_main._sim_tick_id)
	_expect(unit.structure_haste_state_visual() == Vector2(6, 3) and unit.active_attack_speed_multiplier == 1.0, "凝滞拒绝新增层且只抑制属性，保留已有层")
	var payload: Array = _main._snapshot_system._unit_snapshot_payload(unit.net_id, unit)
	_expect(payload[NetworkSnapshotSystem.U_STRUCTURE_HASTE_STATE] == Vector2(6, 3), "凝滞快照保留层数及倒计时")
	for tick in 119: unit._tick_active_statuses(0.05)
	_expect(unit.buffs.stack_count(&"structure_haste") == 3 and is_equal_approx(unit.buffs.remaining(&"structure_haste"), 0.05), "刷新后的第119Tick仍保留全部3层")
	unit._tick_active_statuses(0.05)
	_expect(unit.structure_haste_state_visual() == Vector2.ZERO and unit.active_attack_speed_multiplier == 1.0, "第120Tick全部层数与加速一同到期")
	unit._grant_structure_haste(_main._sim_tick_id)
	_expect(unit.structure_haste_state_visual() == Vector2(6, 1), "到期后再次触发从1层开始")
	unit.buffs.clear_family(&"structure_haste")
	var a := _spawn("target_dummy", 1, Vector2(250, 1000))
	var b := _spawn("target_dummy", 1, Vector2(270, 1000))
	unit.record_structure_attack(a)
	unit.record_structure_attack(b)
	var resolver: CombatResolver = _main.combat_service()
	resolver.begin_batch(_main._sim_tick_id, &"jinx_double_structure")
	resolver.resolve_attack_hit(0, unit.position, a, 999999, 45.0, 0.0, unit, unit.position)
	resolver.commit_batch()
	_expect(unit.structure_haste_state_visual() == Vector2(6, 2), "同一批次两座建筑真实死亡叠为2层")
	for body in [a, b, unit]:
		if is_instance_valid(body): body.free()
	var effect = preload("res://scripts/presentation/jinx_projectile_effect.gd")
	for progress in [0.0, 0.1, 0.25, 0.5, 0.75, 1.0]:
		for smoke in [false, true]:
			var radius: float = effect.blast_radius(45.0, progress, smoke)
			_expect(radius > 0.0 and radius <= 45.0, "爆炸各阶段外沿不超过45像素伤害半径")
	_expect(is_equal_approx(effect.blast_radius(45.0, 0.25, false), 45.0), "主要火焰在前四分之一阶段展开到完整伤害半径")

func _check_moving_switch() -> void:
	var unit := _spawn("jinx", 0, Vector2(200, 1000))
	var view := _view_for(unit)
	for form in 2:
		unit.toggle_weapon_form()
		unit._move_intent = Vector2.UP
		view._sync_visual(false, 0.0)
		var model = view._model_root
		_expect(model._leg_tracks.size() > 10, "下肢遮罩包含骨盆与双腿轨道")
		model._process(0.05)
		var phase: float = model._leg_phase
		var knee: int = model._skeleton.find_bone("L_Hip")
		var pose: Quaternion = model._skeleton.get_bone_pose_rotation(knee)
		model._process(0.05)
		_expect(model._leg_phase != phase and not model._skeleton.get_bone_pose_rotation(knee).is_equal_approx(pose), "两种方向切枪期间腿部持续迈步")
		unit.freeze(0.1)
		phase = model._leg_phase
		model._process(0.05)
		_expect(model._leg_phase == phase, "冰冻不继续推进下肢叠层")
		unit.control.hard.clear_family(&"freeze")
		unit.prepare_action_clocks(0.4)
	unit.free()

func _check_gait_continuity() -> void:
	var unit := _spawn("jinx", 0, Vector2(200, 1000))
	var view := _view_for(unit)
	for form in 2:
		unit.toggle_weapon_form()
		unit._move_intent = Vector2.UP
		view._sync_visual(false, 0.0)
		var model = view._model_root
		_expect(model._leg_tracks.all(func(pair): return not "Minigun" in String(model._skeleton.get_bone_name(pair.y)) and String(model._skeleton.get_bone_name(pair.y)) != "Pistol"), "下肢遮罩不包含挂在骨盆上的武器")
		model._leg_phase = 0.43
		model._update_lower_body(0.0, true, 0.0)
		var hip: int = model._skeleton.find_bone("L_Hip")
		var route: NodePath = model._run_clip.track_get_path(model._leg_tracks.filter(func(pair): return pair.y == hip and model._run_clip.track_get_type(pair.x) == Animation.TYPE_ROTATION_3D)[0].x)
		var track: int = model._run_from.find_track(route, Animation.TYPE_ROTATION_3D)
		_expect(model._skeleton.get_bone_pose_rotation(hip).is_equal_approx(model._run_from.rotation_track_interpolate(track, 0.43 * model._run_from.length)), "切枪起点保持旧形态同相位腿姿")
		model._update_lower_body(0.0, true, 0.5)
		_expect(is_equal_approx(model._leg_blend, 0.5), "切枪中途两跑姿等权混合")
		unit.prepare_action_clocks(0.4)
		view._finish_visual_action()
		model._process(0.0)
		_expect(is_equal_approx(view._animation_player.current_animation_position / model._run_clip.length, 0.43), "切枪结束基础播放器承接共享相位，不从0重播")
		model._process(0.05)
		_expect(model._leg_phase > 0.43, "接回正常跑步仍推进共享时钟")
	unit.free()
