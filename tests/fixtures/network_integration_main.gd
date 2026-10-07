extends "res://scripts/main.gd"
## 终局网络测试需要固定盖伦出牌；随机首手由 MirrorSuite 和双进程镜像配方覆盖。
func _ready() -> void:
	server_auto_restart = false
	# 场景需要盖伦携带一费技能，不能依赖新增卡牌后的数据库注册顺序。
	_deck = ["garen", "gnar", "xin", "teemo", "ashe", "heal", "freeze", "tombstone"]
	_active_skill_choices = {"garen": 0}
	super._ready()

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
		if _incoming_snapshots % 3 == 0: return
		await get_tree().create_timer(0.12 if _incoming_snapshots % 2 == 0 else 0.02).timeout
	super._rpc_snapshot(snapshot_bytes)

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
	if "--network-impaired" in OS.get_cmdline_user_args(): await get_tree().create_timer(0.08).timeout
	super._send_skill_request(ability_id, input_tick, request_id)
