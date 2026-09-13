class_name FixedStepClock
extends RefCounted
## 权威积压全部保留并按顺序执行；渲染只输入 elapsed，不拥有规则时间。
const STEP := 0.05
var remainder := 0.0
var ticks := 0
var step: Callable
var running: Callable

func advance(delta: float) -> void:
	remainder += maxf(delta, 0.0)
	while remainder + 0.0000001 >= STEP and running.call():
		remainder = maxf(0.0, remainder - STEP)
		ticks += 1
		step.call(STEP)
