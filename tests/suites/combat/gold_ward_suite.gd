extends "res://tests/suites/battle_suite.gd"

class RewardBattle extends "res://tests/fixtures/authority_battle.gd":
	var reward_audio_events := 0
	func present_skill_projectile_hit(source: Dictionary, action: String, pos: Vector2, phase: String = "hit") -> void:
		if action == "bounty" and phase == "gain": reward_audio_events += 1
		super.present_skill_projectile_hit(source, action, pos, phase)

func run(harness: Object) -> void:
	_harness = harness
	_check_shared_production_clock()
	_main = RewardBattle.new()
	harness.root.add_child(_main)
	var ward_stats := CardDB.get_card("gold_ward")
	_expect(PresentationEvents.supports(ward_stats, "bounty:gain"), "金币守卫声明收益声音派发能力")
	_expect(ward_stats.audio.events["bounty:gain"].pool == CardDB.get_card("powder_keg").audio.events["bounty:gain"].pool, "金币收益复用已有三条声音资源")
	for team in 2:
		var wallet := ElixirManager.new()
		_main.add_child(wallet)
		_main.runtime.bind_account(team, wallet)
		wallet.elixir = 0
	for team in 2:
		var ward := _spawn_ready_unit("gold_ward", team, Vector2(360, 800 if team == 0 else 400))
		var wallet: ElixirManager = _main.runtime.account(team)
		_tick(ward, 1) # 完成部署后的计时起点
		_tick(ward, 99)
		_expect(wallet.elixir == 0, "金币守卫首次收益不得早于5秒")
		var event_before: int = _main.reward_audio_events
		_tick(ward, 1)
		_expect(_main.reward_audio_events == event_before + 1, "周期实际入账同步派发一次收益声音事件")
		_expect(wallet.elixir == 1, "金币守卫第100Tick所属方获得1金币")
		for state in ["stun", "freeze", "stasis"]:
			var before := wallet.elixir
			match state:
				"stun": ward.stun(6.0)
				"freeze": ward.freeze(6.0)
				"stasis": ward.apply_stasis(6.0)
			var hp_before := ward.hp
			_tick(ward, 110)
			_expect(wallet.elixir == before and (ward.hp == hp_before if state == "stasis" else ward.hp < hp_before), "受控延后产出，仅凝滞暂停自然衰血：" + state)
			_tick(ward, 10)
			_expect(wallet.elixir == before + 1, "解除后只补发一次：" + state)
		ward.take_damage(10000)
		var after := wallet.elixir
		ward._die(true)
		_expect(after == 6 and wallet.elixir == after, "死亡给所属方2金币且重复死亡不重复发放")
		ward.free()
		wallet.elixir = 0
		ward = _spawn_ready_unit("gold_ward", team, Vector2(360, 800 if team == 0 else 400))
		_tick(ward, 640)
		_expect(ward.hp == 0 and wallet.elixir == 8, "完整寿命六次产出及自然死亡两金币")
		ward.free()
		wallet.elixir = 9.5
		ward = _spawn_ready_unit("gold_ward", team, Vector2(360, 800 if team == 0 else 400))
		_tick(ward, 101)
		_expect(wallet.elixir == 10, "周期收益服从金币上限")
		event_before = _main.reward_audio_events
		_tick(ward, 100)
		_expect(_main.reward_audio_events == event_before, "满金币零入账不派发收益声音")
		ward.free()
		_expect(wallet.elixir == 10, "直接清场不触发死亡收益")
	var ward := _spawn_ready_unit("gold_ward", 0, Vector2(360, 800))
	var skill: Dictionary = CardDB.active_skills_for("gold_ward")[0]
	_main._active_skill_effect_system.apply(ward, skill)
	_expect(CombatInteraction.in_stasis(ward) and is_equal_approx(ward.control.stasis_timer, 2.5), "完美时机通过正式效果入口进入2.5秒凝滞")
	var hp := ward.hp
	ward.take_damage(200)
	_expect(ward.hp == hp, "主动凝滞拒绝外来伤害")
	_tick(ward, 49)
	_expect(CombatInteraction.in_stasis(ward), "凝滞第49Tick仍有效")
	_tick(ward, 1)
	_expect(not CombatInteraction.in_stasis(ward), "凝滞第50Tick解除")
	ward.free()
	_main.runtime._deck = ["gold_ward", "garen", "xin", "ashe", "teemo", "gnar", "heal", "freeze"]
	_main.runtime.account(0).elixir = 0
	ward = _main._spawn_unit(UnitSpawnRequest.new(0, "gold_ward", Vector2(360, 800), {"active_slot": 0}))
	_tick(ward, 19)
	_expect(not ward.is_deployed() and _main.runtime.account(0).elixir == 0, "部署中无金币产出")
	_tick(ward, 1)
	_expect(ward.is_deployed(), "正常1秒部署完成")
	_tick(ward, 99)
	_expect(_main.runtime.account(0).elixir == 0, "部署完成后不足5秒不产出")
	_tick(ward, 1)
	_expect(_main.runtime.account(0).elixir == 1, "部署完整5秒首跳")
	var ability := ward.active_ability_id
	_expect(_main.use_active_skill(ability, 0), "正式技能入口接受免费完美时机")
	_main.runtime._sim_tick_id += _main.COMMAND_DELAY_TICKS
	_main.runtime._tick_pending_active_skills(0.05)
	_expect(CombatInteraction.in_stasis(ward), "命令排程后正式施加凝滞")
	_expect(not _main.use_active_skill(ability, 0), "一次机会消费后拒绝重复请求")
	_tick(ward, 50)
	_expect(not _main.use_active_skill(ability, 0), "解除凝滞后仍不能绕过次数限制")
	ward.free()
	var invalid := CardDB.get_card("gold_ward").duplicate(true)
	invalid.elixir_interval = 0.0
	_expect(not CardDB.VALIDATOR.validate_all({"gold_ward": invalid}, false).is_empty(), "零金币周期被校验拒绝")
	invalid = CardDB.get_card("gold_ward").duplicate(true)
	invalid.erase("elixir_amount")
	_expect(not CardDB.VALIDATOR.validate_all({"gold_ward": invalid}, false).is_empty(), "不完整金币配置被校验拒绝")
	_main.free()
	_main = null

func _tick(unit: Unit, count: int) -> void:
	for index in count:
		_main.runtime._sim_tick_id += 1
		unit.sim_tick(0.05)

func _check_shared_production_clock() -> void:
	var clock := PeriodicProduction.new()
	clock.reset(5.0)
	_expect(not clock.tick(4.95, 5.0, false), "通用产出时钟不提前发出")
	_expect(not clock.tick(0.05, 5.0, true) and clock.remaining == 0.0, "受控到期保留一次待发")
	_expect(not clock.tick(30.0, 5.0, true) and clock.remaining == 0.0, "跨多个周期也不积累多个待发")
	_expect(clock.tick(0.05, 5.0, false) and clock.remaining == 5.0, "解除立即发出并重计完整周期")
	_expect(not clock.tick(0.05, 5.0, false), "解除后的下一Tick不连发")
	var unit := Unit.new()
	unit.setup(0, CardDB.get_card("gold_ward"), "production control")
	unit.stun(1.0)
	unit.freeze(1.0)
	_expect(PeriodicProduction.blocked(unit), "通用门禁接受重叠控制")
	unit.control.hard.clear_family(&"stun")
	_expect(PeriodicProduction.blocked(unit), "部分解控仍阻止产出")
	unit.control.hard.clear_family(&"freeze")
	_expect(not PeriodicProduction.blocked(unit), "全部解控才放行")
	unit.apply_stasis(1.0)
	_expect(PeriodicProduction.blocked(unit), "通用门禁同样覆盖凝滞")
	unit.free()
