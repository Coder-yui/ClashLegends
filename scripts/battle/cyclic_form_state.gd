extends RefCounted
## 定时双形态与换形首击；仅由权威固定时钟推进。
var elapsed := 0.0
var first_attack := true

func advance(unit: Unit, dt: float) -> void:
	if unit._in_client_mode() or unit.hp <= 0.0: return
	var period := float(unit._base_form_stats.get("form_cycle_interval", 0.0))
	if period <= 0.0: return
	elapsed = minf(elapsed + dt, period)

func try_switch(unit: Unit) -> bool:
	var period := float(unit._base_form_stats.get("form_cycle_interval", 0.0))
	if period <= 0.0 or elapsed + 0.000001 < period or unit.hp <= 0.0 or unit._in_client_mode(): return false
	if unit._deploy_timer > 0.0 or unit.is_frozen() or unit.is_stunned() or unit.is_form_transitioning() or unit.active_skill_cast_timer > 0.0: return false
	if unit._forced_movement or unit.knockback.remaining > 0.0 or unit.knockback.in_transit or unit.knockback.recovery_pending: return false
	unit.toggle_weapon_form()
	elapsed = 0.0
	first_attack = true
	return true

func consume(unit: Unit, effects: Dictionary) -> void:
	if not first_attack or float(unit._base_form_stats.get("form_cycle_interval", 0.0)) <= 0.0: return
	first_attack = false
	effects["first_strike"] = true
	var stats: Dictionary = unit._base_form_stats if unit.form_index == 0 else unit.transformed_stats
	# 数值随本次出手固化，来源换形/死亡不改变在途攻击。
	effects["primary_bonus_damage"] = float(stats.get("form_first_attack_damage", 0.0))
	effects["primary_bonus_health_ratio"] = float(stats.get("form_first_attack_health_ratio", 0.0))
	effects["primary_bonus_tower_damage"] = float(stats.get("form_first_attack_tower_damage", 0.0))
