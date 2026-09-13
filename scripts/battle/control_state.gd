class_name ControlState
extends RefCounted
## 保留现有聚合语义：同源/异源均取最长时间与最强倍率，不乘算多个来源。
## 免疫由持有者当前 Buff 判定；新减速被拒绝，已有减速仍计时但被抑制。
var frozen_timer := 0.0
var stun_timer := 0.0
var slow_timer := 0.0
var slow_multiplier := 1.0
var attack_speed_slow_timer := 0.0
var attack_speed_slow_multiplier := 1.0

func refresh_freeze(duration: float) -> void:
	frozen_timer = maxf(frozen_timer, BattleNumbers.decimal(duration))

func refresh_stun(duration: float) -> void:
	stun_timer = maxf(stun_timer, BattleNumbers.decimal(duration))

func refresh_slow(duration: float, multiplier: float) -> void:
	slow_timer = maxf(slow_timer, BattleNumbers.decimal(duration))
	slow_multiplier = minf(slow_multiplier, clampf(multiplier, 0.1, 1.0))

func refresh_attack_slow(duration: float, multiplier: float) -> void:
	attack_speed_slow_timer = maxf(attack_speed_slow_timer, BattleNumbers.decimal(duration))
	attack_speed_slow_multiplier = minf(attack_speed_slow_multiplier, clampf(multiplier, 0.1, 1.0))

func tick_slows(dt: float) -> void:
	if slow_timer > 0.0:
		slow_timer = maxf(0.0, slow_timer - dt)
		if slow_timer <= 0.0:
			slow_multiplier = 1.0
	if attack_speed_slow_timer > 0.0:
		attack_speed_slow_timer = maxf(0.0, attack_speed_slow_timer - dt)
		if attack_speed_slow_timer <= 0.0:
			attack_speed_slow_multiplier = 1.0
