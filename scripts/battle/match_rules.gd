class_name MatchRules
extends RefCounted
## 比赛时间与胜负的唯一所有者。Main 提供本 Tick 的塔状态，UI 只读取结果。
signal overtime_started
const REGULATION_TIME := 185.0
const OVERTIME_TIME := 120.0
var time_left := REGULATION_TIME
var overtime := false
var finished := false

func advance(dt: float, my_king_hp: float, enemy_king_hp: float, my_lost: int, enemy_lost: int) -> String:
	if finished:
		return ""
	time_left = maxf(0.0, time_left - dt)
	var result := ""
	if enemy_king_hp <= 0.0:
		result = "胜利！敌方国王塔已被摧毁"
	elif my_king_hp <= 0.0:
		result = "失败……我方国王塔被摧毁"
	elif (overtime or time_left <= 0.000001) and my_lost != enemy_lost:
		result = ("胜利！破塔 %d:%d" if enemy_lost > my_lost else "失败……破塔 %d:%d") % [enemy_lost, my_lost]
	elif time_left <= 0.000001:
		if overtime:
			result = "平局！双方战成 %d:%d" % [enemy_lost, my_lost]
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
