extends "res://scripts/main.gd"
## 故障只注入测试场景；生产协议和 RPC 路径不变。
var loading_wait_observed := false

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
	if assigned_team == 0 and boundary_case() in ["protocol", "content"]:
		local_team = assigned_team
		await get_tree().create_timer(1.0).timeout
		if boundary_case() == "protocol":
			super._rpc_offer(epoch, protocol - 1, fingerprint, assigned_team)
		else:
			_session.join(epoch)
			_snapshot_system.reset_session(epoch)
			_rpc_register_deck.rpc_id(1, _deck, _active_skill_choices, epoch, protocol, "incompatible-content")
	else:
		super._rpc_offer(epoch, protocol, fingerprint, assigned_team)

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
