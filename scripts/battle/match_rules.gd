class_name MatchRules
extends RefCounted
## 比赛时间与胜负的唯一所有者。结果使用队伍与原因，中文文案留给显示层。
signal overtime_started
const REGULATION_TIME := 185.0
const OVERTIME_TIME := 120.0
const END_REASONS := ["nexus", "towers", "draw", "disconnect"]
var time_left := REGULATION_TIME
var overtime := false
var finished := false

func advance(dt: float, team0_king_hp: float, team1_king_hp: float, team0_lost: int, team1_lost: int) -> Dictionary:
	if finished:
		return {}
	time_left = maxf(0.0, time_left - dt)
	var result := {}
	# 本 Tick 所有结算阶段完成后统一检查双方水晶。
	if team0_king_hp <= 0.0 and team1_king_hp <= 0.0:
		result = {"winner_team": -1, "reason": "nexus"}
	elif team1_king_hp <= 0.0:
		result = {"winner_team": 0, "reason": "nexus"}
	elif team0_king_hp <= 0.0:
		result = {"winner_team": 1, "reason": "nexus"}
	elif (overtime or time_left <= 0.000001) and team0_lost != team1_lost:
		result = {"winner_team": 0 if team1_lost > team0_lost else 1, "reason": "towers"}
	elif time_left <= 0.000001:
		if overtime:
			result = {"winner_team": -1, "reason": "draw"}
		else:
			enter_overtime()
	finished = not result.is_empty()
	return result

func enter_overtime() -> void:
	if overtime or finished:
		return
	overtime = true
	time_left = OVERTIME_TIME
	overtime_started.emit()

func apply_replica(remaining: float, extra_time: bool) -> void:
	time_left = remaining
	overtime = extra_time

func snapshot() -> Dictionary:
	return {"time_left": time_left, "overtime": overtime}

func finish() -> void:
	finished = true
