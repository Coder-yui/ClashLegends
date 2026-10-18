extends "res://tests/suites/battle_suite.gd"
## Unit写入口/回执与批次生命边界的唯一入口；无资源，不运行内容/渲染套件。
## 仅回归夹具：推挤读取可行走性时释放同一枚举快照中的后续对象。
class ReleasingWalkabilityUnit extends Unit:
	var release_ref: WeakRef
	func is_walkable_at(_pos: Vector2) -> bool:
		var other = release_ref.get_ref()
		if is_instance_valid(other): other.free()
		return true

func run(harness: Object) -> void:
	_harness = harness
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	_check_health_and_status()
	_check_receipts()
	_check_skill_rewards()
	_check_motion()
	_check_attack_contract()
	_check_skill_source_release()
	_check_batch_effects()
	_check_status_admission_and_heal()
	_check_zero_damage_credit()
	_check_continuous_and_skills()
	_check_freed_instance_guards(harness, _main)
	_check_freed_property_access(harness, _main)
	_check_replica()
	_main.free()
	_main = null

func _spawn(id: String, team: int = 0, pos: Vector2 = Vector2(300, 900)) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, id, pos, {"deploy_time_override": 0.0, "position_resolved": true}))

func _clear() -> void:
	_main.world.clear_units()
	_main.runtime._commands.clear()

func _check_health_and_status() -> void:
	var unit := _spawn("void_spawn")
	unit.take_damage(20)
	var before := unit.hp
	var maximum := unit.max_hp
	var shield := unit.shield_hp
	_expect(unit.apply_sacrifice_empowerment(2.0, 1.5, 0.3, 1.3, 1.2), "牺牲强化通过一次性上限/补偿入口")
	var bonus := BattleNumbers.quantity(maximum * 0.3)
	_expect(unit.hp == before + bonus and unit.max_hp == maximum + bonus and unit.shield_hp == shield, "生命补偿保持受伤缺口，不经过盾或治疗")
	_expect(not unit.apply_sacrifice_empowerment(2, 1.5, 0.3, 1.3, 1.2) and unit.hp == before + bonus, "重复施加不重发一次生命补偿")
	unit.add_shield(50, 2)
	before = unit.hp
	unit.pay_rush_health_cost(0.3)
	_expect(unit.hp == maxf(1, before - BattleNumbers.quantity(before * 0.3)) and unit.shield_hp == 50, "冲撞代价不消耗盾，不作为敌方伤害")
	unit.heal(100000)
	_expect(unit.hp == unit.max_hp, "普通治疗使用当前永久上限")
	unit.heal_with_overflow(30, 1, 1, &"overflow")
	_expect(unit.hp == unit.max_hp and unit.shield_hp == 80, "普通溢出治疗只转盾，不增加生命上限")
	unit.apply_timed_lifesteal(0.1, 0.4, &"one")
	unit.apply_unit_phasing(0.1, &"one")
	unit.apply_ranged_attack(0.1, 50, true, 300, 2, &"one")
	_expect(unit.ignores_unit_collision() and unit.buffs.strongest(&"timed_lifesteal", &"ratio", 0) == 0.4 and unit.buffs.remaining(&"ranged_attack") > 0, "具名状态施加保留原独立窗口")
	unit._tick_active_statuses(0.1)
	_expect(not unit.ignores_unit_collision() and unit.buffs.remaining(&"timed_lifesteal") == 0 and unit.buffs.remaining(&"ranged_attack") == 0, "状态时钟仍由原StatusInstances唯一推进")
	unit.stun(1, &"channel")
	unit.stun(2, &"other")
	unit.clear_channel_stun(&"channel")
	_expect(unit.control.stun_timer == 2, "引导清理只移除自己的控制，不清其他来源")
	_clear()

func _check_receipts() -> void:
	var source := _spawn("masteryi")
	var target := _spawn("garen", 1, Vector2(300, 820))
	target.hp = 90
	target.add_shield(30, 2)
	var resolver: CombatResolver = _main._combat
	resolver.begin_batch(1, "receipt")
	var first := BattleNumbers.hit(target, 120, source, 0, source.position)
	var second := BattleNumbers.hit(target, 60, source, 0, source.position)
	_expect(first.accepted and not first.settled and not first.landed and first.health_lost == 0 and target.hp == 90 and target.shield_hp == 30, "受理排队不冒充真实命中，不先发结果")
	resolver.commit_batch()
	_expect(first.settled and first.landed and second.settled and second.landed, "提交后才发布最终命中")
	_expect(is_equal_approx(first.health_lost, 60) and is_equal_approx(second.health_lost, 30) and first.shield_absorbed == 20 and second.shield_absorbed == 10, "实际掉血/盾量只按同批比例分配一次")
	_expect(first.overkill == 40 and second.overkill == 20 and target.hp == 0, "过量伤害不是吸血或收益依据")
	# 塔败北信号可同步观察回执；全组扣血尚未完成时landed仍不能提前置真。
	var tower: Tower = _main.world.towers_snapshot()[0]
	var before_tower := tower.hp
	resolver.begin_batch(2, "tower_signal")
	var tower_result := BattleNumbers.hit(tower, 100000, source, 0, source.position)
	var pending_seen: Array[bool] = []
	tower.defeated.connect(func(): pending_seen.append(not tower_result.settled and not tower_result.landed), CONNECT_ONE_SHOT)
	resolver.commit_batch()
	_expect(pending_seen == [true] and tower_result.settled and tower_result.landed, "同步败北观察者不在扣血中途读到提前landed")
	tower.hp = before_tower
	var rejected := BattleNumbers.hit(target, 10, source, 0, source.position)
	_expect(not rejected.accepted and rejected.settled and not rejected.landed, "死人即时请求最终拒绝")
	target = _spawn("garen", 1, Vector2(300, 820))
	target.apply_effect_shield(2, 1, 1.5, &"shield")
	resolver.begin_batch(2, "block")
	var blocked := BattleNumbers.hit(target, 20, source, 0, source.position)
	var through := BattleNumbers.hit(target, 20, source, 0, source.position)
	_expect(blocked.accepted and blocked.blocked and not blocked.settled and not blocked.landed and not through.blocked, "效果盾在收集期只预留一次，回执仍未提交")
	resolver.commit_batch()
	_expect(blocked.settled and not blocked.landed and blocked.health_lost == 0 and through.landed and through.health_lost == 20, "被挡回执不能发命中收益，后续独立命中正常")
	_expect(target.buffs.remaining(&"hit_haste") > 0, "消费盾后的收益仍在提交后授予")
	var immediate := BattleNumbers.hit(target, 7, source, 0, source.position)
	_expect(immediate.accepted and immediate.settled and immediate.landed and immediate.health_lost == 7, "即时伤害经过同一正式小批次及回执核心")
	resolver.begin_batch(3, "removed")
	var removed := BattleNumbers.hit(target, 8, source, 0, source.position)
	target.queue_free()
	resolver.commit_batch()
	_expect(removed.accepted and removed.settled and not removed.landed and removed.health_lost == 0, "收集后目标退出，提交回执撤回命中")
	_clear()

func _check_skill_rewards() -> void:
	var source := _spawn("gwen", 0, Vector2(300, 900))
	var target := _spawn("garen", 1, Vector2(300, 820))
	source.hp = 200
	var skill := CardDB.active_skills_for("gwen")[0].duplicate(true)
	skill["first_hit_heal"] = 100.0
	skill["cast_hit_state"] = ActiveSkillEffectSystem.CastHitState.new()
	var state: ActiveSkillEffectSystem.CastHitState = skill.cast_hit_state
	_main._combat.begin_batch(4, "first_heal")
	_main._active_skill_effect_system.apply_frontal(source, skill, Vector2.UP)
	_expect(not state.landed and source.hp == 200, "收集技能只受理，不提前标实际命中或回复")
	_main._combat.commit_batch()
	_expect(state.landed and source.hp == 300, "首次真正提交的技能命中授予一次回复")
	_main._active_skill_effect_system.apply_frontal(source, skill, Vector2.UP)
	_expect(source.hp == 300, "即时技能复用同一施法身份，不重复首次回血")
	state = ActiveSkillEffectSystem.CastHitState.new()
	skill.cast_hit_state = state
	_main._combat.begin_batch(5, "cancelled_heal")
	_main._active_skill_effect_system.apply_frontal(source, skill, Vector2.UP)
	target.queue_free()
	_main._combat.commit_batch()
	_expect(not state.landed and source.hp == 300, "提交前退出的目标不能发首次命中回复")
	_clear()
	# 实际技能击杀收益与普攻共用提交后的去重，不依赖排队bool。
	source = _spawn("gwen")
	source.skill_resource_max = 10
	source.skill_resource_kill_gain = 1
	target = _spawn("garen", 1, Vector2(300, 820))
	target.hp = 20
	_main._combat.begin_batch(6, "skill_kill")
	var a: Dictionary = _main._active_skill_effect_system._damage_combatant(source, target, 20)
	var b: Dictionary = _main._active_skill_effect_system._damage_combatant(source, target, 20)
	_expect(a.accepted and not a.landed and source.skill_resource_value == 0, "技能受理不能先发击杀资源")
	_main._combat.commit_batch()
	_expect(a.landed and b.landed and source.skill_resource_value == 1, "同批同源多技能伤害只发一次真实击杀收益")
	_clear()

func _check_motion() -> void:
	var unit := _spawn("garen")
	unit._path = PackedVector2Array([Vector2(400, 900)])
	var serial := unit.teleport_serial
	unit.teleport_to(Vector2(330, 900))
	_expect(unit.position == Vector2(330, 900) and unit._prev_pos == unit.position and unit.net_target_pos == unit.position and unit._path.is_empty() and unit.teleport_serial == serial + 1, "传送转换同步路径/插值端点并只增加传送序号")
	unit.apply_body_resize_position(Vector2(340, 900))
	_expect(unit._prev_pos == unit.position and unit.net_target_pos == unit.position and unit.teleport_serial == serial + 1, "体型安全修正不伪造技能传送序号")
	unit.apply_deployment_push_position(Vector2(350, 900))
	_expect(unit._prev_pos == unit.position and unit.net_target_pos == unit.position, "部署推挤经具名交接同步缓存")
	unit.begin_dash_motion()
	var previous := unit._prev_pos
	unit.apply_dash_motion(Vector2(360, 900))
	_expect(unit.position == Vector2(360, 900) and unit._prev_pos == previous, "连续突进保留本Tick插值起点，区别不连续交接")
	_clear()

func _check_attack_contract() -> void:
	var source := _spawn("garen")
	var target := _spawn("garen", 1, Vector2(300, 820))
	_main._combat.begin_batch(7, "attack_receipt")
	var receipt: Dictionary = _main._combat.resolve_attack_hit(0, source.position, target, 10, 0, 0, source)
	_expect(receipt.accepted and not receipt.settled and not receipt.landed and receipt.hits.size() == 1, "攻击入口统一返回回执，排队没有即时bool歧义")
	_main._combat.commit_batch()
	_expect(receipt.settled and receipt.landed and receipt.health_lost == 10, "攻击总回执在效果/收益前汇合真实子命中")
	var immediate: Dictionary = _main._combat.resolve_attack_hit(0, source.position, target, 5, 0, 0, source)
	_expect(immediate.accepted and immediate.settled and immediate.landed and immediate.health_lost == 5, "同一入口即时执行仍是相同回执合同")
	_clear()
	# 真正经过改动的技能箭提交消费者；不创建原生表现或音频。
	source = _spawn("ashe")
	target = _spawn("garen", 1, Vector2(300, 820))
	var hp := target.hp
	_main._projectile_system.launch_skill_fan(source, CardDB.active_skills_for("ashe")[0], Vector2.UP)
	_main._combat.begin_batch(8, "arrow_receipt")
	_main._projectile_system.tick(0.2)
	_expect(target.hp == hp and target.control.slow_timer == 0, "技能箭收集时不提前伤害或施加减速")
	_main._combat.commit_batch()
	_expect(target.hp == hp - 70 and target.control.slow_timer > 0, "技能箭提交真实命中后才施加被动，不按受理bool发效果")
	_main._projectile_system.clear_all()
	_clear()

func _check_replica() -> void:
	var authority := _spawn("sion")
	authority.apply_permanent_growth(0.3, 1.3)
	authority.take_damage(100000)
	_expect(authority.death_form.waiting() and authority.hp == 0 and authority.growth_body_scale == 1, "死亡换形保留零血等待并清永久成长")
	for tick in 40:
		if not authority.death_form.waiting(): break
		_main.runtime._sim_tick_id += 1
		authority.death_form.advance(authority, 0.05)
	_expect(authority.form_index == 1 and authority.hp == authority.max_hp and authority.death_form.used, "复生仍由DeathFormState驱动原实体属性/生命恢复")
	var client = preload("res://tests/fixtures/authority_battle.gd").new()
	client.runtime.mode = "client"
	_harness.root.add_child(client)
	client._snapshot_system.reset_session("unit-contract")
	_main._snapshot_system.reset_session("unit-contract")
	_main.runtime._sim_tick_id = 20
	var payload: Array = preload("res://tests/fixtures/network_fixture.gd").snapshot_payload(_main._snapshot_system, authority.net_id, authority)
	var packet: Array = preload("res://tests/fixtures/network_fixture.gd").packet(_main._snapshot_system, [payload], [], preload("res://tests/fixtures/network_fixture.gd").tower_payloads(_main._snapshot_system), 5, 60, false)
	var bytes := var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE)
	var decoded: NetworkSnapshotSystem.DecodedSnapshot = client._snapshot_system.decode_validated(bytes)
	_expect(decoded != null and client._snapshot_system.apply_decoded(decoded), "完整快照先验证再通过副本恢复入口")
	var replica: Unit = client.world.find_replica_unit(authority.net_id)
	if replica != null:
		var generation := replica.form_change_serial
		var resize_calls: int = client.resize_requests
		replica.add_shield(15, 3)
		var action_serial := replica.active_skill_cast_serial
		client._snapshot_system._apply_units([payload])
		_expect(replica.hp == authority.hp and replica.max_hp == authority.max_hp and replica.form_index == 1 and generation == authority.form_change_serial, "首次副本按主机生命/形态代次恢复，不独自加代次")
		_expect(replica.shield_hp == 15 and replica.active_skill_cast_serial == action_serial and client.resize_requests == resize_calls, "重复恢复不消费盾、变施法代次或调用权威修落点")
		var previous_hp := replica.hp
		var corrupt := packet.duplicate(true)
		corrupt[NetworkSnapshotSystem.S_UNITS][0][NetworkSnapshotSystem.U_GROWTH] = Vector2(NAN, 2)
		_expect(not client._snapshot_system.apply_decoded(client._snapshot_system.decode_validated(var_to_bytes(corrupt).compress(FileAccess.COMPRESSION_DEFLATE))) and replica.hp == previous_hp and replica.form_change_serial == generation, "后部坏字段整包拒绝，没有部分写入副本")
	client.free()
	_clear()

func _check_skill_source_release() -> void:
	# 使用真实技能执行入口，在收集与提交之间释放来源，而非只调用Resolver辅助方法。
	for kind in ["frontal", "nova", "continuous", "frontal_stun"]:
		var source := _spawn("gwen" if kind == "frontal" else "garen")
		var target := _spawn("garen", 1, Vector2(300, 820))
		var hp := target.hp
		var state := ActiveSkillEffectSystem.CastHitState.new()
		var effects: ActiveSkillEffectSystem = _main._active_skill_effect_system
		_main._combat.begin_batch(9, "freed_skill_source_" + kind)
		match kind:
			"frontal":
				source.hp = 200
				var skill := CardDB.active_skills_for("gwen")[0].duplicate(true)
				skill["first_hit_heal"] = 100.0
				skill["cast_hit_state"] = state
				effects.apply_frontal(source, skill, Vector2.UP)
			"nova": effects.activate_nova(source, {"radius": 150.0, "damage": 30.0, "visual_action": "active"})
			"continuous": effects._apply_continuous_area_pulse(source, {"team": 0, "center": source.position, "fixed_position": true, "radius": 150.0, "damage": 30.0, "visual_action": "channel"})
			"frontal_stun": effects.apply_frontal_stun(source, {"length": 150.0, "width": 100.0, "damage": 30.0, "visual_action": "active"}, Vector2.UP)
		_expect(target.hp == hp and not state.landed, "技能收集不先扣血或发收益:" + kind)
		source.free()
		_main._combat.commit_batch()
		_expect(target.hp < hp and not _main._combat.collecting and not _main._combat.committing, "来源释放不撤销已受理技能伤害，提交正常结束:" + kind)
		if kind == "frontal":
			_expect(state.landed and not is_instance_valid(source), "真实命中事实保留，失效来源不恢复或领取首次命中收益")
		_clear()
	# 独立固定区域在来源已经释放后仍能创建并提交下一次脉冲。
	var source := _spawn("malzahar")
	var target := _spawn("garen", 1, Vector2(300, 820))
	var skill: Dictionary = _main._active_skill_effect_system.prepare_cast(source, CardDB.active_skills_for("malzahar")[0])
	_main._active_skill_effect_system.begin_channel_zone(source, target.position, skill)
	var hp := target.hp
	source.free()
	_main._combat.begin_batch(10, "independent_zone_dead_source")
	_main._active_skill_effect_system.tick_effects(0.5)
	_main._combat.commit_batch()
	_expect(target.hp == hp - 30 and not _main._active_skill_effect_system.continuous_area_effects.is_empty(), "先知独立区域源已消失仍按自身时钟提交下一脉冲")
	_main._active_skill_effect_system.clear()
	_clear()

func _check_batch_effects() -> void:
	for reverse in [false, true]:
		var a: Unit = _main._spawn_unit(UnitSpawnRequest.new(0, "masteryi", Vector2(180, 760), {"deploy_time_override": 0}))
		var b: Unit = _main._spawn_unit(UnitSpawnRequest.new(1, "masteryi", Vector2(180, 725), {"deploy_time_override": 0}))
		a.hp = 100
		b.hp = 100
		a.attack_lifesteal_ratio = 1
		b.attack_lifesteal_ratio = 1
		a.add_shield(20, 2)
		a.add_shield(30, 1)
		b.add_shield(20, 2)
		b.add_shield(30, 1)
		_main._combat.begin_batch(_main.runtime._sim_tick_id, "test_shield_exchange")
		var order: Array = [a, b] if not reverse else [b, a]
		for source in order:
			var target: Unit = b if source == a else a
			_main._combat.resolve_attack_hit(source.team, source.position, target, 150, 0, 0, source, source.position, 0, {"blind_charges": 1})
		_expect(a.hp == 100 and b.hp == 100 and a.blind_attack_charges == 0 and b.blind_attack_charges == 0, "收集不修改生命、护盾或控制")
		_main._combat.commit_batch()
		_expect(a.hp == 0 and b.hp == 0 and a.shield_hp == 0 and b.shield_hp == 0, "全批死亡确定后不允许靠先处理吸血逃生")
		a.free()
		b.free()
		# 两个存活来源共同过量伤害：实际掉血之和固定为目标剩余生命。
		a = _main._spawn_unit(UnitSpawnRequest.new(0, "masteryi", Vector2(180, 760), {"deploy_time_override": 0}))
		b = _main._spawn_unit(UnitSpawnRequest.new(0, "masteryi", Vector2(220, 760), {"deploy_time_override": 0}))
		var target: Unit = _main._spawn_unit(UnitSpawnRequest.new(1, "garen", Vector2(180, 725), {"deploy_time_override": 0}))
		a.hp = 100
		b.hp = 100
		a.attack_lifesteal_ratio = 1
		b.attack_lifesteal_ratio = 1
		target.hp = 90
		target.add_shield(30, 1)
		_main._combat.begin_batch(_main.runtime._sim_tick_id, "test_overkill")
		order = [a, b] if not reverse else [b, a]
		for source in order:
			_main._combat.resolve_attack_hit(0, source.position, target, 120 if source == a else 60, 0, 0, source, source.position, 0)
		_main._combat.commit_batch()
		_expect(a.hp == 160 and b.hp == 130 and target.hp == 0, "多来源过量伤害按比例归属实际掉血，不重复吸血且不依赖提交顺序")
		for unit in [a, b, target]: unit.free()

func _check_status_admission_and_heal() -> void:
	for reverse in [false, true]:
		var target: Unit = _main._spawn_unit(UnitSpawnRequest.new(0, "garen", Vector2(180, 760), {"deploy_time_override": 0}))
		target.hp = target.max_hp - 20
		_main._combat.begin_batch(_main.runtime._sim_tick_id, "status_admission")
		var shield := func(): target.add_shield(30, 2, false, &"batch")
		var damage := func(): target.take_damage(40)
		if reverse:
			damage.call()
			shield.call()
		else:
			shield.call()
			damage.call()
		target.heal_with_overflow(100, 0.5, 2, &"heal")
		_expect(target.hp == target.max_hp - 20 and target.shield_hp == 0, "收集阶段不提前治疗或加盾")
		_main._combat.commit_batch()
		_expect(target.hp == target.max_hp and target.shield_hp == 50, "批次先承受40伤害，再治疗60，实际溢出40转20盾，另加30盾；反序一致")
		_main._combat.begin_batch(_main.runtime._sim_tick_id, "immunity_admission")
		var immunity := func(): target.apply_active_buff(0.1, 1, 1, 1, true, true, &"immune")
		var slow := func(): target.apply_slow(1, 0.5, &"slow")
		if reverse:
			slow.call()
			immunity.call()
		else:
			immunity.call()
			slow.call()
		_main._combat.commit_batch()
		_expect(target.control.slow_timer > 0 and target.active_buff_ignores_movement_slow, "同阶段免疫与减速按批次开始时资格接收，旧减速被抑制")
		target._tick_active_statuses(0.1)
		_expect(target.control.slow_timer > 0 and not target.active_buff_ignores_movement_slow, "免疫到期后同批接收的减速仍保留剩余窗口")
		target.free()

	# 对死亡准入同时检查直接接口和同批死亡后的延迟提交。
	for deferred in [false, true]:
		var target: Unit = _main._spawn_unit(UnitSpawnRequest.new(0, "garen", Vector2(180, 760), {"deploy_time_override": 0}))
		if deferred:
			_main._combat.begin_batch(_main.runtime._sim_tick_id, "dead_status_admission")
			target.take_damage(target.hp)
		else:
			target.hp = 0
		target.apply_active_buff(2, 2, 2, 2, true, true)
		target.apply_blind(3)
		if deferred: _main._combat.commit_batch()
		_expect(target.hp == 0 and target.active_buff_timer == 0 and target.blind_attack_charges == 0, "直接死亡或同批死亡的对象均不接收新增增益/致盲")
		target.free()

func _check_zero_damage_credit() -> void:
	var a: Unit = _main._spawn_unit(UnitSpawnRequest.new(0, "masteryi", Vector2(180, 760), {"deploy_time_override": 0}))
	var b: Unit = _main._spawn_unit(UnitSpawnRequest.new(0, "masteryi", Vector2(220, 760), {"deploy_time_override": 0}))
	var target: Unit = _main._spawn_unit(UnitSpawnRequest.new(1, "garen", Vector2(180, 725), {"deploy_time_override": 0}))
	for source in [a, b]:
		source.skill_resource_max = 10
		source.skill_resource_kill_gain = 1
	target.hp = 50
	_main._combat.begin_batch(_main.runtime._sim_tick_id, "zero_damage_credit")
	_main._combat.resolve_attack_hit(0, a.position, target, 0, 0, 0, a, a.position, 0)
	_main._combat.resolve_attack_hit(0, b.position, target, 50, 0, 0, b, b.position, 0)
	_main._combat.commit_batch()
	_expect(a.skill_resource_value == 0 and b.skill_resource_value == 1, "零伤害脉冲不分走同批其他来源的击杀资源")
	for unit in [a, b, target]: unit.free()

func _check_continuous_and_skills() -> void:
	for reverse in [false, true]:
		var a: Unit = _main._spawn_unit(UnitSpawnRequest.new(0, "aurelionsol", Vector2(180, 760), {"deploy_time_override": 0}))
		var b: Unit = _main._spawn_unit(UnitSpawnRequest.new(1, "aurelionsol", Vector2(180, 710), {"deploy_time_override": 0}))
		a.hp = 3
		b.hp = 3
		if reverse:
			a.remove_from_group("combatants")
			a.add_to_group("combatants")
		_run_main_ticks(2)
		_expect(a.hp == 0 and b.hp == 0, "持续吐息同阶段互换，累计余量不因遍历顺序撤回")
		a.free()
		b.free()
		# 正式技能影响队列：两个已开始施法的落点在同 Tick 到期。
		a = _main._spawn_unit(UnitSpawnRequest.new(0, "aurelionsol", Vector2(180, 760), {"deploy_time_override": 0}))
		b = _main._spawn_unit(UnitSpawnRequest.new(1, "aurelionsol", Vector2(180, 710), {"deploy_time_override": 0}))
		a.hp = 120
		b.hp = 120
		var skill := CardDB.active_skills_for("aurelionsol")[0].duplicate(true)
		skill.forward_distance = 0
		skill.radius = 150
		skill.erase("result_creation_delay") # 此夹具直接提交已创建结果的同刻命中。
		for source in ([a, b] if not reverse else [b, a]):
			_main.runtime._queue_active_skill_impact(source, skill, 0.05)
		_main._sim_step(0.05)
		_expect(a.hp == 0 and b.hp == 0, "技能队列同刻合法到期伤害与眩晕不撤回对方已提交命中")
		a.free()
		b.free()

func _check_freed_instance_guards(harness: Object, main: Node2D) -> void:
	var source := Unit.new()
	source.setup(0, CardDB.get_card("ornn"), "来源")
	main.add_child(source)
	var target := Unit.new()
	target.setup(0, CardDB.get_card("garen"), "友军")
	main.add_child(target)
	var stale := Unit.new()
	var candidates: Array = [stale, null, main, target]
	stale.free()
	var boosts := TeamAttackBoostSystem.new(main)
	harness._expect(boosts._choose_target(source, candidates) == target, "锻造候选列表跳过已释放引用、空值和非单位，仍选中存活友军")
	harness._expect(boosts._choose_target(source, [stale, null, main]) == null, "无有效锻造候选时安全返回空目标")
	target.free()
	source.free()
	# 命中事件监听者可同步释放来源，结算尾部不能再先做来源类型判断。
	var attacker := Unit.new()
	attacker.setup(0, CardDB.get_card("garen"), "攻击者")
	main.add_child(attacker)
	var victim := Unit.new()
	victim.setup(1, CardDB.training_dummy_stats(), "受击者")
	main.add_child(victim)
	var resolver: CombatResolver = main.combat_service()
	var hits: Array[bool] = []
	var callback := func(_source: Dictionary, _position: Vector2, _first_strike: bool):
		hits.append(true)
		attacker.free()
	resolver.attack_hit.connect(callback, CONNECT_ONE_SHOT)
	var receipt := resolver.resolve_attack_hit(0, attacker.global_position, victim, victim.hp, 0.0, 0.0, attacker)
	harness._expect(receipt.settled and receipt.landed and victim.hp == 0.0 and hits.size() == 1 and not is_instance_valid(attacker), "命中回调释放攻击者后仍完成伤害结算，不对已释放来源先做类型判断")
	if resolver.attack_hit.is_connected(callback): resolver.attack_hit.disconnect(callback)
	if is_instance_valid(attacker): attacker.free()
	victim.free()

func _check_freed_property_access(harness: Object, main: Node2D) -> void:
	for team in [0, 1]:
		var center := Vector2(360.0, 900.0 if team == 0 else 380.0)
		var releasing := ReleasingWalkabilityUnit.new()
		releasing.setup(team, CardDB.get_card("garen"), "释放夹具")
		releasing.position = center
		main.add_child(releasing)
		var stale := Unit.new()
		stale.setup(team, CardDB.get_card("garen"), "后续释放对象")
		stale.position = center + Vector2.UP * 20.0
		main.add_child(stale)
		var survivor := Unit.new()
		survivor.setup(team, CardDB.get_card("garen"), "后续存活对象")
		survivor.position = center + Vector2.UP * 10.0
		main.add_child(survivor)
		releasing.release_ref = weakref(stale)
		main.world.push_units_around(center, 40.0)
		harness._expect(not is_instance_valid(stale) and survivor.position.distance_to(center) >= 40.0 + survivor.body_radius - 0.001, "推挤枚举中途释放后续单位，仍跳过失效引用并继续推挤存活对象：阵营%d" % team)
		releasing.free()
		if is_instance_valid(stale): stale.free()
		survivor.free()
	var attacker := Unit.new()
	attacker.setup(0, CardDB.get_card("garen"), "攻击者")
	main.add_child(attacker)
	var victim := Unit.new()
	victim.setup(1, CardDB.training_dummy_stats(), "命中目标")
	main.add_child(victim)
	var victim_ref: WeakRef = weakref(victim)
	var hits: Array[bool] = []
	var callback := func(_source: Dictionary, _position: Vector2, _first_strike: bool):
		hits.append(true)
		victim_ref.get_ref().free()
	var resolver: CombatResolver = main.combat_service()
	resolver.attack_hit.connect(callback, CONNECT_ONE_SHOT)
	var receipt := resolver.resolve_attack_hit(0, attacker.global_position, victim, victim.hp, 0.0, 0.0, attacker)
	harness._expect(receipt.settled and receipt.landed and hits.size() == 1 and not is_instance_valid(victim), "命中回调释放目标后不再读取其生命属性，已结算命中仍成功")
	if resolver.attack_hit.is_connected(callback): resolver.attack_hit.disconnect(callback)
	if is_instance_valid(victim): victim.free()
	attacker.free()
