extends "res://tests/suites/battle_suite.gd"
## Runtime迁移专项：无UI/模型/音频/预热/端口，只使用有限权威实体及副本。
class TracedCombat extends CombatResolver:
	var phases: Array[String] = []
	var settled: Array[String] = []
	func begin_batch(tick: int, phase: String) -> void:
		phases.append(phase)
		super.begin_batch(tick, phase)
	func commit_batch() -> void:
		var phase := _phase
		super.commit_batch()
		if not collecting and not committing: settled.append(phase)

class RequestProbe extends "res://tests/fixtures/authority_battle.gd":
	var card_requests := 0
	var skill_requests := 0
	func _send_card_request(_card: String, _pos: Vector2, _tick: int, _request: int) -> void:
		card_requests += 1
	func _send_skill_request(_id: int, _tick: int, _request: int) -> void:
		skill_requests += 1

func run(harness: Object) -> void:
	_harness = harness
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	_install_trace()
	_configure()
	_check_admission()
	_check_skills()
	_check_group_and_ai()
	_check_batches()
	_check_rules()
	_main.free()
	_main = RequestProbe.new()
	_main.runtime.mode = "client"
	harness.root.add_child(_main)
	_check_replica()
	_main.free()
	_main = null

func _install_trace() -> void:
	var previous: CombatResolver = _main._combat
	var combat := TracedCombat.new()
	combat._next_source_id = previous._next_source_id
	_main.add_child(combat)
	_main._combat = combat
	_main.runtime._combat = combat
	_main.runtime._skill_lifecycle._combat = combat
	previous.free()

func _configure() -> void:
	var r = _main.runtime
	r._deck = ["garen", "lulu", "ashe", "teemo", "gnar", "freeze", "heal", "tombstone"]
	r._remote_deck = r._deck.duplicate()
	for team in [0, 1]:
		var wallet := ElixirManager.new()
		_main.add_child(wallet)
		wallet.elixir = 10
		r.bind_account(team, wallet)
		r._authoritative_card_cycles[team] = CardCycle.new(r._team_deck(team), false)
	_expect(r.account(0).get_parent() == _main and r.account(1).get_parent() == _main and r.account(0) != r.account(1), "Runtime绑定场景的两个独立钱包，没有Main余额别名")
	var fields: Array = _main.get_property_list().map(func(p): return p.name)
	_expect(not fields.has("_commands") and not fields.has("_active_skills") and not fields.has("_match_rules") and not fields.has("_authoritative_card_cycles") and not fields.has("_sim_tick_id"), "Main不再持有命令/资格/规则/牌序/权威Tick或兼容镜像")
	_expect(not r.get_property_list().any(func(p): return p.name == "_controller"), "Runtime不持有Main控制器或回调原状态")

func _check_admission() -> void:
	var r = _main.runtime
	var original: Dictionary = r.visible_hand_state(0)
	var invalid: Array = [
		[2, "garen", Vector2(300, 900), {}],
		[0, "missing", Vector2(300, 900), {}],
		[0, "garen", Vector2.INF, {}],
		[0, "garen", Vector2(300, 300), {}],
		[0, "gnar", Vector2(300, 900), {}],
		[0, "garen", Vector2(300, 900), {"input_tick": 3}],
		[0, "garen", Vector2(300, 900), {"elixir": r.account(1)}],
	]
	for request in invalid:
		_expect(not r.play_card(request[0], request[1], request[2], request[3]), "无效请求由同一领域入口拒绝")
	_expect(r.account(0).elixir == 10 and r.visible_hand_state(0) == original and r._commands.inspect_cards().is_empty() and r._card_history.get_last(0).is_empty(), "拒绝请求不扣费、不轮换、不写历史、不排程")
	r._sim_tick_id = 30
	_expect(not r.play_card(0, "garen", Vector2(300, 900), {"input_tick": 20}) and r.account(0).elixir == 10, "耗尽Buffer的请求不追加等待、不扣费")
	r._sim_tick_id = 0
	_main._client_inputs.card("garen", 71, Vector2.ZERO)
	_expect(_main.play_card(0, "garen", Vector2(300, 900)), "权威受理不读取本机手牌控件或客户端pending")
	_expect(r.account(0).elixir == 10 - r.card_cost_for_team(0, "garen") and r.account(1).elixir == 10, "未显式传钱包的正式请求仍只向绑定账户付款一次")
	var accepted: Dictionary = r.visible_hand_state(0)
	_expect(accepted.version == original.version + 1 and not "garen" in accepted.hand and accepted.history.card_id == "garen", "接受后才轮换一次并记录成功历史")
	_expect(not _main.play_card(0, "garen", Vector2(300, 900)) and r.visible_hand_state(0) == accepted, "重复出牌因权威牌序拒绝，没有重复付款或轮换")
	_expect(r._commands.inspect_cards().size() == 1 and int(r._commands.inspect_cards()[0].execute_tick) == 10, "本地/服务端共同计算10Tick排程")
	for tick in 9: r.step(0.05)
	_expect(_main.world.authoritative_units_snapshot().is_empty(), "第9Tick仍未出生")
	r.step(0.05)
	var units: Dictionary = _main.world.authoritative_units_snapshot()
	var unit: Unit = units.values()[0]
	_expect(units.size() == 1 and unit.lifecycle_birth_tick == 10 and is_equal_approx(unit._deploy_timer, unit.deploy_time), "第10Tick出生，出生Tick不扣部署时钟")
	r.step(0.05)
	_expect(is_equal_approx(unit._deploy_timer, unit.deploy_time - 0.05) and r._commands.inspect_cards().is_empty(), "下一Tick才推进部署，命令只兑现一次")
	_expect(not r._can_submit_active_skill(unit.active_ability_id, 0), "未部署单位不能提交主动")
	_main.world.clear_units()
	_main._client_inputs.clear()
	_main._network_commands.clear()
	r._sim_tick_id = 0

func _spawn_skill() -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(0, "garen", Vector2(300, 900), {"deploy_time_override": 0.0, "active_slot": 0}))

func _check_skills() -> void:
	var r = _main.runtime
	for scenario in ["control", "replacement", "death", "cancel", "release", "cap", "fee_changed"]:
		r.account(0).elixir = 10
		var unit := _spawn_skill()
		var id := unit.active_ability_id
		var cost: float = r._active_skills.cost(id)
		var before: Dictionary = r.get_active_skill_snapshot(id)
		_main._client_inputs.skill(id, 99)
		_main._network_commands.create("skill", 0, "garen", id, unit.position, r._sim_tick_id, r._sim_tick_id + 10)
		_expect(not r._queue_active_skill(id, 1) and r.account(0).elixir == 10, "错误阵营不能使用技能：" + scenario)
		_expect(_main.use_active_skill(id, 0) and r.account(0).elixir == 10 - cost, "主动受理只看领域资格/账户，忽略适配pending：" + scenario)
		var payment: CommandPayment = r._commands.inspect_skills()[0].payment
		_expect(not r._queue_active_skill(id, 0) and r.account(0).elixir == 10 - cost, "领域队列拒绝重复主动：" + scenario)
		var replacement: Unit
		match scenario:
			"control": unit.stun(1.0)
			"replacement": replacement = _spawn_skill()
			"death": unit.take_damage(100000)
			"cancel": r._cancel_pending_active_skill(id)
			"cap":
				r.account(0).elixir = 10
				r._cancel_pending_active_skill(id)
			"fee_changed":
				var definition: Dictionary = r._active_skills.entry(id).skill.duplicate(true)
				definition.cost = cost + 5
				SuiteUtils.replace_carried_skill(r._active_skills, id, definition)
				r._cancel_pending_active_skill(id)
		r._sim_tick_id += 10
		r._tick_pending_active_skills(0.05)
		var refund: bool = scenario not in ["death", "release"]
		var expected: float = 10 if refund else 10 - cost
		_expect(payment.is_settled() and r.account(0).elixir == expected and r._commands.inspect_skills().is_empty(), "兑现/取消依原因结算原收据：" + scenario)
		payment.settle(true)
		r._cancel_pending_active_skill(id)
		_expect(r.account(0).elixir == expected, "重复取消/结算不重复收益：" + scenario)
		if scenario in ["control", "cancel", "cap", "fee_changed"]:
			_expect(r.get_active_skill_snapshot(id) == before, "取消保留次数与冷却：" + scenario)
		if scenario == "release":
			_expect(int(r.get_active_skill_snapshot(id).uses_remaining) == int(before.uses_remaining) - 1, "成功施放只消费一次次数")
		_main.world.clear_units()
		r._commands.clear()
		_main._client_inputs.clear()
		_main._network_commands.clear()
		r._active_skill_effect_system.clear()
		r._active_skills.clear()

func _check_group_and_ai() -> void:
	var r = _main.runtime
	r._deck[0] = "pix"
	r.account(0).elixir = 10
	var group: Array[Unit] = r._spawn_card_units(0, "pix", Vector2(300, 900), 0.0, 0)
	var id := group[0].active_ability_id
	_expect(group.size() == 5 and r._queue_active_skill(id, 0), "编队只登记一份主动资格并受理一次")
	group[0].take_damage(100000)
	var replacement: Unit = r._active_skills.entry(id).unit
	_expect(replacement != group[0] and replacement in group and r._commands.has_pending_skill(id), "来源死亡只在同一部署编队转交资格，保留已付款命令")
	r._sim_tick_id += 10
	r._tick_pending_active_skills(0.05)
	_expect(int(r.get_active_skill_snapshot(id).uses_remaining) == 0 and r.account(0).elixir == 9, "转交后的同一命令仅消费一次次数与费用")
	_main.world.clear_units()
	r._deck[0] = "garen"
	_main.runtime.mode = "local"
	var ai := AIOpponent.new()
	_main.add_child(ai)
	ai.setup(_main)
	ai.enabled = false
	_expect(r.account(1) == ai._elixir and r.ai == ai, "AI钱包绑定同一个Runtime账户，策略没有第二份余额")
	r._authoritative_card_cycles[1] = CardCycle.new(r._remote_deck, false)
	ai._elixir.elixir = 10
	_expect(_main.play_card(1, "garen", Vector2(300, 380), {"elixir": ai._elixir}), "单机AI来源共用正式出牌受理")
	_expect(ai._elixir.elixir == 5 and r._commands.inspect_cards().size() == 1, "AI请求向同一账户扣费并排一条命令")
	r._commands.clear()
	r._active_skills.clear()
	_main.runtime.mode = "server"

func _check_batches() -> void:
	var r = _main.runtime
	var combat: TracedCombat = _main._combat
	combat.phases.clear()
	combat.settled.clear()
	var target: Unit = _main._spawn_unit(UnitSpawnRequest.new(1, "target_dummy", Vector2(360, 800), {"deploy_time_override": 0.0}))
	var source := _spawn_skill()
	var events: Array[String] = []
	target.died.connect(func(): events.append("death"))
	var original: Callable = r._commands.impact
	r._commands.impact = func(_unit: Unit, _skill: Dictionary):
		combat.submit_damage(target, target.hp + 100, source, 0, source.position)
		events.append("collect")
		combat.defer_effect(func(): events.append("effect"))
		combat.defer_benefit(func(): events.append("benefit"))
	r._commands.enqueue_impact(source, {"independent_result": RefCounted.new()}, 0.05)
	r.step(0.05)
	r._commands.impact = original
	var phases: Array[String] = ["skill_impacts", "skill_effects", "skill_commands", "spell_zones", "combatants", "pre_deployment", "projectiles"]
	_expect(combat.phases == phases and combat.settled == phases, "Simulation保持所有独立批次、顺序与逐批提交，不合并全Tick交易")
	_expect(events == ["collect", "effect", "benefit", "death"], "真实致死提交保持收集→效果→收益→死亡顺序")
	_expect(not r._sim_step_active and not combat.collecting and not combat.committing, "完整Tick归还阶段权限")
	_main.world.clear_units()

func _check_rules() -> void:
	var r = _main.runtime
	r._match_started = true
	r._match_rules.time_left = 60.05
	r.account(0).elixir = 0
	r.account(1).elixir = 0
	r.account(0)._timer = 2.75
	r.account(1)._timer = 2.75
	r.step(0.05)
	_expect(r.account(0).elixir == 1 and r.account(1).elixir == 1, "比赛阶段只推进绑定钱包一次，双方同Tick回复")
	_expect(r.account(0).regen_multiplier == 2 and r.account(1).regen_multiplier == 2, "比赛时钟更新后同步双方金币倍率")
	r._match_rules.time_left = 0.05
	r.step(0.05)
	_expect(r._match_rules.overtime and r._match_rules.time_left == MatchRules.OVERTIME_TIME and not r.game_over, "规则对象进入加时，Runtime不复制第二套phase")
	_expect(r.session == _main.runtime.session, "会话仍使用唯一MatchSession")
	r._match_rules.time_left = 60
	r._update_elixir_rate()
	_expect(r.account(0).regen_multiplier == 3, "加时最后一分钟使用原三倍金币")
	var unit := _spawn_skill()
	r.account(0).elixir = 10
	_expect(r._queue_active_skill(unit.active_ability_id, 0), "终局前接受技能")
	var receipt: CommandPayment = r._commands.inspect_skills()[0].payment
	var coins: float = r.account(0).elixir
	_main.world.king(1).take_damage(100000)
	r.step(0.05)
	_expect(r.game_over and r._match_rules.finished and _main._terminal_result.winner_team == 0 and _main._terminal_result.reason == "nexus", "完整Tick后按原水晶规则生成真实终态")
	var tick: int = r._sim_tick_id
	r.step(0.05)
	receipt.settle(true)
	_expect(r._sim_tick_id == tick and r._commands.inspect_skills().is_empty() and receipt.is_settled() and r.account(0).elixir == coins, "终局阻止推进并关闭未执行收据，不在清场后退款")

func _check_replica() -> void:
	var r = _main.runtime
	var wallet := ElixirManager.new()
	_main.add_child(wallet)
	r.bind_account(0, wallet)
	r._match_started = true
	var snapshot := {"uses_remaining": 1, "cooldown_left": 3.0, "free_recast": false}
	var unit: Unit = _main._spawn_unit(UnitSpawnRequest.new(0, "garen", Vector2(300, 900), {"deploy_time_override": 0.0, "active_slot": 0}))
	r.apply_skill_replica(unit.active_ability_id, snapshot.uses_remaining, snapshot.cooldown_left)
	r.apply_match_replica(7, 42, true)
	var before: Dictionary = r.get_active_skill_snapshot(unit.active_ability_id)
	var pos := unit.position
	var hp := unit.hp
	r.step(0.05)
	r._battle_simulation.step(0.05)
	r._simulation_clock.advance(0.2)
	_expect(r._sim_tick_id == 0 and unit.position == pos and unit.hp == hp and r._match_rules.time_left == 42 and r.get_active_skill_snapshot(unit.active_ability_id) == before and wallet.elixir == 7, "客户端直接/固定时钟/Simulation入口均不推进权威状态")
	_expect(not r.play_card(0, "garen", pos) and not r._queue_active_skill(unit.active_ability_id, 0) and not r._activate_active_skill(unit.active_ability_id, 0), "客户端不能直接受理、付款或兑现权威动作")
	_expect(r._authoritative_card_cycles.is_empty() and r.visible_hand_state(0).is_empty(), "客户端不创建或泄漏权威牌序")
	_expect(r.network_match_snapshot(0).elixir == 7 and r.network_match_snapshot(0).overtime and r.get_active_skill_snapshot(unit.active_ability_id) == snapshot, "副本状态经Runtime操作提交后可供只读投影")
	r._deck = ["garen", "lulu", "ashe", "teemo", "gnar", "freeze", "heal", "tombstone"]
	var visible := CardCycle.new(r._deck, false).visible_state(0, {})
	_expect(_main._apply_client_hand_state(visible), "客户端可见手牌由网络适配接收")
	_expect(_main.play_card(0, "garen", pos, {"client_request": true}) and _main.card_requests == 1 and _main._client_inputs.has_card("garen"), "客户端正式入口仅发送请求并记录输入反馈")
	_expect(not _main.play_card(0, "garen", pos, {"client_request": true}) and _main.card_requests == 1 and wallet.elixir == 7 and r._commands.inspect_cards().is_empty(), "客户端重复pending只抑制发送，不轮换权威牌序或扣费")
	r.apply_skill_replica(unit.active_ability_id, 1, 0.0)
	_expect(_main.use_active_skill(unit.active_ability_id, 0, 0, true) and _main.skill_requests == 1, "客户端主动入口同样仅提交网络请求")
	_expect(not _main.use_active_skill(unit.active_ability_id, 0, 0, true) and wallet.elixir == 7 and r._commands.inspect_skills().is_empty() and r.get_active_skill_snapshot(unit.active_ability_id).uses_remaining == 1, "客户端反馈不消费权威主动次数、不付款、不排权威命令")
