extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	for tower in _main._towers: tower.can_attack = false
	_check_cycles()
	_check_mirror()
	_check_extra_boundaries()
	_check_batch_effects()
	_check_early_tick()
	_check_cancelled_cycle()
	_check_extra_exchange_and_deaths()
	_check_continuous_and_skills()
	_check_same_batch_blind()
	_check_zero_damage_credit()
	var rules := MatchRules.new()
	var result := rules.advance(0.05, 0.0, 0.0, 0, 0)
	_expect(result.winner_team == -1, "双水晶同 Tick 摧毁为平局")
	_expect(rules.advance(0.05, 0.0, 10.0, 0, 0).is_empty(), "正式终局不能被晚到状态改判")

func _check_cycles() -> void:
	var yi: Unit = _main._spawn_unit(0, "masteryi", Vector2(180, 760), 0.0)
	var target: Unit = _main._spawn_unit(1, "garen", Vector2(180, 725), 0.0)
	target.max_hp = 100000
	target.hp = target.max_hp
	target.freeze(100.0)
	var extras: Array[int] = []
	var last := 0
	for tick in 240:
		_main._sim_step(0.05)
		if yi._attack_hit_index != last:
			last = yi._attack_hit_index
			if not yi._pending_extra_attacks.is_empty(): extras.append(last)
		if last >= 9: break
	_expect(last == 9 and extras == [3, 6, 9], "正常初始状态连续九次主攻击：第三、第六、第九次均排队追加刀")
	_run_main_ticks(3)
	_expect(target.max_hp - target.hp == 546 and yi._attack_swing_count == 12, "三轮连续主刀和追加刀均实际命中：九主刀三追加刀")
	yi.free()
	target.free()

func _check_mirror() -> void:
	for permutation in 16:
		var reverse := (permutation & 1) != 0
		var a: Unit
		var b: Unit
		if permutation & 8:
			b = _main._spawn_unit(0 if reverse else 1, "masteryi", Vector2(180, 725), 0)
			a = _main._spawn_unit(1 if reverse else 0, "masteryi", Vector2(180, 760), 0)
		else:
			a = _main._spawn_unit(1 if reverse else 0, "masteryi", Vector2(180, 760), 0)
			b = _main._spawn_unit(0 if reverse else 1, "masteryi", Vector2(180, 725), 0)
		if permutation & 2:
			_main.move_child(b, a.get_index())
		if permutation & 4:
			a.remove_from_group("combatants")
			a.add_to_group("combatants")
		_main._combat.trace_enabled = true
		_main._combat.trace.clear()
		a.hp = a.damage
		b.hp = b.damage
		for tick in 100:
			_main._sim_step(0.05)
			if a.hp <= 0 or b.hp <= 0:
				print("FAIRNESS tick=", _main._sim_tick_id, " a=", a.hp, " b=", b.hp, " stages=", a._attack_hit_index, "/", b._attack_hit_index)
				break
		print("FAIRNESS_TRACE ", JSON.stringify(_main._combat.trace))
		_main._combat.trace_enabled = false
		_expect(a.hp == 0 and b.hp == 0, "正常近战镜像同刻致死，换边不改变互换")
		a.free()
		b.free()

func _extra_pair() -> Array[Unit]:
	var yi: Unit = _main._spawn_unit(0, "masteryi", Vector2(180, 760), 0.0)
	var target: Unit = _main._spawn_unit(1, "garen", Vector2(180, 725), 0.0)
	target.max_hp = 100000
	target.hp = target.max_hp
	target.freeze(100)
	for tick in 80:
		_main._sim_step(0.05)
		if yi._attack_hit_index == 3: break
	_expect(yi._pending_extra_attacks.size() == 1, "等待时序夹具由正常第三次主攻击产生追加刀")
	return [yi, target]

func _check_extra_boundaries() -> void:
	for scenario in ["haste", "slow", "slow_expiry", "expiry", "immunity", "freeze", "stun", "knockback", "cast", "source_death", "target_death", "blind"]:
		var pair := _extra_pair()
		var yi := pair[0]
		var target := pair[1]
		var before := target.hp
		match scenario:
			"haste":
				yi._tick_pending_extra_attacks(0.05)
				yi.apply_active_buff(1.0, 3.0, 1.0, 2.0)
				_expect(is_equal_approx(yi._pending_extra_attacks[0].time_left, 0.035), "加速按已完成进度缩放，不误用三倍移速")
			"slow":
				yi._tick_pending_extra_attacks(0.05)
				yi.apply_attack_speed_slow(1.0, 0.5)
				_expect(is_equal_approx(yi._pending_extra_attacks[0].time_left, 0.14), "减攻速按剩余进度延长追加刀")
			"slow_expiry":
				yi.apply_attack_speed_slow(0.05, 0.5)
				yi._tick_pending_extra_attacks(0.05)
				yi._tick_active_statuses(0.05)
				_expect(is_equal_approx(yi._pending_extra_attacks[0].time_left, 0.095), "减攻速到期按剩余进度加快追加刀")
			"expiry":
				yi.apply_active_buff(0.05, 1.0, 1.0, 2.0)
				yi._tick_pending_extra_attacks(0.02)
				yi._tick_active_statuses(0.05)
				_expect(is_equal_approx(yi._pending_extra_attacks[0].time_left, 0.08), "攻速增益到期恢复剩余进度，不重启全长")
			"immunity":
				yi.apply_attack_speed_slow(1.0, 0.5)
				yi.apply_active_buff(0.05, 1.0, 1.0, 1.4, false, true)
				_expect(is_equal_approx(yi._pending_extra_attacks[0].time_left, 0.12 / 1.4), "减攻速免疫使用相同有效速率")
				yi._tick_active_statuses(0.05)
				_expect(is_equal_approx(yi._pending_extra_attacks[0].time_left, 0.24), "免疫到期重新纳入仍在持续的减攻速")
			"freeze", "stun":
				if scenario == "freeze": yi.freeze(0.2)
				else: yi.stun(0.2)
				_run_main_ticks(3)
				_expect(target.hp == before and is_equal_approx(yi._pending_extra_attacks[0].time_left, 0.12), "硬控暂停追加刀计时：" + scenario)
			"knockback": yi.apply_knockback(target.global_position, 20.0)
			"cast": yi.begin_active_skill_cast(1.0, Vector2.UP, ["attack"])
			"source_death": yi.take_damage(100000)
			"target_death":
				yi.freeze(1.0)
				target.take_damage(100000)
			"blind": yi.apply_blind(1)
		# 只观察已提交连击，锁普攻施法不撤销追加刀。
		if scenario not in ["source_death", "cast"]: yi.begin_active_skill_cast(1.0, Vector2.UP, ["attack"])
		for tick in 8:
			_main._sim_step(0.05)
		if scenario == "source_death":
			_expect(target.hp == before, "更早批次来源死亡取消未来追加刀")
		elif scenario == "target_death":
			_expect(yi._pending_extra_attacks.is_empty(), "目标死亡取消未提交追加刀")
		elif scenario == "blind":
			_expect(target.hp == before and yi.blind_attack_charges == 0, "追加刀独立消费致盲，主刀不追溯撤回")
		else:
			_expect(before - target.hp == 26 and yi._pending_extra_attacks.is_empty(), "追加刀恰好命中一次：" + scenario)
		yi.free()
		target.free()

func _check_batch_effects() -> void:
	for reverse in [false, true]:
		var a: Unit = _main._spawn_unit(0, "masteryi", Vector2(180, 760), 0)
		var b: Unit = _main._spawn_unit(1, "masteryi", Vector2(180, 725), 0)
		a.hp = 100
		b.hp = 100
		a.attack_lifesteal_ratio = 1
		b.attack_lifesteal_ratio = 1
		a.add_shield(20, 2)
		a.add_shield(30, 1)
		b.add_shield(20, 2)
		b.add_shield(30, 1)
		_main._combat.begin_batch(_main._sim_tick_id, "test_shield_exchange")
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
		a = _main._spawn_unit(0, "masteryi", Vector2(180, 760), 0)
		b = _main._spawn_unit(0, "masteryi", Vector2(220, 760), 0)
		var target: Unit = _main._spawn_unit(1, "garen", Vector2(180, 725), 0)
		a.hp = 100
		b.hp = 100
		a.attack_lifesteal_ratio = 1
		b.attack_lifesteal_ratio = 1
		target.hp = 90
		target.add_shield(30, 1)
		_main._combat.begin_batch(_main._sim_tick_id, "test_overkill")
		order = [a, b] if not reverse else [b, a]
		for source in order:
			_main._combat.resolve_attack_hit(0, source.position, target, 120 if source == a else 60, 0, 0, source, source.position, 0)
		_main._combat.commit_batch()
		_expect(a.hp == 160 and b.hp == 130 and target.hp == 0, "多来源过量伤害按比例归属实际掉血，不重复吸血且不依赖提交顺序")
		for unit in [a, b, target]: unit.free()

func _check_early_tick() -> void:
	var a: Unit = _main._spawn_unit(0, "masteryi", Vector2(180, 760), 0)
	var b: Unit = _main._spawn_unit(1, "masteryi", Vector2(180, 725), 0)
	a.hp = a.damage
	b.hp = b.damage
	b.freeze(0.05)
	for tick in 12:
		_main._sim_step(0.05)
		if a.hp <= 0 or b.hp <= 0: break
	_expect(a.hp > 0 and b.hp == 0 and a._attack_hit_index == 1 and b._attack_hit_index == 0, "真实早一个 Tick 出手保留先手，不强制镜像同归于尽")
	a.free()
	b.free()

func _check_cancelled_cycle() -> void:
	var pair := _extra_pair()
	var yi := pair[0]
	var target := pair[1]
	_run_main_ticks(3)
	var cancelled := false
	var extras: Array[int] = [3]
	var last := 3
	for tick in 240:
		_main._sim_step(0.05)
		if not cancelled and yi._attack_hit_index == 4 and yi.attack_timeline.cooldown > 0 and not yi._attack_visual_pending:
			# 施法锁是正式前摇取消入口，不直接修改权威计数。
			yi.begin_active_skill_cast(0.1, Vector2.UP, ["attack"])
			cancelled = true
		if last != yi._attack_hit_index:
			last = yi._attack_hit_index
			if not yi._pending_extra_attacks.is_empty():
				extras.append(last)
				_expect((yi._attack_visual_serial - 1) % 3 == 2, "取消重播后追加刀、动画与音效仍使用权威第三段")
		if last >= 9: break
	_expect(cancelled and extras == [3, 6, 9], "正常连续三轮攻击含中途取消前摇，第三六九刀循环不漂移")
	yi.free()
	target.free()

func _check_extra_exchange_and_deaths() -> void:
	for replacement in [false, true]:
		var a: Unit = _main._spawn_unit(0, "masteryi", Vector2(180, 760), 0)
		var b: Unit = _main._spawn_unit(1, "masteryi", Vector2(180, 725), 0)
		for unit in [a, b]:
			unit.hp = 182 # 三次主刀 + 一次追加刀，最后追加刀同时致死。
			if replacement:
				unit.death_replacement_id = "anivia_egg"
				unit.death_replacement_charges = 1
			else:
				unit.death_spawn_id = "imp"
				unit.death_spawn_count = 1
		var previous := _main.get_tree().get_nodes_in_group("combatants")
		_main._combat.trace_enabled = true
		_main._combat.trace.clear()
		for tick in 90:
			_main._sim_step(0.05)
			if a.hp <= 0 or b.hp <= 0: break
		_expect(a.hp == 0 and b.hp == 0 and a._attack_hit_index == 3 and b._attack_hit_index == 3, "连续战斗第三次主刀后的追加刀同刻互换")
		a._die(true)
		b._die(true)
		var spawned := 0
		for unit in _main.get_tree().get_nodes_in_group("combatants"):
			if unit not in previous:
				spawned += 1
				_expect(unit._attack_hit_index == 0, "死亡提交中新生单位不能进入已收集的攻击批次")
				unit.free()
		_expect(spawned == 2, "重复死亡请求不重复生成死亡召唤或替身")
		print("EXTRA_FAIRNESS_TRACE ", JSON.stringify(_main._combat.trace))
		_main._combat.trace_enabled = false
		a.free()
		b.free()

func _check_continuous_and_skills() -> void:
	for reverse in [false, true]:
		var a: Unit = _main._spawn_unit(0, "aurelionsol", Vector2(180, 760), 0)
		var b: Unit = _main._spawn_unit(1, "aurelionsol", Vector2(180, 710), 0)
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
		a = _main._spawn_unit(0, "aurelionsol", Vector2(180, 760), 0)
		b = _main._spawn_unit(1, "aurelionsol", Vector2(180, 710), 0)
		a.hp = 120
		b.hp = 120
		var skill := CardDB.active_skills_for("aurelionsol")[0].duplicate(true)
		skill.forward_distance = 0
		skill.radius = 150
		for source in ([a, b] if not reverse else [b, a]):
			_main._queue_active_skill_impact(source, skill, 0.05)
		_main._sim_step(0.05)
		_expect(a.hp == 0 and b.hp == 0, "技能队列同刻合法到期伤害与眩晕不撤回对方已提交命中")
		a.free()
		b.free()


func _check_same_batch_blind() -> void:
	var a: Unit = _main._spawn_unit(0, "masteryi", Vector2(180, 760), 0)
	var b: Unit = _main._spawn_unit(1, "masteryi", Vector2(180, 725), 0)
	for unit in [a, b]:
		unit.hp = 100
		unit.prepare_empowered_attack(1, 1, 1)
	for tick in 12:
		_main._sim_step(0.05)
		if a._attack_hit_index > 0 and b._attack_hit_index > 0: break
	_expect(a.hp == 48 and b.hp == 48 and a.blind_attack_charges == 1 and b.blind_attack_charges == 1, "同批新致盲不撤回已提交刀，保留到下一刀消费")
	a.free()
	b.free()


func _check_zero_damage_credit() -> void:
	var a: Unit = _main._spawn_unit(0, "masteryi", Vector2(180, 760), 0)
	var b: Unit = _main._spawn_unit(0, "masteryi", Vector2(220, 760), 0)
	var target: Unit = _main._spawn_unit(1, "garen", Vector2(180, 725), 0)
	for source in [a, b]:
		source.skill_resource_max = 10
		source.skill_resource_kill_gain = 1
	target.hp = 50
	_main._combat.begin_batch(_main._sim_tick_id, "zero_damage_credit")
	_main._combat.resolve_attack_hit(0, a.position, target, 0, 0, 0, a, a.position, 0)
	_main._combat.resolve_attack_hit(0, b.position, target, 50, 0, 0, b, b.position, 0)
	_main._combat.commit_batch()
	_expect(a.skill_resource_value == 0 and b.skill_resource_value == 1, "零伤害脉冲不分走同批其他来源的击杀资源")
	for unit in [a, b, target]: unit.free()
