extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var ai: AIOpponent = main._ai
	_expect(main._team_deck(1) == main._remote_deck and main._team_deck(0) == main._deck, "AI和玩家分别查询自己的卡组")
	for index in 20:
		var deck := AIOpponent.build_deck()
		_expect(MatchSession.valid_deck(deck, {}), "AI随机卡组合法且无重复：%d" % index)
	var ally := _spawn_test_unit("garen", 1, Vector2(140, 460))
	var enemy := _spawn_test_unit("garen", 0, Vector2(580, 820))
	_expect(not ai._spell_position("heal", CardDB.get_card("heal")).is_finite(), "AI满血不浪费治疗术")
	ally.hp -= 200
	_expect(ai._spell_position("heal", CardDB.get_card("heal")).distance_to(ally.position) < 40, "AI治疗选受伤友军")
	_expect(ai._spell_position("zap", CardDB.get_card("zap")).distance_to(enemy.position) < 40, "AI伤害法术优先敌军而非友军")
	for card_id in ["pantheon", "twisted_fate"]:
		var pos := ai._position(card_id, CardDB.get_card(card_id))
		_expect(pos.y > 640 and main.is_card_deploy_position_valid(1, card_id, pos), "AI全场卡进入敌方半场：" + card_id)
	var building_pos := ai._position("tombstone", CardDB.get_card("tombstone"))
	_expect(absf(building_pos.x - 360) <= 20 and building_pos.y < 600 and main.is_card_deploy_position_valid(1, "tombstone", building_pos), "AI建筑合法中置拉扯")
	var skill: Dictionary = CardDB.active_skills_for("garen")[0]
	_expect(not ai._skill_useful(ally, skill), "AI远离敌人时保留攻击技能")
	enemy.position = ally.position + Vector2(0, 65)
	_expect(ai._skill_useful(ally, skill), "AI交战距离内考虑攻击技能")
	var heal_skill: Dictionary = CardDB.active_skills_for("kayle")[0]
	_expect(ai._skill_useful(ally, heal_skill), "AI受伤时考虑治疗主动")
	ally.hp = ally.max_hp
	_expect(not ai._skill_useful(ally, heal_skill), "AI满血即使交战也保留治疗主动")
	# 固定手牌与意图，验证从6费等待到真实高费出牌，走正式扣费与命令队列。
	main._remote_deck = ["garen", "ashe", "rift_herald", "heal", "pantheon", "tombstone", "zap", "xin"]
	main._authoritative_card_cycles[1] = CardCycle.new(main._remote_deck, false)
	ai.enabled = true
	ai._planned_card = "rift_herald"
	ai._elixir.elixir = 6
	ai._think_timer = 0
	ai.sim_tick(1.0)
	_expect(ai._elixir.elixir == 6 and ai._planned_card == "rift_herald", "AI保留费用等待先锋，不改出便宜牌")
	ai._elixir.elixir = 10
	ai.sim_tick(1.0)
	_expect("rift_herald" not in main.get_authoritative_hand(1) and ai._elixir.elixir < 10, "AI高费卡正式扣费并轮换手牌")
	main._remote_deck[2] = "shurima_guard"
	main._authoritative_card_cycles[1] = CardCycle.new(main._remote_deck, false)
	ai._planned_card = "shurima_guard"
	ai._elixir.elixir = 6
	ai.sim_tick(1.0)
	_expect(ai._elixir.elixir == 6, "AI为恕瑞玛卫队保留金币")
	ai._elixir.elixir = 7
	ai.sim_tick(1.0)
	_expect("shurima_guard" not in main.get_authoritative_hand(1) and ai._elixir.elixir == 0, "AI攒足7费出恕瑞玛卫队")
	# 部署未完成时不能提交；部署就绪后后续思考仍会再尝试。
	ally.active_ability_id = 9876
	ally.active_ability_slot = 0
	main._remote_active_skill_choices.clear()
	main._register_active_skill(ally, "garen", 1)
	ai._elixir.elixir = 10
	ally._deploy_timer = 1.0
	ai._try_skills(0)
	_expect(not main._commands.has_pending_skill(9876), "AI部署期间不提交技能")
	ally._deploy_timer = 0.0
	ai._try_skills(10)
	_expect(not main._commands.has_pending_skill(9876), "AI攒牌时不挪用预留费用放技能")
	ai._try_skills(0)
	_expect(main._commands.has_pending_skill(9876), "AI部署完成后重新判断并提交技能")
	ai.enabled = false
