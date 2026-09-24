class_name CardCycle
extends RefCounted
## 权威手牌循环；客户端确认使用 replace_replica，不由 UI 消费牌。
var _deck: Array = []
var _hand: Array = []
var _queue: Array = []

func _init(deck: Array = [], randomize_opening: bool = true) -> void:
	for id in deck: _deck.append(String(id))
	var order := _deck.duplicate()
	if randomize_opening:
		order.shuffle()
		# 条件均匀分布：镜像落在前四时，与后四中的随机位置交换。
		for index in mini(4, order.size()):
			if CardPlayHistory.is_mirror(String(order[index])) and order.size() == 8:
				var replacement := randi_range(4, 7)
				var other = order[replacement]
				order[replacement] = order[index]
				order[index] = other
	_hand = order.slice(0, 4)
	_queue = order.slice(4, 8)

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
