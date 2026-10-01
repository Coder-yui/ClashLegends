extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_idle_consumers()
	_check_events()
	_check_action_audio()
	_check_growth_knockback()
	_check_displacement()

func _make(card: String, team: int = 0, point: Vector2 = Vector2(300,1000)) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, card, point, {"deploy_time_override": 0.0}))

func _age(unit: Unit, ticks: int) -> void:
	for i in ticks:
		unit._tick_active_statuses(0.05)
		unit.prepare_action_clocks(0.05)

func _check_idle_consumers() -> void:
	var sett := _make("sett")
	sett.configure_carried_active_skill(CardDB.active_skills_for("sett")[0])
	sett.skill_resource_value = 200
	sett._attacking = true
	_age(sett, 30)
	_expect(sett.skill_resource_value == 200 and sett.combat_idle_seconds == 0, "正在攻击持续阻止豪意衰减")
	sett.apply_stasis(2)
	_age(sett, 40)
	_expect(not sett._attacking and sett.skill_resource_value == 200 and sett.combat_idle_seconds == 0, "友方凝滞虽取消攻击仍是硬控，豪意不衰减")
	_age(sett, 20)
	_expect(is_equal_approx(sett.skill_resource_value,200), "最终硬控结束后完整1秒等待")
	_age(sett, 10)
	_expect(is_equal_approx(sett.skill_resource_value,150), "单份空闲时长超过1秒后按100每秒衰减")
	sett.skill_resource_value = 200
	sett.apply_slow(2,0.5)
	_age(sett,40)
	_expect(sett.skill_resource_value == 200, "有效减速期间瑟提豪意保持")
	sett.apply_attack_speed_slow(2,0.5)
	_age(sett,40)
	_expect(sett.skill_resource_value == 200, "有效减攻速期间瑟提豪意保持")
	sett.apply_blind(1)
	_age(sett,40)
	_expect(sett.skill_resource_value == 200, "致盲未消费时瑟提豪意保持")
	sett.blind_attack_charges = 0
	var bleeder := _make("darius",1)
	sett.bleeding.apply(sett,bleeder,{"bleed_max_stacks":5,"bleed_duration":2,"bleed_damage_per_second":0.1},false)
	_age(sett,40)
	_expect(sett.skill_resource_value == 200, "流血未结算整数伤害期间豪意仍保持")
	sett.bleeding.clear()
	_age(sett,30)
	_expect(is_equal_approx(sett.skill_resource_value,150), "减益全消失后空闲1秒再衰减")
	bleeder.free()
	sett.free()
	for kind in ["slow", "attack_slow", "blind", "bleed", "knockback"]:
		var rat := _make("twitch")
		var enemy := _make("darius",1,Vector2(600,1000))
		rat.record_combat_activity(true)
		match kind:
			"slow": rat.apply_slow(3,0.5)
			"attack_slow": rat.apply_attack_speed_slow(3,0.5)
			"blind": rat.apply_blind(1)
			"bleed": rat.bleeding.apply(rat,enemy,{"bleed_max_stacks":5,"bleed_duration":3,"bleed_damage_per_second":0.1},false)
			"knockback": rat.apply_knockback(Vector2(200,1000),20,3)
		_age(rat,40)
		_expect(not rat.stealth_hidden() and rat.combat_idle_seconds == 0, "%s有效期间包括零伤害间隔都不脱战" % kind)
		rat.control.modifiers.clear_family(&"slow")
		rat.control.modifiers.clear_family(&"attack_slow")
		rat.blind_attack_charges = 0
		rat.bleeding.clear()
		rat.knockback.cancel(&"test")
		_age(rat,39)
		_expect(not rat.stealth_hidden(), "%s结束后未满2秒不入隐" % kind)
		_age(rat,1)
		_expect(rat.stealth_hidden(), "%s结束后2秒入隐，无额外消费计时" % kind)
		rat.free()
		enemy.free()
	var rat := _make("twitch")
	rat.record_combat_activity(true)
	rat.apply_active_buff(10,1.2,1.2,1.2)
	rat.add_shield(100,10)
	rat.heal(10)
	rat.apply_slow(10,1.0)
	for i in 40:
		rat.position.x += 1
		_age(rat,1)
	_expect(rat.stealth_hidden(), "友方增益护盾治疗、无效减速及走路不阻止脱战")
	rat.stun(1)
	_age(rat,20)
	_expect(rat.stealth_hidden(), "共享战斗事实不打破已有隐身")
	rat.free()
	var building := _make("apex_turret")
	var before := building.hp
	for i in 40:
		building._tick_building_lifetime(0.05)
		_age(building,1)
	_expect(building.hp < before and is_equal_approx(building.combat_idle_seconds,2), "建筑自然寿命掉血不是战斗伤害")
	building.free()

func _check_events() -> void:
	var target := _make("sett")
	var attacker := _make("twitch",1,Vector2(600,1000))
	target.add_shield(100,5)
	_age(target,50)
	_age(attacker,50)
	var hp := target.hp
	_main._combat.begin_batch(1,"combat_fact")
	var result: Dictionary = _main._combat.submit_damage(target,10,attacker,1,attacker.position)
	_main._combat.commit_batch()
	_expect(result.shield_absorbed == 10 and target.hp == hp and target.combat_idle_seconds == 0 and attacker.combat_idle_seconds == 0, "同批纯盾承伤双方刷新战斗事实")
	_age(target,50)
	_age(attacker,50)
	_main._combat.begin_batch(2,"combat_control")
	target.stun(0.1,&"test",CombatInteraction.effect_context(attacker))
	_main._combat.commit_batch()
	_expect(target.combat_idle_seconds == 0 and attacker.combat_idle_seconds == 0, "延迟结算控制保留来源，双方刷新")
	_age(target,50)
	_age(attacker,50)
	target.apply_stasis(3)
	target.take_damage(10,attacker)
	_expect(attacker.combat_idle_seconds > 2, "凝滞拒绝的伤害不冒充成功伤害")
	_age(target,40)
	_expect(target.combat_idle_seconds == 0, "凝滞即使拒绝伤害仍因硬控无法脱战")
	target.free()
	attacker.free()
	var mover := _make("kayn")
	mover.begin_active_skill_cast(2,Vector2.UP)
	var dash := DashStrikeState.new(mover,CardDB.active_skills_for("kayn")[0])
	mover.stun(-1)
	mover.apply_knockback(Vector2.ZERO,-1)
	_expect(mover.skill_dash_active and mover.cancelled_skill_cast_serial < mover.active_skill_cast_serial, "非法眩晕/击退不取消突进")
	mover.structure_rush.phase = StructureRushState.Phase.DASHING
	mover.stun(1)
	mover.apply_knockback(Vector2.ZERO,10)
	_expect(mover.skill_dash_active and mover.control.stun_timer == 0 and mover._knockback_timer == 0, "现有免控入口拒绝的控制不取消位移动作")
	dash._finish(mover)
	mover.free()

func _check_displacement() -> void:
	for card in ["kayn", "belveth", "ornn"]:
		for kind in ["stun", "knockback", "freeze", "stasis"]:
			var source := _make(card,0,Vector2(300,1000))
			var skill: Dictionary = CardDB.active_skills_for(card)[0]
			source.begin_active_skill_cast(2,Vector2.UP)
			source.play_visual_action(&"ornn_charge" if card == "ornn" else &"active",2)
			var state = OrnnChargeState.new(source,skill) if card == "ornn" else DashStrikeState.new(source,skill)
			if card == "ornn":
				for i in 8: state.tick(0.05)
			else: state.tick(0.05)
			_expect(source.skill_dash_active, "%s控制前确在位移阶段" % card)
			var before := source.position
			match kind:
				"stun": source.stun(1)
				"knockback": source.apply_knockback(before+Vector2.LEFT*100,40)
				"freeze": source.freeze(1)
				"stasis": source.apply_stasis(1)
			var again: bool = state.tick(0.05)
			_expect(not again and state.cancelled and source.position == before and not source.skill_dash_active, "%s突进被%s取消，不补走" % [card,kind])
			_expect(source.cancelled_skill_cast_serial == source.active_skill_cast_serial and source.cancelled_visual_serial == source.get_visual_action_serial(), "%s取消施法与表现身份，停止相应动作音" % card)
			if card == "ornn": _expect(not state.hit_obstacle and state.blast_hit_ids.is_empty(), "控制取消不伪造奥恩撞墙爆炸")
			else: _expect(not state.spin_hit, "控制取消未开始旋转")
			source.free()
	for kind in ["stun", "knockback", "freeze", "stasis"]:
		var source := _make("kayn",0,Vector2(300,1000))
		var skill: Dictionary = CardDB.active_skills_for("kayn")[0]
		source.begin_active_skill_cast(2,Vector2.UP)
		var dash := DashStrikeState.new(source,skill)
		for i in 10: dash.tick(0.05)
		_expect(dash.stopped and not dash.spin_hit and not source.skill_dash_active, "凯隐已结束位移，旋转命中尚未发生")
		match kind:
			"stun": source.stun(1)
			"knockback":
				source.apply_knockback(source.position+Vector2.LEFT*100,20)
				source._tick_knockback_movement(0.05)
				var moving: Array[Unit] = [source]
				_main._movement._apply_unit_movement(0.05,moving)
			"freeze": source.freeze(1)
			"stasis": source.apply_stasis(1)
		for i in 20: dash.tick(0.05)
		_expect(dash.spin_hit == (kind in ["stun","knockback"]), "停止后的普通旋转阶段响应%s" % kind)
		source.free()
	# 位移提交的本批伤害保留；未来路径目标和未开始旋转不补发。
	for card in ["kayn", "belveth"]:
		var source := _make(card,0,Vector2(300,1000))
		var near := _make("anivia" if card == "belveth" else "garen",1,Vector2(300,980))
		var far := _make("anivia" if card == "belveth" else "garen",1,Vector2(300,890))
		var near_hp := near.hp
		var far_hp := far.hp
		source.begin_active_skill_cast(2,Vector2.UP)
		var dash := DashStrikeState.new(source,CardDB.active_skills_for(card)[0])
		_main._combat.begin_batch(3,"dash_then_control")
		dash.tick(0.05)
		source.stun(2)
		_main._combat.commit_batch()
		for i in 30: dash.tick(0.05)
		_expect(near.hp < near_hp and far.hp == far_hp and dash.cancelled, "%s同批已提交伤害不回滚，未来路径/旋转不补发" % card)
		for unit in [source,near,far]: unit.free()

func _check_action_audio() -> void:
	var source := _make("kayn")
	source.begin_active_skill_cast(2,Vector2.UP)
	source.play_visual_action(&"active",2)
	var audio: GameAudioManager = _main._audio_manager
	var own := audio._event_owner(source,&"active:cast")
	_expect(own.get("kind") == "action" and own.serial == source.get_visual_action_serial(), "起手声音归属已建立的本次施法实例")
	var cast_serial := source.get_visual_action_serial()
	var action := AudioStreamPlayer2D.new()
	var independent := AudioStreamPlayer2D.new()
	var successor := AudioStreamPlayer2D.new()
	for player in [action,independent,successor]:
		audio.add_child(player)
		player.stream = AudioStreamWAV.new()
		audio._world_players.append(player)
	action.set_meta("action_owner",own)
	successor.set_meta("action_owner",{"unit":source.get_instance_id(),"kind":"action","serial":source.get_visual_action_serial()+1})
	source.skill_dash_active = true
	source.stun(1)
	_expect(action.stream == null and independent.stream != null and successor.stream != null, "位移眩晕取消只停止旧动作音，不停止独立结果或后继实例")
	# 模拟客户端快照尚未到达、取消先到达，迟到旧声音不能认作新动作。
	var previous_mode: String = _main.mode
	_main.mode = "client"
	source.net_visual_action_serial = cast_serial + 1
	source.active_skill_cast_timer = 0
	_expect(not audio.play_event(source,&"active:cast",source.position,-1,false,cast_serial), "客户端迟到旧施法音按发送序号拒绝，不套用后继身份")
	_main.mode = previous_mode
	for player in [action,independent,successor]:
		audio._world_players.erase(player)
		player.free()
	source.free()

func _check_growth_knockback() -> void:
	var source := _make("lulu",0,Vector2(300,1000))
	var ally := _make("garen",0,Vector2(330,1000))
	var enemy := _make("garen",1,Vector2(350,1000))
	for unit in [source,ally,enemy]: _age(unit,50)
	_main._combat.begin_batch(4,"growth_control_fact")
	var applied: bool = _main._active_skill_effect_system.apply_permanent_growth(source,CardDB.active_skills_for("lulu")[0])
	_main._combat.commit_batch()
	_expect(applied and enemy._knockback_timer > 0 and source.combat_idle_seconds == 0 and enemy.combat_idle_seconds == 0, "璐璐纯击退没有伤害也在成功结算时记录敌对双方")
	_expect(ally.combat_idle_seconds > 2, "接受狂野生长的友军不因正面收益误入战")
	for unit in [source,ally,enemy]: unit.free()
