extends RefCounted

func run(harness: Object) -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	harness.root.add_child(main)
	main._deck = ["garen", "xin", "ashe", "teemo", "gnar", "freeze", "heal", "tombstone"]
	main._start_local()
	main.set_process(false)
	main._ai.enabled = false
	for scenario in ["control", "transform", "replaced", "death", "cancel", "release", "cap", "fee_changed"]:
		main._commands.clear()
		main._active_skills.clear()
		main._sim_tick_id = 0
		main._elixir.elixir = 10
		var unit: Unit = main._spawn_unit(0, "garen", Vector2(300, 800), 0, 0)
		var ability: int = unit.active_ability_id
		var entry: Dictionary = main._active_skills[ability]
		var cost: float = entry.skill.cost
		var queued: bool = main._queue_active_skill(ability, 0)
		var receipt: CommandPayment = main._commands.skill_commands[0].payment
		harness._expect(queued and main._elixir.elixir == 10 - cost, "技能入队只扣一次实际费用：" + scenario)
		var replacement: Unit
		match scenario:
			"control": unit.stun(1.0)
			"transform": unit.form_transition_timer = 1.0
			"replaced": replacement = main._spawn_unit(0, "garen", Vector2(400, 800), 0, 0)
			"death": unit.take_damage(100000)
			"cancel": main._cancel_pending_active_skill(ability)
			"cap":
				main._elixir.elixir = 10
				main._cancel_pending_active_skill(ability)
			"fee_changed":
				entry.skill.cost = cost + 5
				main._cancel_pending_active_skill(ability)
		main._sim_tick_id = main.COMMAND_DELAY_TICKS
		main._tick_pending_active_skills(0.05)
		var should_refund: bool = scenario not in ["death", "release"]
		var expected: float = 10 if should_refund else 10 - cost
		harness._expect(main._elixir.elixir == expected and receipt.is_settled() and main._commands.skill_commands.is_empty(), "取消按原因结算：" + scenario)
		receipt.settle(true)
		harness._expect(main._elixir.elixir == expected, "重复取消或已释放后的退款请求幂等：" + scenario)
		if is_instance_valid(unit): unit.free()
		if is_instance_valid(replacement): replacement.free()
	var payer := ElixirManager.new()
	payer.elixir = 8
	var receipt := CommandPayment.charge(payer, 3)
	var other := ElixirManager.new()
	other.elixir = 1
	receipt.settle(true)
	harness._expect(payer.elixir == 8 and other.elixir == 1, "收据退款给原付款者，不按当前队伍指针重新找钱包")
	var failed := CommandPayment.charge(payer, 9)
	harness._expect(failed == null and payer.elixir == 8, "余额不足不能创建可退款收据")
	var discarded := CommandPayment.charge(payer, 2)
	main._commands.skill_commands.append({"ability_id": 999, "payment": discarded})
	main._commands.clear()
	discarded.settle(true)
	harness._expect(payer.elixir == 6 and discarded.is_settled(), "终局关闭经济并结清收据，不在清场后生成退款")
	var released_payer := CommandPayment.charge(payer, 1)
	payer.free()
	released_payer.settle(true)
	harness._expect(released_payer.is_settled(), "付款者已释放时仍可安全结清收据")
	other.free()
	main.free()
