class_name ClientHandState
extends RefCounted
## 客户端只保留可见牌面，永不持有完整待抽队列或洗牌随机源。
var version := -1
var acknowledged_request := -1
var hand: Array = []
var next_card := ""
var history: Dictionary = {}

static func valid(state: Dictionary, deck: Array) -> bool:
	if state.size() != 5: return false
	if not state.get("version") is int or state.version < 0: return false
	if not state.get("ack") is int or state.ack < 0: return false
	if not state.get("hand") is Array or state.hand.size() != 4: return false
	if not state.get("next") is String or not state.get("history") is Dictionary: return false
	var seen := {}
	for id in state.hand + [state.next]:
		if not id is String or id not in deck or seen.has(id): return false
		seen[id] = true
	if not state.history.is_empty():
		if state.history.size() != 3: return false
		if not state.history.get("card_id") is String or state.history.card_id not in deck: return false
		if not state.history.get("deployment_card_id") is String or not CardDB.has_card(state.history.deployment_card_id): return false
		if not state.history.get("cost") is int or state.history.cost < 0: return false
	return true

func apply(state: Dictionary, deck: Array) -> bool:
	if not valid(state, deck) or int(state.version) <= version or int(state.ack) < acknowledged_request: return false
	version = int(state.version)
	acknowledged_request = int(state.ack)
	hand = state.hand.duplicate()
	next_card = String(state.next)
	history = state.history.duplicate(true)
	return true

func clear() -> void:
	version = -1
	acknowledged_request = -1
	hand.clear()
	next_card = ""
	history.clear()
