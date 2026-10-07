class_name ClientInputState
extends RefCounted
## 本机输入反馈与请求对应，不拥有付款、牌序或战斗效果。
var _cards: Dictionary = {}
var _skills: Dictionary = {}

func card(id: String, request: int, pos: Vector2) -> void:
	_cards[id] = {"request": request, "pos": pos}

func finish_card(id: String, request: int) -> bool:
	if int(_cards.get(id, {}).get("request", -1)) != request: return false
	_cards.erase(id)
	return true

func has_card(id: String) -> bool:
	return _cards.has(id)

func visit_cards(visitor: Callable) -> void:
	for entry in _cards.values(): visitor.call(entry.pos)

func skill(id: int, request: int) -> void:
	_skills[id] = request

func finish_skill(id: int, request: int) -> bool:
	if int(_skills.get(id, -1)) != request: return false
	_skills.erase(id)
	return true

func forget_skill(id: int) -> void:
	_skills.erase(id)

func clear() -> void:
	_cards.clear()
	_skills.clear()
