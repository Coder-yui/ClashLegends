class_name MatchSession
extends RefCounted
## 一场 1v1 会话的身份、阶段与请求去重；不持有场景、RPC 或战斗对象。
enum Phase { LOBBY, LOADING, RUNNING, FINISHED, DISCONNECTED }
const PROTOCOL_VERSION := 44
var phase := Phase.LOBBY
var session_id := ""
var opponent_id := 0
var deck_confirmed := false
var local_ready := false
var remote_ready := false
var last_request_id := 0

func bind_opponent(peer_id: int, epoch: String) -> bool:
	if phase != Phase.LOBBY or opponent_id != 0 or peer_id <= 1 or epoch.is_empty():
		return false
	opponent_id = peer_id
	session_id = epoch
	phase = Phase.LOADING
	return true

func join(epoch: String) -> bool:
	if phase != Phase.LOBBY or epoch.is_empty():
		return false
	opponent_id = 1
	session_id = epoch
	phase = Phase.LOADING
	return true

func accepts(peer_id: int, epoch: String, required_phase: Phase) -> bool:
	return peer_id == opponent_id and peer_id > 0 and not epoch.is_empty() and epoch == session_id and phase == required_phase

func confirm_deck(peer_id: int, epoch: String) -> bool:
	if not accepts(peer_id, epoch, Phase.LOADING) or deck_confirmed:
		return false
	deck_confirmed = true
	return true

func mark_remote_ready(peer_id: int, epoch: String) -> bool:
	if not accepts(peer_id, epoch, Phase.LOADING) or not deck_confirmed or remote_ready:
		return false
	remote_ready = true
	return true

func start() -> bool:
	if phase != Phase.LOADING or not deck_confirmed or not local_ready or not remote_ready:
		return false
	phase = Phase.RUNNING
	return true

func accept_command(peer_id: int, epoch: String, request_id: int) -> bool:
	if not accepts(peer_id, epoch, Phase.RUNNING) or request_id <= last_request_id:
		return false
	last_request_id = request_id
	return true

func finish(disconnected: bool = false) -> void:
	phase = Phase.DISCONNECTED if disconnected else Phase.FINISHED

static func content_fingerprint() -> String:
	# 卡牌完整编译内容与规则版本共同标识兼容性；修改规则算法时必须提升协议版本。
	return var_to_bytes([PROTOCOL_VERSION, CardDB.all(), MatchRules.REGULATION_TIME,
		MatchRules.OVERTIME_TIME, FixedStepClock.STEP]).hex_encode().sha256_text()

static func valid_deck(deck: Array, choices: Dictionary) -> bool:
	if deck.size() != 8:
		return false
	var seen := {}
	for id in deck:
		if not id is String or not CardDB.has_card(id) or seen.has(id) or not bool(CardDB.get_card(id).get("selectable", true)):
			return false
		seen[id] = true
	for id in choices:
		if not seen.has(id) or not choices[id] is int:
			return false
		var skills := CardDB.active_skills_for(id)
		if choices[id] < 0 or choices[id] >= maxi(skills.size(), 1):
			return false
	return true
