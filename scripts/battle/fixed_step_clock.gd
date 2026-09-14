class_name FixedStepClock
extends RefCounted
## 权威积压全部保留并按顺序执行；渲染只输入 elapsed，不拥有规则时间。
const STEP := 0.05
var remainder := 0.0
var ticks := 0
## 0 表示不限制；主场景采用 4 Tick / 8ms 的单帧赶步预算。单个 Tick 不可打断。
var max_ticks_per_advance := 0
var max_work_usec := 0
var step: Callable
var running: Callable

func advance(delta: float) -> void:
	remainder += maxf(delta, 0.0)
	var started := Time.get_ticks_usec()
	var executed := 0
	while remainder + 0.0000001 >= STEP and running.call():
		remainder = maxf(0.0, remainder - STEP)
		ticks += 1
		step.call(STEP)
		executed += 1
		if max_ticks_per_advance > 0 and executed >= max_ticks_per_advance: break
		if max_work_usec > 0 and Time.get_ticks_usec() - started >= max_work_usec: break
