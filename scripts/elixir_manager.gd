class_name ElixirManager
extends Node
## 金币管理器：自动回复、扣费校验。（类名保留 elixir 不影响显示）

signal changed(value: float)

const MAX_ELIXIR := 10.0
const REGEN_INTERVAL := 2.8

var elixir := 5.0:
	set(value):
		elixir = clampf(value, 0.0, MAX_ELIXIR)
		changed.emit(elixir)

# 回复倍率：常规时间最后一分钟双倍、加时三倍，由 main 按比赛计时统一设置
var regen_multiplier := 1.0

var _timer := 0.0

func _process(delta: float) -> void:
	if elixir >= MAX_ELIXIR or regen_multiplier <= 0.0:
		return
	_timer += delta
	if _timer >= REGEN_INTERVAL / regen_multiplier:
		_timer = 0.0
		elixir += 1.0

func can_afford(cost: float) -> bool:
	return elixir >= cost

func spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	elixir -= cost
	return true
