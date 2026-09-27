extends RefCounted
## 由唯一机制入口 --network-smoke 启动，Python 执行器负责双进程和日志比对。
func run(harness: SceneTree) -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.set_script(preload("res://tests/fixtures/network_integration_main.gd"))
	harness.root.add_child(main)
	harness.current_scene = main
	var capture_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--network-render-dir="): capture_dir = arg.trim_prefix("--network-render-dir=")
	var recorder: AudioEffectRecord
	var recording_slot := -1
	var captured: Dictionary = {}
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		recorder = AudioEffectRecord.new()
		recording_slot = AudioServer.get_bus_effect_count(0)
		AudioServer.add_bus_effect(0, recorder)
		recorder.set_recording_active(true)
	var double_nexus := OS.get_environment("CLASH_TEST_DOUBLE_NEXUS") == "1"
	var result_cues: Array[StringName] = []
	main._audio_manager.cue_played.connect(func(card, cue, _pos):
		if card == "match" and cue in [&"victory", &"defeat"]: result_cues.append(cue))
	var start := Time.get_ticks_msec()
	var boundary_unit: Unit
	var expired_id := -1
	var takeover_applied := false
	var fired := false
	var sent_requests := false
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
	while Time.get_ticks_msec() - start < 20000:
		await harness.process_frame
		if main.mode == "host" and main._match_started and not shields_added:
			main._towers[0].add_shield(300, 2, true)
			main._towers[0].add_shield(300, 8)
			shields_added = true
		if main.mode == "host" and main._match_started and main._sim_tick_id >= 10 and status_case.is_empty():
			status_case = _begin_status_case(main)
		if main.mode == "host" and not status_case.is_empty():
			var gnar: Unit = status_case.gnar
			if gnar.is_frozen() and gnar.pending_form_generation == gnar.form_change_serial and gnar.transform_hit_count == 6:
				status_pending_seen = true
			if main._sim_tick_id >= 48 and not status_checked:
				status_checked = true
				status_passed = status_pending_seen and gnar.form_index == 1 and gnar.is_stunned() and gnar.pending_form_generation == -1
				status_passed = status_passed and gnar.active_skill_cast_serial == 0 and main._active_skills.entry(gnar.active_ability_id).uses_remaining == main._active_skills.entry(gnar.active_ability_id).max_uses and status_case.payment.is_settled()
				status_passed = status_passed and status_case.star_target.hp == status_case.star_target.max_hp - 120 and status_case.frozen_target.hp == status_case.frozen_target.max_hp and status_case.stunned_target.hp < status_case.stunned_target.max_hp
				print("[NETWORK_STATUS] ", {"passed": status_passed, "pending_seen": status_pending_seen, "form": gnar.form_index, "star_hp": status_case.star_target.hp, "frozen_hp": status_case.frozen_target.hp, "stunned_hp": status_case.stunned_target.hp})
		if main.mode == "host" and not status_case.is_empty() and main._sim_tick_id >= 50 and not mist_exit_applied:
			mist_exit_applied = true
			var exiting: Unit = status_case.mist[1]
			exiting.apply_knockback(exiting.position + Vector2.LEFT, 180.0, 0.2, 1.0)
		var mist_registry: Dictionary = main._client_units if main.mode == "client" else main._net_units
		for mist_id in mist_registry:
			var mist_unit: Unit = mist_registry[mist_id]
			if mist_unit.target_protection.active(): mist_seen[mist_id] = true
		if main.mode == "client" and main._match_started and main.get_estimated_server_tick() >= 5 and not sent_requests:
			sent_requests = true
			var epoch: String = main._session.session_id
			main._rpc_register_deck.rpc_id(1, main._deck, main._active_skill_choices, epoch, MatchSession.PROTOCOL_VERSION, MatchSession.content_fingerprint())
			var input_tick: int = main.get_authoritative_server_tick()
			main._rpc_deploy_request.rpc_id(1, "garen", Vector2(300, 580), input_tick, epoch, 1)
			main._rpc_deploy_request.rpc_id(1, "garen", Vector2(300, 580), input_tick, epoch, 1)
			main._rpc_active_skill_request.rpc_id(1, 999, input_tick, "old-session", 100)
		if main.mode == "client" and main._match_started and main.get_authoritative_server_tick() >= 57 and not sent_skill:
			for ability in main._active_skills.ids():
				var entry: Dictionary = main._active_skills.entry(ability)
				if entry.card_id == "garen" and entry.team == 1 and main._elixir.elixir >= float(entry.skill.cost):
					main._rpc_active_skill_request.rpc_id(1, ability, main.get_authoritative_server_tick(), main._session.session_id, 2)
					sent_skill = true
					break
		if main.mode == "host" and not main._commands.inspect_skills().is_empty() and not interrupted_skill and int(main._commands.inspect_skills()[0].team) == 1:
			var ability: int = main._commands.inspect_skills()[0].ability_id
			var unit: Unit = main._active_skills.entry(ability).unit
			unit.add_shield(300, 2, true)
			unit.add_shield(200, 6)
			unit.stun(2.0)
			interrupted_skill = true
		if main.mode == "host" and main._match_started and main._sim_tick_id >= 20 and not outsider_started:
			outsider_started = true
			outsider = ENetMultiplayerPeer.new()
			outsider.peer_disconnected.connect(func(_id): outsider_disconnected[0] = true)
			outsider.create_client("127.0.0.1", main._network_port)
		if outsider != null:
			if outsider.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
				outsider.poll()
			outsider_rejected = outsider_disconnected[0] or outsider.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED
		if main.mode == "host" and main._sim_tick_id >= 55 and not stable_callback:
			var before: int = main.get_child_count()
			main._on_peer_connected(main._session.opponent_id)
			stable_callback = main.get_child_count() == before and main._towers.size() == 6 and main._session.phase == MatchSession.Phase.RUNNING
		if main.mode == "host" and main._match_started and main._sim_tick_id >= 40 and expired_id < 0:
			var building: Unit = main._spawn_unit(0, "tombstone", Vector2(500, 950), 0)
			building.spawn_interval = 0
			building._lifespan_left = 0.05
			expired_id = building.net_id
			boundary_unit = main._spawn_unit(0, "masteryi", Vector2(480, 850), 0)
			boundary_unit.apply_knockback(Vector2(400, 850), 40, 0.4)
			boundary_unit.freeze(0.05)
		if main.mode == "host" and main._sim_tick_id >= 42 and not takeover_applied and is_instance_valid(boundary_unit):
			takeover_applied = true
			main._combat.begin_batch(main._sim_tick_id, "network_boundary_takeover")
			# 高序号先收集，低序号后收集；终态位置由正式快照/RPC 对比。
			boundary_unit.apply_knockback(Vector2(600, 850), 10, 0.1, 1.4, [boundary_unit.combat_source_id, 2, 0])
			boundary_unit.apply_knockback(Vector2(400, 850), 30, 0.4, 1.4, [boundary_unit.combat_source_id, 1, 0])
			main._combat.commit_batch()
		if main.mode == "host" and main._match_started and main._sim_tick_id >= 85 and not fired:
			fired = true
			# 使用真实普攻弹体致胜，覆盖“上一快照刚发出”的终局路径。
			main.launch_attack(main._towers[0], main._king_enemy, 100000.0, 100000.0, 0.0, 0.0, Color.WHITE)
			if double_nexus:
				main.launch_attack(main._towers[2], main._king_player, 100000.0, 100000.0, 0.0, 0.0, Color.WHITE)
		if not capture_dir.is_empty() and main._match_started:
			var tick: int = main.get_authoritative_server_tick()
			for checkpoint in [12, 32, 50]:
				if tick >= checkpoint and not captured.has(checkpoint):
					captured[checkpoint] = tick
					RenderingServer.force_draw(false)
					harness.root.get_texture().get_image().save_png(capture_dir.path_join("%s-status-%d.png" % [main.mode, checkpoint]))
		if main.game_over:
			break
	if outsider != null:
		outsider.close()
	var result := {"schema": 1, "role": main.mode, "passed": main.game_over}
	if recorder != null:
		recorder.set_recording_active(false)
		var wav := recorder.get_recording()
		result["audio_recorded"] = wav != null and not wav.data.is_empty() and wav.save_to_wav(capture_dir.path_join(main.mode + "-status.wav")) == OK
		result["capture_ticks"] = captured
		AudioServer.remove_bus_effect(0, recording_slot)
	if main.game_over:
		result["session_id"] = main._terminal_result.session_id
		result["final_tick"] = main._terminal_result.final_tick
		result["winner_team"] = main._terminal_result.winner_team
		result["reason"] = main._terminal_result.reason
		result["tower_hp"] = main._towers.map(func(t): return t.hp)
		result["tower_controls"] = main._towers.map(func(t): return [t.frozen_timer > 0, t.control.stun_timer > 0])
		result["tower_shields"] = main._towers.map(func(t): return [snappedf(t.get_shield_ratio(), 0.000001), snappedf(t.get_shield_capacity_ratio(), 0.000001)])
		result["audio_stopped"] = main._audio_manager.battle_audio_stopped()
		var units: Array = []
		var registry: Dictionary = main._client_units if main.mode == "client" else main._net_units
		var ids: Array = registry.keys()
		ids.sort()
		for id in ids:
			var unit: Unit = registry[id]
			var pos := unit.net_target_pos if main.mode == "client" else unit.global_position
			units.append([id, unit.card_id, unit.hp, snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(unit.get_shield_ratio(), 0.000001), snappedf(unit.get_shield_capacity_ratio(), 0.000001), unit.form_index, unit.net_form_change_serial if main.mode == "client" else unit.form_change_serial, unit.get_attack_visual_serial(), unit.action_cancel_serial, unit.cancelled_visual_serial, unit.action_permissions(), snappedf(unit.get_visual_facing_direction().x, 0.00001), snappedf(unit.get_visual_facing_direction().y, 0.00001), main.get_active_skill_snapshot(unit.active_ability_id), unit.target_protection.snapshot()])
		result["units"] = units
		result["passed"] = result.audio_stopped and result.winner_team == (-1 if double_nexus else 0) and main._king_enemy.hp == 0.0 and not result.session_id.is_empty()
		var session_guards: bool = sent_requests and sent_skill if main.mode == "client" else outsider_rejected and stable_callback and main._session.last_request_id == 2 and main.get_authoritative_queue(1).back() == "garen" and interrupted_skill
		result["remote_elixir"] = main._elixir.elixir if main.mode == "client" else main._elixir_p1.elixir
		session_guards = session_guards and result.remote_elixir == 1.0
		result["session_guards"] = session_guards
		if main.mode == "host":
			result["status_rules"] = status_checked and status_passed
			result["passed"] = result.passed and status_checked and status_passed and takeover_applied and not main._net_units.has(expired_id)
			result["boundary_lifecycle"] = takeover_applied and not main._net_units.has(expired_id)
			result["request_sequence"] = main._session.last_request_id
			result["outsider_rejected"] = outsider_rejected
			result["callback_stable"] = stable_callback
			result["remote_queue"] = main.get_authoritative_queue(1)
		var active_mists := 0
		for mist_id in mist_seen:
			if registry.has(mist_id) and registry[mist_id].target_protection.active(): active_mists += 1
		result["mist_replication"] = mist_seen.size() == 2 and active_mists == 1
		result["passed"] = result.passed and session_guards and result.mist_replication
		# 有 GPU 的执行可以保存终局画面；不作为听感确认。
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--network-render-dir="):
				var directory := arg.trim_prefix("--network-render-dir=")
				DirAccess.make_dir_recursive_absolute(directory)
				RenderingServer.force_draw(false)
				harness.root.get_texture().get_image().save_png(directory.path_join(main.mode + ".png"))
	if main.game_over:
		var silent_before_finish := result_cues.is_empty()
		var expected_tracks := 2 if double_nexus else 1
		var preserved: bool = main._audio_manager._nexus_players.size() == expected_tracks
		var audio_deadline := Time.get_ticks_msec() + 20000
		while main._audio_manager._terminal_audio_pending and Time.get_ticks_msec() < audio_deadline:
			await harness.process_frame
		var expected: Array = [] if double_nexus else ([&"defeat"] if main.mode == "client" else [&"victory"])
		result["audio_sequence"] = silent_before_finish and preserved and not main._audio_manager._terminal_audio_pending and result_cues == expected
		result["result_cues"] = result_cues
		result["double_nexus"] = double_nexus
		result["passed"] = result.passed and result.audio_sequence
	if recorder != null: result["passed"] = result.passed and result.audio_recorded and captured.size() == 3
	print("[NETWORK_RESULT] " + JSON.stringify(result))
	# 留出可靠结果送达和音频线程释放的窗口，然后关闭自己的 ENet peer。
	await harness.create_timer(0.5).timeout
	main.free()
	await harness.create_timer(0.25).timeout
	harness.quit(0 if result.passed else 1)

## 使用正式创建、弹体和技能排程；主机断言规则，终局单位列表由执行器逐项对比双端。
func _begin_status_case(main: Node2D) -> Dictionary:
	for tower in main._towers: tower.can_attack = false
	main._towers[0].freeze(10)
	main._towers[1].stun(10)
	main._deck[1] = "gnar"
	main._elixir.elixir = 10.0
	var gnar: Unit = main._spawn_unit(0, "gnar", Vector2(80, 1000), 0, 1)
	var queued: bool = main.use_active_skill(gnar.active_ability_id, 0)
	assert(queued)
	var payment: CommandPayment = main._commands.inspect_skills().back().payment
	var gnar_target := _status_target(main, 1, Vector2(80, 900))
	gnar.freeze(0.5)
	gnar.stun(10)
	for i in 6: main.launch_attack(gnar, gnar_target, 1, 1000, 0, 0, Color.WHITE)
	var star: Unit = main._spawn_unit(0, "aurelionsol", Vector2(360, 1000), 0)
	var star_target := _status_target(main, 1, Vector2(360, 825))
	var star_skill: Dictionary = CardDB.active_skills_for("aurelionsol")[0].duplicate(true)
	star_skill["cast_forward"] = Vector2.UP
	main._start_active_skill_cast(star, star_skill)
	star.freeze(10)
	star.apply_knockback(star.position + Vector2.LEFT * 40, 100, 0.4)
	var targets: Array[Unit] = []
	for frozen in [false, true]:
		var origin := Vector2(600, 1000 if not frozen else 300)
		var caster: Unit = main._spawn_unit(0, "sett", origin, 0)
		var target := _status_target(main, 1, origin + Vector2(0, -80))
		var skill: Dictionary = CardDB.active_skills_for("sett")[0].duplicate(true)
		skill["cast_forward"] = Vector2.UP
		main._start_active_skill_cast(caster, skill)
		if frozen: caster.freeze(10)
		else: caster.stun(10)
		targets.append(target)
	# 金币门槛选择通过正式出牌入口，出生载荷携带实际形态和原卡资格。
	for available in [3.0, 6.0]:
		var wallet := ElixirManager.new()
		wallet.elixir = available
		assert(main.play_card(0, "kayle", Vector2(560 + available * 10, 1180), {"immediate": true, "validate_position": false, "elixir": wallet}))
		var angel: Unit = main._latest_unit_for_card("kayle", 0)
		assert(angel.card_id == ("kayle" if available < 6 else "kayle_ranged") and wallet.elixir == 0)
		angel._deploy_timer = 0
		angel.hp -= 160
		main.preview_active_skill(angel, CardDB.active_skills_for("kayle")[0])
		angel.stun(10)
		wallet.free()
	var mist_units: Array[Unit] = []
	for position in [Vector2(65, 800), Vector2(360, 1100)]:
		var mist: Unit = main._spawn_unit(0, "gwen", position, 0)
		main.preview_active_skill(mist, CardDB.active_skills_for("gwen")[1])
		mist.freeze(10)
		mist_units.append(mist)
	return {"mist": mist_units, "gnar": gnar, "payment": payment, "star_target": star_target, "stunned_target": targets[0], "frozen_target": targets[1]}

func _status_target(main: Node2D, team: int, position: Vector2) -> Unit:
	var target: Unit = main._spawn_unit(team, "super_minion", position, 0)
	target.freeze(10)
	return target
