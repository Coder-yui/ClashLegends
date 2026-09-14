class_name ShieldState
extends RefCounted
## 每次施加是一层，独立持有生命、容量、剩余时间与衰减余量。
## 抵伤优先最早到期层；同刻到期按施加顺序，不依赖字典遍历顺序。
var _layers: Array[Dictionary] = []
var _next_id := 1

func add(amount: float, duration: float, decays: bool = false) -> int:
	if not is_finite(amount) or not is_finite(duration):
		return -1
	amount = BattleNumbers.quantity(maxf(amount, 0.0))
	duration = maxf(BattleNumbers.decimal(duration), 0.0)
	if amount <= 0.0 or duration <= 0.0:
		return -1
	var id := _next_id
	_next_id += 1
	_layers.append({"id": id, "hp": amount, "capacity": amount, "left": duration,
		"rate": amount / duration if decays else 0.0, "remainder": 0.0})
	return id

func tick(dt: float) -> void:
	if dt <= 0.0 or not is_finite(dt):
		return
	for layer in _layers:
		var elapsed := minf(dt, float(layer.left))
		layer.left = maxf(0.0, float(layer.left) - dt)
		var total := float(layer.remainder) + float(layer.rate) * elapsed
		var decay := roundf(total)
		layer.remainder = total - decay
		layer.hp = maxf(0.0, float(layer.hp) - decay)
	_prune()

## 返回未被吸收的伤害；结算边界使用整数，衰减的零头归各层自己持有。
func absorb(amount: float) -> float:
	var remaining := float(BattleNumbers.quantity(amount))
	_layers.sort_custom(func(a, b):
		if is_equal_approx(float(a.left), float(b.left)):
			return int(a.id) < int(b.id)
		return float(a.left) < float(b.left))
	for layer in _layers:
		var absorbed := minf(float(layer.hp), remaining)
		layer.hp = float(layer.hp) - absorbed
		remaining -= absorbed
		if remaining <= 0.0:
			break
	_prune()
	return remaining

func clear() -> void:
	_layers.clear()
	_next_id = 1

func total_hp() -> float:
	var total := 0.0
	for layer in _layers:
		total += float(layer.hp)
	return total

func total_capacity() -> float:
	var total := 0.0
	for layer in _layers:
		total += float(layer.capacity)
	return total

func longest_remaining() -> float:
	var longest := 0.0
	for layer in _layers:
		longest = maxf(longest, float(layer.left))
	return longest

func _prune() -> void:
	_layers = _layers.filter(func(layer): return float(layer.left) > 0.000001 and float(layer.hp) > 0.0)

## 诊断副本；调用者不能通过它修改护盾权威状态。
func inspect_layers() -> Array[Dictionary]:
	return _layers.duplicate(true)
