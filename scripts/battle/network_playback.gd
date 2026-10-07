class_name NetworkPlayback
extends RefCounted
## 只延后副本/表现的应用；绝不运行权威模拟。相同Tick保留事件顺序，快照最后应用。
const DELAY_TICKS := 2.0
const MIN_DELAY_TICKS := 1.0
const MAX_DELAY_TICKS := 4.0
var delay_ticks := DELAY_TICKS
var _delay_samples: Array[float] = []
const MAX_QUEUED := 4096
var _queue: Array[Dictionary] = []
var _serial := 0
var _needs_sort := false
var tick := 0.0

func observe_delay(milliseconds: float) -> void:
	if not is_finite(milliseconds) or milliseconds < 0.0: return
	_delay_samples.append(milliseconds)
	if _delay_samples.size() > 32: _delay_samples.pop_front()
	var samples := _delay_samples.duplicate()
	samples.sort()
	var target := clampf((float(samples[int(floor(float(samples.size() - 1) * 0.9))]) + 50.0) / 50.0, MIN_DELAY_TICKS, MAX_DELAY_TICKS)
	# 抖动增加时迅速留出余量；稳定后缓慢减少，不让时间轴倒退。
	delay_ticks = target if target > delay_ticks else move_toward(delay_ticks, target, 0.02)

func enqueue(at_tick: int, method: StringName, args: Array) -> bool:
	if at_tick < 0 or _queue.size() >= MAX_QUEUED: return false
	_needs_sort = true
	_serial += 1
	_queue.append({"tick": at_tick, "method": method, "args": args.duplicate(true), "serial": _serial})
	return true

func advance(server_tick: float) -> Array[Dictionary]:
	tick = maxf(tick, server_tick - delay_ticks)
	if _needs_sort:
		_queue.sort_custom(func(a, b):
			if a.tick != b.tick: return a.tick < b.tick
			if (a.method == &"_apply_buffered_snapshot") != (b.method == &"_apply_buffered_snapshot"):
				return b.method == &"_apply_buffered_snapshot"
			return a.serial < b.serial)
		_needs_sort = false
	var ready: Array[Dictionary] = []
	while not _queue.is_empty() and float(_queue[0].tick) <= tick:
		ready.append(_queue.pop_front())
	return ready

func clear() -> void:
	_queue.clear()
	_needs_sort = false
	_delay_samples.clear()
	delay_ticks = DELAY_TICKS
	tick = 0.0
	_serial = 0

func size() -> int:
	return _queue.size()

