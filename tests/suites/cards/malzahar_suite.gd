extends "res://tests/suites/battle_suite.gd"
func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_test_w_composition()
	var cues: Array = []
	var source := _spawn("malzahar", 0, Vector2(360, 1000))
	source.presentation_cue.connect(func(cue): cues.append(cue))
	source._deploy_timer = 0.05
	source.sim_tick(0.05)
	for i in 39: source.sim_tick(0.05)
	_expect(_children().is_empty(), "首次2秒前不生成虚灵")
	source.sim_tick(0.05)
	_expect(_children().is_empty() and not source.summon_sequences.is_empty(), "2秒先开裂隙，无隐藏或可碰撞虚灵实体")
	for i in 4: source.sim_tick(0.05)
	_expect(_children().is_empty(), "开门0.2秒不提前生成")
	source.sim_tick(0.05)
	_expect(_children().size() == 1, "开门0.25秒首只实际生成")
	var anchor: Vector2 = source.summon_sequences[0].origin
	source.global_position += Vector2(80,0)
	for i in 10: source.sim_tick(0.05)
	_expect(_children().size() == 2, "原版SummonDelay 0.5秒第二只")
	for i in 10: source.sim_tick(0.05)
	_expect(_children().size() == 3, "开门1.25秒第三只")
	_expect(main._skill_presentation.frontal_effects.filter(func(e): return e.shape == &"voidling_portal").size() == 1, "三只虚灵共用一个裂隙")
	_expect(cues.count(&"summon:start") == 1, "一批仅派发一次W音效")
	_expect(_children().all(func(u): return u.summon_visual_origin == anchor and u.visual_spawn_transition == &"void_portal" and u.is_deployed()), "先知移动后整批仍从固定裂隙出场且不增加部署锁")
	for i in 139: source.sim_tick(0.05)
	_expect(_children().size() == 3, "8秒前无下一批")
	source.sim_tick(0.05)
	_expect(_children().size() == 4, "下一批开门0.25秒后生成首只")
	var target := _spawn("garen", 1, Vector2(360, 900))
	var skill: Dictionary = CardDB.get_card("malzahar").active_skills[0]
	var effects = main._active_skill_effect_system
	effects.apply(source, skill)
	_expect(not source.channel_attack.prepared.is_empty() and not source.channel_attack.active(), "按钮只准备下一击")
	source.channel_attack.begin(source, target)
	_expect(target.is_stunned() and source.channel_attack.active(), "引导眩晕立即生效")
	_expect(source.is_active_skill_attack_locked() and source.is_active_skill_movement_locked(), "引导锁攻击与移动")
	target.stun(4.0, &"other")
	source.stun(0.5)
	_expect(not source.channel_attack.active(), "施法者眩晕立即打断")
	_expect(target.control.hard.remaining(&"stun") == 4.0, "解除引导保留其他来源眩晕")
	_expect(effects.continuous_area_effects.size() == 1, "打断后区域独立存在")
	var before: float = target.hp
	effects.tick_effects(0.5)
	_expect(target.hp == before - 30.0, "区域每0.5秒结算30伤害")
	source.free()
	effects.tick_effects(0.5)
	_expect(target.hp == before - 60.0, "来源释放后区域继续伤害")
	for i in 8: effects.tick_effects(0.5)
	_expect(effects.continuous_area_effects.is_empty(), "区域满5秒精确结束")
	for reason in ["freeze", "stasis", "knockback", "forced", "silence", "taunt", "death"]:
		var caster := _spawn("malzahar", 0, Vector2(220, 1000))
		var victim := _spawn("garen", 1, Vector2(250, 920))
		caster.channel_attack.prepared = skill
		caster.channel_attack.begin(caster, victim)
		match reason:
			"freeze": caster.freeze(1.0)
			"stasis": caster.apply_stasis(1.0)
			"knockback": caster.apply_knockback(Vector2(200,1000), 40.0)
			"forced": caster.apply_forced_displacement(Vector2.RIGHT, 40.0, 0.2)
			"silence": caster.silence(1.0)
			"taunt": caster.taunt(victim, 1.0)
			"death": caster.take_damage(9999.0)
		_expect(not caster.channel_attack.active() and not victim.is_stunned(), reason + "立即打断并移除本来源眩晕")
		caster.free()
		victim.free()
		effects.clear()
	var blinded := _spawn("malzahar", 0, Vector2(220, 1000))
	var dummy := _spawn("target_dummy", 1, Vector2(250, 920))
	blinded.channel_attack.prepared = skill
	blinded.apply_blind(2)
	blinded._target = dummy
	blinded.attack_timeline.windup = 0.0
	blinded.attack_timeline.cooldown = 0.0
	blinded._attack(0.05)
	_expect(blinded.channel_attack.active() and dummy.is_stunned(), "正式下一击入口不受致盲影响")
	_expect(blinded.blind_attack_charges == 2, "技能命中不消耗普攻致盲次数")
	for i in 49: blinded.channel_attack.tick(blinded, 0.05)
	_expect(blinded.channel_attack.active(), "引导2.45秒仍持续")
	blinded.channel_attack.tick(blinded, 0.05)
	_expect(not blinded.channel_attack.active() and not dummy.is_stunned(), "引导2.5秒解除眩晕")
	var cards := CardDB.all().duplicate(true)
	cards.malzahar.spawn_initial_delay = -1.0
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "拒绝负首次召唤延时")
	cards = CardDB.all().duplicate(true)
	cards.malzahar.spawn_sequence_interval = "bad"
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "拒绝非数值逐只间隔")
	var batch_source := _spawn("malzahar", 0, Vector2(220,1000))
	var batch_target := _spawn("garen", 1, Vector2(250,920))
	batch_source.channel_attack.prepared = skill
	main._combat.begin_batch(99, "channel_cancel")
	batch_source.channel_attack.begin(batch_source, batch_target)
	batch_source.channel_attack.stop(batch_source)
	main._combat.commit_batch()
	_expect(not batch_target.is_stunned(), "同批已取消引导不延后补眩晕")
	var before_views: int = main._skill_presentation.frontal_effects.size()
	var payload := {"pos":Vector2(360,900), "dir":Vector2.UP, "length":90.0, "width":90.0, "duration":5.0, "team":0, "shape":"nether_zone"}
	main._skill_presentation.show_skill_effect(90909, payload)
	main._skill_presentation.show_skill_effect(90909, payload)
	_expect(main._skill_presentation.frontal_effects.size() == before_views + 1, "网络区域表现事件去重")
	cards = CardDB.all().duplicate(true)
	cards.malzahar.spawn_sequence_interval = 4.0
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "拒绝跨周期重叠的逐只召唤")
	var freed_source := _spawn("malzahar", 0, Vector2(220,1000))
	var freed_target := _spawn("pix", 1, Vector2(250,920))
	freed_source.channel_attack.prepared = skill
	freed_source.channel_attack.begin(freed_source, freed_target)
	freed_target.free()
	_expect(not freed_source.has_continuous_visual_target(), "目标释放后光束立即不再可见")
	_expect(freed_source.get_continuous_visual_target_air_id() == -1, "目标释放后不读取空军ID")
	_expect(freed_source.get_continuous_visual_target_position().is_finite(), "目标释放后端点安全回退")
	freed_source.channel_attack.tick(freed_source, 0.05)
	_expect(not freed_source.channel_attack.active(), "目标释放后下一权威Tick解除自身锁")
	var replica_source := _spawn("malzahar", 0, Vector2(220,1000))
	var replica_target := _spawn("garen", 1, Vector2(250,920))
	replica_source.channel_attack.prepared = skill
	replica_source.channel_attack.begin(replica_source, replica_target)
	var snapshot: Array = main._snapshot_system._unit_snapshot_payload(999998, replica_source, true, replica_target.position)
	var saved_mode: String = main.mode
	main._client_units[999998] = replica_source
	main.mode = "client"
	main._snapshot_system._apply_units([snapshot])
	_expect(replica_source.net_has_continuous_target and replica_source.get_visual_action_name() == &"channel", "旧普攻取消记录不清除新技能引导端点")
	main.mode = saved_mode
	main._client_units.erase(999998)
	_expect(not CardDB.selectable_ids().has("voidling"), "虚灵不加入正式卡组池")

	_check_w()

func _children() -> Array:
	return _main.get_tree().get_nodes_in_group("combatants").filter(func(u): return is_instance_valid(u) and u is Unit and u.card_id == "voidling")

func _spawn(id: String, team: int, pos: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, id, pos, {"deploy_time_override": 0.0}))

func _check_w() -> void:
	for actor in _main.get_tree().get_nodes_in_group("combatants"):
		if is_instance_valid(actor) and actor is Unit: actor.free()
	_main._commands.clear()
	_main._active_skill_effect_system.clear()
	_main._active_skills.clear()
	_main._ai.enabled = false
	_main._minion_waves_enabled = false
	var skill: Dictionary = CardDB.active_skills_for("malzahar")[1]
	var caster := _spawn("malzahar", 0, Vector2(300,1000))
	caster.spawn_interval = 0.0
	caster.active_ability_id = 90221
	caster.active_ability_slot = 0
	caster.configure_carried_active_skill(skill)
	_main._active_skills.register(caster, "malzahar", 0, skill)
	var payer = _main._elixir_for_team(0)
	payer.elixir = 10.0
	_expect(_main.use_active_skill(90221,0) and payer.elixir == 9.0, "W真实请求扣1金币")
	for i in 12:
		if caster.active_skill_cast_timer > 0.0: break
		_run_main_ticks(1)
	_expect(caster.is_active_skill_attack_locked() and caster.get_visual_action_name() == &"void_swarm", "W施法动作开启普攻锁")
	_expect(_children().is_empty(), "W抬手不提前产生虚灵")
	_expect(not _main.use_active_skill(90221,0), "W冷却期间拒绝重复付款")
	for i in 13:
		if not _children().is_empty(): break
		_run_main_ticks(1)
	_expect(is_equal_approx(caster.active_skill_cast_timer, 0.5) and _children().size()==1, "W读条0.25秒开门，动作0.5秒时首只生成")
	caster._spawn_batch()
	_run_main_ticks(27)
	_expect(_children().size()==6 and caster.summon_sequences.is_empty(), "主动与被动重叠仍完整产出两批共6只")
	_expect(not caster.is_active_skill_attack_locked(), "W动作结束解除普攻锁")
	_expect(int(_main._active_skills.entry(90221).uses_remaining)==2, "W首发只消耗一次资格")
	for use in 2:
		_main._active_skills.tick(6.0)
		_expect(_main.use_active_skill(90221,0), "W六秒后可再次请求")
		_run_main_ticks(40)
	_expect(int(_main._active_skills.entry(90221).uses_remaining)==0 and not _main.use_active_skill(90221,0), "W三次耗尽拒绝第四次")
	var cancelled := _spawn("malzahar",0,Vector2(400,1000))
	cancelled.spawn_interval = 0.0
	var before := _children().size()
	_main._skill_lifecycle.start(cancelled,skill)
	cancelled.freeze(1.0)
	_run_main_ticks(8)
	_expect(cancelled.summon_sequences.is_empty() and _children().filter(func(u): return u.summon_visual_origin == Vector2(400,1000)).is_empty(), "W释放前被冻结不补出虚灵")
	var cards := CardDB.all().duplicate(true)
	cards.malzahar.active_skills[1].spawn_sequence_interval = 0.0
	_expect(not CardDB.VALIDATOR.validate_all(cards,false).is_empty(), "W拒绝零逐只间隔")

	var dying := _spawn("malzahar",0,Vector2(450,1000))
	dying.spawn_interval=0.0
	before=_children().size()
	_main._skill_lifecycle.start(dying,skill)
	_run_main_ticks(11)
	_expect(_children().size()==before+1, "W释放节点只产生首只")
	dying.take_damage(99999.0)
	_run_main_ticks(25)
	_expect(_children().size()==before+1, "先知死亡取消W尚未生成的两只")

func _test_w_composition() -> void:
	var presentation = load("res://scripts/presentation/skill_effect_presentation.gd").new(_main)
	var view = load("res://scripts/presentation/malzahar_effect_3d.gd").new()
	_main.add_child(view)
	var camera: Camera3D = _main._battle_presentation._camera
	for team in 2:
		presentation.add_fixed_area_effect(Vector2(300, 850 if team == 0 else 430), 28.0, 28.0, 3.0, team, &"voidling_portal")
	presentation.add_fixed_area_effect(Vector2(300,850), 22.0, 22.0, 1.5, 0, &"voidling_birth")
	view.sync_effects(presentation, camera)
	_expect(view.views.size() == 5, "双阵营裂隙各含独立施法层，出生层独立")
	var opening = view.views["area_1"]
	var birth = view.views["area_3"]
	_expect(is_equal_approx(birth._age, 0.25), "出生事件从源首次发射节点继续，闪光不落后模型0.25秒")
	_expect(opening.scale.is_equal_approx(birth.scale), "裂隙与出生闪光使用相同原版单位比例")
	_expect(opening.projection_basis.is_equal_approx(Basis.IDENTITY), "立体裂隙不按范围圆拉伸")
	_expect(is_equal_approx(view.views["area_1_cast"]._age, 0.25), "释放时恢复施法时钟，不重复等待源0.25秒")
	for effect in presentation.frontal_effects:
		effect.timer = effect.duration - 1.49
	view.sync_effects(presentation, camera)
	_expect(not view.views.has("area_1_end"), "第三只生成后继续保持裂隙至1.5秒")
	var core_index := -1
	for i in opening._data.emitters.size():
		if opening._data.emitters[i].name == "Temp_Mesh": core_index = i
	_expect(core_index >= 0 and not opening._data.frames[178][core_index].is_empty(), "采样中裂隙主体实际保持至1.49秒，拒绝旧导出数据")
	for effect in presentation.frontal_effects:
		effect.timer = effect.duration - 1.55
	view.sync_effects(presentation, camera)
	var closing = view.views["area_1_end"]
	_expect(closing.transform.is_equal_approx(opening.transform) and closing.projection_basis.is_equal_approx(opening.projection_basis), "第三只出生后关门沿用开门位置尺寸及空间方向")
	_expect(is_equal_approx(closing._age, 0.05), "关门时钟从开门1.5秒推进")
	presentation.frontal_effects.clear()
	view.sync_effects(presentation, camera)
	_expect(view.views.is_empty(), "批次到期清理开门关门施法及出生层")
	view.free()
