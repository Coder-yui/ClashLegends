class_name ElixirManager
extends Node
## 金币管理器：自动回复、扣费校验。（类名保留 elixir 不影响显示）

signal changed(value: float)

const MAX_ELIXIR := 10.0
const REGEN_INTERVAL := 2.8

var elixir := 5.0:
	set(value):
		var next := clampf(value, 0.0, MAX_ELIXIR)
		if is_equal_approx(elixir, next):
			return
		elixir = next
		changed.emit(elixir)

# 回复倍率由 main 按比赛计时统一设置：正赛末段/加时前段为双倍，加时最后一分钟为三倍。
var regen_multiplier := 1.0

var _timer := 0.0

func sim_tick(delta: float) -> void:
	if elixir >= MAX_ELIXIR or regen_multiplier <= 0.0:
		return
	_timer += delta
	while _timer + 0.0000001 >= REGEN_INTERVAL / regen_multiplier and elixir < MAX_ELIXIR:
		_timer = maxf(0.0, _timer - REGEN_INTERVAL / regen_multiplier)
		elixir += 1.0

func can_afford(cost: float) -> bool:
	return elixir >= cost

func spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	elixir -= cost
	return true
