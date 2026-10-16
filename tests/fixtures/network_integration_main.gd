extends "res://scripts/main.gd"
var _queue_probe: Variant
var _queue_trace_output := ""
var accepted_fixture_skills: Array[Dictionary] = []
var completed_fixture_skills: Array[Dictionary] = []
var fixture_refunds: Array[Dictionary] = []
## 终局网络测试需要固定盖伦出牌；随机首手由 MirrorSuite 和双进程镜像配方覆盖。
func _ready() -> void:
	server_auto_restart = false
	# 场景需要盖伦携带一费技能，不能依赖新增卡牌后的数据库注册顺序。
	_deck = ["garen", "gnar", "xin", "teemo", "ashe", "heal", "freeze", "tombstone"]
	_active_skill_choices = {"garen": 0}
	super._ready()
	_queue_trace_output = OS.get_environment("CLASH_QUEUE_TRACE_DIR")
	var fixed_delay := 0.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--queue-trace-output="): _queue_trace_output = argument.trim_prefix("--queue-trace-output=")
		if argument.begins_with("--queue-trace-delay-ticks="): fixed_delay = float(argument.trim_prefix("--queue-trace-delay-ticks="))
	if mode == "client" and not _queue_trace_output.is_empty():
		_queue_probe = load("res://tools/performance/network_queue_probe.gd").new()
		_queue_probe.configure(fixed_delay)
		_network_playback = _queue_probe

func _exit_tree() -> void:
	if _queue_probe != null:
		_queue_probe.save(_queue_trace_output.path_join("client%d.bin" % local_team), {"team": local_team, "impaired": "--network-impaired" in OS.get_cmdline_user_args(), "game_over": game_over, "session_id": _session.session_id})
	super._exit_tree()

func _initialize_authoritative_card_cycle(team: int, deck: Array) -> bool:
	if not super._initialize_authoritative_card_cycle(team, deck): return false
	preload("res://tests/fixtures/network_fixture.gd").fixed_cycle(self, team, deck)
	return true

var _incoming_snapshots := 0

@rpc("authority", "call_remote", "unreliable")
func _rpc_snapshot(snapshot_bytes: PackedByteArray) -> void:
	if "--network-impaired" in OS.get_cmdline_user_args():
		_incoming_snapshots += 1
		# 丢弃三分之一普通快照，并让其余快照交错延迟，产生可复现乱序。
		if _incoming_snapshots % 3 == 0:
			if _queue_probe != null: _queue_probe.record_transport_drop(snapshot_bytes.size())
			return
		await get_tree().create_timer(0.12 if _incoming_snapshots % 2 == 0 else 0.02).timeout
	if _queue_probe != null: _queue_probe.begin_receive(snapshot_bytes)
	super._rpc_snapshot(snapshot_bytes)
	if _queue_probe != null: _queue_probe.end_receive()

@rpc("authority", "call_remote", "reliable")
func _rpc_command_scheduled(epoch: String, command: Dictionary) -> void:
	if "--network-impaired" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.07).timeout
	super._rpc_command_scheduled(epoch, command)

@rpc("authority", "call_remote", "reliable")
func _rpc_battle_event(epoch: String, tick: int, method: StringName, args: Array) -> void:
	if "--network-impaired" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.12).timeout
	super._rpc_battle_event(epoch, tick, method, args)

@rpc("authority", "call_remote", "unreliable", 2)
func _rpc_clock_sample(epoch: String, probe_id: int, tick_time: float) -> void:
	if "--network-impaired" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.04).timeout
	super._rpc_clock_sample(epoch, probe_id, tick_time)

func _send_card_request(card_id: String, pos: Vector2, input_tick: int, request_id: int) -> void:
	if "--network-impaired" in OS.get_cmdline_user_args(): await get_tree().create_timer(0.08).timeout
	super._send_card_request(card_id, pos, input_tick, request_id)

func _send_skill_request(ability_id: int, input_tick: int, request_id: int) -> void:
	_trace_skill("client_submit", {"ability": ability_id, "input_tick": input_tick, "request_id": request_id})
	if "--network-impaired" in OS.get_cmdline_user_args(): await get_tree().create_timer(0.08).timeout
	_trace_skill("client_send", {"ability": ability_id, "input_tick": input_tick, "request_id": request_id})
	super._send_skill_request(ability_id, input_tick, request_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_active_skill_request(ability_id: int, input_tick: int = -1, epoch: String = "", request_id: int = 0) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var team := _session.team_for_peer(sender)
	_trace_skill("server_receive", {"ability": ability_id, "input_tick": input_tick, "request_id": request_id, "sender": sender, "team": team, "epoch_matches": epoch == _session.session_id, "sequence_before": _session.request_sequence(team), "execute_tick": _resolve_command_execute_tick(input_tick)})
	super._rpc_active_skill_request(ability_id, input_tick, epoch, request_id)
	_trace_skill("server_request_result", {"ability": ability_id, "request_id": request_id, "team": team, "sequence_after": _session.request_sequence(team), "pending": _commands.has_pending_skill(ability_id)})

func _queue_active_skill(ability_id: int, expected_team: int = -1, requester_peer_id: int = 0, input_tick: int = -1) -> bool:
	var qualified := _active_skill_has_qualification(ability_id, expected_team)
	var can_submit := _can_submit_active_skill(ability_id, expected_team)
	var execute_tick := _resolve_command_execute_tick(input_tick)
	var entry := _active_skills.entry(ability_id)
	var wallet := _elixir_for_team(int(entry.get("team", expected_team)))
	var cost := _active_skills.cost(ability_id) if not entry.is_empty() else -1.0
	var coins := wallet.elixir if wallet != null else -1.0
	var accepted := super._queue_active_skill(ability_id, expected_team, requester_peer_id, input_tick)
	if accepted:
		accepted_fixture_skills.append({"team": expected_team, "card": entry.get("card_id", ""), "ability": ability_id, "input_tick": input_tick, "execute_tick": execute_tick})
	var reason := "accepted" if accepted else ("qualification" if not qualified else ("submission_gate" if not can_submit else ("input_tick_window" if execute_tick < 0 else "payment")))
	_trace_skill("server_queue", {"ability": ability_id, "card": entry.get("card_id", ""), "team": expected_team, "input_tick": input_tick, "execute_tick": execute_tick, "qualified": qualified, "can_submit": can_submit, "coins_before": coins, "cost": cost, "accepted": accepted, "reason": reason})
	return accepted

func _complete_network_command(id: int, outcome: String) -> void:
	for command in _network_commands.inspect():
		if int(command.id) == id and command.kind == "skill":
			completed_fixture_skills.append({"team": command.team, "card": command.card_id, "ability": command.ability_id, "execute_tick": command.execute_tick, "outcome": outcome})
			_trace_skill("server_finished", completed_fixture_skills.back().duplicate())
			break
	super._complete_network_command(id, outcome)

func _tick_pending_active_skills(dt: float) -> void:
	var refunds: Array[Dictionary] = []
	for pending in _commands.inspect_skills():
		if int(pending.team) != 1 or int(pending.execute_tick) > _sim_tick_id: continue
		var entry := _active_skills.entry(int(pending.ability_id))
		if entry.get("card_id") != "garen": continue
		var payment: CommandPayment = pending.payment
		refunds.append({"ability": int(pending.ability_id), "payment": payment, "amount": payment._amount, "coins_before": _elixir_p1.elixir, "settled_before": payment.is_settled(), "payer_matches": payment._payer != null and payment._payer.get_ref() == _elixir_p1, "uses_before": entry.uses_remaining, "cooldown_before": entry.cooldown_left, "cast_before": (entry.unit as Unit).active_skill_cast_serial})
	super._tick_pending_active_skills(dt)
	for refund in refunds:
		var after := _active_skills.entry(refund.ability)
		var receipt: CommandPayment = refund.payment
		refund.erase("payment")
		refund.merge({"tick": _sim_tick_id, "coins_after": _elixir_p1.elixir, "settled_after": receipt.is_settled(), "uses_after": after.uses_remaining, "cooldown_after": after.cooldown_left, "cast_after": (after.unit as Unit).active_skill_cast_serial})
		refund["passed"] = refund.payer_matches and not refund.settled_before and refund.settled_after and refund.coins_after - refund.coins_before == refund.amount and refund.uses_after == refund.uses_before and refund.cooldown_after == refund.cooldown_before and refund.cast_after == refund.cast_before
		fixture_refunds.append(refund)
		_trace_skill("server_refund", refund.duplicate())

func fixture_skills_completed() -> bool:
	for team in [0, 1]:
		if not accepted_fixture_skills.any(func(skill): return skill.team == team and skill.card == "garen"): return false
		if not completed_fixture_skills.any(func(skill): return skill.team == team and skill.card == "garen" and skill.outcome == ("executed" if team == 0 else "cancelled")): return false
	return true

@rpc("authority", "call_remote", "reliable")
func _rpc_active_skill_rejected(epoch: String, ability_id: int, request_id: int) -> void:
	_trace_skill("client_rejected", {"ability": ability_id, "request_id": request_id, "epoch_matches": epoch == _session.session_id})
	super._rpc_active_skill_rejected(epoch, ability_id, request_id)

func _trace_skill(stage: String, details: Dictionary) -> void:
	details.merge({"stage": stage, "role": mode, "local_team": local_team, "sim_tick": _sim_tick_id, "authority_tick": get_authoritative_server_tick(), "estimated_tick": get_estimated_server_tick(), "clock_estimate": _network_clock.estimate(Time.get_ticks_msec()), "clock_synchronized": _network_clock.synchronized, "phase": _session.phase, "game_over": game_over, "wall_msec": Time.get_ticks_msec()})
	print("[NETWORK_SKILL_TRACE] " + JSON.stringify(details))
