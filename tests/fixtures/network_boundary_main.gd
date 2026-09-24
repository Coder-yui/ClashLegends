extends "res://scripts/main.gd"
## 仅测试场景替换：保留正式 RPC 名称/权限/参数，注入慢加载及兼容性故障。
var loading_wait_observed := false

func _ready() -> void:
	if boundary_case() == "buildings":
		_deck = ["tombstone", "sun_disc", "apex_turret", "garen", "xin", "ashe", "freeze", "heal"]
	super._ready()

func boundary_case() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--network-case="):
			return argument.trim_prefix("--network-case=")
	return ""

@rpc("authority", "call_remote", "reliable")
func _rpc_offer(epoch: String, protocol: int, fingerprint: String, deck: Array, choices: Dictionary) -> void:
	if boundary_case() == "protocol":
		super._rpc_offer(epoch, protocol - 1, fingerprint, deck, choices)
	elif boundary_case() == "content":
		# 客户端宣称不兼容内容，验证主机在建立战场/扣费前拒绝。
		_session.join(epoch)
		_snapshot_system.reset_session(epoch)
		_rpc_register_deck.rpc_id(1, _deck, _active_skill_choices, epoch, protocol, "incompatible-content")
	else:
		super._rpc_offer(epoch, protocol, fingerprint, deck, choices)

@rpc("authority", "call_remote", "reliable")
func _rpc_start(epoch: String) -> void:
	if boundary_case() == "slow":
		loading_wait_observed = not _match_started and _sim_tick_id == 0
		await get_tree().create_timer(1.0).timeout
		loading_wait_observed = loading_wait_observed and not _match_started and _sim_tick_id == 0
	super._rpc_start(epoch)

func _prepare_match_assets() -> void:
	if boundary_case() == "slow_host" and mode == "host":
		loading_wait_observed = _sim_tick_id == 0 and not _session.local_ready
		await get_tree().create_timer(1.0, true).timeout
		loading_wait_observed = loading_wait_observed and _sim_tick_id == 0
	await super._prepare_match_assets()

func _initialize_authoritative_card_cycle(team: int, deck: Array) -> bool:
	if not super._initialize_authoritative_card_cycle(team, deck): return false
	if boundary_case() == "buildings":
		preload("res://tests/suites/network_fixture.gd").fixed_cycle(self, team, deck)
	return true
