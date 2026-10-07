class_name CardCycle
extends RefCounted
## 服务端/单机权威手牌循环；联网客户端只用ClientHandState。
var _deck: Array = []
var _hand: Array = []
var _queue: Array = []
var version := 0
var shuffle_seed := -1

func _init(deck: Array = [], randomize_opening: bool = true, initial_seed: int = -1) -> void:
	for id in deck: _deck.append(String(id))
	var order := _deck.duplicate()
	if randomize_opening:
		var rng := RandomNumberGenerator.new()
		if initial_seed < 0: rng.randomize()
		else: rng.seed = initial_seed
		shuffle_seed = rng.seed
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var other = order[j]
			order[j] = order[i]
			order[i] = other
		# 条件均匀分布：镜像落在前四时，与后四中的随机位置交换。
		for index in mini(4, order.size()):
			if CardPlayHistory.is_mirror(String(order[index])) and order.size() == 8:
				var replacement := rng.randi_range(4, 7)
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
	version += 1
	return true

func visible_state(ack: int, history: Dictionary) -> Dictionary:
	return {"version": version, "ack": ack, "hand": hand(), "next": String(_queue[0]) if not _queue.is_empty() else "", "history": history.duplicate(true)}

func replace_replica(hand: Array, queue: Array) -> void:
	_hand = hand.duplicate()
	_queue = queue.duplicate()
