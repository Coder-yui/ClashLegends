extends "res://tests/suites/battle_suite.gd"
## 无表现的小型权威边界：施法身份、攻速事务、正式命令阶段和塔首击。
func run(harness: Object) -> void:
	_harness = harness
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	for shield_first in [true, false]:
		_test_channel(shield_first)
		_clear()
	_test_channel_summons()
	_clear()
	_test_haste()
	_clear()
	_test_tower()
	_clear()
	for id in ["twisted_fate", "pantheon"]:
		_test_deployment(id)
		_clear()
	_main.free()
	_main = null

func _spawn(id: String, team: int, pos: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, id, pos, {"deploy_time_override": 0.0}))

func _clear() -> void:
	_main._active_skill_effect_system.clear()
	_main._projectile_system.clear_all()
	_main.runtime._commands.clear()
	for actor in _main.get_tree().get_nodes_in_group("combatants"):
		if actor is Unit: actor.free()

func _shield(target: Unit) -> void:
	var skill: Dictionary = CardDB.active_skills_for("nocturne")[0]
	_main._active_skill_effect_system.apply(target, _main._active_skill_effect_system.prepare_cast(target, skill))

func _test_channel(shield_first: bool) -> void:
	var caster := _spawn("malzahar", 0, Vector2(360, 950))
	var target := _spawn("nocturne", 1, Vector2(360, 850))
	var bystander := _spawn("target_dummy", 1, Vector2(400, 850))
	var effects = _main._active_skill_effect_system
	if shield_first: _shield(target)
	var skill: Dictionary = effects.prepare_cast(caster, CardDB.active_skills_for("malzahar")[0])
	effects.apply(caster, skill)
	_main._combat.begin_batch(1, "channel_action")
	caster._target = target
	caster._attack(0.05)
	_expect(caster.channel_attack.active(), "正式下一击建立引导")
	_main._combat.commit_batch()
	_expect(target.is_stunned() != shield_first, "控制按首次命中护盾判定")
	if not shield_first: _shield(target)
	caster.channel_attack.stop(caster)
	caster.free()
	var health := target.hp
	var other_health := bystander.hp
	for pulse in 10:
		_main._combat.begin_batch(pulse + 2, "channel_pulse")
		effects.tick_effects(0.5)
		_main._combat.commit_batch()
	_expect(target.hp == health - (0.0 if shield_first else 300.0), "同次R控制和10次区域共享结果，死源仍维持完整区域")
	_expect(bystander.hp == other_health - 300.0, "同施法各目标独立接受结果")
	_expect(effects.continuous_area_effects.is_empty(), "区域5秒正常到期")
	if not shield_first:
		# 这里只推进效果时钟；盾时钟不推进，以隔离身份合同。
		_expect(target.buffs.remaining(&"effect_shield") > 0.0, "已接受R不会消耗后来开的盾")

func _start_channel(caster: Unit, target: Unit) -> void:
	var effects = _main._active_skill_effect_system
	effects.apply(caster, effects.prepare_cast(caster, CardDB.active_skills_for("malzahar")[0]))
	caster._target = target
	_main._combat.begin_batch(_main.runtime._sim_tick_id, "summon_channel")
	caster._attack(0.05)
	_main._combat.commit_batch()

func _test_channel_summons() -> void:
	var caster := _spawn("malzahar", 0, Vector2(360, 960))
	var target := _spawn("target_dummy", 1, Vector2(360, 850))
	caster.spawn_initial_delay_left = 0.0
	caster._initial_summons_spawned = true
	caster._spawn_timer = 0.1 # 定位到既有8秒周期的最后两步。
	_start_channel(caster, target)
	var action_serial := caster.get_visual_action_serial()
	_run_main_ticks(1)
	_expect(is_equal_approx(caster._spawn_timer, 0.05) and _main.runtime._commands.inspect_summons().is_empty(), "引导跨周期前一步计时继续且不提前开门")
	_run_main_ticks(1)
	_expect(caster.channel_attack.active() and _main.runtime._commands.inspect_summons().size() == 3 and is_equal_approx(caster._spawn_timer, 8.0), "引导中到期照常开门并从实际开门重计8秒")
	_expect(caster.get_visual_action_serial() == action_serial and target.is_stunned(), "被动召唤不抢引导演出或解除控制")
	caster.freeze(0.6)
	caster._spawn_timer = 0.0
	_run_main_ticks(5)
	_expect(not caster.channel_attack.active() and caster.is_frozen() and _units("voidling").size() == 1 and _main.runtime._commands.inspect_summons().size() == 2, "引导受控打断但已发序列仍按0.25秒生成首只")
	_expect(caster._spawn_timer == 0.0, "受控到期仅保留一批不新增序列")
	caster.take_damage(100000)
	_run_main_ticks(20)
	_expect(_units("voidling").size() == 3 and _main.runtime._commands.inspect_summons().is_empty(), "来源死亡保留已发序列，不补发受控待发批次")
	_clear()
	for kind in ["stun", "freeze", "stasis"]:
		caster = _spawn("malzahar", 0, Vector2(360, 960))
		target = _spawn("target_dummy", 1, Vector2(360, 850))
		caster.spawn_initial_delay_left = 0.0
		caster._initial_summons_spawned = true
		caster._spawn_timer = 0.05
		_start_channel(caster, target)
		match kind:
			"stun": caster.stun(0.15)
			"freeze": caster.freeze(0.15)
			"stasis": caster.apply_stasis(0.15)
		_run_main_ticks(2)
		_expect(not caster.channel_attack.active() and caster._spawn_timer == 0.0 and _main.runtime._commands.inspect_summons().is_empty(), "引导中受控沿用计时到期待发:" + kind)
		_run_main_ticks(1)
		_expect(_main.runtime._commands.inspect_summons().size() == 3 and is_equal_approx(caster._spawn_timer, 8.0), "解控立即释放一批并重计周期:" + kind)
		_clear()
	caster = _spawn("malzahar", 0, Vector2(360, 960))
	caster._deploy_timer = 0.1
	caster.spawn_initial_delay_left = 0.05
	_run_main_ticks(1)
	_expect(_main.runtime._commands.inspect_summons().is_empty() and not caster._initial_summons_spawned, "部署锁期间仍不启动首次召唤")
	_run_main_ticks(1)
	_expect(_main.runtime._commands.inspect_summons().is_empty() and not caster._initial_summons_spawned, "部署完成当Tick不预扣首次延迟")
	_run_main_ticks(1)
	_expect(_main.runtime._commands.inspect_summons().size() == 3 and caster._initial_summons_spawned, "部署完成后首次延迟按原规则启动")

func _test_haste() -> void:
	var target := _spawn("nocturne", 0, Vector2(360, 900))
	var attacker := _spawn("garen", 1, Vector2(360, 820))
	target.attack_timeline.windup = 0.39
	target.attack_timeline.recovery = 0.65
	target.attack_timeline.cooldown = 0.91
	target._pending_extra_attacks.append({"time_left": 0.26})
	_shield(target)
	_main._combat.begin_batch(2, "shield_reservation")
	var first: Dictionary = _main._combat.submit_damage(target, 10, attacker, 1, attacker.position)
	var second: Dictionary = _main._combat.submit_damage(target, 10, attacker, 1, attacker.position)
	_expect(first.blocked and not second.blocked, "收集期立即预留一次盾，不阻挡第二独立攻击")
	_expect(is_equal_approx(target._effective_attack_speed_multiplier(), 1.0), "收集期不提前改变收益攻速")
	var before := target.hp
	_main._combat.commit_batch()
	_expect(target.hp == before - 10.0, "同批第二次伤害正常提交")
	_expect(_phases_equal(target, 0.3, 0.5, 0.7, 0.2), "盾收益归一化重算前摇/后摇/间隔/额外攻击")
	_shield(target)
	CombatInteraction.blocks_effect(target, CombatInteraction.effect_context(attacker))
	_expect(_phases_equal(target, 0.3, 0.5, 0.7, 0.2), "同速刷新不重复缩短各攻击阶段")
	# 只推进旧状态时钟，避免行动消费阶段时间，检查到期恢复归一化进度。
	target._tick_active_statuses(2.0)
	_expect(_phases_equal(target, 0.39, 0.65, 0.91, 0.26), "奖励到期归一化恢复各攻击阶段")
	_shield(target)
	target._tick_active_statuses(1.5)
	_expect(is_equal_approx(target._effective_attack_speed_multiplier(), 1.0), "盾自然结束没有奖励")
	# 受减攻速时按旧新有效倍率换算，不忽略已有减益。
	target.apply_attack_speed_slow(4.0, 0.5)
	_shield(target)
	CombatInteraction.blocks_effect(target, CombatInteraction.effect_context(attacker))
	_expect(is_equal_approx(target._effective_attack_speed_multiplier(), 0.65) and _phases_equal(target, 0.6, 1.0, 1.4, 0.4), "护盾奖励与减攻速按有效倍率共同换算")
	target.buffs.clear_family(&"hit_haste")
	_shield(target)
	_main._combat.begin_batch(3, "shield_reward_death")
	_main._combat.submit_damage(target, 10, attacker, 1, attacker.position)
	_main._combat.submit_damage(target, 10000, attacker, 1, attacker.position)
	_main._combat.commit_batch()
	_expect(target.hp <= 0.0 and target.buffs.remaining(&"hit_haste") <= 0.0, "同批死亡不发护盾攻速收益")

func _phases_equal(target: Unit, windup: float, recovery: float, cooldown: float, extra: float) -> bool:
	return is_equal_approx(target.attack_timeline.windup, windup) and is_equal_approx(target.attack_timeline.recovery, recovery) and is_equal_approx(target.attack_timeline.cooldown, cooldown) and is_equal_approx(float(target._pending_extra_attacks[0].time_left), extra)

func _test_tower() -> void:
	var tower: Tower = _main.world.towers_snapshot()[0]
	var target := _spawn("target_dummy", 1, tower.position + Vector2(150, 0))
	tower.can_attack = true
	tower._target = null
	tower._cooldown = 0.0
	for tick in 3: tower.sim_tick(0.05)
	_expect(_main._projectile_system.authoritative_snapshot().is_empty(), "塔首击前三步不发弹体")
	tower.sim_tick(0.05)
	_expect(_main._projectile_system.authoritative_snapshot().size() == 1, "塔0.2秒四步精确发射")
	for tick in 15: tower.sim_tick(0.05)
	_expect(_main._projectile_system.authoritative_snapshot().size() == 1, "塔间隔未到不发第二弹")
	tower.sim_tick(0.05)
	_expect(_main._projectile_system.authoritative_snapshot().size() == 2, "塔0.8秒间隔十六步精确发射")
	tower.can_attack = false
	tower._target = null
	target.free()

func _test_deployment(id: String) -> void:
	var deck: Array = [id, "garen", "ashe", "xin", "lulu", "nocturne", "malzahar", "jinx"]
	_main.runtime._deck = deck
	if _main.runtime.account(0) == null:
		var wallet := ElixirManager.new()
		_main.add_child(wallet)
		_main.runtime.bind_account(0, wallet)
	_main.runtime.account(0).elixir = 10
	_main.runtime._authoritative_card_cycles[0] = CardCycle.new(deck, false)
	var center := Vector2(360, 900)
	var victim := _spawn("garen", 1, center + Vector2(0, 110))
	victim.can_attack = false
	victim.move_speed = 0.0
	var air := _spawn("malzahar", 1, center + Vector2(0, 110))
	air.can_attack = false
	air.spawn_interval = 0.0
	var health := victim.hp
	var air_health := air.hp
	_expect(_main.play_card(0, id, center), "正式非immediate手牌命令受理:" + id)
	_run_main_ticks(9)
	_expect(_main.runtime._commands.inspect_deployments().is_empty(), "缓冲前9步没有预部署:" + id)
	_run_main_ticks(1)
	var entries: Array = _main.runtime._commands.inspect_deployments()
	_expect(entries.size() == 1 and is_equal_approx(float(entries[0].time_left), 1.3), "命令创建Tick不预扣预部署:" + id)
	_run_main_ticks(1)
	entries = _main.runtime._commands.inspect_deployments()
	_expect(entries.size() == 1 and is_equal_approx(float(entries[0].time_left), 1.25), "旧实例从下一Tick正常扣时:" + id)
	_run_main_ticks(11)
	if id == "pantheon": _expect(victim.hp == health, "潘森创建后12步还未开始扫掠")
	_run_main_ticks(1)
	if id == "pantheon": _expect(victim.hp == health - 100.0, "潘森创建后13步按0.65秒开始扫掠")
	_run_main_ticks(12)
	_expect(_units(id).is_empty(), "创建后25步尚未到场:" + id)
	_run_main_ticks(1)
	var units := _units(id)
	_expect(units.size() == 1 and is_equal_approx(units[0]._deploy_timer, float(CardDB.get_card(id).deploy_time)), "创建后26步到场且部署时钟不预扣:" + id)
	if id == "pantheon":
		_expect(victim.hp == health - 100.0, "潘森正式扫掠只伤害地面目标一次")
		_expect(air.hp == air_health, "潘森正式扫掠不伤空中目标")

func _units(id: String) -> Array:
	return _main.get_tree().get_nodes_in_group("combatants").filter(func(u): return u is Unit and u.card_id == id and u.team == 0)
