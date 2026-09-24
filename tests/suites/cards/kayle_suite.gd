extends "res://tests/suites/battle_suite.gd"
## 支付边界、排程形态锁定、主动资格及真实在途溅射。
func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	main._deck = ["kayle", "garen", "ashe", "teemo", "xin", "freeze", "heal", "pix"]
	for tower in main._towers: tower.can_attack = false
	for money in [2.99, 3.0, 5.99, 6.0, 10.0]:
		_clear()
		preload("res://tests/suites/network_fixture.gd").fixed_cycle(main, 0, main._deck)
		main._elixir.elixir = money
		var expected_id := "kayle_ranged" if money >= 6 else "kayle"
		var cost := 6 if money >= 6 else 3
		_expect(main.card_cost_for_team(0, "kayle") == cost, "费用在6金币边界同步切换")
		_expect(main._hand._display_cost("kayle", CardDB.get_card("kayle")) == cost, "手牌费用与权威一致")
		var accepted: bool = main.play_card(0, "kayle", Vector2(300, 900), {"elixir": main._elixir})
		_expect(accepted == (money >= 3), "不足3拒绝，足够3接受")
		if not accepted:
			_expect(main._commands.inspect_cards().is_empty() and is_equal_approx(main._elixir.elixir, money), "拒绝不扣费不入队")
			continue
		_expect(is_equal_approx(main._elixir.elixir, money - cost), "只扣所选形态实际费用")
		var command: Dictionary = main._commands.inspect_cards()[0]
		main._elixir.elixir = 10 if money < 6 else 0
		main._sim_tick_id = int(command.execute_tick)
		main._tick_pending_card_deployments(0.05)
		var unit: Unit = main._latest_unit_for_card("kayle", 0)
		_expect(unit != null and unit.card_id == expected_id, "等待期间跨过6金币仍保持付款形态")
		_expect(unit.active_skill_card_id == "kayle" and unit.active_ability_id >= 0, "衍生形态保留下牌与主动槽资格")
		_expect(unit.is_air and unit.can_attack_air, "两种形态都为空军并可对空")
		unit._deploy_timer = 0
		unit.hp = 100
		var ability := unit.active_ability_id
		_expect(main.use_active_skill(ability, 0), "W正式排程接受")
		var before: float = main._elixir.elixir
		for _i in 11:
			main._sim_tick_id += 1
			main._tick_pending_active_skills(0.05)
			main._commands.tick_impacts(0.05)
		_expect(unit.hp == 260 and is_equal_approx(unit.active_speed_multiplier, 1.3), "W实际开始治疗160并加速30%")
		_expect(main._elixir.elixir == before, "W不消耗金币")
		_expect(not main.use_active_skill(ability, 0), "6秒冷却不能连续施放")
		unit._tick_active_statuses(0.95)
		_expect(is_equal_approx(unit.active_speed_multiplier, 1.3), "加速前19Tick仍生效")
		unit._tick_active_statuses(0.05)
		_expect(is_equal_approx(unit.active_speed_multiplier, 1.0), "20Tick后加速结束")
		unit.prepare_action_clocks(1.0)
		main._tick_active_skill_cooldowns(6.0)
		_expect(main.use_active_skill(ability, 0), "冷却结束可以第二次释放")
		main._sim_tick_id += 10
		main._tick_pending_active_skills(0.05)
		main._commands.tick_impacts(0.05)
		_expect(unit.hp == 420, "第二次再回复160生命")
		main._tick_active_skill_cooldowns(6.0)
		_expect(not main.use_active_skill(ability, 0), "两次耗尽后不能再用")
	_clear()
	var ranged: Unit = main._spawn_unit(0, "kayle_ranged", Vector2(300, 900), 0.0)
	var target: Unit = main._spawn_unit(1, "garen", Vector2(300, 780), 0.0)
	var air: Unit = main._spawn_unit(1, "anivia", Vector2(325, 780), 0.0)
	var ally: Unit = main._spawn_unit(0, "garen", Vector2(285, 780), 0.0)
	var far: Unit = main._spawn_unit(1, "garen", Vector2(450, 780), 0.0)
	var start := [target.hp, air.hp, ally.hp, far.hp]
	_expect(main.launch_attack(ranged, target, ranged.damage, ranged.projectile_speed, ranged.splash_radius, 0, Color.YELLOW), "远程真实发射弹体")
	_expect(target.hp == start[0] and air.hp == start[1], "出手不提前造成伤害")
	ranged.free()
	for _i in 12: main._tick_projectiles(0.05)
	_expect(target.hp == start[0] - 105 and air.hp == start[1] - 105, "来源死亡后在途弹体命中地面与空中范围目标")
	_expect(ally.hp == start[2] and far.hp == start[3], "溅射不伤友方或范围外目标")
	_clear()
	var invalid := CardDB.all().duplicate(true)
	invalid.kayle.deployment_upgrade_id = 6
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all(invalid, false).is_empty(), "升级引用拒绝错误类型")
	invalid = CardDB.all().duplicate(true)
	invalid.kayle.deployment_upgrade_id = "kayle"
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all(invalid, false).is_empty(), "拒绝自引用升级")
	invalid = CardDB.all().duplicate(true)
	invalid.kayle.active_skills[0].heal_amount = -1
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all(invalid, false).is_empty(), "治疗量拒绝负数")

func _clear() -> void:
	_main._commands.clear()
	_main._projectile_system.clear_all()
	for c in _main.get_tree().get_nodes_in_group("combatants"):
		if c is Unit: c.free()
