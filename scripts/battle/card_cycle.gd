class_name CardCycle
extends RefCounted
## 权威手牌循环；客户端确认使用 replace_replica，不由 UI 消费牌。
var _deck: Array = []
var _hand: Array = []
var _queue: Array = []

func _init(deck: Array = []) -> void:
	for id in deck: _deck.append(String(id))
	_hand = _deck.slice(0, 4)
	_queue = _deck.slice(4, 8)

func matches(deck: Array) -> bool:
	return _deck == deck.map(func(id): return String(id))

func hand() -> Array:
	return _hand.duplicate()

func queue() -> Array:
	return _queue.duplicate()

func consume(card_id: String) -> bool:
	var index := _hand.find(card_id)
	if index < 0 or _queue.is_empty(): return false
	_hand[index] = _queue.pop_front()
	_queue.push_back(card_id)
	return true

func replace_replica(hand: Array, queue: Array) -> void:
	_hand = hand.duplicate()
	_queue = queue.duplicate()
