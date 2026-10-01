extends RefCounted
## 脱战隐身：仅权威 Tick 推进；受伤重置脱战时钟但不破隐。
signal changed(hidden: bool)

var delay := 0.0
var remaining := 0.0
var hidden := false

func setup(seconds: float) -> void:
	delay = seconds
	remaining = 0.0
	hidden = delay > 0.0

func activity(break_hidden: bool = false) -> void:
	if delay <= 0.0: return
	remaining = delay
	if break_hidden and hidden:
		hidden = false
		changed.emit(false)

func advance(dt: float, entry_allowed: bool = true) -> void:
	if delay <= 0.0: return
	remaining = maxf(remaining - dt, 0.0)
	if remaining <= 0.000001 and entry_allowed and not hidden:
		hidden = true
		changed.emit(true)
