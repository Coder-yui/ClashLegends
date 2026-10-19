extends RefCounted
## 纯调度：frame_id去重；已发生的主线程工作与补货step wall决定退让，不读取帧间隔。
const STEP_BUDGET_USEC := 1000
const FOREGROUND_BUDGET_USEC := 8000
const MAX_DEFER_FRAMES := 3
var metrics := {"steps": 0, "duplicate_calls": 0, "foreground_deferrals": 0, "cooldown_frames": 0, "forced_steps": 0, "long_steps": 0, "max_step_usec": 0}
var _last_frame := -1
var _deferred := 0
var _cooldown := 0

func allow_step(frame_id: int, foreground_usec: int) -> bool:
	if frame_id == _last_frame:
		metrics.duplicate_calls += 1
		return false
	_last_frame = frame_id
	if _cooldown > 0:
		_cooldown -= 1
		metrics.cooldown_frames += 1
		return false
	if foreground_usec >= FOREGROUND_BUDGET_USEC and _deferred < MAX_DEFER_FRAMES:
		_deferred += 1
		metrics.foreground_deferrals += 1
		return false
	if foreground_usec >= FOREGROUND_BUDGET_USEC: metrics.forced_steps += 1
	_deferred = 0
	return true

func finished_step(wall_usec: int) -> void:
	metrics.steps += 1
	metrics.max_step_usec = maxi(metrics.max_step_usec, wall_usec)
	if wall_usec > STEP_BUDGET_USEC:
		metrics.long_steps += 1
		# 实测长step后有限退让，不永久停用能力，不按delta/FPS推断CPU忙碌。
		_cooldown = mini(MAX_DEFER_FRAMES, maxi(1, ceili(float(wall_usec) / STEP_BUDGET_USEC) - 1))

func reset_clock() -> void:
	_last_frame = -1
	_deferred = 0
	_cooldown = 0
