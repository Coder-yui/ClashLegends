class_name MatchSession
extends RefCounted
## 服务器拥有两席玩家；连接可替换，玩家身份与阵营不依赖 peer_id。
enum Phase { LOBBY, LOADING, RUNNING, FINISHED, DISCONNECTED }
const PROTOCOL_VERSION := 99
var phase := Phase.LOBBY
var session_id := ""
var players: Dictionary = {}
# 以下仅为客户端的服务器身份与准备状态。
var opponent_id := 0
var local_ready := false
var remote_ready := false
var deck_confirmed := false

func open(epoch: String) -> void:
	session_id = epoch

func bind_player(peer_id: int) -> int:
	if phase != Phase.LOBBY or peer_id <= 1 or session_id.is_empty() or team_for_peer(peer_id) >= 0 or players.size() >= 2:
		return -1
	var team := players.size()
	players[team] = {"player_id": "%s:%d" % [session_id, team], "peer_id": peer_id,
		"deck_confirmed": false, "ready": false, "last_request_id": 0}
	return team

func team_for_peer(peer_id: int) -> int:
	for team in players:
		if int(players[team].peer_id) == peer_id: return int(team)
	return -1

func peer_for_team(team: int) -> int:
	return int(players.get(team, {}).get("peer_id", 0))

func request_sequence(team: int) -> int:
	return int(players.get(team, {}).get("last_request_id", 0))

func has_deck(peer_id: int) -> bool:
	return bool(players.get(team_for_peer(peer_id), {}).get("deck_confirmed", false))

func join(epoch: String) -> bool:
	if phase != Phase.LOBBY or epoch.is_empty(): return false
	opponent_id = 1
	session_id = epoch
	phase = Phase.LOADING
	return true

func accepts(peer_id: int, epoch: String, required_phase: Phase) -> bool:
	var bound := team_for_peer(peer_id) >= 0 if not players.is_empty() else peer_id == opponent_id and peer_id > 0
	return bound and not epoch.is_empty() and epoch == session_id and phase == required_phase

func confirm_deck(peer_id: int, epoch: String) -> bool:
	if not accepts(peer_id, epoch, Phase.LOBBY) or has_deck(peer_id): return false
	players[team_for_peer(peer_id)].deck_confirmed = true
	return true

func begin_loading() -> bool:
	if phase != Phase.LOBBY or players.size() != 2: return false
	for player in players.values():
		if not player.deck_confirmed: return false
	phase = Phase.LOADING
	return true

func mark_remote_ready(peer_id: int, epoch: String) -> bool:
	if not accepts(peer_id, epoch, Phase.LOADING): return false
	if not players.is_empty():
		var player: Dictionary = players[team_for_peer(peer_id)]
		if not player.deck_confirmed or player.ready: return false
		player.ready = true
	else:
		if not deck_confirmed or remote_ready: return false
		remote_ready = true
	return true

func start() -> bool:
	if phase != Phase.LOADING or not local_ready: return false
	if not players.is_empty():
		if players.size() != 2: return false
		for player in players.values():
			if not player.ready: return false
	elif not deck_confirmed or not remote_ready: return false
	phase = Phase.RUNNING
	return true

func accept_command(peer_id: int, epoch: String, request_id: int) -> bool:
	if not accepts(peer_id, epoch, Phase.RUNNING): return false
	var team := team_for_peer(peer_id)
	if team < 0 or request_id <= request_sequence(team): return false
	players[team].last_request_id = request_id
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
