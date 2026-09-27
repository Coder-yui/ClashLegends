extends RefCounted

func run(harness: SceneTree, scenario: String) -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.set_script(preload("res://tests/fixtures/network_boundary_main.gd"))
	harness.root.add_child(main)
	harness.current_scene = main
	var started := Time.get_ticks_msec()
	var waiting := true
	var observed_loading := false
	var acted := false
	var restarted := false
	var previous_epoch := ""
	var restart_clean := false
	var funded := false
	var buildings_sent := false
	while Time.get_ticks_msec() - started < 15000:
		await harness.process_frame
		if main._session.phase == MatchSession.Phase.LOADING:
			observed_loading = true
			waiting = waiting and not main._match_started and main._sim_tick_id == 0
		if scenario == "buildings" and main._match_started:
			if main.mode == "host" and not funded:
				main._elixir_p1.elixir = 10
				funded = true
			if main.mode == "client" and main.get_authoritative_server_tick() >= 5 and main._elixir.elixir == 10 and not buildings_sent:
				buildings_sent = true
				main._rpc_deploy_request.rpc_id(1, "tombstone", Vector2(300, 440), main.get_authoritative_server_tick(), main._session.session_id, 1)
				main._rpc_deploy_request.rpc_id(1, "sun_disc", Vector2(300, 440), main.get_authoritative_server_tick(), main._session.session_id, 2)
		if scenario == "load_disconnect" and main.mode == "client" and main._battle_loading and is_instance_valid(main._battle_presentation) and not acted:
			acted = true
			main._network_peer.close()
			main._on_server_disconnected()
		if scenario == "load_timeout" and main.mode == "host" and main._battle_loading and not acted:
			acted = true
			# 只跳过等待时间，仍由正式暂停树下的超时观察器执行失败与清理。
			main._network_loading_started = Time.get_ticks_msec() - 30001
		if scenario == "disconnect" and main.mode == "client" and main.get_authoritative_server_tick() >= 20 and not acted:
			acted = true
			main._network_peer.close()
			main._on_server_disconnected()
		if scenario in ["slow", "slow_host", "restart", "buildings"] and main.mode == "host" and main._sim_tick_id >= 20 and not acted:
			acted = true
			main._end_game(-1, "draw")
		if scenario == "restart" and main.game_over and not restarted:
			previous_epoch = main._session.session_id
			restarted = true
			acted = false
			# 触发真实返回按钮连接的 reload_current_scene，检查 ENet 端口释放和新场景。
			var button: Button = main.get_node("MatchResult").get_child(1)
			button.pressed.emit()
			while harness.current_scene == null or harness.current_scene == main:
				await harness.process_frame
			main = harness.current_scene
			restart_clean = not main.game_over and main._commands.inspect_cards().is_empty() and main._session.last_request_id == 0 and not main.has_node("MatchResult")
			continue
		if main._session.phase in [MatchSession.Phase.FINISHED, MatchSession.Phase.DISCONNECTED]:
			while main._battle_loading: await harness.process_frame
			break
	var result := {"schema": 1, "case": scenario, "role": main.mode, "session_id": main._session.session_id,
		"phase": main._session.phase, "tick": main._sim_tick_id, "passed": false}
	if scenario in ["protocol", "content"]:
		result.passed = main._session.phase == MatchSession.Phase.DISCONNECTED and main._sim_tick_id == 0 and main._towers.is_empty() and main._commands.inspect_cards().is_empty() and main._authoritative_card_cycles.is_empty()
	elif scenario == "disconnect":
		result.passed = main.game_over and main._session.phase == MatchSession.Phase.DISCONNECTED and main._commands.inspect_cards().is_empty() and main._commands.inspect_skills().is_empty() and main._audio_manager.battle_audio_stopped() and main.has_node("MatchResult")
	elif scenario in ["load_disconnect", "load_timeout"]:
		result.passed = main._session.phase == MatchSession.Phase.DISCONNECTED and main._sim_tick_id == 0 and not main._battle_loading and not harness.paused and main._network_peer == null
	elif scenario == "slow_host":
		result.passed = waiting and observed_loading and main.game_over and (main.mode == "client" or main.loading_wait_observed)
	elif scenario == "slow":
		result.passed = waiting and observed_loading and main.game_over and main._session.phase == MatchSession.Phase.FINISHED and (main.mode == "host" or main.loading_wait_observed)
	elif scenario == "restart":
		result.passed = restarted and restart_clean and main.game_over and main._session.phase == MatchSession.Phase.FINISHED and main._session.session_id != previous_epoch and not main._session.session_id.is_empty()
	elif scenario == "buildings":
		var registry: Dictionary = main._net_units if main.mode == "host" else main._client_units
		var buildings: Array = registry.values().filter(func(unit): return unit is Unit and unit.is_building)
		var coins: float = main._elixir_p1.elixir if main.mode == "host" else main._elixir.elixir
		result.passed = main.game_over and buildings.size() == 2 and coins == 3 and not main._structure_deployment_rect(buildings[0]).intersects(main._structure_deployment_rect(buildings[1]), false) and "sun_disc" not in main.get_authoritative_hand(1)
		result["buildings"] = buildings.size()
		result["coins"] = coins
	result["waiting_safe"] = waiting
	print("[NETWORK_BOUNDARY_RESULT] " + JSON.stringify(result))
	await harness.create_timer(0.5).timeout
	main.free()
	await harness.create_timer(0.25).timeout
	harness.quit(0 if result.passed else 1)
