extends RefCounted

func run(harness: Object) -> void:
	var session := MatchSession.new()
	session.open("epoch")
	harness._expect(session.bind_player(42) == 0 and session.bind_player(53) == 1, "两条连接分别绑定稳定玩家席位")
	harness._expect(session.bind_player(42) == -1 and session.bind_player(66) == -1 and session.players.size() == 2, "重复回调和第三人不改写玩家")
	harness._expect(session.players[0].player_id != session.players[1].player_id and session.team_for_peer(42) == 0 and session.peer_for_team(1) == 53, "玩家身份、阵营、连接映射独立")
	harness._expect(not session.accept_command(42, "epoch", 1) and not session.start(), "准备前禁止命令和开局")
	harness._expect(not session.confirm_deck(66, "epoch") and not session.confirm_deck(42, "old"), "未绑定和旧局不能注册卡组")
	harness._expect(session.confirm_deck(42, "epoch") and not session.confirm_deck(42, "epoch") and not session.begin_loading(), "第一人卡组只确认一次，等待第二人")
	harness._expect(session.confirm_deck(53, "epoch") and session.begin_loading(), "双方卡组合法才进入加载")
	session.local_ready = true
	harness._expect(session.mark_remote_ready(42, "epoch") and not session.start(), "服务器和第一端就绪仍不模拟")
	harness._expect(session.mark_remote_ready(53, "epoch") and session.start() and not session.start(), "两端就绪后只开局一次")
	harness._expect(not session.confirm_deck(42, "epoch"), "局中不能重置卡组")
	harness._expect(not session.accept_command(66, "epoch", 1) and not session.accept_command(42, "old", 1) and session.request_sequence(0) == 0, "非法来源不能消耗请求序号")
	harness._expect(session.accept_command(42, "epoch", 1) and not session.accept_command(42, "epoch", 1) and session.accept_command(53, "epoch", 1), "两名玩家分别去重，同序号互不干扰")
	session.finish(true)
	harness._expect(not session.accept_command(42, "epoch", 2), "断线后拒绝命令")
	var main = load("res://scenes/main.tscn").instantiate()
	harness.root.add_child(main)
	main.set_process(false)
	main.mode = "server"
	main._session.open("deck")
	main._session.bind_player(42)
	var deck: Array = CardDB.selectable_ids().slice(0, 8)
	harness._expect(not main._accept_remote_deck(0, "deck", deck, {}) and main._authoritative_card_cycles.is_empty(), "原 CL-04：未绑定调用者不能创建手牌循环")
	harness._expect(not main._accept_remote_deck(42, "deck", [null], {}) and not main._session.has_deck(42), "坏卡组不会占用一次性确认")
	harness._expect(main._accept_remote_deck(42, "deck", deck, {}), "合法绑定对手可以确认卡组")
	main._initialize_authoritative_card_cycle(0, deck)
	main._consume_authoritative_card(0, String(main.get_authoritative_hand(0)[0]))
	main._session.phase = MatchSession.Phase.RUNNING
	var before: Array = [main.get_authoritative_hand(0), main.get_authoritative_queue(0)]
	harness._expect(not main._accept_remote_deck(42, "deck", deck, {}) and [main.get_authoritative_hand(0), main.get_authoritative_queue(0)] == before, "原 CL-04：局中相同卡组重注册不重置手牌")
	main._rpc_deploy_request("garen", Vector2(300, 580), 0, "deck", 1)
	main._rpc_active_skill_request(1, 0, "deck", 2)
	harness._expect(main._commands.inspect_cards().is_empty() and main._commands.inspect_skills().is_empty() and main._session.request_sequence(0) == 0, "实际 RPC 入口拒绝非参与者，不入队、不改变序号")
	main.mode = "client"
	main.local_team = 1
	main._session = MatchSession.new()
	main._session.join("new")
	main._session.phase = MatchSession.Phase.RUNNING
	main._rpc_card_pre_deploy_started("old", 77, "tombstone", 1, Vector2.ZERO, 2.0)
	main._rpc_projectile_launch_audio("old", 77, {"card_id": "gnar", "form": 0}, Vector2.ZERO, true)
	harness._expect(main._commands.inspect_deployments().is_empty() and main._audio_manager._projectile_launch_players.is_empty(), "旧局表现事件不能创建新局部署标记或飞行声")
	main._session = MatchSession.new()
	main._on_connection_failed()
	harness._expect(main._session.phase == MatchSession.Phase.DISCONNECTED and main._network_peer == null and main._menu_status.text.contains("连接失败"), "连接失败有明确提示且可留在菜单重新选择")
	main._session = MatchSession.new()
	main._session.join("timeout")
	main._network_loading_started = Time.get_ticks_msec() - 30001
	main._process(0.0)
	harness._expect(main._session.phase == MatchSession.Phase.DISCONNECTED and main._menu_status.text.contains("超时"), "加载超时停止并提示，不无限等待")
	main.free()
	harness._expect(MatchSession.content_fingerprint() == MatchSession.content_fingerprint() and MatchSession.content_fingerprint().length() == 64, "内容指纹稳定且完整")

	_check_private_hand_and_adaptation(harness)
	_check_buffer_clock_and_playback(harness)
	_check_default_local_deck(harness)
	_check_client_team_presentation(harness)

func _check_default_local_deck(harness: Object) -> void:
	var local = load("res://scenes/main.tscn").instantiate()
	harness.root.add_child(local)
	local.set_process(false)
	local._start_local()
	local._ai.enabled = false
	local._minion_waves_enabled = false
	local._elixir.elixir = 10.0
	var visible: Array = local._hand._hand.duplicate()
	harness._expect(local._deck.size() == 8 and visible == local.get_authoritative_hand(0) and local.get_authoritative_hand(1).size() == 4, "直接单机启动的默认卡组、显示手牌与本地权威循环一致，AI独立随机四张")
	# 本断言检查单位部署；默认卡组也可能抽到法术，不能要求法术生成Unit。
	var unit_cards := visible.filter(func(id): return String(CardDB.get_card(id).get("type", "unit")) != "spell")
	harness._expect(not unit_cards.is_empty(), "默认起手包含可验证部署的单位或建筑")
	if unit_cards.is_empty():
		local.free()
		return
	var card: String = unit_cards[0]
	var cost: float = local.card_cost_for_team(0, card)
	var accepted: bool = local.play_card(0, card, Vector2(300, 900), {"elixir": local._elixir})
	harness._expect(accepted and is_equal_approx(local._elixir.elixir, 10.0 - cost) and local._hand._hand != visible, "直接单机启动可以真实扣费出牌并轮换")
	# 默认手牌随机，潘森等卡还有预部署窗口；不能固定只等命令缓冲。
	var wait_ticks := ceili((0.5 + float(CardDB.get_card(card).get("pre_deploy_time", 0.0))) / local.SIM_DT) + 1
	for tick in wait_ticks: local._sim_step(local.SIM_DT)
	var spawned := false
	for unit in harness.get_nodes_in_group("combatants"):
		if unit is Unit and unit.card_id == card and unit.team == 0: spawned = true
	harness._expect(spawned, "默认卡组命令实际生成单位而非只更新界面")
	local.free()

func _check_client_team_presentation(harness: Object) -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	harness.root.add_child(main)
	main.set_process(false)
	main.mode = "client"
	var unit := Unit.new()
	var tower := Tower.new()
	unit.set_battle_context(main.battle_context)
	tower.set_battle_context(main.battle_context)
	for assigned in [0, 1]:
		main.local_team = assigned
		unit.team = assigned
		tower.team = assigned
		var own_unit := unit.get_health_bar_fill_color()
		var own_tower := tower.get_health_bar_fill_color()
		unit.team = 1 - assigned
		tower.team = 1 - assigned
		harness._expect(own_unit.g > own_unit.r and own_tower.g > own_tower.r and unit.get_health_bar_fill_color().r > unit.get_health_bar_fill_color().g and tower.get_health_bar_fill_color().r > tower.get_health_bar_fill_color().g, "任一客户端阵营均显示己方绿血条、敌方红血条")
	main._sim_step(0.05)
	harness._expect(main._sim_tick_id == 0, "客户端不能直接推进共享权威核心")
	unit.free()
	tower.free()
	main.free()

func _check_buffer_clock_and_playback(harness: Object) -> void:
	var clock := NetworkClock.new()
	var probe := clock.begin_probe(1000)
	harness._expect(not clock.accept_probe(probe + 1, 22.0, 1200), "时钟只接受本局自己发出的探测序号")
	harness._expect(clock.accept_probe(probe, 22.0, 1200) and is_equal_approx(clock.estimate(1200), 24.0), "200ms往返样本以100ms单程估计校准服务器Tick")
	harness._expect(not clock.accept_probe(probe, 1000.0, 1201), "重复时钟响应不能重拨时钟")
	probe = clock.begin_probe(1300)
	clock.accept_probe(probe, 30.0, 1700)
	harness._expect(is_equal_approx(clock.estimate(1700), 34.0) and clock.rtt_msec == 200.0, "抖动高的样本不覆盖窗口内最小RTT时钟偏移")
	probe = clock.begin_probe(2000)
	harness._expect(not clock.accept_probe(probe, 60.0, 5001), "超时样本不污染时钟")
	clock.reset()
	harness._expect(not clock.synchronized and not clock.accept_probe(probe, 60.0, 5002), "新局清空时钟样本与在途探测")
	var playback := NetworkPlayback.new()
	playback.enqueue(110, &"_apply_buffered_snapshot", [])
	playback.enqueue(109, &"early", [])
	playback.enqueue(110, &"spawn", [])
	harness._expect(playback.advance(110.0).is_empty(), "100ms表现缓冲内不提前应用快照或出生")
	var first := playback.advance(111.0)
	var second := playback.advance(112.0)
	harness._expect(first.size() == 1 and first[0].method == &"early" and second.size() == 2 and second[0].method == &"spawn" and second[1].method == &"_apply_buffered_snapshot", "乱序到达按Tick播放，同Tick事件先于最终快照")
	playback.enqueue(120, &"future", [])
	playback.advance(113.0)
	playback.enqueue(115, &"inserted", [])
	var inserted := playback.advance(117.0)
	harness._expect(inserted.size() == 1 and inserted[0].method == &"inserted" and playback.size() == 1, "已排序的未来队列收到更早事件后仍按Tick释放")
	playback.clear()
	playback.advance(112.0)
	playback.enqueue(105, &"late", [])
	harness._expect(playback.advance(109.0).size() == 1 and playback.tick == 110.0, "迟到事件追赶，不让播放时钟倒退")
	playback.enqueue(200, &"future", [])
	playback.clear()
	harness._expect(playback.advance(300.0).is_empty(), "终局清理后晚到播放不能重建战斗")
	var commands := NetworkCommandState.new()
	var card := commands.create("card", 0, "garen", -1, Vector2(300, 900), 100, 110)
	var skill := commands.create("skill", 1, "garen", 7, Vector2(300, 300), 100, 110)
	var replica := NetworkCommandState.new()
	harness._expect(replica.receive(card) and replica.receive(skill) and not replica.receive(card), "双方出牌与技能共享10Tick排程，通知按权威命令ID去重")
	var visited: Array = []
	replica.visit(func(command): visited.append(command))
	harness._expect(visited.size() == 2 and visited[0].is_read_only(), "公开命令遍历只提供只读状态")
	var inspected := replica.inspect()
	inspected[0].team = 1
	card.pos = Vector2.ZERO
	harness._expect(replica.inspect()[0].team == 0 and replica.inspect()[0].pos != Vector2.ZERO, "接收和检查副本与外部可变字典隔离")
	card.pos = Vector2(300, 900)
	var malformed := card.duplicate()
	malformed.id = 3
	malformed.execute_tick = 109
	harness._expect(not replica.receive(malformed) and replica.inspect().size() == 2, "坏排程不能跳过0.5秒窗口")
	harness._expect(replica.finish(card.id) == card and replica.finish(card.id).is_empty(), "命令完成/取消幂等消费一次")
	replica.clear()
	harness._expect(replica.inspect().is_empty(), "终局丢弃所有已接受但未执行命令")
	var main = load("res://scenes/main.tscn").instantiate()
	harness.root.add_child(main)
	main.set_process(false)
	main.mode = "client"
	main._session.join("buffer")
	main._session.phase = MatchSession.Phase.RUNNING
	main._rpc_command_scheduled("old", card)
	harness._expect(main._network_commands.inspect().is_empty(), "旧会话排程不能进入客户端")
	main._rpc_command_scheduled("buffer", card)
	harness._expect(main._network_commands.inspect().size() == 1 and main._client_units.is_empty() and main._commands.inspect_cards().is_empty(), "提前通知只保存表现准备，不生成单位、不进入客户端权威队列")
	main._receive_battle_event("buffer", 110, &"_start_local", [])
	harness._expect(main._network_playback.size() == 0, "网络表现信封不能调用白名单之外的方法")
	main._rpc_command_finished("buffer", card.id, "executed")
	harness._expect(main._network_commands.inspect().is_empty(), "权威完成通知清理客户端准备记录")
	var caster := Unit.new()
	caster.active_ability_id = 7
	caster.active_ability_slot = 0
	main._active_skills.register(caster, "garen", 0, {"max_uses": 2})
	main._active_skills.replace_replica(7, 1, 3.0)
	main._snapshot_system.lifecycle.snapshot_tick = 111
	main._estimated_server_tick = 114
	main._has_estimated_server_tick = true
	main._receive_battle_event("buffer", 110, &"_rpc_active_skill_used", ["buffer", 7, 2, 5.0, false])
	main._advance_network_playback()
	harness._expect(main._active_skills.entry(7).uses_remaining == 1 and main._active_skills.entry(7).cooldown_left == 3.0, "迟到技能通知不能覆盖更新快照的次数和冷却")
	main._active_skills.clear()
	caster.free()
	main.free()

func _check_private_hand_and_adaptation(harness: Object) -> void:
	var deck: Array = ["garen", "xin", "ashe", "teemo", "freeze", "heal", "tombstone", "gnar"]
	seed(90210)
	var expected_global := randi()
	seed(90210)
	var cycle := CardCycle.new(deck, true, 123456)
	harness._expect(randi() == expected_global, "洗牌不消耗战斗全局随机序列")
	for i in 50: randf()
	var replay := CardCycle.new(deck, true, cycle.shuffle_seed)
	harness._expect(cycle.hand() == replay.hand() and cycle.queue() == replay.queue(), "记录的独立种子可复现初始八张顺序")
	var view := cycle.visible_state(0, {})
	harness._expect(view.size() == 5 and not view.has("queue") and not view.has("seed") and view.hand.size() == 4 and view.next == cycle.queue()[0], "服务端只投影四手牌与下一张，隐藏队列和种子不进载荷")
	var replica := ClientHandState.new()
	harness._expect(replica.hand.is_empty() and replica.next_card.is_empty() and replica.apply(view, deck), "客户端不洗牌，等待正式初始状态")
	var played: String = cycle.hand()[2]
	var next: String = cycle.queue()[0]
	cycle.consume(played)
	var newer := cycle.visible_state(3, {})
	harness._expect(cycle.version == 1 and cycle.hand()[2] == next and cycle.queue().back() == played and replica.apply(newer, deck), "服务器消费后递增版本并在原槽补牌，客户端只应用可见状态")
	harness._expect(not replica.apply(view, deck) and not replica.apply(newer, deck) and replica.hand == newer.hand, "旧版与重复回执不会回拨手牌")
	var bad := newer.duplicate(true)
	bad.version = 2
	bad.ack = 2
	harness._expect(not replica.apply(bad, deck), "新版本却倒退请求编号的状态被拒绝")
	bad = newer.duplicate(true)
	bad.queue = cycle.queue()
	harness._expect(not ClientHandState.valid(bad, deck), "客户端拒绝意外携带隐藏队列的协议载荷")
	bad = newer.duplicate(true)
	bad.next = bad.hand[0]
	harness._expect(not ClientHandState.valid(bad, deck), "手牌与下一张不能重复或冒用非卡组牌")
	var inputs := ClientInputState.new()
	inputs.card("garen", 7, Vector2(300, 900))
	harness._expect(not inputs.finish_card("garen", 6) and inputs.has_card("garen") and inputs.finish_card("garen", 7), "迟到拒绝不能撤掉新请求的即时反馈")
	inputs.skill(8, 9)
	harness._expect(not inputs.finish_skill(8, 8) and inputs.finish_skill(8, 9), "技能拒绝同样对应确切请求编号")
	var playback := NetworkPlayback.new()
	for i in 100: playback.observe_delay(0.0)
	harness._expect(is_equal_approx(playback.delay_ticks, 1.0), "稳定链路逐步收敛到50ms表现缓冲")
	playback.advance(20.0)
	for i in 16: playback.observe_delay(180.0)
	harness._expect(playback.delay_ticks == 4.0 and playback.advance(21.0).is_empty() and playback.tick == 19.0, "抖动时增加至200ms且播放时间不倒退")
	for i in 200: playback.observe_delay(0.0)
	harness._expect(playback.delay_ticks >= 1.0 and playback.delay_ticks < 2.0, "恢复稳定后缓慢降低表现缓冲")
	playback.observe_delay(NAN)
	playback.clear()
	harness._expect(playback.delay_ticks == 2.0, "非法延迟不污染自适应，新会话恢复默认100ms")
	var main = load("res://scenes/main.tscn").instantiate()
	harness.root.add_child(main)
	main.set_process(false)
	main.mode = "client"
	main.local_team = 0
	main._deck = deck
	main._setup_player_ui()
	harness._expect(main._authoritative_card_cycles.is_empty() and main._hand.get_hand().is_empty() and main._hand.get_next_card().is_empty(), "真实客户端UI初始化不创建权威牌序，也不生成临时手牌")
	main._session.join("private-hand")
	main._session.phase = MatchSession.Phase.RUNNING
	main._apply_client_hand_state(view)
	main._client_inputs.card(played, 3, Vector2.ZERO)
	main._hand.set_card_pending(played, true)
	main._rpc_deploy_accepted("private-hand", played, 20, newer)
	main._client_inputs.card(played, 5, Vector2.ZERO)
	main._hand.set_card_pending(played, true)
	main._rpc_deploy_accepted("private-hand", played, 20, newer)
	main._rpc_deploy_rejected("private-hand", played, 3)
	harness._expect(main._hand.is_card_pending(played) and main._client_inputs.has_card(played) and main._client_hand.version == 1, "实际RPC的旧接受/拒绝均不能覆盖新pending")
	main._rpc_deploy_rejected("private-hand", played, 5)
	harness._expect(not main._hand.is_card_pending(played) and main.get_authoritative_queue(0).is_empty() and main.get_next_card(0) == newer.next, "对应拒绝解除反馈，客户端始终无法查询隐藏队列")
	main.free()
