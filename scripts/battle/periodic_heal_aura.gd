extends RefCounted
## 独立周期启动治疗光环；固定模拟推进，客户端只读快照。
var remaining := 0.0
var age := 0.0
var pulse_elapsed := 0.0
var cycle := PeriodicProduction.new()
var initialized := false

func tick(unit: Unit, dt: float) -> void:
	if unit._in_client_mode(): return
	var stats := PresentationConfig.for_form(unit._base_form_stats, unit.form_index)
	if unit.hp <= 0.0 or not stats.has("heal_aura_trigger_interval"):
		clear()
		return
	# 部署时间不计入首轮周期；部署结束后的第一个固定Tick开始计时。
	if unit._deploy_timer > 0.0: return
	var interval := float(stats.heal_aura_trigger_interval)
	if not initialized:
		cycle.reset(float(stats.heal_aura_initial_delay))
		initialized = true
	_advance_aura(unit, maxf(dt, 0.0), stats)
	# 到期受眩晕/冰冻/凝滞阻止时只保留一轮，恢复后启动并重计完整周期。
	if cycle.tick(maxf(dt, 0.0), interval, PeriodicProduction.blocked(unit)):
		remaining = float(stats.heal_aura_duration)
		age = 0.0
		pulse_elapsed = 0.0
		if unit.battle_context != null:
			unit.battle_context.notify_unit_audio_event(unit, &"heal_aura:start", unit.global_position)

func _advance_aura(unit: Unit, dt: float, stats: Dictionary) -> void:
	if remaining <= 0.0: return
	var elapsed := minf(dt, remaining)
	remaining = maxf(0.0, remaining - elapsed)
	if remaining < 0.000001: remaining = 0.0
	age += elapsed
	pulse_elapsed += elapsed
	var interval := float(stats.heal_aura_pulse_interval)
	while pulse_elapsed + 0.000001 >= interval:
		pulse_elapsed = maxf(0.0, pulse_elapsed - interval)
		# 凝滞抑制已建立的光环但不延寿、不补发；眩晕/冰冻不取消既有光环。
		if CombatInteraction.in_stasis(unit): continue
		var interaction := CombatInteraction.effect_context(unit, unit.team, unit.global_position, true)
		for target in unit.get_tree().get_nodes_in_group("combatants"):
			if not is_instance_valid(target) or not target is Unit or target.is_building or target.hp <= 0.0 or target.team != unit.team: continue
			if unit.global_position.distance_to(target.global_position) <= float(stats.heal_aura_radius) + target.body_radius:
				target.heal(float(stats.heal_aura_amount), interaction)

func clear() -> void:
	remaining = 0.0
	age = 0.0
	pulse_elapsed = 0.0
	cycle.reset(0.0)
	initialized = false

func state() -> Vector2:
	return Vector2(age, remaining) if remaining > 0.0 else Vector2.ZERO
