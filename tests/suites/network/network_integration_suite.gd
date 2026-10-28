extends RefCounted
## 由唯一机制入口 --network-smoke 启动，Python 执行器负责三进程和日志比对。
func run(harness: SceneTree) -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.set_script(preload("res://tests/fixtures/network_integration_main.gd"))
	harness.root.add_child(main)
	harness.current_scene = main
	if main.runtime.mode == "server": main._auto_test = false
	var capture_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--network-render-dir="): capture_dir = arg.trim_prefix("--network-render-dir=")
	var recorder: AudioEffectRecord
	var recording_slot := -1
	var captured: Dictionary = {}
	var announced: Array = []
	var completed: Array = []
	main.network_command_announced.connect(func(command):
		announced.append([command.kind, command.team, command.execute_tick - command.input_tick, command.execute_tick - main.get_estimated_server_tick()])
		print("[NETWORK_COMMAND_TRACE] ", {"stage": "announced", "role": main.runtime.mode, "team": command.team, "kind": command.kind, "input_tick": command.input_tick, "execute_tick": command.execute_tick, "estimated_tick": main.get_estimated_server_tick(), "authority_tick": main.get_authoritative_server_tick()}))
	main.network_command_finished.connect(func(command, outcome):
		completed.append([command.kind, command.team, outcome])
		print("[NETWORK_COMMAND_TRACE] ", {"stage": "finished", "role": main.runtime.mode, "team": command.team, "kind": command.kind, "outcome": outcome, "execute_tick": command.execute_tick, "estimated_tick": main.get_estimated_server_tick(), "authority_tick": main.get_authoritative_server_tick()}))
	var playback_peak := 0
	var delay_bounds := Vector2(4.0, 1.0)
	if not capture_dir.is_empty() and main.runtime.mode == "client":
		DirAccess.make_dir_recursive_absolute(capture_dir)
		recorder = AudioEffectRecord.new()
		recording_slot = AudioServer.get_bus_effect_count(0)
		AudioServer.add_bus_effect(0, recorder)
		recorder.set_recording_active(true)
	var double_nexus := OS.get_environment("CLASH_TEST_DOUBLE_NEXUS") == "1"
	# 确定覆盖终局跨过4秒雾区到期与第二次金币回复；仅测试入口读取。
	var terminal_not_before := 85
	var terminal_override := OS.get_environment("CLASH_TEST_TERMINAL_TICK")
	if not terminal_override.is_empty():
		if not terminal_override.is_valid_int() or int(terminal_override) < 85 or int(terminal_override) > 160:
			push_error("CLASH_TEST_TERMINAL_TICK must be an integer in 85..160")
			main.free()
			harness.quit(1)
			return
		terminal_not_before = int(terminal_override)
	var result_cues: Array[StringName] = []
	if main._audio_manager != null:
		main._audio_manager.cue_played.connect(func(card, cue, _pos):
			if card == "match" and cue in [&"victory", &"defeat"]: result_cues.append(cue))
	var bomb_case = preload("res://tests/fixtures/mega_inferno_bomb_network_case.gd").new() if OS.get_environment("CLASH_TEST_MEGA_INFERNO_BOMB") == "1" else null
	var tentacle_case = preload("res://tests/fixtures/soul_tentacle_network_case.gd").new() if OS.get_environment("CLASH_TEST_SOUL_TENTACLE") == "1" else null
	var spark_case = preload("res://tests/fixtures/final_spark_network_case.gd").new() if OS.get_environment("CLASH_TEST_FINAL_SPARK") == "1" else null
	var pulse_case = preload("res://tests/fixtures/convergent_pulse_network_case.gd").new() if OS.get_environment("CLASH_TEST_CONVERGENT_PULSE") == "1" else null
	var solar_case = preload("res://tests/fixtures/solar_flare_network_case.gd").new() if OS.get_environment("CLASH_TEST_SOLAR_FLARE") == "1" else null
	var pool_case = preload("res://tests/fixtures/pool_of_reflection_network_case.gd").new() if OS.get_environment("CLASH_TEST_POOL_OF_REFLECTION") == "1" else null
	var bolt_case = preload("res://tests/fixtures/severing_bolt_network_case.gd").new() if OS.get_environment("CLASH_TEST_SEVERING_BOLT") == "1" else null
	var horizon_case = preload("res://tests/fixtures/event_horizon_network_case.gd").new() if OS.get_environment("CLASH_TEST_EVENT_HORIZON") == "1" else null
	var medium_case = preload("res://tests/fixtures/medium_lightning_network_case.gd").new() if OS.get_environment("CLASH_TEST_MEDIUM_LIGHTNING") == "1" else null
	var start := Time.get_ticks_msec()
	var boundary_unit: Unit
	var expired_id := -1
	var takeover_applied := false
	var fired := false
	var sent_requests := false
	var immediate_feedback := false
	var sent_skill := false
	var interrupted_skill := false
	var shields_added := false
	var outsider: ENetMultiplayerPeer
	var outsider_started := false
	var outsider_rejected := false
	var outsider_disconnected: Array[bool] = [false]
	var stable_callback := false
	var status_case: Dictionary = {}
	var status_pending_seen := false
	var status_checked := false
	var status_passed := false
	var mist_seen := {}
	var mist_exit_applied := false
	var mist_pair_active := false
	var mist_observation: Dictionary = {}
	while Time.get_ticks_msec() - start < 20000:
		await harness.process_frame
		if bomb_case != null: bomb_case.poll(main)
		if tentacle_case != null: tentacle_case.poll(main)
		if spark_case != null: spark_case.poll(main)
		if pulse_case != null: pulse_case.poll(main)
		if solar_case != null: solar_case.poll(main)
		if pool_case != null: pool_case.poll(main)
		if bolt_case != null: bolt_case.poll(main)
		if horizon_case != null: horizon_case.poll(main)
		if medium_case != null: medium_case.tick(main)
		if main.runtime.mode == "server" and main.runtime._match_started and not shields_added:
			main.world.towers_snapshot()[0].add_shield(300, 2, true)
			main.world.towers_snapshot()[0].add_shield(300, 8)
			main.runtime._card_growth.replace_replica({0: {"kayn": {"ranged": 1, "melee": 0, "unlocked": "kayn"}}, 1: {"kayn": {"ranged": 0, "melee": 2, "unlocked": "kayn"}}})
			shields_added = true
		if main.runtime.mode == "server" and main.runtime._match_started and main.runtime._sim_tick_id >= 10 and status_case.is_empty():
			status_case = _begin_status_case(main)
		if main.runtime.mode == "server" and not status_case.is_empty():
			var gnar: Unit = status_case.gnar
			if gnar.is_frozen() and gnar.pending_form_generation == gnar.form_change_serial and gnar.transform_hit_count == 6:
				status_pending_seen = true
			if main.runtime._sim_tick_id >= 48 and not status_checked:
				status_checked = true
				status_passed = status_pending_seen and gnar.form_index == 1 and gnar.is_stunned() and gnar.pending_form_generation == -1
				status_passed = status_passed and gnar.active_skill_cast_serial == 0 and main.runtime._active_skills.entry(gnar.active_ability_id).uses_remaining == main.runtime._active_skills.entry(gnar.active_ability_id).max_uses and status_case.payment.is_settled()
				status_passed = status_passed and status_case.star_target.hp == status_case.star_target.max_hp - 120 and status_case.frozen_target.hp == status_case.frozen_target.max_hp and status_case.stunned_target.hp < status_case.stunned_target.max_hp
				print("[NETWORK_STATUS] ", {"passed": status_passed, "pending_seen": status_pending_seen, "form": gnar.form_index, "star_hp": status_case.star_target.hp, "frozen_hp": status_case.frozen_target.hp, "stunned_hp": status_case.stunned_target.hp})
		if main.runtime.mode == "server" and not status_case.is_empty() and main.runtime._sim_tick_id >= 50 and not mist_exit_applied:
			mist_exit_applied = true
			var exiting: Unit = status_case.mist[1]
			exiting.apply_knockback(exiting.position + Vector2.LEFT, 180.0, 0.2, 1.0)
		var mist_registry: Dictionary = main.world.replica_units_snapshot() if main.runtime.mode == "client" else main.world.authoritative_units_snapshot()
		var mist_ids: Array = []
		for mist_id in mist_registry:
			var mist_unit: Unit = mist_registry[mist_id]
			if mist_unit.target_protection.active(): mist_seen[mist_id] = true
			if mist_unit.card_id == "gwen": mist_ids.append(mist_id)
		# 真实出生ID确定角色：先生成者留在雾内，后生成者在50Tick强制退出。
		# 观察其正式有效窗口，不要求延后的终局仍保留已经自然到期的4秒效果。
		mist_ids.sort()
		var observed_tick: int = main.get_authoritative_server_tick()
		if mist_ids.size() == 2:
			var retained_active: bool = mist_registry[mist_ids[0]].target_protection.active()
			var exited_active: bool = mist_registry[mist_ids[1]].target_protection.active()
			if observed_tick < 50 and retained_active and exited_active: mist_pair_active = true
			if observed_tick >= 55 and observed_tick <= 85 and mist_pair_active and retained_active and not exited_active and mist_observation.is_empty():
				mist_observation = {"tick": observed_tick, "retained_id": mist_ids[0], "exited_id": mist_ids[1], "both_previously_active": mist_pair_active, "retained_active": retained_active, "exited_active": exited_active}
				print("[NETWORK_MIST_OBSERVATION] ", mist_observation)
		if main.runtime.mode == "client" and main.runtime._match_started and main.get_estimated_server_tick() >= 5 and not sent_requests:
			sent_requests = true
			var epoch: String = main.runtime.session.session_id
			main._rpc_register_deck.rpc_id(1, main.runtime._deck, main.runtime._active_skill_choices, epoch, MatchSession.PROTOCOL_VERSION, MatchSession.content_fingerprint())
			var input_tick: int = main.get_estimated_server_tick()
			var before_hand: Array = main.get_authoritative_hand(main.runtime.local_team)
			var before_coins: float = main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir
			var submitted: bool = main.play_card(main.runtime.local_team, "garen", Vector2(300, 580 if main.runtime.local_team == 1 else 1000), {"client_request": true, "elixir": main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team)})
			immediate_feedback = submitted and main._client_inputs.has_card("garen") and main._hand.is_card_pending("garen") and main.get_authoritative_hand(main.runtime.local_team) == before_hand and main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir == before_coins and main.runtime._commands.inspect_cards().is_empty()
			if not capture_dir.is_empty():
				# 等待 CanvasItem 完成本帧重绘，避免截到点击前的画面。
				await harness.process_frame
				await harness.process_frame
				RenderingServer.force_draw(false)
				harness.root.get_texture().get_image().save_png(capture_dir.path_join("client%d-input.png" % main.runtime.local_team))
			main._rpc_active_skill_request.rpc_id(1, 999, input_tick, "old-session", 100)
		# 仅在正式输入时钟与当前单调探针估计一致时点击；长帧后等待正式探针校正，
		# 不改写 input_tick、不补发已拒绝请求，也不放宽服务器 late/future 策略。
		var fresh_input_clock: bool = main._network_clock.synchronized and absf(float(main.get_estimated_server_tick()) - main._network_clock.estimate(Time.get_ticks_msec())) <= 1.5
		if main.runtime.mode == "client" and main.runtime._match_started and main.get_authoritative_server_tick() >= 57 and fresh_input_clock and not sent_skill:
			for ability in main.runtime._active_skills.ids():
				var entry: Dictionary = main.runtime._active_skills.entry(ability)
				if entry.card_id == "garen" and entry.team == main.runtime.local_team and main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir >= float(entry.skill.cost):
					sent_skill = main.use_active_skill(ability, main.runtime.local_team, 0, true)
					break
		if main.runtime.mode == "server" and not interrupted_skill:
			for pending in main.runtime._commands.inspect_skills():
				if int(pending.team) != 1: continue
				var unit: Unit = main.runtime._active_skills.entry(int(pending.ability_id)).unit
				unit.add_shield(300, 2, true)
				unit.add_shield(200, 6)
				unit.stun(2.0)
				interrupted_skill = true
				break
		if main.runtime.mode == "server" and main.runtime._match_started and main.runtime._sim_tick_id >= 20 and not outsider_started:
			outsider_started = true
			outsider = ENetMultiplayerPeer.new()
			outsider.peer_disconnected.connect(func(_id): outsider_disconnected[0] = true)
			outsider.create_client("127.0.0.1", main._network_port)
		if outsider != null:
			if outsider.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
				outsider.poll()
			outsider_rejected = outsider_disconnected[0] or outsider.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED
		if main.runtime.mode == "server" and main.runtime._sim_tick_id >= 55 and not stable_callback:
			var before: int = main.get_child_count()
			main._on_peer_connected(main.runtime.session.peer_for_team(1))
			stable_callback = main.get_child_count() == before and main.world.towers_snapshot().size() == 6 and main.runtime.session.phase == MatchSession.Phase.RUNNING
		if main.runtime.mode == "server" and main.runtime._match_started and main.runtime._sim_tick_id >= 40 and expired_id < 0:
			var building: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "tombstone", Vector2(500, 950), {"deploy_time_override": 0}))
			building.spawn_interval = 0
			building._lifespan_left = 0.05
			expired_id = building.net_id
			boundary_unit = main._spawn_unit(UnitSpawnRequest.new(0, "masteryi", Vector2(480, 850), {"deploy_time_override": 0}))
			boundary_unit.apply_knockback(Vector2(400, 850), 40, 0.4)
			boundary_unit.freeze(0.05)
		if main.runtime.mode == "server" and main.runtime._sim_tick_id >= 42 and not takeover_applied and is_instance_valid(boundary_unit):
			takeover_applied = true
			main._combat.begin_batch(main.runtime._sim_tick_id, "network_boundary_takeover")
			# 高序号先收集，低序号后收集；终态位置由正式快照/RPC 对比。
			boundary_unit.apply_knockback(Vector2(600, 850), 10, 0.1, 1.4, [boundary_unit.combat_source_id, 2, 0])
			boundary_unit.apply_knockback(Vector2(400, 850), 30, 0.4, 1.4, [boundary_unit.combat_source_id, 1, 0])
			main._combat.commit_batch()
		# 必须观察真实技能接纳、team1中断与双方完成后才能终局；外层20秒仍是硬上限。
		if main.runtime.mode == "server" and main.runtime._match_started and main.runtime._sim_tick_id >= terminal_not_before and interrupted_skill and main.fixture_skills_completed() and not fired:
			fired = true
			# 使用真实普攻弹体致胜，覆盖“上一快照刚发出”的终局路径。
			main.launch_attack(main.world.towers_snapshot()[0], main.world.king(1), 100000.0, 100000.0, 0.0, 0.0, Color.WHITE)
			if double_nexus:
				main.launch_attack(main.world.towers_snapshot()[2], main.world.king(0), 100000.0, 100000.0, 0.0, 0.0, Color.WHITE)
		if not capture_dir.is_empty() and main.runtime.mode == "client" and main.runtime._match_started:
			var tick: int = main.get_authoritative_server_tick()
			for checkpoint in [8, 12, 32, 50, 62]:
				if tick >= checkpoint and not captured.has(checkpoint):
					captured[checkpoint] = tick
					RenderingServer.force_draw(false)
					harness.root.get_texture().get_image().save_png(capture_dir.path_join("%s-status-%d.png" % ["client%d" % main.runtime.local_team, checkpoint]))
		playback_peak = maxi(playback_peak, main._network_playback.size())
		if main.runtime.mode == "client" and main._network_clock.synchronized:
			delay_bounds.x = minf(delay_bounds.x, main._network_playback.delay_ticks)
			delay_bounds.y = maxf(delay_bounds.y, main._network_playback.delay_ticks)
		if main.runtime.game_over:
			break
	if outsider != null:
		outsider.close()
	var has_terminal: bool = main.runtime.game_over and not main._terminal_result.is_empty()
	var result := {"schema": 1, "role": "server" if main.runtime.mode == "server" else "client%d" % main.runtime.local_team, "passed": has_terminal}
	if medium_case != null:
		result["medium_lightning"] = medium_case.result(main.runtime.mode == "server")
		result.passed = result.passed and result.medium_lightning.passed
		print("[MEDIUM_LIGHTNING_NETWORK] ", result.medium_lightning)
	result["terminal_not_before"] = terminal_not_before
	result["skill_progress"] = {"sent": sent_skill, "interrupted": interrupted_skill, "accepted": main.accepted_fixture_skills, "completed": main.completed_fixture_skills, "refunds": main.fixture_refunds}
	result["mist_observation"] = mist_observation
	if recorder != null:
		recorder.set_recording_active(false)
		var wav := recorder.get_recording()
		result["audio_recorded"] = wav != null and not wav.data.is_empty() and wav.save_to_wav(capture_dir.path_join(("client%d" % main.runtime.local_team) + "-status.wav")) == OK
		result["capture_ticks"] = captured
		AudioServer.remove_bus_effect(0, recording_slot)
	if has_terminal:
		result["session_id"] = main._terminal_result.session_id
		result["final_tick"] = main._terminal_result.final_tick
		result["winner_team"] = main._terminal_result.winner_team
		result["reason"] = main._terminal_result.reason
		result["tower_hp"] = main.world.towers_snapshot().map(func(t): return t.hp)
		result["tower_controls"] = main.world.towers_snapshot().map(func(t): return [t.frozen_timer > 0, t.control.stun_timer > 0])
		result["tower_shields"] = main.world.towers_snapshot().map(func(t): return [snappedf(t.get_shield_ratio(), 0.000001), snappedf(t.get_shield_capacity_ratio(), 0.000001)])
		result["audio_stopped"] = main._audio_manager == null or main._audio_manager.battle_audio_stopped()
		var units: Array = []
		var registry: Dictionary = main.world.replica_units_snapshot() if main.runtime.mode == "client" else main.world.authoritative_units_snapshot()
		var ids: Array = registry.keys()
		ids.sort()
		for id in ids:
			var unit: Unit = registry[id]
			var pos := unit.net_target_pos if main.runtime.mode == "client" else unit.global_position
			units.append([id, unit.card_id, unit.hp, snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(unit.get_shield_ratio(), 0.000001), snappedf(unit.get_shield_capacity_ratio(), 0.000001), unit.form_index, unit.net_form_change_serial if main.runtime.mode == "client" else unit.form_change_serial, unit.get_attack_visual_serial(), unit.action_cancel_serial, unit.cancelled_visual_serial, unit.action_permissions(), snappedf(unit.get_visual_facing_direction().x, 0.00001), snappedf(unit.get_visual_facing_direction().y, 0.00001), main.runtime.get_active_skill_snapshot(unit.active_ability_id), unit.target_protection.snapshot()])
		result["units"] = units
		result["passed"] = result.audio_stopped and result.winner_team == (-1 if double_nexus else 0) and main.world.king(1).hp == 0.0 and not result.session_id.is_empty() and int(result.final_tick) >= terminal_not_before
		var session_guards: bool = sent_requests and sent_skill if main.runtime.mode == "client" else outsider_rejected and stable_callback and main.runtime.session.request_sequence(1) == 2 and main.runtime.session.request_sequence(0) == 2 and main.runtime.get_authoritative_queue(1).back() == "garen" and interrupted_skill
		if main.runtime.mode == "server":
			result["player_states"] = [_private_state(main, 0), _private_state(main, 1)]
		else:
			result["player_state"] = _private_state(main, main.runtime.local_team)
			result["hand_projection"] = main.runtime._authoritative_card_cycles.is_empty() and main.runtime.get_authoritative_queue(main.runtime.local_team).is_empty() and main._client_hand.version == 1 and main._client_hand.acknowledged_request == 1 and main._hand.get_next_card() == main.get_next_card(main.runtime.local_team)
			result["immediate_feedback"] = immediate_feedback
			result["passed"] = result.passed and result.hand_projection and immediate_feedback
			result["passed"] = result.passed and not main.runtime._card_growth.snapshot().has(1 - main.runtime.local_team)
		if main.runtime.mode == "client":
			var buffer_ok: bool = main._network_clock.synchronized and playback_peak > 0
			for side in [0, 1]:
				for kind in ["card", "skill"]:
					buffer_ok = buffer_ok and announced.any(func(c): return c[0] == kind and c[1] == side and c[2] == 10 and c[3] > 0)
			buffer_ok = buffer_ok and completed.any(func(c): return c[0] == "card" and c[2] == "executed")
			buffer_ok = buffer_ok and completed.any(func(c): return c[0] == "skill" and c[2] == "cancelled")
			buffer_ok = buffer_ok and main._network_commands.inspect().is_empty() and main._network_playback.size() == 0
			result["command_buffer"] = {"passed": buffer_ok, "announced": announced, "completed": completed, "rtt_msec": main._network_clock.rtt_msec, "playback_peak": playback_peak, "delay_tick_range": [delay_bounds.x, delay_bounds.y]}
			var adaptive_ok := delay_bounds.x >= 1.0 and delay_bounds.y <= 4.0
			adaptive_ok = adaptive_ok and (delay_bounds.y >= 3.0 if "--network-impaired" in OS.get_cmdline_user_args() else delay_bounds.x < 2.0)
			result["adaptive_playback"] = adaptive_ok
			result["passed"] = result.passed and buffer_ok and adaptive_ok
		result["remote_elixir"] = main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir if main.runtime.mode == "client" else main.runtime.account(1).elixir
		# team1初始5-盖伦5，技能预扣与原收据退款净0；初期倍率1，金币只由实际Tick回复。
		var expected_team1_coins := float(floor((float(result.final_tick) * main.SIM_DT + 0.0000001) / ElixirManager.REGEN_INTERVAL))
		result["expected_team1_coins"] = expected_team1_coins
		session_guards = session_guards and (result.remote_elixir == expected_team1_coins if main.runtime.mode == "server" or main.runtime.local_team == 1 else result.remote_elixir >= 0.0)
		if main.runtime.mode == "server":
			session_guards = session_guards and main.fixture_refunds.size() == 1 and main.fixture_refunds[0].passed
		if bomb_case != null:
			result["mega_inferno_bomb"] = bomb_case.result()
			result["passed"] = result.passed and result.mega_inferno_bomb.passed
		if tentacle_case != null:
			result["soul_tentacle"] = tentacle_case.result()
			result["passed"] = result.passed and result.soul_tentacle.passed
		if spark_case != null:
			result["final_spark"] = spark_case.result()
			result["passed"] = result.passed and result.final_spark.passed
		if pulse_case != null:
			result["convergent_pulse"] = pulse_case.result()
			result["passed"] = result.passed and result.convergent_pulse.passed
		if solar_case != null:
			result["solar_flare"] = solar_case.result()
			result["passed"] = result.passed and result.solar_flare.passed
		if pool_case != null:
			result["pool_of_reflection"] = pool_case.result()
			result["passed"] = result.passed and result.pool_of_reflection.passed
		if bolt_case != null:
			result["severing_bolt"] = bolt_case.result()
			result["passed"] = result.passed and result.severing_bolt.passed
		if horizon_case != null:
			result["event_horizon"] = horizon_case.result()
			result["passed"] = result.passed and result.event_horizon.passed
		result["session_guards"] = session_guards
		if main.runtime.mode == "server":
			result["status_rules"] = status_checked and status_passed
			result["passed"] = result.passed and status_checked and status_passed and takeover_applied and not main.world.authoritative_units_snapshot().has(expired_id)
			result["boundary_lifecycle"] = takeover_applied and not main.world.authoritative_units_snapshot().has(expired_id)
			result["request_sequence"] = [main.runtime.session.request_sequence(0), main.runtime.session.request_sequence(1)]
			result["outsider_rejected"] = outsider_rejected
			result["callback_stable"] = stable_callback
			result["remote_queue"] = main.runtime.get_authoritative_queue(1)
		result["mist_replication"] = mist_seen.size() == 2 and mist_pair_active and not mist_observation.is_empty()
		result["passed"] = result.passed and session_guards and result.mist_replication
		# 有 GPU 的执行可以保存终局画面；不作为听感确认。
		for arg in OS.get_cmdline_user_args():
			if main.runtime.mode == "client" and arg.begins_with("--network-render-dir="):
				var directory := arg.trim_prefix("--network-render-dir=")
				DirAccess.make_dir_recursive_absolute(directory)
				await harness.process_frame
				await harness.process_frame
				RenderingServer.force_draw(false)
				harness.root.get_texture().get_image().save_png(directory.path_join(("client%d" % main.runtime.local_team) + ".png"))
	if has_terminal and main.runtime.mode == "client":
		var silent_before_finish := result_cues.is_empty()
		var expected_tracks := 2 if double_nexus else 1
		var preserved: bool = main._audio_manager._nexus_players.size() == expected_tracks
		var audio_deadline := Time.get_ticks_msec() + 20000
		while main._audio_manager._terminal_audio_pending and Time.get_ticks_msec() < audio_deadline:
			await harness.process_frame
		var expected: Array = [] if double_nexus else ([&"defeat"] if main.runtime.local_team == 1 else [&"victory"])
		result["audio_sequence"] = silent_before_finish and preserved and not main._audio_manager._terminal_audio_pending and result_cues == expected
		result["result_cues"] = result_cues
		result["double_nexus"] = double_nexus
		result["passed"] = result.passed and result.audio_sequence
	if recorder != null: result["passed"] = result.passed and result.audio_recorded and captured.size() == 5
	if main.runtime.mode == "server":
		result["audio_sequence"] = main._audio_manager == null and main._battle_presentation == null and main._hand == null and main._effects_view == null and main._resources.resources.is_empty() and main._projectile_system.get_child_count() == 0 and main.runtime.local_team == -1
		result["passed"] = result.passed and result.audio_sequence
	if medium_case != null: result.passed = result.passed and result.medium_lightning.passed
	print("[NETWORK_RESULT] " + JSON.stringify(result))
	# 留出可靠结果送达和音频线程释放的窗口，然后关闭自己的 ENet peer。
	await harness.create_timer(0.5).timeout
	main.free()
	await harness.create_timer(0.25).timeout
	harness.quit(0 if result.passed else 1)

## 使用正式创建、弹体和技能排程；主机断言规则，终局单位列表由执行器逐项对比双端。
func _begin_status_case(main: Node2D) -> Dictionary:
	for tower in main.world.towers_snapshot(): tower.can_attack = false
	main.world.towers_snapshot()[0].freeze(10)
	main.world.towers_snapshot()[1].stun(10)
	var saved_history: Dictionary = main.runtime._card_history.get_last(0)
	main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir = 10.0
	var gnar: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "gnar", Vector2(80, 1000), {"deploy_time_override": 0, "active_slot": 1}))
	var queued: bool = main.use_active_skill(gnar.active_ability_id, 0)
	assert(queued)
	var payment: CommandPayment = main.runtime._commands.inspect_skills().back().payment
	var gnar_target := _status_target(main, 1, Vector2(80, 900))
	gnar.freeze(0.5)
	gnar.stun(10)
	for i in 6: main.launch_attack(gnar, gnar_target, 1, 1000, 0, 0, Color.WHITE)
	var star: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "aurelionsol", Vector2(360, 1000), {"deploy_time_override": 0}))
	var star_target := _status_target(main, 1, Vector2(360, 825))
	var star_skill: Dictionary = CardDB.active_skills_for("aurelionsol")[0].duplicate(true)
	star_skill["cast_forward"] = Vector2.UP
	main.runtime._start_active_skill_cast(star, star_skill)
	main.runtime._commands.tick_impacts(float(star_skill.result_creation_delay))
	star.freeze(10)
	star.apply_knockback(star.position + Vector2.LEFT * 40, 100, 0.4)
	var targets: Array[Unit] = []
	for frozen in [false, true]:
		var origin := Vector2(600, 1000 if not frozen else 300)
		var caster: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "sett", origin, {"deploy_time_override": 0}))
		var target := _status_target(main, 1, origin + Vector2(0, -80))
		var skill: Dictionary = CardDB.active_skills_for("sett")[0].duplicate(true)
		skill["cast_forward"] = Vector2.UP
		main.runtime._start_active_skill_cast(caster, skill)
		if frozen: caster.freeze(10)
		else: caster.stun(10)
		targets.append(target)
	# 金币门槛选择通过正式出牌入口，出生载荷携带实际形态和原卡资格。
	var wallet: ElixirManager = main.runtime.account(0)
	var saved_coins := wallet.elixir
	for available in [3.0, 6.0]:
		wallet.elixir = available
		assert(main.play_card(0, "kayle", Vector2(560 + available * 10, 1180), {"immediate": true, "validate_position": false, "elixir": wallet}))
		var angel: Unit = main._latest_unit_for_card("kayle", 0)
		assert(angel.card_id == ("kayle" if available < 6 else "kayle_ranged") and wallet.elixir == 0)
		angel._deploy_timer = 0
		angel.hp -= 160
		main.preview_active_skill(angel, CardDB.active_skills_for("kayle")[0])
		angel.stun(10)
	wallet.elixir = saved_coins
	main.runtime._card_history.replace_replica(0, saved_history)
	var mist_units: Array[Unit] = []
	for position in [Vector2(65, 800), Vector2(360, 1100)]:
		var mist: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "gwen", position, {"deploy_time_override": 0}))
		main.preview_active_skill(mist, CardDB.active_skills_for("gwen")[1])
		mist.freeze(10)
		mist_units.append(mist)
	return {"mist": mist_units, "gnar": gnar, "payment": payment, "star_target": star_target, "stunned_target": targets[0], "frozen_target": targets[1]}

func _status_target(main: Node2D, team: int, position: Vector2) -> Unit:
	var target: Unit = main._spawn_unit(UnitSpawnRequest.new(team, "super_minion", position, {"deploy_time_override": 0}))
	target.freeze(10)
	return target

func _private_state(main: Node2D, team: int) -> Dictionary:
	return {"coins": main.runtime.account(team).elixir, "hand": main.get_authoritative_hand(team),
		"next": main.get_next_card(team), "history": main.runtime._card_history.get_last(team), "growth": main.runtime.growth_snapshot(team)}
