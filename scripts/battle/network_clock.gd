class_name NetworkClock
extends RefCounted
## 单调本机时间与服务器模拟时间的对应关系；不推进战斗。
const STEP_MSEC := 50.0
const MAX_RTT_MSEC := 2000
var _probes: Dictionary = {}
var _samples: Array[Dictionary] = []
var _sequence := 0
var synchronized := false
var rtt_msec := 0.0
var jitter_msec := 0.0
var _offset_ticks := 0.0

func begin_probe(now: int) -> int:
	_sequence += 1
	_probes[_sequence] = now
	for id in _probes.keys():
		if now - int(_probes[id]) > MAX_RTT_MSEC: _probes.erase(id)
	return _sequence

func accept_probe(id: int, server_tick: float, now: int) -> bool:
	if not _probes.has(id) or not is_finite(server_tick) or server_tick < 0.0: return false
	var sent := int(_probes[id])
	_probes.erase(id)
	var elapsed := now - sent
	if elapsed < 0 or elapsed > MAX_RTT_MSEC: return false
	var sample_offset := server_tick + float(elapsed) / (2.0 * STEP_MSEC) - float(now) / STEP_MSEC
	_samples.append({"rtt": elapsed, "offset": sample_offset})
	if _samples.size() > 8: _samples.pop_front()
	var best: Dictionary = _samples[0]
	for sample in _samples:
		if int(sample.rtt) < int(best.rtt): best = sample
	jitter_msec = absf(float(elapsed) - rtt_msec) if synchronized else 0.0
	rtt_msec = float(best.rtt)
	_offset_ticks = float(best.offset)
	synchronized = true
	return true

func estimate(now: int) -> float:
	return maxf(0.0, float(now) / STEP_MSEC + _offset_ticks)

func reset() -> void:
	_probes.clear()
	_samples.clear()
	synchronized = false
	rtt_msec = 0.0
	jitter_msec = 0.0
	_offset_ticks = 0.0

