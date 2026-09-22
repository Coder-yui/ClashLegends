extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var old_deck: Array = main._deck.duplicate()
	for card_id in ["minion_squad", "shurima_guard", "heavy_minion_squad", "siege_minion_squad", "melee_minion_squad", "ranged_minion_squad", "super_minion_squad"]:
		main._deck[0] = card_id
		main._workbench.selection = card_id
		main._workbench.team = 0
		# 走工作台真实放牌入口，保留一批旧兵和一批敌兵检查隔离。
		var old: Array[Unit] = main._spawn_card_units(0, card_id, Vector2(360, 1100), 0.0)
		var enemy: Array[Unit] = main._spawn_card_units(1, card_id, Vector2(360, 200), 0.0)
		main._place_art_dev_item(Vector2(360, 900))
		var chosen: Unit = main._art_dev_selected_unit()
		_expect(chosen != null, card_id + " 工作台记录本次下牌")
		var members: Array[Unit] = main.living_deployment_members(chosen.deployment_group_id, 0)
		for member in members: member._deploy_timer = 0.0
		chosen.take_damage(100000)
		chosen.free() # 引用已经释放，不能靠死亡对象读取部署身份。
		var survivor: Unit = main._art_dev_selected_unit()
		_expect(survivor != null and survivor in members and survivor != chosen, card_id + " 工作台在原成员释放后仍选中同批存活成员")
		main._use_art_dev_active_skill()
		for member in members:
			if is_instance_valid(member):
				_expect(member.active_buff_timer > 0 or member.shield_hp > 0, card_id + " 存活成员获得技能效果")
		for member in old + enemy:
			_expect(member.active_buff_timer == 0 and member.shield_hp == 0, card_id + " 其他批次与敌军不受影响")
		for member in members:
			if is_instance_valid(member): member.free()
		_expect(main._art_dev_selected_unit() == null, card_id + " 最新批次全灭不能回退旧批次")
		# 同卡再次下牌：旧批的待施放请求退款作废，死亡不能夺回主动槽。
		var previous: Array[Unit] = main._spawn_card_units(0, card_id, Vector2(360, 900), 0.0, 0)
		var old_ability := previous[0].active_ability_id
		main._elixir.elixir = 10
		_expect(main.use_active_skill(old_ability, 0), card_id + " 旧批技能先入队")
		var newest: Array[Unit] = main._spawn_card_units(0, card_id, Vector2(360, 1000), 0.0, 0)
		var new_ability := newest[0].active_ability_id
		_expect(not main.use_active_skill(old_ability, 0) and main._elixir.elixir == 10 and main._commands.inspect_skills().is_empty(), card_id + " 新批替换旧资格并取消退款")
		previous[0].take_damage(100000)
		newest[0].take_damage(100000)
		_expect(main._active_skills.has(new_ability) and main._active_skills.entry(new_ability).unit in newest and not main._active_skills.has(old_ability), card_id + " 新旧队长死亡只转交最新批次")
		for member in newest:
			if member.hp > 0: member.take_damage(100000)
		_expect(not main.use_active_skill(old_ability, 0) and not main._active_skills.has(new_ability), card_id + " 最新批全灭也不恢复旧批资格")
		for member in previous + newest: member.free()
		# 正式资格：请求付款后连续失去持有者，剩余成员只执行一次。
		var paid: Array[Unit] = main._spawn_card_units(0, card_id, Vector2(360, 900), 0.0, 0)
		var ability := paid[0].active_ability_id
		main._elixir.elixir = 10
		_expect(main.use_active_skill(ability, 0), card_id + " 正式技能入队")
		var balance: float = main._elixir.elixir
		for i in range(paid.size() - 1): paid[i].take_damage(100000)
		main._sim_tick_id += 10
		main._tick_pending_active_skills(0.05)
		var last := paid.back() as Unit
		_expect(last.active_buff_timer > 0 or last.shield_hp > 0, card_id + " 等待期间连续死亡后最后成员仍施放")
		_expect(main._elixir.elixir == balance and main._active_skills.entry(ability).uses_remaining == main._active_skills.entry(ability).max_uses - 1, card_id + " 转交不重复收费不重置次数")
		last.take_damage(100000)
		_expect(not main._active_skills.has(ability), card_id + " 全灭清除正式资格")
		for member in old + enemy + paid:
			if is_instance_valid(member): member.free()
	# 共享成员卡不能混淆部署来源；延迟效果在落地时重新筛选存活成员。
	var mixed: Array[Unit] = main._spawn_card_units(0, "minion_squad", Vector2(360, 900), 0.0)
	var melee: Array[Unit] = main._spawn_card_units(0, "melee_minion_squad", Vector2(360, 1000), 0.0)
	_expect(main._latest_unit_for_card("minion_squad", 0) in mixed, "共享近战兵成员的不同卡牌不会串批")
	var delayed: Dictionary = CardDB.active_skills_for("minion_squad")[0].duplicate(true)
	delayed["impact_delay"] = 0.2
	delayed["cast_duration"] = 0.2
	main.preview_active_skill(mixed[0], delayed)
	mixed[1].take_damage(100000)
	main._commands.tick_impacts(0.2)
	_expect(mixed[1].active_buff_timer == 0 and mixed[2].active_buff_timer > 0 and melee[0].active_buff_timer == 0, "效果落地时剔除期间死亡的成员并隔离共享成员卡")
	for member in mixed + melee: member.free()
	main._deck = old_deck
	main._workbench.last_units.clear()
	main._workbench.last_groups.clear()
