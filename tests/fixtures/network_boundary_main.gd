extends "res://scripts/main.gd"
## 故障只注入测试场景；生产协议和 RPC 路径不变。
var loading_wait_observed := false
var _boundary_offer_seen: Dictionary = {}
var _boundary_pending_offer: Dictionary = {}
var _boundary_fault_dispatched := false

func _ready() -> void:
	server_auto_restart = boundary_case() == "restart"
	if boundary_case() == "buildings":
		_deck = ["tombstone", "sun_disc", "apex_turret", "garen", "xin", "ashe", "freeze", "heal"]
	super._ready()

func boundary_case() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--network-case="): return argument.trim_prefix("--network-case=")
	return ""

@rpc("authority", "call_remote", "reliable")
func _rpc_offer(epoch: String, protocol: int, fingerprint: String, assigned_team: int) -> void:
	if boundary_case() not in ["protocol", "content"]:
		super._rpc_offer(epoch, protocol, fingerprint, assigned_team)
		return
	if assigned_team == 0:
		super._rpc_offer(epoch, protocol, fingerprint, assigned_team)
	elif assigned_team == 1:
		# 身份来自真实offer；第二席暂不提交卡组，等待两端都实际收到offer。
		local_team = assigned_team
		_boundary_pending_offer = {"epoch": epoch, "protocol": protocol, "fingerprint": fingerprint, "team": assigned_team}
	else:
		super._rpc_offer(epoch, protocol, fingerprint, assigned_team)
		return
	_rpc_boundary_offer_seen.rpc_id(1, epoch)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_boundary_offer_seen(epoch: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if boundary_case() not in ["protocol", "content"] or mode != "server" or not _session.accepts(sender, epoch, MatchSession.Phase.LOBBY): return
	_boundary_offer_seen[sender] = true
	_maybe_inject_boundary_fault()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_register_deck(deck: Array, active_skill_choices: Dictionary = {}, epoch: String = "", protocol: int = -1, fingerprint: String = "") -> void:
	super._rpc_register_deck(deck, active_skill_choices, epoch, protocol, fingerprint)
	_maybe_inject_boundary_fault()

func _maybe_inject_boundary_fault() -> void:
	if boundary_case() not in ["protocol", "content"] or mode != "server" or _boundary_fault_dispatched or _session.phase != MatchSession.Phase.LOBBY or _session.players.size() != 2: return
	var first := _session.peer_for_team(0)
	var second := _session.peer_for_team(1)
	if not _boundary_offer_seen.has(first) or not _boundary_offer_seen.has(second) or not _session.has_deck(first): return
	_boundary_fault_dispatched = true
	print("[BOUNDARY_HANDSHAKE] 双方真实offer已确认，第一席卡组已验证，向第二席注入：", boundary_case())
	_rpc_boundary_inject_fault.rpc_id(second, _session.session_id)

@rpc("authority", "call_remote", "reliable")
func _rpc_boundary_inject_fault(epoch: String) -> void:
	if mode != "client" or _boundary_pending_offer.get("epoch") != epoch or _boundary_pending_offer.get("team") != local_team or _session.phase != MatchSession.Phase.LOBBY: return
	var offer := _boundary_pending_offer
	_boundary_pending_offer = {}
	if boundary_case() == "protocol":
		# 经正式客户端offer入口拒绝旧协议；join仍记录真实会话供终态比对。
		super._rpc_offer(epoch, int(offer.protocol) - 1, String(offer.fingerprint), int(offer.team))
	elif boundary_case() == "content":
		# 内容故障必须经正式服务端注册入口拒绝，不能在客户端自造失败。
		if not _session.join(epoch): return
		_snapshot_system.reset_session(epoch)
		_rpc_register_deck.rpc_id(1, _deck, _active_skill_choices, epoch, int(offer.protocol), "incompatible-content")

@rpc("authority", "call_remote", "reliable")
func _rpc_start(epoch: String, remote_deck: Array, remote_choices: Dictionary) -> void:
	if boundary_case() in ["slow", "slow_second_client"] and local_team == (0 if boundary_case() == "slow" else 1):
		loading_wait_observed = not _match_started and _sim_tick_id == 0
		await get_tree().create_timer(1.0).timeout
		loading_wait_observed = loading_wait_observed and not _match_started and _sim_tick_id == 0
	if boundary_case() == "load_timeout" and local_team == 0:
		# 不发送 ready，服务器超时处理由场景驱动器缩短等待触发。
		return
	super._rpc_start(epoch, remote_deck, remote_choices)

func _initialize_authoritative_card_cycle(team: int, deck: Array) -> bool:
	if not super._initialize_authoritative_card_cycle(team, deck): return false
	if boundary_case() == "buildings": preload("res://tests/fixtures/network_fixture.gd").fixed_cycle(self, team, deck)
	return true
