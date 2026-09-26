extends "res://tests/suites/battle_suite.gd"
const FIXTURE = preload("res://tests/suites/network_fixture.gd")
const DECK := ["mirror", "ashe", "garen", "heal", "freeze", "kayle", "shurima_guard", "tombstone"]

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_opening()
	main._deck = DECK.duplicate()
	main._active_skill_choices = {"garen": 1, "heal": 1}
	for tower in main._towers: tower.can_attack = false
	_reset()
	_put_in_hand("mirror")
	var before: Array = main.get_authoritative_hand(0)
	_expect(not main.play_card(0, "mirror", Vector2(300, 900), {"elixir": main._elixir}) and main.get_authoritative_hand(0) == before and main._elixir.elixir == 10, "无历史镜像拒绝且不扣费轮换")
	_expect(_play("garen"), "普通槽盖伦接受")
	var original := _latest("garen")
	_expect(original != null and original.active_ability_id == -1, "普通槽原卡不携带技能")
	_expect(main.card_cost_for_team(0, "mirror") == 5, "镜像费用等于原卡基础费用")
	_expect(not main.is_card_deploy_position_valid(0, "mirror", Vector2(300, 300)), "镜像单位继承己方部署区")
	_expect(_play("mirror"), "主动镜像正式接受并部署")
	var copied := _latest("garen")
	var copied_id := copied.active_ability_id
	_expect(copied != original and copied_id >= 0 and copied.active_ability_slot == 0, "复制体占镜像槽而非原卡槽")
	_expect(main._active_skills.entry(copied_id).skill == CardDB.active_skills_for("garen")[1], "普通席预选第二技能用于镜像")
	copied._deploy_timer = 0
	_expect(main.use_active_skill(copied_id, 0), "普通席复制体可走正式技能请求")
	_expect(_play("ashe"), "另一个主动槽部署")
	var other := _latest("ashe")
	_expect(other.active_ability_slot == 1, "原主动槽独立存在")
	_expect(_play("mirror"), "第二轮镜像接受")
	var new_copy := _latest("ashe")
	_expect(is_instance_valid(copied) and copied.hp > 0 and copied.active_ability_id == -1 and not main._active_skills.has(copied_id), "旧复制体存活但技能资格被替换")
	_expect(not main._commands.has_pending_skill(copied_id), "替换取消旧槽待释放请求")
	_expect(new_copy.active_ability_slot == 0 and other.active_ability_slot == 1 and main._active_skills.ids().size() == 2, "同英雄原体与镜像最多左右两个技能")
	# 镜像法术也必须替换旧单位资格，不能残留第三个可操作来源。
	_expect(_play("heal"), "非主动治疗接受")
	_expect(main.card_cost_for_team(0, "mirror") == 2, "治疗镜像保持2费，不额外加原法术强化费")
	new_copy.hp -= 50
	_expect(_play("mirror"), "镜像强化治疗接受")
	_expect(new_copy.active_ability_id == -1 and main._active_skills.ids().size() == 1 and new_copy.shield_hp > 0, "复制法术清空旧镜像技能并使用预选过量治疗")
	# 普通镜像不能偷用原主动槽的资格。
	_reset()
	main._deck = ["garen", "ashe", "mirror", "heal", "freeze", "kayle", "shurima_guard", "tombstone"]
	FIXTURE.fixed_cycle(main, 0, main._deck)
	_expect(_play("garen") and _play("mirror"), "普通镜像复制主动席单位")
	_expect(_latest("garen").active_ability_id == -1 and main._active_skills.ids().size() == 1, "普通镜像无技能，原主动单位资格保留")
	# 付款时锁定形态；之后金币变动或新的出牌不改变已入队镜像。
	_reset()
	main._deck = DECK.duplicate()
	FIXTURE.fixed_cycle(main, 0, main._deck)
	_expect(_play("kayle"), "6费天使接受")
	_expect(main._card_history.get_last(0).deployment_card_id == "kayle_ranged", "记录原卡实际部署形态")
	_put_in_hand("mirror")
	main._elixir.elixir = 6
	_expect(main.play_card(0, "mirror", Vector2(300, 900), {"elixir": main._elixir}), "镜像按6费锁定远程形态")
	var command: Dictionary = main._commands.inspect_cards().back()
	main._card_history.record(0, "freeze", "freeze", 3)
	main._elixir.elixir = 0
	main._sim_tick_id = int(command.execute_tick)
	main._tick_pending_card_deployments(0.05)
	_expect(_latest("kayle").card_id == "kayle_ranged", "后续历史及金币变化不改变镜像排程")
	# 编队技能仍按新部署编号转交，不回到旧批。
	_reset()
	_expect(_play("shurima_guard") and _play("mirror"), "镜像六人编队")
	var captain: Unit = main._active_skills.entry(int(main._active_skills.ids()[0])).unit
	var group := captain.deployment_group_id
	var ability := captain.active_ability_id
	_expect(main.living_deployment_members(group, 0).size() == 6 and ability >= 0, "镜像生成完整六人独立编队")
	captain.hp = 0
	main._on_active_skill_unit_died(ability)
	_expect(main._active_skills.has(ability) and main._active_skills.entry(ability).unit.deployment_group_id == group, "镜像队长死亡资格转交本批成员")
	_check_queued_spell()
	_check_delayed_replacement()
	_check_building_and_rejections()
	_check_replica()
	_check_resources()
	_check_workbench()
	_reset()

func _check_opening() -> void:
	var positions := {}
	var firsts := {}
	for index in 256:
		var cycle := CardCycle.new(DECK)
		var all_cards := cycle.hand() + cycle.queue()
		_expect("mirror" not in cycle.hand() and cycle.queue().has("mirror") and all_cards.size() == 8, "随机首手排除镜像并保留8牌")
		positions[cycle.queue().find("mirror")] = true
		firsts[cycle.hand()[0]] = true
		var unique := {}
		for id in all_cards: unique[id] = true
		_expect(unique.size() == 8 and cycle.matches(DECK), "随机不改变卡组与主动席定义")
	_expect(positions.size() == 4 and firsts.size() == 7, "镜像覆盖队列四位置，其余卡均可首抽")
	var ordinary := DECK.duplicate()
	ordinary[0] = "xin"
	var orders := {}
	for index in 32: orders[str(CardCycle.new(ordinary).hand())] = true
	_expect(orders.size() > 1, "无镜像卡组同样随机开局")

func _check_replica() -> void:
	var old_mode: String = _main.mode
	_main.mode = "client"
	_main._deck = DECK.duplicate()
	FIXTURE.fixed_cycle(_main, 1, _main._deck)
	var history := {"card_id": "kayle", "deployment_card_id": "kayle_ranged", "cost": 6}
	FIXTURE.deliver(_main, "_rpc_deploy_accepted", ["kayle", 20, ["mirror", "ashe", "garen", "heal"], ["freeze", "kayle", "shurima_guard", "tombstone"], history])
	_expect(_main.card_cost_for_team(1, "mirror") == 6 and _main.resolved_card_for_team(1, "mirror") == "kayle", "可靠确认同步镜像形态与费用")
	_expect(_main._hand._button_slots[0].get_node("CardArtwork").texture == CardArt.texture_for("kayle_ranged") and _main._hand._button_slots[0].get_node("MirrorGlass").visible, "客户端镜像保留原卡画面并叠镜面标记")
	_main._hand.set_card_pending("garen", true)
	_expect(_main._hand._button_slots[0].disabled, "未确认原卡期间镜像禁止选择")
	_expect(not _main.play_card(1, "mirror", Vector2(300, 300), {"elixir": _main._elixir, "client_request": true}), "未确认历史不能发送镜像请求")
	_main._hand.set_card_pending("garen", false)
	_expect(not _main._hand._button_slots[0].disabled, "原卡确认后镜像恢复")
	FIXTURE.deliver(_main, "_rpc_deploy_rejected", ["mirror"])
	_expect(_main._card_history.get_last(1) == history, "拒绝不覆盖镜像历史")
	_main._hand.set_mirror_copy({"card_id": "kayn", "deployment_card_id": "kayn_assassin", "cost": 4})
	_expect(_main._hand._button_slots[0].get_node("CardArtwork").texture == CardArt.texture_for("kayn_assassin"), "镜像展示锁定的进阶形态而非基础凯隐")
	_main.mode = old_mode

func _check_resources() -> void:
	var resources := MatchResources.new()
	resources.prepare(DECK)
	_expect(resources.cards.has("kayle_ranged") and resources.cards.has("imp") and resources.resources.has("res://assets/cards/mirror_loading.png"), "镜像资源包含卡面、衍生形态与编队依赖")
	var normal := resources.cards.duplicate()
	normal.erase("mirror")
	var copied := MatchModelPool.build_specs(resources.cards)
	var base := MatchModelPool.build_specs(normal)
	var path := PresentationConfig.scene_path(CardDB.get_card("garen"), 0)
	_expect(int(copied[path][0].count) == int(base[path][0].count) * 2, "镜像扩大预建模型并发库存")

func _put_in_hand(card_id: String) -> void:
	var cycle: CardCycle = _main._authoritative_card_cycles[0]
	var hand := cycle.hand()
	var queue := cycle.queue()
	if card_id not in hand:
		var index := queue.find(card_id)
		queue[index] = hand[0]
		hand[0] = card_id
		cycle.replace_replica(hand, queue)
	_main._sync_card_cycle_ui(0)

func _play(card_id: String) -> bool:
	_put_in_hand(card_id)
	_main._elixir.elixir = 10
	if not _main.play_card(0, card_id, Vector2(300, 900), {"elixir": _main._elixir}): return false
	_main._sim_tick_id += 10
	_main._tick_pending_card_deployments(0.05)
	_main._tick_pending_card_pre_deployments(3.0)
	return true

func _latest(source: String) -> Unit:
	return _main._latest_unit_for_card(source, 0)

func _reset() -> void:
	_main._commands.clear()
	_main._card_history.clear()
	for slot in 2: _main._clear_active_slot(0, slot)
	for c in _main.get_tree().get_nodes_in_group("combatants"):
		if c is Unit: c.free()
	_main._projectile_system.clear_all()
	_main._spell_system.clear()
	_main._elixir.elixir = 10
	FIXTURE.fixed_cycle(_main, 0, _main._deck)

func _check_delayed_replacement() -> void:
	_reset()
	_main._deck = ["mirror", "ashe", "garen", "heal", "freeze", "kayle", "twisted_fate", "tombstone"]
	FIXTURE.fixed_cycle(_main, 0, _main._deck)
	_expect(_play("twisted_fate"), "带额外部署等待的卡牌接受")
	_put_in_hand("mirror")
	_main._elixir.elixir = 10
	_expect(_main.play_card(0, "mirror", Vector2(300, 900), {"elixir": _main._elixir}), "旧镜像进入排程")
	_main._sim_tick_id += 10
	_main._tick_pending_card_deployments(0.05)
	_expect(not _main._commands.inspect_deployments().is_empty(), "旧镜像等待卡牌大师预部署")
	for id in ["garen", "mirror"]:
		_put_in_hand(id)
		_main._elixir.elixir = 10
		_expect(_main.play_card(0, id, Vector2(420, 900), {"elixir": _main._elixir}), "较新卡牌正式接受")
		_main._sim_tick_id += 10
		_main._tick_pending_card_deployments(0.05)
	var holder := _latest("garen")
	var ability := holder.active_ability_id
	_main._tick_pending_card_pre_deployments(3.0)
	_expect(ability >= 0 and _latest("twisted_fate").active_ability_id == -1 and _main._active_skills.has(ability), "较早镜像更晚落地不夺回最新技能槽")

func _check_building_and_rejections() -> void:
	_reset()
	_main._deck = DECK.duplicate()
	FIXTURE.fixed_cycle(_main, 0, _main._deck)
	_put_in_hand("tombstone")
	_expect(_main.play_card(0, "tombstone", Vector2(300, 820), {"elixir": _main._elixir}), "建筑原卡入队")
	var last: Dictionary = _main._card_history.get_last(0)
	_put_in_hand("mirror")
	_main._elixir.elixir = 0
	var hand: Array = _main.get_authoritative_hand(0)
	_expect(not _main.play_card(0, "mirror", Vector2(300, 820), {"elixir": _main._elixir}) and hand == _main.get_authoritative_hand(0) and last == _main._card_history.get_last(0), "镜像不足费不改变历史、手牌或排程")
	_main._elixir.elixir = 10
	_expect(_main.play_card(0, "mirror", Vector2(300, 820), {"elixir": _main._elixir}), "生成前同落点建筑镜像接受")
	_main._sim_tick_id += 10
	_main._tick_pending_card_deployments(0.05)
	var buildings: Array = _main.get_tree().get_nodes_in_group("combatants").filter(func(c): return c is Unit and c.card_id == "tombstone")
	_expect(buildings.size() == 2 and buildings[0].position != buildings[1].position and buildings[1].active_ability_slot == 0, "复制建筑复用落地挪位及镜像技能槽")
	_expect(_main._card_history.get_last(1).is_empty(), "蓝方出牌不污染红方镜像历史")
	var invalid := CardDB.all().duplicate(true)
	invalid.mirror.duration = 1.0
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all(invalid, false).is_empty(), "镜像拒绝虚假的独立持续时间")

func _check_workbench() -> void:
	_reset()
	_main._workbench.enabled = true
	_main._workbench.team = 0
	_main._workbench.skill_choices["garen"] = 1
	_main._set_art_dev_selection("garen")
	_main._place_art_dev_item(Vector2(300, 900))
	_main._set_art_dev_selection("mirror")
	_main._workbench.spell_active = true
	_main._place_art_dev_item(Vector2(420, 900))
	var copy: Unit = _main._art_dev_selected_unit()
	_expect(copy != null and copy.active_skill_card_id == "garen" and copy.active_ability_slot == 0, "工作台镜像选择跟随复制体")
	_expect(_main._art_dev_selected_skill() == CardDB.active_skills_for("garen")[1], "工作台使用原卡预选技能")
	_main._workbench.spell_active = false
	_main._place_art_dev_item(Vector2(500, 900))
	_expect(_main._art_dev_selected_skill().is_empty(), "工作台普通镜像不提供技能")
	_main._workbench.enabled = false
	_main._workbench.last_units.clear()
	_main._workbench.last_groups.clear()

func _check_queued_spell() -> void:
	_reset()
	_main._deck = DECK.duplicate()
	FIXTURE.fixed_cycle(_main, 0, _main._deck)
	_expect(_play("garen") and _play("heal"), "准备连续镜像法术历史")
	var patient := _latest("garen")
	for index in 2:
		_put_in_hand("mirror")
		_main._elixir.elixir = 10
		_expect(_main.play_card(0, "mirror", Vector2(300, 900) if index == 0 else Vector2(600, 1100), {"elixir": _main._elixir}), "连续镜像法术入队")
	_main._sim_tick_id += 10
	_main._tick_pending_card_deployments(0.05)
	_expect(patient.shield_hp > 0, "较早镜像法术仍保留预选强化，不因新镜像入队失效")
