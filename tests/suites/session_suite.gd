extends RefCounted

func run(harness: Object) -> void:
	var early := MatchSession.new()
	early.bind_opponent(42, "parallel")
	early.confirm_deck(42, "parallel")
	harness._expect(early.mark_remote_ready(42, "parallel") and not early.mark_remote_ready(42, "parallel") and not early.start(), "对手先准备完成时记住就绪，重复消息不提前开战")
	early.local_ready = true
	harness._expect(early.start() and not early.start(), "本机随后完成时复用已记录的远端就绪，只开战一次")
	var session := MatchSession.new()
	harness._expect(session.bind_opponent(42, "epoch") and not session.bind_opponent(42, "epoch"), "会话绑定唯一对手；重复连接回调幂等")
	harness._expect(not session.bind_opponent(43, "other") and session.opponent_id == 42 and session.session_id == "epoch", "第三个连接不改变对手或会话")
	harness._expect(not session.accept_command(42, "epoch", 1) and not session.start(), "双方加载确认之前禁止命令与模拟开局")
	harness._expect(not session.confirm_deck(43, "epoch") and not session.confirm_deck(42, "old"), "非对手及旧局不能注册卡组")
	harness._expect(session.confirm_deck(42, "epoch") and not session.confirm_deck(42, "epoch"), "卡组仅在加载阶段确认一次")
	session.local_ready = true
	harness._expect(not session.start(), "本机先加载完时仍等待对手")
	harness._expect(session.mark_remote_ready(42, "epoch") and session.start(), "双方就绪后才进入运行")
	harness._expect(not session.confirm_deck(42, "epoch") and not session.start(), "局中注册和重复开局无副作用")
	harness._expect(not session.accept_command(43, "epoch", 1) and not session.accept_command(42, "old", 1) and session.last_request_id == 0, "非法来源不消耗合法对手命令序号")
	harness._expect(session.accept_command(42, "epoch", 1) and not session.accept_command(42, "epoch", 1) and session.accept_command(42, "epoch", 2), "可靠命令按单调序号去重")
	session.finish(true)
	harness._expect(not session.accept_command(42, "epoch", 3), "断线后拒绝命令")
	var main = load("res://scenes/main.tscn").instantiate()
	harness.root.add_child(main)
	main.set_process(false)
	main.mode = "host"
	main._session.bind_opponent(42, "deck")
	var deck: Array = CardDB.selectable_ids().slice(0, 8)
	harness._expect(not main._accept_remote_deck(0, "deck", deck, {}) and main._authoritative_card_cycles.is_empty(), "原 CL-04：未绑定调用者不能创建手牌循环")
	harness._expect(not main._accept_remote_deck(42, "deck", [null], {}) and not main._session.deck_confirmed, "坏卡组不会占用一次性确认")
	harness._expect(main._accept_remote_deck(42, "deck", deck, {}), "合法绑定对手可以确认卡组")
	main._authoritative_card_cycles[1].hand.pop_front()
	main._session.phase = MatchSession.Phase.RUNNING
	var before: Dictionary = main._authoritative_card_cycles.duplicate(true)
	harness._expect(not main._accept_remote_deck(42, "deck", deck, {}) and main._authoritative_card_cycles == before, "原 CL-04：局中相同卡组重注册不重置手牌")
	main._rpc_deploy_request("garen", Vector2(300, 580), 0, "deck", 1)
	main._rpc_active_skill_request(1, 0, "deck", 2)
	harness._expect(main._commands.card_commands.is_empty() and main._commands.skill_commands.is_empty() and main._session.last_request_id == 0, "实际 RPC 入口拒绝非参与者，不入队、不改变序号")
	main.mode = "client"
	main._session = MatchSession.new()
	main._session.join("new")
	main._session.phase = MatchSession.Phase.RUNNING
	main._rpc_card_pre_deploy_started("old", 77, "tombstone", 1, Vector2.ZERO, 2.0)
	main._rpc_projectile_launch_audio("old", 77, {"card_id": "gnar", "form": 0}, Vector2.ZERO, true)
	harness._expect(main._commands.pre_deployments.is_empty() and main._audio_manager._projectile_launch_players.is_empty(), "旧局表现事件不能创建新局部署标记或飞行声")
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

	_check_default_local_deck(harness)

func _check_default_local_deck(harness: Object) -> void:
	var local = load("res://scenes/main.tscn").instantiate()
	harness.root.add_child(local)
	local.set_process(false)
	local._start_local()
	local._ai.enabled = false
	local._minion_waves_enabled = false
	local._elixir.elixir = 10.0
	var visible: Array = local._hand._hand.duplicate()
	harness._expect(local._deck.size() == 8 and visible == local.get_authoritative_hand(0) and visible == local.get_authoritative_hand(1), "直接单机启动的默认卡组、显示手牌与双方权威循环一致")
	var card: String = visible[0]
	var cost: float = local.card_cost_for_team(0, card)
	var accepted: bool = local.play_card(0, card, Vector2(300, 900), {"elixir": local._elixir})
	harness._expect(accepted and is_equal_approx(local._elixir.elixir, 10.0 - cost) and local._hand._hand != visible, "直接单机启动可以真实扣费出牌并轮换")
	for tick in 11: local._sim_step(0.05)
	var spawned := false
	for unit in harness.get_nodes_in_group("combatants"):
		if unit is Unit and unit.card_id == card and unit.team == 0: spawned = true
	harness._expect(spawned, "默认卡组命令实际生成单位而非只更新界面")
	local.free()
