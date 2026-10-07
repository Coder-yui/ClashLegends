extends RefCounted

func run(harness: SceneTree, scenario: String) -> void:
	var main = _new_main(harness)
	var started := Time.get_ticks_msec()
	var waiting := true
	var observed_loading := false
	var acted := false
	var restarted := false
	var previous_epoch := ""
	var initial_role := ""
	var restart_clean := false
	var funded := false
	var buildings_sent := false
	var budget_ms := 75000 if scenario == "restart" else 40000
	while Time.get_ticks_msec() - started < budget_ms:
		await harness.process_frame
		if main._session.phase == MatchSession.Phase.LOADING:
			observed_loading = true
			waiting = waiting and not main._match_started and main._sim_tick_id == 0
		if scenario == "buildings" and main._match_started:
			if main.mode == "server" and not funded:
				main._elixir.elixir = 10
				main._elixir_p1.elixir = 10
				funded = true
			if main.mode == "client" and main.get_authoritative_server_tick() >= 5 and main._elixir.elixir == 10 and not buildings_sent:
				buildings_sent = true
				var pos := Vector2(300, 440 if main.local_team == 1 else 840)
				main._rpc_deploy_request.rpc_id(1, "tombstone", pos, main.get_authoritative_server_tick(), main._session.session_id, 1)
				main._rpc_deploy_request.rpc_id(1, "sun_disc", pos, main.get_authoritative_server_tick(), main._session.session_id, 2)
		if scenario == "load_disconnect" and main.mode == "client" and main.local_team == 0 and main._battle_loading and is_instance_valid(main._battle_presentation) and not acted:
			acted = true
			main._close_network()
			main._on_server_disconnected()
		if scenario == "load_timeout" and main.mode == "server" and main._session.phase == MatchSession.Phase.LOADING and not acted:
			acted = true
			main._network_loading_started = Time.get_ticks_msec() - 30001
		if scenario == "disconnect" and main.mode == "client" and main.local_team == 0 and main.get_authoritative_server_tick() >= 20 and not acted:
			acted = true
			main._close_network()
			main._on_server_disconnected()
		if scenario in ["slow", "slow_second_client", "restart", "buildings"] and main.mode == "server" and main._sim_tick_id >= 25 and not acted:
			acted = true
			main._end_game(-1, "draw")
		if scenario == "restart" and main.game_over and not restarted:
			initial_role = "server" if main.mode == "server" else "client%d" % main.local_team
			previous_epoch = main._session.session_id
			restarted = true
			acted = false
			var previous_team: int = main.local_team
			if main.mode == "client":
				# 真实返回按钮释放连接并回菜单；服务器在两端离开后自动重建。
				var button: Button = main.get_node("MatchResult").get_child(1)
				button.pressed.emit()
			while is_instance_valid(main) and harness.current_scene == main:
				await harness.process_frame
			while harness.current_scene == null: await harness.process_frame
			main = harness.current_scene
			if previous_team >= 0:
				restart_clean = main.mode == "local" and main._menu_layer != null and main._network_peer == null
				await harness.create_timer(1.8 if previous_team == 0 else 1.5).timeout
				main._start_client("127.0.0.1")
			else: restart_clean = true
			restart_clean = restart_clean and not main.game_over and main._commands.inspect_cards().is_empty() and main._session.request_sequence(0) == 0 and main._session.request_sequence(1) == 0 and not main.has_node("MatchResult")
			continue
		if main._session.phase in [MatchSession.Phase.FINISHED, MatchSession.Phase.DISCONNECTED]:
			while main._battle_loading: await harness.process_frame
			break
	var role: String = "server" if main.mode == "server" else "client%d" % main.local_team
	if not initial_role.is_empty(): role = initial_role
	var result := {"schema": 1, "case": scenario, "role": role, "session_id": main._session.session_id,
		"assigned_team": main.local_team, "phase": main._session.phase, "tick": main._sim_tick_id, "passed": false}
	if scenario in ["protocol", "content"]:
		result.passed = main._session.phase == MatchSession.Phase.DISCONNECTED and main._sim_tick_id == 0 and main._towers.is_empty() and main._commands.inspect_cards().is_empty() and main._authoritative_card_cycles.is_empty()
	elif scenario == "disconnect":
		result.passed = main.game_over and main._session.phase == MatchSession.Phase.DISCONNECTED and main._commands.inspect_cards().is_empty() and main._commands.inspect_skills().is_empty() and (main._audio_manager == null or main._audio_manager.battle_audio_stopped()) and (main.mode == "server" or main.has_node("MatchResult"))
	elif scenario in ["load_disconnect", "load_timeout"]:
		result.passed = main._session.phase == MatchSession.Phase.DISCONNECTED and main._sim_tick_id == 0 and not main._battle_loading and not harness.paused and (main.mode == "server" or main._network_peer == null)
	elif scenario in ["slow", "slow_second_client"]:
		var delayed_team := 0 if scenario == "slow" else 1
		result.passed = waiting and observed_loading and main.game_over and main._session.phase == MatchSession.Phase.FINISHED and (main.mode == "server" or main.local_team != delayed_team or main.loading_wait_observed)
	elif scenario == "restart":
		result.passed = restarted and restart_clean and main.game_over and main._session.phase == MatchSession.Phase.FINISHED and main._session.session_id != previous_epoch and not main._session.session_id.is_empty()
	elif scenario == "buildings":
		var registry: Dictionary = main._net_units if main.mode == "server" else main._client_units
		var buildings: Array = registry.values().filter(func(unit): return unit is Unit and unit.is_building)
		result.passed = main.game_over and buildings.size() == 4
		for team in [0, 1]:
			var own: Array = buildings.filter(func(unit): return unit.team == team)
			result.passed = result.passed and own.size() == 2
			if own.size() == 2: result.passed = result.passed and not main._structure_deployment_rect(own[0]).intersects(main._structure_deployment_rect(own[1]), false)
		if main.mode == "server":
			result.passed = result.passed and main._elixir.elixir == 3 and main._elixir_p1.elixir == 3
		else:
			result.passed = result.passed and main._elixir.elixir == 3 and "sun_disc" not in main.get_authoritative_hand(main.local_team)
	result["waiting_safe"] = waiting
	print("[NETWORK_BOUNDARY_RESULT] " + JSON.stringify(result))
	await harness.create_timer(0.5).timeout
	main.free()
	await harness.create_timer(0.25).timeout
	harness.quit(0 if result.passed else 1)

func _new_main(harness: SceneTree) -> Node2D:
	var main = load("res://scenes/main.tscn").instantiate()
	main.set_script(preload("res://tests/fixtures/network_boundary_main.gd"))
	harness.root.add_child(main)
	harness.current_scene = main
	return main
