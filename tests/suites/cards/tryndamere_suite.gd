extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_attack_tail()
	_check_continuous_cadence()
	_check_held_poses_and_r()
	var king := _spawn(0, Vector2(200, 900))
	var target := _spawn(1, Vector2(270, 900))
	target.hp = 10000.0
	var skill: Dictionary = CardDB.active_skills_for("tryndamere")[0]
	_expect(king.skill_resource_enabled and king.skill_resource_max == 2.0, "未带主动槽也拥有两点被动怒气")
	for expected in [180.0, 180.0, 360.0, 180.0]:
		var before := target.hp
		strike(king, target)
		_expect(before - target.hp == expected, "普通、普通、暴击循环伤害 %s" % expected)
	_expect(king.skill_resource_value == 1.0, "暴击不产怒，下一次普通攻击回到1点")
	king.clear_carried_active_skill_resource()
	_expect(king.skill_resource_value == 1.0 and king.skill_resource_enabled, "主动槽替换不清除被动怒气")
	strike(king, target)
	king._attack_visual_pending = true
	king._try_start_attack_visual(0.0)
	var cancelled := king.get_attack_visual_serial()
	king.cancel_basic_attack(&"stun")
	_expect(king.skill_resource_value == 2.0, "前摇取消不消费怒气")
	strike(king, target)
	_expect(posmod(king.get_attack_visual_serial() - 1, 3) == 2 and king.get_attack_visual_serial() > cancelled, "重起仍用暴击动画且动作身份递增")
	king.freeze(2.0)
	_expect(king.can_start_active_skill(skill), "冰冻不阻止拒绝死亡")
	_expect(main.preview_active_skill(king, skill), "工作台走正式生命周期可在冰冻中施放")
	_expect(king.is_frozen() and king.skill_resource_value == 2.0 and king.buffs.remaining(&"undying") == 4.0, "技能不解控，立即满怒与保命")
	_expect(Unit.valid_action_cancellation(king.last_action_cancellation), "满怒刷新使用可同步的动作取消合同")
	var snap: Array = main._snapshot_system._unit_snapshot_payload(4242, king)
	_expect(snap[NetworkSnapshotSystem.U_SKILL_RESOURCE_RATIO] == 1.0 and snap[NetworkSnapshotSystem.U_SKILL_RESOURCE_ENABLED], "快照同步满怒与被动资源可见性")
	_expect(snap[NetworkSnapshotSystem.U_ACTIVE_BUFF_ACTIVE] and snap[NetworkSnapshotSystem.U_FROZEN], "快照同时表达保命表现与冻结，不伪造解控")
	king.hp = 10.0
	var resolver: CombatResolver = king.battle_context.damage_batch()
	resolver.begin_batch(0, "tryndamere")
	king.take_damage(999.0, target)
	king.take_damage(999.0, target)
	resolver.commit_batch()
	_expect(king.hp == 1.0, "同批多刀伤害最低为1且不会排队死亡")
	king.control.hard.clear_family(&"freeze")
	for index in 3:
		var before := target.hp
		strike(king, target)
		_expect(before - target.hp == 360.0 and king.skill_resource_value == 2.0, "大招每刀暴击且不耗怒 %d" % index)
	king.buffs.advance(3.95)
	king.take_damage(999.0, target)
	_expect(king.hp == 1.0, "第79 Tick仍保命")
	king.buffs.advance(0.05)
	_expect(king.buffs.remaining(&"undying") == 0.0, "第80 Tick精确到期")
	strike(king, target)
	_expect(king.skill_resource_value == 0.0, "到期后的满怒暴击重新消费怒气")
	king.take_damage(999.0, target)
	_expect(king.hp <= 0.0, "到期后可正常死亡")
	var controlled := _spawn(0, Vector2(400, 900))
	controlled.stun(2.0)
	_expect(controlled.can_start_active_skill(skill), "眩晕允许释放")
	controlled._knockback_timer = 1.0
	_expect(controlled.can_start_active_skill(skill), "击退允许释放")
	controlled.apply_stasis(2.0)
	_expect(not controlled.can_start_active_skill(skill) and not main.preview_active_skill(controlled, skill), "凝滞禁止技能且不建立保命")
	var old_deck: Array = main._deck.duplicate()
	main._deck[0] = "tryndamere"
	var paid: Unit = main._spawn_card_units(0, "tryndamere", Vector2(500, 1050), 0.0, 0)[0]
	paid.freeze(3.0)
	main._elixir.elixir = 8.0
	_expect(main.use_active_skill(paid.active_ability_id, 0) and main._elixir.elixir == 5.0, "正式请求扣3费，受控可提交")
	main._sim_tick_id += 10
	main._tick_pending_active_skills(0.05)
	_expect(paid.buffs.remaining(&"undying") > 0.0 and paid.is_frozen(), "命令缓冲后受控仍可生效")
	var entry: Dictionary = main._active_skills.entry(paid.active_ability_id)
	_expect(entry.uses_remaining == 0 and entry.cooldown_left == 15.0 and not main.use_active_skill(paid.active_ability_id, 0), "一次使用并启动15秒冷却")
	var rejected: Unit = main._spawn_card_units(0, "tryndamere", Vector2(550, 1000), 0.0, 0)[0]
	main._elixir.elixir = 8.0
	_expect(main.use_active_skill(rejected.active_ability_id, 0), "凝滞前成功提交技能")
	rejected.apply_stasis(2.0)
	main._sim_tick_id += 10
	main._tick_pending_active_skills(0.05)
	_expect(main._elixir.elixir == 8.0 and main._active_skills.entry(rejected.active_ability_id).uses_remaining == 1 and rejected.buffs.remaining(&"undying") == 0.0, "等待期间进入凝滞则一次退款、保留次数且不施加保护")
	var blind := _spawn(0, Vector2(200, 900))
	blind.skill_resource_value = 2.0
	blind.apply_blind(1)
	var before_blind := target.hp
	strike(blind, target)
	_expect(target.hp == before_blind and blind.skill_resource_value == 0.0, "致盲暴击落空但正式出手耗怒")
	blind.skill_resource_value = 2.0
	blind.begin_undying_rage(4.0)
	blind.apply_stasis(2.0)
	blind.buffs.advance(4.0)
	_expect(blind.buffs.remaining(&"undying") == 0.0, "凝滞不延长保命窗口")
	main._deck = old_deck
	for bad in ["wrong", -1.0, 1.0, INF]:
		var cards := CardDB.all().duplicate(true)
		cards.tryndamere.rage_crit_multiplier = bad
		_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "拒绝非法暴击倍率 %s" % str(bad))
	var cards := CardDB.all().duplicate(true)
	cards.tryndamere.active_skills[0].duration = 0.0
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "拒绝无持续时间的拒绝死亡")

func _spawn(team: int, pos: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, "tryndamere", pos, {"deploy_time_override": 0.0}))

func strike(unit: Unit, target: Unit) -> void:
	unit._target = target
	unit.attack_timeline.cancel(true)
	unit._attack_visual_pending = true
	unit._attack(0.0)

func _check_attack_tail() -> void:
	var unit := _spawn(0, Vector2(180, 1100))
	var foe := _spawn(1, Vector2(235, 1100))
	unit._target = foe
	unit._attacking = true
	unit._attack_hit_index = 1
	unit.attack_timeline.recovery = 0.5
	unit.attack_timeline.cooldown = 1.0
	foe.hp = 0.0
	unit.sim_tick(0.05)
	_expect(unit.attack_timeline.recovery > 0.0, "无目标仍必须完成原攻击动画后摇")
	unit.attack_timeline.recovery = 0.2
	unit.sim_tick(0.05)
	_expect(unit.attack_timeline.recovery == 0.0 and not unit._attacking, "无目标可以跳过末尾0.23秒待机")
	foe.hp = 1000.0
	unit._target = foe
	unit._attacking = true
	unit.attack_timeline.recovery = 0.2
	unit.attack_timeline.cooldown = 0.8
	unit.sim_tick(0.05)
	_expect(unit.attack_timeline.recovery > 0.0, "圈内有下个目标时保留待机和1.7秒攻击周期")
	foe.hp = 0.0
	unit.apply_active_buff(10.0, 1.0, 1.0, 2.0)
	unit.attack_timeline.recovery = 0.15
	unit.sim_tick(0.01)
	_expect(unit.attack_timeline.recovery > 0.0, "加速后取消窗口同比缩短，不截断原动作")
	unit.attack_timeline.recovery = 0.1
	unit.sim_tick(0.01)
	_expect(unit.attack_timeline.recovery == 0.0, "加速后的尾段允许离开")
	unit.free()
	foe.free()
	for bad in [0.0, -0.1, 1.0, "invalid", INF]:
		var cards := CardDB.all().duplicate(true)
		cards.tryndamere.attack_recovery_cancel_window = bad
		_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "拒绝无效末尾待机取消窗口 %s" % str(bad))
	var model: Node = load("res://assets/units/tryndamere/tryndamere_view.tscn").instantiate()
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	for clip in ["HeldAttack1", "HeldAttack2", "HeldCrit"]:
		_expect(is_equal_approx(player.get_animation(clip).length, 1.7), "分段攻击完整周期为1.7秒 " + clip)
	_expect(is_equal_approx(player.get_animation("DeployIdle").length, 1.0), "部署使用Idle最后1秒的独立片段")
	model.free()

func _check_continuous_cadence() -> void:
	var unit := _spawn(0, Vector2(180, 1100))
	var foe := _spawn(1, Vector2(235, 1100))
	foe.hp = 10000.0
	var hits: Array[int] = []
	for tick in 110:
		var before := foe.hp
		unit.sim_tick(0.05)
		if foe.hp < before: hits.append(tick)
	_expect(hits.size() >= 3, "连续攻击夹具产生普通、普通、暴击")
	if hits.size() >= 3:
		_expect(hits[0] >= 15 and hits[0] <= 16, "首次命中保留0.4秒待机加原动作前摇")
		_expect(hits[1] - hits[0] == 34 and hits[2] - hits[1] == 34, "普通与暴击均保持34 Tick即1.7秒命中间隔")
	unit.free()
	foe.free()

func _check_held_poses_and_r() -> void:
	var model: Node = load("res://assets/units/tryndamere/tryndamere_view.tscn").instantiate()
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	for clip in ["Attack1", "Attack2", "Crit"]:
		var native: Animation = player.get_animation(clip)
		var cycle: Animation = player.get_animation("Held" + clip)
		for time in [0.0, 0.2, 0.4]:
			_expect(_matching_pose(native, 0.0, cycle, time), "%s前0.4秒保持自身起始姿势 %s" % [clip, time])
		for time in [1.47, 1.6, 1.7]:
			_expect(_matching_pose(native, native.length, cycle, time), "%s后0.23秒保持自身结束姿势 %s" % [clip, time])
	model.free()
	var effect = load("res://assets/effects/tryndamere/undying_rage.tscn").instantiate()
	_main.add_child(effect)
	effect.configure(25.0)
	var overlay: Material = effect.make_overlay(null)
	_expect(overlay != null and effect._layers.size() == 5, "大招使用五个独立身体附着层")
	effect.advance(true, 0.1)
	for definition in effect._definitions:
		_expect(definition.name in ["WindTunnel", "Temp_Mesh", "Temp_Mesh1", "sparks", "CAS_Flames", "FlameBits_Alpha1"] and not definition.get("ground", false), "大招保留身体火焰与外围旋风，不包含地面阴影或冲击")
	var mirrored := false
	for particle in effect._player._particles:
		if particle.c.name == "Temp_Mesh": mirrored = particle.node.global_basis.determinant() < 0.0
	_expect(mirrored, "火焰网格保留负缩放的镜像方向")
	effect.advance(true, 0.5)
	for layer in effect._layers:
		if layer.definition.name == "Start":
			_expect(layer.material.get_shader_parameter("strength") == 0.0, "起始闪光0.44秒后关闭，不当成持续层")
		if layer.definition.name == "Fresnel1":
			_expect(layer.material.get_shader_parameter("strength") > 0.0, "持续附着层仍然保留")
	effect.advance(true, 3.25)
	for layer in effect._layers:
		if layer.definition.name == "End":
			_expect(layer.material.get_shader_parameter("strength") > 0.0, "结束闪光适配4秒技能末尾")
	effect.advance(false, 0.31)
	_expect(not effect.visible and not is_instance_valid(effect._player), "增益结束清除粒子，不残留附着对象")
	effect.free()

func _matching_pose(a: Animation, at: float, b: Animation, bt: float) -> bool:
	for track in a.get_track_count():
		var other := b.find_track(a.track_get_path(track), a.track_get_type(track))
		if other < 0: return false
		match a.track_get_type(track):
			Animation.TYPE_POSITION_3D:
				if not a.position_track_interpolate(track, at).is_equal_approx(b.position_track_interpolate(other, bt)):
					print("POSE_DIFF position ", a.track_get_path(track), " ", at, " -> ", bt, " ", a.position_track_interpolate(track, at), " ", b.position_track_interpolate(other, bt))
					return false
			Animation.TYPE_ROTATION_3D:
				if absf(a.rotation_track_interpolate(track, at).dot(b.rotation_track_interpolate(other, bt))) < 0.99999:
					print("POSE_DIFF rotation ", a.track_get_path(track), " ", at, " -> ", bt)
					return false
			Animation.TYPE_SCALE_3D:
				if not a.scale_track_interpolate(track, at).is_equal_approx(b.scale_track_interpolate(other, bt)): return false
	return true
