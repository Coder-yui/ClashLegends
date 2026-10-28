class_name SpellSystem
extends RefCounted
## 数据驱动法术的权威执行与持续区域。
## Main 只负责出牌编排；新增 spell_kind 时在这里实现一次，并由 CardDB 拒绝未实现的配置。

var summon_zones: Array[Dictionary] = []
var summon_effects: Array[Dictionary] = []

var corrosion_zones: Array[Dictionary] = []
var corrosion_effects: Array[Dictionary] = []

var freeze_effects: Array[Dictionary] = []
var slow_zones: Array[Dictionary] = []
var slow_effects: Array[Dictionary] = []
## 治疗术表现区域：阵营色边界与淡黄内光；全图强化治疗额外带全图扩散波纹。
var heal_effects: Array[Dictionary] = []

var cask_hits: Array[Dictionary] = []
var cask_effects: Array[Dictionary] = []
var bomb_effects: Array[Dictionary] = []
var spell_flights: Array[Dictionary] = []
var spark_casts: Array[Dictionary] = []
var spark_effects: Array[Dictionary] = []
var pulse_casts: Array[Dictionary] = []
var pulse_effects: Array[Dictionary] = []
var solar_casts: Array[Dictionary] = []
var solar_effects: Array[Dictionary] = []
var pool_visual_time := 0.0
var pool_zones: Array[Dictionary] = []
var pool_effects: Array[Dictionary] = []
var bolt_casts: Array[Dictionary] = []
var bolt_effects: Array[Dictionary] = []
var horizon_zones: Array[Dictionary] = []
var dark_matters: Array[Dictionary] = []
var horizon_effects: Array[Dictionary] = []
var tidal_waves: Array[Dictionary] = []
var tidal_effects: Array[Dictionary] = []
var stasis_effects: Array[Dictionary] = []

var medium_lightning_casts: Array[Dictionary] = []
var lightning_casts: Array[Dictionary] = []
var lightning_effects: Array[Dictionary] = []
var lightning_areas: Array[Dictionary] = []

var _effect_serial := 0
var _controller: Node2D


func _init(controller: Node2D) -> void:
	_controller = controller


static func supports(kind: StringName) -> bool:
	return kind in CardDB.SPELL_KINDS


func cast(team: int, stats: Dictionary, position: Vector2, active_enabled: bool = false, active_skill_index: int = 0) -> bool:
	if float(stats.get("flight_speed", 0.0)) > 0.0:
		_start_flight(team, stats, position, active_enabled, active_skill_index)
		return true
	return _resolve_cast(team, stats, position, active_enabled, active_skill_index)

func _resolve_cast(team: int, stats: Dictionary, position: Vector2, active_enabled: bool, active_skill_index: int) -> bool:
	match StringName(stats.get("spell_kind", "")):
		&"mega_inferno_bomb":
			_apply_mega_inferno_bomb(team, stats, position, active_enabled, active_skill_index)
			return true
		&"pool_of_reflection":
			_start_pool(team, stats, position, active_enabled, active_skill_index)
			return true
		&"final_spark":
			_start_final_spark(team, stats, position, active_enabled, active_skill_index)
			return true
		&"convergent_pulse":
			_start_convergent_pulse(team, stats, position, active_enabled, active_skill_index)
			return true
		&"solar_flare":
			_start_solar_flare(team, stats, position, active_enabled, active_skill_index)
			return true
		&"severing_bolt":
			_start_severing_bolt(team, stats, position, active_enabled, active_skill_index)
			return true
		&"event_horizon":
			_start_event_horizon(team, stats, position, active_enabled, active_skill_index)
			return true
		&"medium_lightning":
			_start_medium_lightning(team, stats, position, active_enabled, active_skill_index)
			return true
		&"tidal_wave":
			_start_tidal_wave(team, stats, position, active_enabled, active_skill_index)
			return true
		&"void_summoning":
			_start_summoning(team, stats, position, active_enabled)
			return true
		&"explosive_cask":
			_apply_explosive_cask(team, stats, position, active_enabled, active_skill_index)
			return true
		&"corrosion":
			_start_corrosion(team, stats, position, active_enabled, active_skill_index)
			return true
		&"zap", &"lightning":
			start_lightning(team, stats, position, active_enabled, active_skill_index)
			return true
		&"stasis":
			_apply_stasis(team, stats, position, active_enabled, active_skill_index)
			return true
		&"freeze":
			var radius := float(stats.get("radius", 0.0))
			var duration := float(stats.get("duration", 0.0))
			var skill := _active_heal_skill(stats, active_skill_index) if active_enabled else {}
			var slow_duration := float(skill.get("slow_duration", 0.0))
			var slow_multiplier := float(skill.get("slow_multiplier", 1.0))
			var attack_multiplier := float(skill.get("attack_speed_multiplier", 1.0))
			apply_freeze(position, radius, duration, team, slow_duration, slow_multiplier, attack_multiplier, float(skill.get("radius", radius)))
			_controller.present_freeze_spell(position, radius, duration, slow_duration, slow_multiplier, team, float(skill.get("radius", radius)))
			return true
		&"heal":
			var heal_radius := float(stats.get("radius", 0.0))
			var fx_duration := float(stats.get("duration", 1.2))
			var active_skill: Dictionary = _active_heal_skill(stats, active_skill_index) if active_enabled else {}
			apply_heal(position, heal_radius, team, stats, active_enabled, active_skill)
			_controller.present_heal_spell(position, heal_radius, fx_duration, team, active_enabled, bool(active_skill.get("global_heal", false)))
			return true
		_:
			push_error("未实现的 spell_kind：%s" % String(stats.get("spell_kind", "")))
			return false


func _active_heal_skill(stats: Dictionary, skill_index: int) -> Dictionary:
	var skills: Array = stats.get("active_skills", [])
	if skill_index < 0 or skill_index >= skills.size() or not skills[skill_index] is Dictionary:
		return {}
	return skills[skill_index] as Dictionary


## 法术卡由本方水晶释放；落点仅决定覆盖范围，不是效果来源。
func _spell_context(team: int) -> Dictionary:
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if combatant is Tower and combatant.is_king and combatant.team == team:
			return CombatInteraction.effect_context(combatant, team, combatant.global_position)
	return CombatInteraction.effect_context(null, team)


func apply_freeze(position: Vector2, radius: float, duration: float, team: int, slow_duration: float = 0.0, slow_multiplier: float = 1.0, attack_multiplier: float = 1.0, slow_radius: float = 0.0) -> void:
	_effect_serial += 1
	var source := StringName("spell:%d:%d" % [team, _effect_serial])
	var interaction := _spell_context(team)
	interaction["delivery"] = CombatInteraction.Delivery.new()
	show_freeze(position, radius, duration, slow_duration, team, slow_radius)
	if slow_duration > 0.0:
		slow_zones.append({"created_tick": _controller.get_authoritative_server_tick() if _controller.simulation_step_active() else -1, "pos": position, "radius": slow_radius if slow_radius > 0.0 else radius, "delay": 0.0, "timer": duration + slow_duration, "team": team, "multiplier": slow_multiplier, "attack_multiplier": attack_multiplier, "status_source": source, "effect_delivery": interaction.delivery})
		_apply_slow_zone(slow_zones.back(), FixedStepClock.STEP)
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(combatant) or combatant.team == team or combatant.hp <= 0.0:
			continue
		if combatant is Tower and combatant.is_king: continue
		if not CombatInteraction.allows_effect(combatant, interaction): continue
		if combatant.global_position.distance_to(position) > radius + combatant.body_radius:
			continue
		if combatant is Unit:
			(combatant as Unit).freeze(duration, source, interaction)
		elif combatant is Tower:
			(combatant as Tower).freeze(duration, source)


## 治疗术权威结算。治疗只作用于普通单位（Unit 且非建筑卡），统一走 Unit.heal()，
## 不会超过单位最大生命值；建筑卡、防御塔与水晶不吃治疗。
## 治疗法术主动选项：强化治疗可全图治疗但只在落点范围内提高倍率；过量治疗只治疗范围内单位，
## 并将实际未恢复的部分按 overheal_shield_ratio 转为限时护盾；建筑卡、防御塔与水晶不受治疗影响。
func apply_heal(position: Vector2, radius: float, team: int, stats: Dictionary, active_enabled: bool = false, active_skill: Dictionary = {}) -> void:
	_effect_serial += 1
	var shield_source := StringName("heal:%d:%d" % [team, _effect_serial])
	var interaction := _spell_context(team)
	var heal_amount := maxf(float(stats.get("heal_amount", 0.0)), 0.0)
	var heal_multiplier := maxf(float(active_skill.get("heal_multiplier", 1.0)), 1.0) if active_enabled else 1.0
	var global_heal := active_enabled and bool(active_skill.get("global_heal", false))
	var overheal_shield_ratio := clampf(float(active_skill.get("overheal_shield_ratio", 0.0)), 0.0, 1.0) if active_enabled else 0.0
	var shield_duration := maxf(float(active_skill.get("shield_duration", 0.0)), 0.0) if active_enabled else 0.0
	show_heal(position, radius, float(stats.get("duration", 1.2)), team, active_enabled, global_heal)
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(combatant) or combatant.team != team or combatant.hp <= 0.0:
			continue
		var in_range: bool = combatant.global_position.distance_to(position) <= radius + combatant.body_radius
		if combatant is Unit and not (combatant as Unit).is_building and (in_range or global_heal):
			var requested_heal := heal_amount * heal_multiplier
			if global_heal and not in_range:
				requested_heal = heal_amount
			if overheal_shield_ratio > 0.0 and shield_duration > 0.0:
				(combatant as Unit).heal_with_overflow(requested_heal, overheal_shield_ratio, shield_duration, shield_source, interaction)
			else:
				(combatant as Unit).heal(requested_heal, interaction)



## 主机结算和客户端 RPC 共用表现创建入口，副本不创建权威区域。
func show_freeze(position: Vector2, radius: float, duration: float, slow_duration: float = 0.0, team: int = 0, slow_radius: float = 0.0) -> void:
	if not _controller.has_presentation(): return
	freeze_effects.append({"pos": position, "timer": duration, "duration": duration, "radius": radius, "team": team})
	if slow_duration > 0.0:
		slow_effects.append({"pos": position, "radius": slow_radius if slow_radius > 0.0 else radius, "freeze_radius": radius, "freeze_duration": duration, "delay": 0.0, "timer": duration + slow_duration, "duration": duration + slow_duration, "team": team})

func show_heal(position: Vector2, radius: float, duration: float, team: int, enhanced: bool = false, global_heal: bool = false) -> void:
	if not _controller.has_presentation(): return
	heal_effects.append({"pos": position, "radius": radius, "timer": duration, "duration": duration, "team": team, "enhanced": enhanced, "global_heal": global_heal})

func tick(dt: float) -> void:
	_tick_summoning()
	_tick_corrosion()
	_tick_flights()
	_tick_pool()
	_tick_final_spark()
	_tick_convergent_pulse()
	_tick_solar_flare()
	_tick_severing_bolt()
	_tick_event_horizon()
	_tick_tidal_waves()
	_tick_lightning()
	_tick_medium_lightning()
	var alive: Array[Dictionary] = []
	for zone in slow_zones:
		if _controller.simulation_step_active() and int(zone.get("created_tick", -1)) == _controller.get_authoritative_server_tick():
			alive.append(zone)
			continue
		zone.timer = maxf(0.0, float(zone.timer) - dt)
		_apply_slow_zone(zone, FixedStepClock.STEP)
		if float(zone.timer) > 0.0:
			alive.append(zone)
	slow_zones.assign(alive)


func _apply_slow_zone(zone: Dictionary, dt: float) -> void:
	var interaction := _spell_context(int(zone.team))
	interaction["delivery"] = zone.get("effect_delivery")
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(combatant) or not combatant is Unit or combatant.team == int(zone.team) or combatant.hp <= 0.0:
			continue
		if not CombatInteraction.allows_effect(combatant, interaction): continue
		if combatant.global_position.distance_to(zone.pos) <= float(zone.radius) + combatant.body_radius:
			if not zone.has("contacts"): zone["contacts"] = {}
			var contact_id: int = combatant.get_instance_id()
			if not zone.contacts.has(contact_id):
				zone.contacts[contact_id] = CombatInteraction.blocks_effect(combatant, interaction)
			if bool(zone.contacts[contact_id]): continue
			var ongoing := interaction.duplicate()
			ongoing["attached"] = true
			(combatant as Unit).apply_slow(dt + FixedStepClock.STEP, float(zone.multiplier), zone.status_source, ongoing)
			if float(zone.attack_multiplier) < 1.0:
				(combatant as Unit).apply_attack_speed_slow(dt + FixedStepClock.STEP, float(zone.attack_multiplier), zone.status_source, ongoing)


func tick_visuals(delta: float) -> void:
	var visual_tick: float = float(_controller.get_presentation_tick()) + (0.0 if _controller.is_net_client() else _controller.get_sim_interpolation_alpha())
	pool_visual_time = visual_tick * FixedStepClock.STEP
	for effect in pool_effects: effect.age = maxf(0.0, visual_tick - float(effect.start_tick)) * FixedStepClock.STEP
	pool_effects.assign(pool_effects.filter(func(effect): return visual_tick < float(effect.end_tick) + 40.0))
	for effect in spark_effects: effect.age = maxf(0.0, visual_tick - float(effect.start_tick)) * FixedStepClock.STEP
	spark_effects.assign(spark_effects.filter(func(effect): return float(effect.age) < 2.5))
	for effect in pulse_effects: effect.age = maxf(0.0, visual_tick - float(effect.start_tick)) * FixedStepClock.STEP
	pulse_effects.assign(pulse_effects.filter(func(effect): return visual_tick < float(effect.start_tick) + 50.0))
	for effect in solar_effects: effect.age = maxf(0.0, visual_tick - float(effect.start_tick)) * FixedStepClock.STEP
	solar_effects.assign(solar_effects.filter(func(effect): return visual_tick < float(effect.end_tick) + 100.0))
	for effect in bolt_effects: effect.age = maxf(0.0, visual_tick - float(effect.start_tick)) * FixedStepClock.STEP
	bolt_effects.assign(bolt_effects.filter(func(effect): return visual_tick < float(effect.end_tick) + 100.0))
	for effect in horizon_effects: effect.age = maxf(0.0, visual_tick - float(effect.start_tick)) * FixedStepClock.STEP
	horizon_effects.assign(horizon_effects.filter(func(effect): return visual_tick < float(effect.end_tick) + (100.0 if effect.kind == "dark_matter" else 40.0)))
	for effect in tidal_effects:
		var tick: float = float(_controller.get_presentation_tick()) + (0.0 if _controller.is_net_client() else _controller.get_sim_interpolation_alpha())
		effect.progress = clampf((tick - float(effect.start_tick)) / float(effect.end_tick - effect.start_tick), 0.0, 1.0)
		effect.tail = maxf(0.0, tick - float(effect.end_tick)) * FixedStepClock.STEP
	tidal_effects.assign(tidal_effects.filter(func(effect): return float(effect.tail) < 2.2))
	for effect in summon_effects: effect.timer = maxf(0.0, float(effect.timer) - delta)
	summon_effects.assign(summon_effects.filter(func(effect): return float(effect.timer) > 0.0))
	for hit in cask_hits: hit.timer = maxf(0.0, float(hit.timer) - delta)
	cask_hits.assign(cask_hits.filter(func(hit): return float(hit.timer) > 0.0))
	for effect in corrosion_effects:
		effect.timer = maxf(0.0, float(effect.timer) - delta)
	corrosion_effects.assign(corrosion_effects.filter(func(effect): return float(effect.timer) > 0.0))
	for effect in stasis_effects + cask_effects + bomb_effects:
		if bool(effect.impacted):
			effect.timer = maxf(0.0, float(effect.timer) - delta)
		else:
			var tick: int = int(_controller.get_presentation_tick())
			var fraction: float = 0.0 if _controller.is_net_client() else _controller.get_sim_interpolation_alpha()
			effect.progress = clampf((float(tick - int(effect.start_tick)) + fraction) / maxi(1, int(effect.impact_tick) - int(effect.start_tick)), 0.0, 1.0)
	bomb_effects.assign(bomb_effects.filter(func(effect): return not bool(effect.impacted) or float(effect.timer) > 0.0))
	cask_effects.assign(cask_effects.filter(func(effect): return not bool(effect.impacted) or float(effect.timer) > 0.0))
	stasis_effects.assign(stasis_effects.filter(func(effect): return not bool(effect.impacted) or float(effect.timer) > 0.0))
	for area in lightning_areas:
		area.timer = maxf(0.0, float(area.timer) - delta)
	lightning_areas.assign(lightning_areas.filter(func(area): return float(area.timer) > 0.0))
	for effect in lightning_effects:
		effect.timer = maxf(0.0, float(effect.timer) - delta)
	lightning_effects.assign(lightning_effects.filter(func(effect): return float(effect.timer) > 0.0))
	for effect in freeze_effects:
		effect.timer = maxf(0.0, float(effect.timer) - delta)
	freeze_effects.assign(freeze_effects.filter(func(effect): return float(effect.timer) > 0.0))
	for effect in slow_effects:
		if float(effect.delay) > 0.0:
			effect.delay = maxf(0.0, float(effect.delay) - delta)
		else:
			effect.timer = maxf(0.0, float(effect.timer) - delta)
	var alive: Array[Dictionary] = []
	for effect in slow_effects:
		if float(effect.delay) > 0.0 or float(effect.timer) > 0.0:
			alive.append(effect)
	slow_effects.assign(alive)
	for effect in heal_effects:
		effect.timer = maxf(0.0, float(effect.timer) - delta)
	heal_effects.assign(heal_effects.filter(func(effect): return float(effect.timer) > 0.0))


func clear() -> void:
	pool_zones.clear()
	pool_effects.clear()
	summon_zones.clear()
	summon_effects.clear()
	corrosion_zones.clear()
	corrosion_effects.clear()
	spell_flights.clear()
	horizon_zones.clear()
	dark_matters.clear()
	spark_casts.clear()
	spark_effects.clear()
	pulse_casts.clear()
	pulse_effects.clear()
	solar_casts.clear()
	solar_effects.clear()
	bolt_casts.clear()
	bolt_effects.clear()
	horizon_effects.clear()
	tidal_waves.clear()
	tidal_effects.clear()
	stasis_effects.clear()
	cask_effects.clear()
	bomb_effects.clear()
	cask_hits.clear()
	lightning_casts.clear()
	medium_lightning_casts.clear()
	lightning_effects.clear()
	lightning_areas.clear()
	freeze_effects.clear()
	slow_zones.clear()
	slow_effects.clear()
	heal_effects.clear()


## 独立法术结果，以整数权威Tick调度；客户端只接收每次落雷的表现。
func start_lightning(team: int, stats: Dictionary, position: Vector2, enhanced: bool, skill_index: int) -> void:
	_effect_serial += 1
	var skill := _active_heal_skill(stats, skill_index) if enhanced else {}
	var cast_data := {"effect_delivery": CombatInteraction.Delivery.new(), "team": team, "pos": position, "stats": stats,
		"count": int(skill.get("strike_count", stats.strike_count)), "index": 0, "struck_ids": {},
		"multiplier": float(skill.get("strike_damage_multiplier", 1.0)),
		"interval_ticks": maxi(roundi(float(stats.strike_interval) / FixedStepClock.STEP), 1),
		"next_tick": _controller.get_authoritative_server_tick(),
		"source": StringName("lightning:%d:%d" % [team, _effect_serial])}
	var window := float(int(cast_data.count) - 1) * float(cast_data.interval_ticks) * FixedStepClock.STEP + float(stats.stun_duration)
	_controller.present_lightning_area(String(stats.spell_kind), position, float(stats.radius), window, team)
	_strike_lightning(cast_data)
	cast_data.index = 1
	cast_data.next_tick += int(cast_data.interval_ticks)
	if int(cast_data.count) > 1: lightning_casts.append(cast_data)


func _tick_lightning() -> void:
	var tick: int = _controller.get_authoritative_server_tick()
	var alive: Array[Dictionary] = []
	for cast_data in lightning_casts:
		if tick >= int(cast_data.next_tick):
			_strike_lightning(cast_data)
			cast_data.index += 1
			cast_data.next_tick += int(cast_data.interval_ticks)
		if int(cast_data.index) < int(cast_data.count): alive.append(cast_data)
	lightning_casts.assign(alive)


func _strike_lightning(cast_data: Dictionary) -> void:
	var previous := CombatInteraction.current_delivery
	CombatInteraction.current_delivery = cast_data.effect_delivery
	_strike_lightning_delivery(cast_data)
	CombatInteraction.current_delivery = previous

func _strike_lightning_delivery(cast_data: Dictionary) -> void:
	var stats: Dictionary = cast_data.stats
	var team := int(cast_data.team)
	var interaction := _spell_context(team)
	var targets: Array[Node2D] = []
	for target in _controller.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(target) or target.is_queued_for_deletion() or target.hp <= 0 or target.team == team: continue
		if String(stats.spell_kind) == "lightning" and cast_data.struck_ids.has(target.combat_source_id): continue
		if not CombatInteraction.allows_effect(target, interaction): continue
		if target.global_position.distance_to(cast_data.pos) > float(stats.radius) + target.body_radius: continue
		targets.append(target)
	var kind := String(stats.spell_kind)
	if kind == "lightning":
		# 血量相同用出生身份稳定排序；每次重新查询并排除本次施法已经电击的目标。
		targets.sort_custom(func(a, b): return a.hp > b.hp if a.hp != b.hp else a.combat_source_id < b.combat_source_id)
		if targets.size() > 1: targets.resize(1)
		if targets.is_empty(): return
		cast_data.struck_ids[targets[0].combat_source_id] = true
	var strike_pos: Vector2 = cast_data.pos if kind == "zap" else targets[0].global_position
	var damage := float(stats.damage) * pow(float(cast_data.multiplier), int(cast_data.index))
	for target in targets:
		var amount := damage * (float(stats.tower_damage_multiplier) if target is Tower else 1.0)
		var result := BattleNumbers.hit(target, amount, interaction.get("source"), team, interaction.get("position", Vector2(INF, INF)))
		var apply_stun := func():
			if bool(result.landed) and is_instance_valid(target) and target.hp > 0:
				if target is Unit: target.stun(float(stats.stun_duration), cast_data.source, interaction)
				elif target is Tower: target.stun(float(stats.stun_duration), cast_data.source)
		if _controller.combat_service().collecting: _controller.combat_service().defer_effect(apply_stun)
		else: apply_stun.call()
	_controller.present_lightning_spell(kind, strike_pos, float(stats.radius), team)


## E: 2秒蓄雷；敌方仅最后1秒看到专用预警。结算只由整数Tick驱动。
func _start_medium_lightning(team: int, stats: Dictionary, position: Vector2, enhanced: bool, skill_index: int) -> void:
	var tick: int = _controller.get_authoritative_server_tick()
	var impact := tick + roundi(float(stats.spell_windup) / FixedStepClock.STEP)
	medium_lightning_casts.append({"team": team, "stats": stats, "pos": position, "enhanced": enhanced, "skill_index": skill_index, "impact_tick": impact, "warned": false})
	_controller.present_lightning_spell("medium_lightning_warning", position, float(stats.radius), team)

func _tick_medium_lightning(at_tick: int = -1) -> void:
	var tick: int = _controller.get_authoritative_server_tick() if at_tick < 0 else at_tick
	var waiting: Array[Dictionary] = []
	for cast_data in medium_lightning_casts:
		if not cast_data.warned and tick >= int(cast_data.impact_tick) - 20:
			cast_data.warned = true
			_controller.present_lightning_spell("medium_lightning_warning_enemy", cast_data.pos, float(cast_data.stats.radius), int(cast_data.team))
		if tick >= int(cast_data.impact_tick):
			_apply_medium_lightning(int(cast_data.team), cast_data.stats, cast_data.pos, bool(cast_data.enhanced), int(cast_data.skill_index))
		else: waiting.append(cast_data)
	medium_lightning_casts.assign(waiting)

## 单次落雷：伤害统一收集，命中后只对存活防御塔施加失效。
func _apply_medium_lightning(team: int, stats: Dictionary, position: Vector2, enhanced: bool, skill_index: int) -> void:
	_effect_serial += 1
	var source := StringName("medium_lightning:%d:%d" % [team, _effect_serial])
	var interaction := _spell_context(team)
	interaction["delivery"] = CombatInteraction.Delivery.new()
	var skill := _active_heal_skill(stats, skill_index) if enhanced else {}
	_controller.present_lightning_spell("medium_lightning", position, float(stats.radius), team)
	for target in _controller.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(target) or target.is_queued_for_deletion() or target.hp <= 0: continue
		if target.global_position.distance_to(position) > float(stats.radius) + target.body_radius: continue
		if target.team == team:
			if enhanced and target is Unit and not target.is_building:
				target.add_shield(float(skill.get("shield", 0)), float(skill.get("shield_duration", 0)), false, source, interaction)
			continue
		if not CombatInteraction.allows_effect(target, interaction): continue
		var amount := float(stats.damage) * (float(stats.tower_damage_multiplier) if target is Tower else 1.0)
		var result := BattleNumbers.hit(target, amount, interaction.get("source"), team, interaction.get("position", Vector2(INF, INF)))
		var apply_status := func():
			if not bool(result.landed) or not is_instance_valid(target): return
			_controller.present_lightning_spell("medium_lightning_hit", target.global_position, target.body_radius, team)
			if target.hp <= 0: return
			if target is Tower and not target.is_king:
				target.stun(float(stats.stun_duration), source, interaction, false)
				_controller.present_lightning_spell("medium_lightning_disabled", target.global_position, target.body_radius, team)
			elif enhanced and target is Unit and not target.is_building:
				target.apply_slow(float(skill.get("slow_duration", 0)), float(skill.get("slow_multiplier", 1)), source, interaction)
		if _controller.combat_service().collecting: _controller.combat_service().defer_effect(apply_status)
		else: apply_status.call()

func show_lightning(kind: String, position: Vector2, radius: float) -> void:
	if not _controller.has_presentation(): return
	if kind == "medium_lightning_disabled":
		lightning_effects.assign(lightning_effects.filter(func(effect): return String(effect.kind) != kind or effect.pos.distance_to(position) > 1.0))
	# 风暴狂涌地面焦痕约2秒，电刑烟影约1秒；仅影响表现数组寿命。
	var duration := 2.3 if kind == "medium_lightning_disabled" else (2.1 if kind in ["zap", "medium_lightning"] else 1.1)
	if kind == "medium_lightning_warning": duration = 4.0
	if kind == "medium_lightning_warning_enemy": duration = 1.5
	lightning_effects.append({"kind": kind, "pos": position, "radius": radius, "duration": duration, "timer": duration})


func show_lightning_area(kind: String, position: Vector2, radius: float, duration: float, team: int) -> void:
	if not _controller.has_presentation(): return
	lightning_areas.append({"kind": kind, "pos": position, "radius": radius, "duration": duration, "timer": duration, "team": team})


## 在途仅持有落点与整数时钟，不碰撞、不追踪目标，不依附水晶后续生命。
func _start_flight(team: int, stats: Dictionary, position: Vector2, enhanced: bool, skill_index: int) -> void:
	_effect_serial += 1
	var context := _spell_context(team)
	var origin: Vector2 = context.position
	if not origin.is_finite(): origin = Vector2(360, 1160 if team == 0 else 120)
	var duration := maxf(float(stats.get("flight_min_duration", 0.0)), origin.distance_to(position) / float(stats.flight_speed))
	var ticks := maxi(1, ceili(duration / FixedStepClock.STEP - 0.00000001))
	var start_tick: int = _controller.get_authoritative_server_tick()
	spell_flights.append({"id": _effect_serial, "team": team, "stats": stats, "pos": position,
		"enhanced": enhanced, "skill_index": skill_index, "impact_tick": start_tick + ticks})
	_controller.present_spell_flight(_effect_serial, String(stats.spell_kind), origin, position, float(stats.radius), start_tick, start_tick + ticks, team)

func _tick_flights() -> void:
	var tick: int = _controller.get_authoritative_server_tick()
	var waiting: Array[Dictionary] = []
	for flight in spell_flights:
		if tick < int(flight.impact_tick):
			waiting.append(flight)
			continue
		_resolve_cast(int(flight.team), flight.stats, flight.pos, bool(flight.enhanced), int(flight.skill_index))
		_controller.present_spell_arrival(int(flight.id), String(flight.stats.spell_kind), flight.pos, int(flight.team))
	spell_flights.assign(waiting)

func _apply_stasis(team: int, stats: Dictionary, position: Vector2, enhanced: bool, skill_index: int) -> void:
	_effect_serial += 1
	var interaction := _spell_context(team)
	var skill := _active_heal_skill(stats, skill_index) if enhanced else {}
	var source := StringName("stasis:%d:%d" % [team, _effect_serial])
	for target in _controller.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(target) or not (target is Unit or target is Tower) or target.hp <= 0: continue
		if target is Tower and target.is_king: continue
		if target.global_position.distance_to(position) > float(stats.radius) + target.body_radius: continue
		target.apply_stasis(float(skill.get("duration", stats.duration)) if target.team == team else float(stats.duration), source, interaction)

func show_flight(id: int, kind: String, origin: Vector2, position: Vector2, radius: float, start_tick: int, impact_tick: int, team: int = 0) -> void:
	if not _controller.has_presentation(): return
	if kind == "pool_of_reflection":
		pool_effects.append({"id": id, "kind": kind, "pos": position, "radius": radius, "start_tick": start_tick, "end_tick": impact_tick, "age": 0.0, "team": team})
		return
	if kind == "final_spark":
		spark_effects.append({"id": id, "kind": kind, "origin": origin, "pos": position, "radius": radius, "start_tick": start_tick, "end_tick": impact_tick, "age": 0.0, "team": team})
		return
	if kind == "convergent_pulse":
		pulse_effects.append({"id": id, "pos": position, "radius": radius, "start_tick": start_tick, "end_tick": impact_tick, "age": 0.0, "team": team})
		return
	if kind in ["solar_flare", "sunlight_consume"]:
		solar_effects.append({"id": id, "kind": kind, "pos": position, "radius": radius, "start_tick": start_tick, "end_tick": impact_tick, "age": 0.0, "team": team})
		return
	if kind in ["severing_bolt", "severing_bolt_hit"]:
		bolt_effects.append({"id": id, "kind": kind, "pos": position, "radius": radius, "start_tick": start_tick, "end_tick": impact_tick, "age": 0.0, "team": team})
		return
	if kind in ["event_horizon", "dark_matter"]:
		horizon_effects.append({"id": id, "kind": kind, "pos": position, "radius": radius, "start_tick": start_tick, "end_tick": impact_tick, "age": 0.0, "team": team})
		return
	if kind == "tidal_wave":
		tidal_effects.append({"id": id, "origin": origin, "pos": position, "radius": radius, "start_tick": start_tick, "end_tick": impact_tick, "progress": 0.0, "tail": 0.0})
		return
	# 首个皮肤为凝滞；其他法术复用调度并沿用自身抵达表现。
	if kind == "mega_inferno_bomb":
		bomb_effects.append({"id": id, "origin": origin, "pos": position, "radius": radius, "team": team,
			"start_tick": start_tick, "impact_tick": impact_tick, "progress": 0.0, "impacted": false, "duration": 5.0, "timer": 5.0})
		return
	if kind not in ["stasis", "explosive_cask"]: return
	var effects := cask_effects if kind == "explosive_cask" else stasis_effects
	effects.append({"id": id, "origin": origin, "pos": position, "radius": radius,
		"start_tick": start_tick, "impact_tick": impact_tick, "progress": 0.0, "impacted": false, "duration": 2.15 if kind == "explosive_cask" else 2.0, "timer": 2.15 if kind == "explosive_cask" else 2.0})

func show_arrival(id: int) -> void:
	if not _controller.has_presentation(): return
	for effect in stasis_effects + cask_effects + bomb_effects:
		if int(effect.id) == id:
			effect.impacted = true
			effect.timer = float(effect.duration)
			return



## 独立区域：每10Tick结算一次伤害，0.5至5秒共10次；减速每Tick检测，独立于伤害节拍。
func _start_corrosion(team: int, stats: Dictionary, position: Vector2, enhanced: bool, skill_index: int) -> void:
	_effect_serial += 1
	var skill := _active_heal_skill(stats, skill_index) if enhanced else {}
	var tick: int = _controller.get_authoritative_server_tick()
	var interval_ticks := maxi(1, ceili(float(stats.interval) / FixedStepClock.STEP))
	var zone := {"effect_delivery": CombatInteraction.Delivery.new(), "team": team, "pos": position, "radius": float(stats.radius),
		"start_tick": tick, "end_tick": tick + maxi(1, ceili(float(stats.duration) / FixedStepClock.STEP)),
		"last_tick": tick, "damage": float(stats.damage), "tower_damage_multiplier": float(stats.tower_damage_multiplier), "interval_ticks": interval_ticks,
		"next_damage_tick": tick + interval_ticks, "slow": float(skill.get("slow_multiplier", 1.0)),
		"source": StringName("corrosion:%d:%d" % [team, _effect_serial])}
	corrosion_zones.append(zone)
	# 施放当刻圈内目标立即减速，不提前造成伤害。
	var interaction := _spell_context(team)
	for target in _corrosion_targets(zone, interaction):
		_apply_corrosion_slow(zone, target, interaction)
	show_corrosion(position, float(stats.radius), float(stats.duration), team)
	_controller.present_corrosion_spell(position, float(stats.radius), float(stats.duration), team)

func show_corrosion(position: Vector2, radius: float, duration: float, team: int) -> void:
	if not _controller.has_presentation(): return
	corrosion_effects.append({"pos": position, "radius": radius, "duration": duration, "timer": duration, "team": team})

func _corrosion_targets(zone: Dictionary, interaction: Dictionary) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for target in _controller.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(target) or target.is_queued_for_deletion(): continue
		if target.team == int(zone.team) or target.hp <= 0.0: continue
		if target.global_position.distance_to(zone.pos) > float(zone.radius) + target.body_radius: continue
		if CombatInteraction.allows_effect(target, interaction): targets.append(target)
	return targets

func _apply_corrosion_slow(zone: Dictionary, target: Node2D, interaction: Dictionary) -> void:
	if not target is Unit or target.is_building or float(zone.slow) >= 1.0: return
	interaction = interaction.duplicate()
	interaction["delivery"] = zone.effect_delivery
	var apply_slow := func():
		if is_instance_valid(target) and target.hp > 0.0:
			target.apply_slow(FixedStepClock.STEP * 2.0, float(zone.slow), zone.source, interaction)
	if _controller.combat_service().collecting: _controller.combat_service().defer_effect(apply_slow)
	else: apply_slow.call()

func _tick_corrosion() -> void:
	var tick: int = _controller.get_authoritative_server_tick()
	var alive: Array[Dictionary] = []
	for zone in corrosion_zones:
		if tick <= int(zone.last_tick):
			alive.append(zone)
			continue
		zone.last_tick = tick
		if tick > int(zone.end_tick): continue
		var previous := CombatInteraction.current_delivery
		CombatInteraction.current_delivery = zone.effect_delivery
		var damage_due := tick >= int(zone.next_damage_tick)
		var interaction := _spell_context(int(zone.team))
		for target in _corrosion_targets(zone, interaction):
			if damage_due:
				var amount := float(zone.damage) * (float(zone.tower_damage_multiplier) if target is Tower else 1.0)
				BattleNumbers.hit(target, amount, interaction.get("source"), int(zone.team), interaction.get("position", Vector2(INF, INF)))
			_apply_corrosion_slow(zone, target, interaction)
		CombatInteraction.current_delivery = previous
		if damage_due: zone.next_damage_tick += int(zone.interval_ticks)
		# 先结算到期末跳，再移除区域。
		if tick < int(zone.end_tick): alive.append(zone)
	corrosion_zones.assign(alive)


func _apply_explosive_cask(team: int, stats: Dictionary, position: Vector2, enhanced: bool, skill_index: int) -> void:
	var interaction := _spell_context(team)
	var skill := _active_heal_skill(stats, skill_index) if enhanced else {}
	var damage := float(skill.get("damage", stats.damage))
	var resolver: CombatResolver = _controller.combat_service()
	var source: Node2D = interaction.get("source")
	var order := resolver.next_displacement_order(source)
	var delivery := CombatInteraction.Delivery.new()
	interaction["delivery"] = delivery
	for target in _controller.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(target) or target.is_queued_for_deletion() or target.hp <= 0 or target.team == team: continue
		if not CombatInteraction.allows_effect(target, interaction): continue
		if target.global_position.distance_to(position) > float(stats.radius) + target.body_radius: continue
		var amount := damage * (float(stats.tower_damage_multiplier) if target is Tower else 1.0)
		var previous := CombatInteraction.current_delivery
		CombatInteraction.current_delivery = delivery
		var result := BattleNumbers.hit(target, amount, source, team, interaction.get("position", Vector2(INF, INF)))
		CombatInteraction.current_delivery = previous
		var hit_pos: Vector2 = target.global_position
		var show_hit := func():
			if bool(result.landed): _controller.present_cask_hit(hit_pos, team)
		if resolver.collecting: resolver.defer_effect(show_hit)
		else: show_hit.call()
		if is_instance_valid(target) and target is Unit:
			if resolver.collecting:
				resolver.submit_knockback(target, position, float(stats.knockback), 0.2, 1.4, order, result, interaction)
			elif bool(result.landed) and is_instance_valid(target) and target.hp > 0:
				target.apply_knockback(position, float(stats.knockback), 0.2, 1.4, order, interaction)


## 固定Tick间隔召唤，局部种子落点不消费战斗随机流。
func _start_summoning(team: int, stats: Dictionary, pos: Vector2, enhanced: bool) -> void:
	_effect_serial += 1
	var tick: int = _controller.get_authoritative_server_tick()
	var ticks := maxi(1, ceili(float(stats.duration) / FixedStepClock.STEP))
	var zone := {"team": team, "pos": pos, "radius": float(stats.radius), "stats": stats,
		"start_tick": tick, "end_tick": tick + ticks, "index": 0, "enhanced": enhanced, "deaths": {}, "offsets": _summoning_offsets(int(stats.spawn_count), float(stats.radius), pos, float(CardDB.get_unit_stats(String(stats.spawn_id)).radius))}
	summon_zones.append(zone)
	show_summoning(pos, float(stats.radius), float(stats.duration), team)
	_controller.present_summoning_spell(pos, float(stats.radius), float(stats.duration), team)
	_tick_summoning()

## 固定局部种子只决定本卡的形状，不消耗全局或战斗随机序列。
func _summoning_offsets(count: int, radius: float, center: Vector2 = Vector2.INF, body_radius: float = 0.0) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 223069
	var offsets: Array[Vector2] = []
	for index in count:
		var chosen := Vector2.ZERO
		var best_spacing := -1.0
		# 固定候选数的最远点选择：不规则，同时避免随机扎堆。
		for attempt in 64:
			var candidate := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * radius * 0.9
			if center.is_finite():
				var point := center + candidate
				if point.x < body_radius or point.x > ArenaRules.FIELD_W - body_radius or point.y < body_radius or point.y > ArenaRules.FIELD_H - body_radius: continue
			var spacing := INF
			for previous in offsets: spacing = minf(spacing, candidate.distance_squared_to(previous))
			if spacing > best_spacing:
				chosen = candidate
				best_spacing = spacing
		offsets.append(chosen)
	return offsets

func _tick_summoning() -> void:
	var tick: int = _controller.get_authoritative_server_tick()
	var alive: Array[Dictionary] = []
	for zone in summon_zones:
		var count := int(zone.stats.spawn_count)
		var interval_ticks := maxi(1, roundi(float(zone.stats.interval) / FixedStepClock.STEP))
		while int(zone.index) < count:
			var index := int(zone.index)
			var due := int(zone.start_tick) + roundi(float(zone.stats.spawn_initial_delay) / FixedStepClock.STEP) + index * interval_ticks
			if tick < due: break
			_spawn_zone_fish(zone, zone.pos + zone.offsets[index])
			zone.index = index + 1
		if tick < int(zone.end_tick): alive.append(zone)
	summon_zones.assign(alive)

func _spawn_zone_fish(zone: Dictionary, pos: Vector2) -> void:
	_controller.spawn_summoned(int(zone.team), String(zone.stats.spawn_id), pos, float(zone.stats.spawn_deploy_time), "", -1, Vector2.INF, zone.pos, float(zone.radius))

func on_unit_death(unit: Unit) -> void:
	if not is_instance_valid(unit) or unit.is_building or not unit.is_true_death(): return
	if unit.card_id == "voidfish": return
	var tick: int = _controller.get_authoritative_server_tick()
	for zone in summon_zones:
		if not bool(zone.enhanced) or tick >= int(zone.end_tick): continue
		if unit.global_position.distance_to(zone.pos) > float(zone.radius): continue
		var id := unit.get_instance_id()
		if zone.deaths.has(id): continue
		zone.deaths[id] = true
		_spawn_zone_fish(zone, unit.global_position)

func show_summoning(pos: Vector2, radius: float, duration: float, team: int) -> void:
	if not _controller.has_presentation(): return
	summon_effects.append({"pos": pos, "radius": radius, "duration": duration, "timer": duration, "team": team})


func _start_tidal_wave(team: int, stats: Dictionary, pos: Vector2, enhanced: bool, skill_index: int) -> void:
	_effect_serial += 1
	var tick: int = _controller.get_authoritative_server_tick() + ceili(float(stats.spell_windup) / FixedStepClock.STEP)
	var direction := Vector2.UP if team == 0 else Vector2.DOWN
	var end_tick := tick + maxi(1, ceili(float(stats.duration) / FixedStepClock.STEP))
	var wave := {"id": _effect_serial, "team": team, "origin": pos, "direction": direction,
		"stats": stats, "skill": _active_heal_skill(stats, skill_index) if enhanced else {},
		"start_tick": tick, "end_tick": end_tick, "distance": 0.0, "last_tick": tick - 1, "launched": false,
		"contacts": {}, "delivery": CombatInteraction.Delivery.new(), "source": StringName("tidal:%d:%d" % [team, _effect_serial])}
	tidal_waves.append(wave)

func _tick_tidal_waves() -> void:
	var tick: int = _controller.get_authoritative_server_tick()
	for wave in tidal_waves:
		if tick < int(wave.start_tick): continue
		if not wave.launched:
			wave.launched = true
			_controller.present_spell_flight(int(wave.id), "tidal_wave", wave.origin, Vector2(wave.origin) + Vector2(wave.direction) * float(wave.stats.range), float(wave.stats.wave_width) * 0.5, int(wave.start_tick), int(wave.end_tick), int(wave.team))
			_controller.runtime.card_event("tidal_wave", "spell:launch", wave.origin, int(wave.team))
		if tick <= int(wave.last_tick): continue
		var distance := minf(float(wave.stats.range), float(tick - int(wave.start_tick)) * FixedStepClock.STEP * float(wave.stats.speed))
		_contact_tidal_wave(wave, float(wave.distance), distance)
		wave.distance = distance
		wave.last_tick = tick
	tidal_waves.assign(tidal_waves.filter(func(wave): return tick < int(wave.end_tick)))

func _contact_tidal_wave(wave: Dictionary, from_distance: float, to_distance: float) -> void:
	var interaction := _spell_context(int(wave.team))
	interaction["delivery"] = wave.delivery
	var resolver: CombatResolver = _controller.combat_service()
	var source: Node2D = interaction.get("source")
	var order := resolver.next_displacement_order(source)
	for target in _controller.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(target) or target.is_queued_for_deletion() or target.hp <= 0: continue
		if target is Unit and target.is_air: continue
		var id: int = target.get_instance_id()
		if wave.contacts.has(id): continue
		var relative: Vector2 = target.global_position - Vector2(wave.origin)
		var along := relative.dot(Vector2(wave.direction))
		# Circle against swept wave-front rectangle, including rounded corner distance.
		var nearest := Vector2(clampf(relative.x, -float(wave.stats.wave_width) * 0.5, float(wave.stats.wave_width) * 0.5), clampf(along, from_distance, to_distance))
		if Vector2(relative.x, along).distance_squared_to(nearest) > float(target.body_radius) * float(target.body_radius): continue
		wave.contacts[id] = true
		if target.team == int(wave.team):
			if not wave.skill.is_empty() and target is Unit and not target.is_building:
				target.apply_active_buff(float(wave.skill.duration), float(wave.skill.speed_multiplier), 1.0, 1.0, false, false, wave.source, interaction)
			continue
		if not CombatInteraction.allows_effect(target, interaction): continue
		var previous := CombatInteraction.current_delivery
		CombatInteraction.current_delivery = wave.delivery
		var amount := float(wave.stats.damage) * (float(wave.stats.tower_damage_multiplier) if target is Tower else 1.0)
		var result := BattleNumbers.hit(target, amount, source, int(wave.team), interaction.get("position", Vector2.INF))
		CombatInteraction.current_delivery = previous
		var hit_position: Vector2 = target.global_position
		var hit_audio := func():
			if result.landed:
				_controller.runtime.card_event("tidal_wave", "spell:hit", hit_position, int(wave.team))
		if resolver.collecting: resolver.defer_effect(hit_audio)
		else: hit_audio.call()
		if target is Unit:
			var push_origin: Vector2 = target.global_position - Vector2(wave.direction)
			if resolver.collecting:
				resolver.submit_knockback(target, push_origin, float(wave.stats.knockback), 0.2, 1.4, order, result, interaction)
			elif bool(result.landed) and is_instance_valid(target) and target.hp > 0:
				target.apply_knockback(push_origin, float(wave.stats.knockback), 0.2, 1.4, order, interaction)


## 空间边界按身体圆与运动线段扫掠；每次施法独立去重，纯圈内不触发。
func _start_event_horizon(team: int, stats: Dictionary, pos: Vector2, enhanced: bool, skill_index: int) -> void:
	_effect_serial += 1
	var tick: int = _controller.get_authoritative_server_tick()
	var start := tick + ceili(float(stats.spell_windup) / FixedStepClock.STEP)
	var finish := start + ceili(float(stats.duration) / FixedStepClock.STEP)
	horizon_zones.append({"id": _effect_serial, "team": team, "pos": pos, "stats": stats,
		"skill": _active_heal_skill(stats, skill_index) if enhanced else {}, "triggered": false,
		"start_tick": start, "end_tick": finish, "last_tick": start - 1,
		"contacts": {}, "previous": {}, "delivery": CombatInteraction.Delivery.new(),
		"source": StringName("horizon:%d:%d" % [team, _effect_serial])})
	_controller.present_spell_flight(_effect_serial, "event_horizon", pos, pos, float(stats.radius), tick, finish, team)

static func touches_boundary(from: Vector2, to: Vector2, center: Vector2, radius: float, body: float) -> bool:
	var nearest := Geometry2D.get_closest_point_to_segment(center, from, to)
	var minimum := nearest.distance_to(center)
	var maximum := maxf(from.distance_to(center), to.distance_to(center))
	return minimum <= radius + body and maximum >= maxf(0.0, radius - body)

func _tick_event_horizon() -> void:
	var tick: int = _controller.get_authoritative_server_tick()
	for zone in horizon_zones:
		if tick < int(zone.start_tick) or tick >= int(zone.end_tick) or tick <= int(zone.last_tick): continue
		if int(zone.last_tick) < int(zone.start_tick):
			_controller.present_horizon_zone_audio(zone.pos, float(int(zone.end_tick) - tick) * FixedStepClock.STEP, int(zone.team))
		zone.last_tick = tick
		var targets: Array = _controller.get_tree().get_nodes_in_group("combatants")
		targets.sort_custom(func(a, b): return a.combat_source_id < b.combat_source_id)
		for target in targets:
			if not is_instance_valid(target) or target.is_queued_for_deletion() or not target is Unit: continue
			if target.hp <= 0 or target.team == int(zone.team) or target.is_building: continue
			var id: int = target.get_instance_id()
			var pos: Vector2 = target.global_position
			var previous: Vector2 = zone.previous.get(id, pos)
			zone.previous[id] = pos
			if zone.contacts.has(id) or not touches_boundary(previous, pos, zone.pos, float(zone.stats.radius), float(target.body_radius)): continue
			var interaction := _spell_context(int(zone.team))
			interaction["delivery"] = zone.delivery
			if not CombatInteraction.allows_effect(target, interaction) or target.structure_rush.control_immune(): continue
			zone.contacts[id] = true
			if CombatInteraction.blocks_effect(target, interaction): continue
			# 同一批次完成伤害与死亡后再施加；只有仍存活且准入的目标触发黑暗物质。
			var apply := func():
				if not is_instance_valid(target) or target.hp <= 0: return
				if not CombatInteraction.allows_effect(target, interaction) or target.structure_rush.control_immune(): return
				target.stun(float(zone.stats.stun_duration), zone.source, interaction)
				_controller.runtime.card_event("event_horizon", "spell:hit", pos, int(zone.team))
				if not zone.triggered and not zone.skill.is_empty():
					zone.triggered = true
					_start_dark_matter(zone, pos, tick)
			if _controller.combat_service().collecting: _controller.combat_service().defer_effect(apply)
			else: apply.call()
	horizon_zones.assign(horizon_zones.filter(func(zone): return tick < int(zone.end_tick)))
	for matter in dark_matters:
		if tick < int(matter.impact_tick): continue
		var interaction := _spell_context(int(matter.team))
		var previous := CombatInteraction.current_delivery
		CombatInteraction.current_delivery = matter.delivery
		for target in _controller.get_tree().get_nodes_in_group("combatants"):
			if not is_instance_valid(target) or target.is_queued_for_deletion() or target.hp <= 0 or target.team == int(matter.team): continue
			if not CombatInteraction.allows_effect(target, interaction): continue
			if target.global_position.distance_to(matter.pos) > float(matter.skill.radius) + target.body_radius: continue
			var amount := float(matter.skill.damage) * (float(matter.skill.tower_damage_multiplier) if target is Tower else 1.0)
			BattleNumbers.hit(target, amount, interaction.get("source"), int(matter.team), interaction.get("position", Vector2.INF))
		CombatInteraction.current_delivery = previous
		_controller.runtime.card_event("event_horizon", "spell:impact", matter.pos, int(matter.team))
	dark_matters.assign(dark_matters.filter(func(matter): return tick < int(matter.impact_tick)))

func _start_dark_matter(zone: Dictionary, pos: Vector2, tick: int) -> void:
	_effect_serial += 1
	var impact := tick + ceili(float(zone.skill.dark_matter_delay) / FixedStepClock.STEP)
	dark_matters.append({"pos": pos, "team": zone.team, "skill": zone.skill, "impact_tick": impact, "delivery": CombatInteraction.Delivery.new()})
	_controller.present_spell_flight(_effect_serial, "dark_matter", pos, pos, float(zone.skill.radius), tick, impact, int(zone.team))
	_controller.runtime.card_event("event_horizon", "spell:meteor", pos, int(zone.team))


func _start_severing_bolt(team: int, stats: Dictionary, pos: Vector2, enhanced: bool, skill_index: int) -> void:
	_effect_serial += 1
	var tick: int = _controller.get_authoritative_server_tick()
	var warning := tick + ceili(float(stats.spell_windup) / FixedStepClock.STEP)
	var impact := warning + ceili(float(stats.duration) / FixedStepClock.STEP)
	bolt_casts.append({"team": team, "pos": pos, "stats": stats, "warning_tick": warning,
		"impact_tick": impact, "warned": false, "skill": _active_heal_skill(stats, skill_index) if enhanced else {},
		"delivery": CombatInteraction.Delivery.new()})
	_controller.present_spell_flight(_effect_serial, "severing_bolt", pos, pos, float(stats.radius), tick, impact, team)

static func bolt_hard_controlled(target: Node) -> bool:
	if target is Tower:
		return target.control.frozen_timer > 0.0 or target.control.stun_timer > 0.0
	if not target is Unit: return false
	return target.control.frozen_timer > 0.0 or target.control.stun_timer > 0.0 or target.control.hard.remaining(&"root") > 0.0 or target.knockback.remaining > 0.0

func _tick_severing_bolt() -> void:
	var tick: int = _controller.get_authoritative_server_tick()
	for bolt in bolt_casts:
		if tick >= int(bolt.warning_tick) and not bolt.warned:
			bolt.warned = true
			# Original OnCast sounds at cast completion, alongside the target warning.
			_controller.runtime.card_event("severing_bolt", "spell:launch", bolt.pos, int(bolt.team))
			_controller.runtime.card_event("severing_bolt", "spell:warning", bolt.pos, int(bolt.team))
		if tick < int(bolt.impact_tick): continue
		var interaction := _spell_context(int(bolt.team))
		var targets: Array = []
		# 先固定命中集合与倍率，不能因同批死亡或盾消费顺序改变单体资格。
		for target in _controller.get_tree().get_nodes_in_group("combatants"):
			if not is_instance_valid(target) or target.is_queued_for_deletion() or target.hp <= 0 or target.team == int(bolt.team): continue
			if not CombatInteraction.allows_effect(target, interaction): continue
			if target.global_position.distance_to(bolt.pos) <= float(bolt.stats.radius) + target.body_radius: targets.append(target)
		var previous := CombatInteraction.current_delivery
		CombatInteraction.current_delivery = bolt.delivery
		for target in targets:
			var multiplier := float(bolt.skill.get("isolated_damage_multiplier", bolt.stats.isolated_damage_multiplier)) if targets.size() == 1 else 1.0
			if bolt_hard_controlled(target): multiplier = maxf(multiplier, float(bolt.skill.get("controlled_damage_multiplier", bolt.stats.controlled_damage_multiplier)))
			var amount := float(bolt.stats.damage) * multiplier * (float(bolt.stats.tower_damage_multiplier) if target is Tower else 1.0)
			var receipt := BattleNumbers.hit(target, amount, interaction.get("source"), int(bolt.team), interaction.get("position", Vector2.INF))
			var hit_pos: Vector2 = target.global_position
			var present_hit := func():
				if not receipt.landed: return
				_effect_serial += 1
				_controller.present_spell_flight(_effect_serial, "severing_bolt_hit", hit_pos, hit_pos, float(bolt.stats.radius), tick, tick, int(bolt.team))
			if _controller.combat_service().collecting: _controller.combat_service().defer_effect(present_hit)
			else: present_hit.call()
		CombatInteraction.current_delivery = previous
		_controller.runtime.card_event("severing_bolt", "spell:impact", bolt.pos, int(bolt.team))
	bolt_casts.assign(bolt_casts.filter(func(bolt): return tick < int(bolt.impact_tick)))


func _start_solar_flare(team: int, stats: Dictionary, pos: Vector2, enhanced: bool, skill_index: int) -> void:
	_effect_serial += 1
	var tick: int = _controller.get_authoritative_server_tick()
	var impact := tick + ceili(float(stats.spell_windup) / FixedStepClock.STEP)
	solar_casts.append({"team": team, "pos": pos, "stats": stats, "impact_tick": impact,
		"skill": _active_heal_skill(stats, skill_index) if enhanced else {}, "delivery": CombatInteraction.Delivery.new()})
	_controller.present_spell_flight(_effect_serial, "solar_flare", pos, pos, float(stats.radius), tick, impact, team)

func _tick_solar_flare() -> void:
	var tick: int = _controller.get_authoritative_server_tick()
	for cast in solar_casts:
		if tick < int(cast.impact_tick): continue
		var interaction := _spell_context(int(cast.team))
		interaction["delivery"] = cast.delivery
		for target in _controller.get_tree().get_nodes_in_group("combatants"):
			if not is_instance_valid(target) or target.is_queued_for_deletion() or not (target is Unit or target is Tower): continue
			if target.hp <= 0 or target.team == int(cast.team): continue
			var distance: float = target.global_position.distance_to(cast.pos)
			if distance > float(cast.stats.radius) + target.body_radius: continue
			if not CombatInteraction.allows_effect(target, interaction) or CombatInteraction.blocks_effect(target, interaction): continue
			if distance <= float(cast.stats.inner_radius) + target.body_radius:
				target.stun(float(cast.stats.duration), &"solar_flare", interaction)
			elif target is Unit and not target.is_building:
				target.apply_slow(float(cast.stats.duration), float(cast.stats.slow_multiplier), &"solar_flare", interaction)
			if not cast.skill.is_empty():
				var apply := func():
					if is_instance_valid(target) and target.hp > 0 and CombatInteraction.allows_effect(target, interaction):
						var marks: StatusInstances = target.sunlight_marks if target is Tower else target.buffs
						var damage := float(cast.skill.damage) * (float(cast.skill.tower_damage_multiplier) if target is Tower else 1.0)
						marks.apply(&"sunlight", &"solar_flare", float(cast.skill.duration), {"damage": damage})
				if _controller.combat_service().collecting: _controller.combat_service().defer_effect(apply)
				else: apply.call()
		_controller.runtime.card_event("solar_flare", "spell:impact", cast.pos, int(cast.team))
	solar_casts.assign(solar_casts.filter(func(cast): return tick < int(cast.impact_tick)))

func present_sunlight_consumed(pos: Vector2, team: int) -> void:
	_effect_serial += 1
	var tick: int = _controller.get_authoritative_server_tick()
	_controller.present_spell_flight(_effect_serial, "sunlight_consume", pos, pos, 25.0, tick, tick, team)
	_controller.runtime.card_event("solar_flare", "spell:sunlight", pos, team)

func _start_pool(team: int, stats: Dictionary, pos: Vector2, enhanced: bool, skill_index: int) -> void:
	var tick: int = _controller.get_authoritative_server_tick()
	var skill := _active_heal_skill(stats, skill_index) if enhanced else {}
	var zone := {"team": team, "pos": pos, "stats": stats, "start_tick": tick,
		"end_tick": tick + ceili(float(stats.duration) / FixedStepClock.STEP), "last_tick": tick}
	pool_zones.append(zone)
	_effect_serial += 1
	_controller.present_spell_flight(_effect_serial, "pool_of_reflection", pos, pos, float(stats.radius), tick, int(zone.end_tick), team)
	_controller.present_pool_zone_audio(pos, float(stats.duration), team)
	if enhanced:
		for target in _controller.get_tree().get_nodes_in_group("combatants"):
			if _pool_target(target, zone): target.replenish_pool_shield(float(skill.shield), float(stats.shield_duration), _spell_context(team))

func _pool_target(target: Node, zone: Dictionary) -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion() and target is Unit and not target.is_building and target.hp > 0.0 and target.team == int(zone.team) and target.global_position.distance_to(zone.pos) <= float(zone.stats.radius) + target.body_radius

func _tick_pool() -> void:
	var tick: int = _controller.get_authoritative_server_tick()
	# 相同Tick每单位只补充一次，重叠不叠加补盾速率。
	var recipients := {}
	for zone in pool_zones:
		if tick <= int(zone.last_tick) or tick > int(zone.end_tick): continue
		zone.last_tick = tick
		for target in _controller.get_tree().get_nodes_in_group("combatants"):
			if not _pool_target(target, zone): continue
			if not recipients.has(target): recipients[target] = zone
	for target in recipients:
		var zone: Dictionary = recipients[target]
		target.replenish_pool_shield(float(zone.stats.shield_per_second) * FixedStepClock.STEP, float(zone.stats.shield_duration), _spell_context(int(zone.team)))
	pool_zones.assign(pool_zones.filter(func(zone): return tick < int(zone.end_tick)))


func _apply_mega_inferno_bomb(team: int, stats: Dictionary, pos: Vector2, enhanced: bool, skill_index: int) -> void:
	var interaction := _spell_context(team)
	var delivery := CombatInteraction.Delivery.new()
	interaction["delivery"] = delivery
	var previous := CombatInteraction.current_delivery
	CombatInteraction.current_delivery = delivery
	var resolver: CombatResolver = _controller.combat_service()
	for target in _controller.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(target) or target.is_queued_for_deletion() or target.hp <= 0 or target.team == team: continue
		var distance: float = target.global_position.distance_to(pos)
		if distance > float(stats.radius) + target.body_radius: continue
		if not CombatInteraction.allows_effect(target, interaction) or CombatInteraction.blocks_effect(target, interaction): continue
		var amount := float(stats.inner_damage if distance <= float(stats.inner_radius) + target.body_radius else stats.damage)
		if target is Tower: amount *= float(stats.tower_damage_multiplier)
		if enhanced and not resolver.collecting: target.clear_shields()
		var receipt := BattleNumbers.hit(target, amount, interaction.get("source"), team, interaction.get("position", Vector2.INF))
		# 收集阶段只标记；提交阶段在本批扣血前清盾，不计作耗盾伤害或吸血收益。
		if enhanced and resolver.collecting: receipt["break_shields"] = true
		if enhanced and target is Unit and not target.is_building:
			var apply := func():
				if receipt.landed and is_instance_valid(target) and target.hp > 0:
					target.grievous_wounds = true
					target.queue_redraw()
			if resolver.collecting: resolver.defer_effect(apply)
			else: apply.call()
	CombatInteraction.current_delivery = previous

func _start_convergent_pulse(team: int, stats: Dictionary, pos: Vector2, enhanced: bool, skill_index: int) -> void:
	_effect_serial += 1
	var tick: int = _controller.get_authoritative_server_tick()
	var impact := tick + ceili(float(stats.spell_windup) / FixedStepClock.STEP)
	var skill := _active_heal_skill(stats, skill_index) if enhanced else {}
	var radius := float(skill.get("radius", stats.radius))
	pulse_casts.append({"team": team, "pos": pos, "stats": stats, "radius": radius,
		"damage": float(skill.get("damage", stats.damage)), "impact_tick": impact,
		"pull_distance": float(skill.get("pull_distance", stats.pull_distance)),
		"duration": float(skill.get("duration", stats.duration))})
	_controller.present_spell_flight(_effect_serial, "convergent_pulse", pos, pos, radius, tick, impact, team)
	_controller.runtime.card_event("convergent_pulse", "spell:charge", pos, team)

func _tick_convergent_pulse() -> void:
	var tick: int = _controller.get_authoritative_server_tick()
	var resolver: CombatResolver = _controller.combat_service()
	for cast in pulse_casts:
		if tick < int(cast.impact_tick): continue
		var interaction := _spell_context(int(cast.team))
		var source: Node2D = interaction.get("source")
		var order := resolver.next_displacement_order(source)
		var delivery := CombatInteraction.Delivery.new()
		interaction["delivery"] = delivery
		for target in _controller.get_tree().get_nodes_in_group("combatants"):
			if not is_instance_valid(target) or target.is_queued_for_deletion() or target.hp <= 0 or target.team == int(cast.team): continue
			if not (target is Unit or target is Tower) or not CombatInteraction.allows_effect(target, interaction): continue
			var distance: float = target.global_position.distance_to(cast.pos)
			if distance > float(cast.radius) + target.body_radius: continue
			var amount := float(cast.damage) * (float(cast.stats.tower_damage_multiplier) if target is Tower else 1.0)
			var previous := CombatInteraction.current_delivery
			CombatInteraction.current_delivery = delivery
			var result := BattleNumbers.hit(target, amount, source, int(cast.team), interaction.get("position", Vector2(INF, INF)))
			CombatInteraction.current_delivery = previous
			var hit_pos: Vector2 = target.global_position
			var hit_team := int(cast.team)
			var show_hit := func():
				if bool(result.landed): _controller.runtime.card_event("convergent_pulse", "spell:hit", hit_pos, hit_team)
			if resolver.collecting: resolver.defer_effect(show_hit)
			else: show_hit.call()
			if target is Unit and not target.is_building and distance > 0.001:
				var direction: Vector2 = (Vector2(cast.pos) - target.global_position).normalized()
				var pull_distance := float(cast.pull_distance)
				var duration := float(cast.duration)
				var batched := resolver.collecting
				# 先等伤害准入结果；法术盾拒绝整次命中时不能提交外力。
				# 延迟效果在位移队列提交前执行，保留统一位移排序与控制门禁。
				var pull := func():
					if not bool(result.landed) or not is_instance_valid(target) or target.hp <= 0: return
					if batched:
						resolver.submit_forced_displacement(target, direction, pull_distance, duration, -1.0, order, interaction)
					else:
						target.apply_forced_displacement(direction, pull_distance, duration, -1.0, interaction, order)
				if batched: resolver.defer_effect(pull)
				else: pull.call()
	pulse_casts.assign(pulse_casts.filter(func(cast): return tick < int(cast.impact_tick)))

func _start_final_spark(team: int, stats: Dictionary, pos: Vector2, enhanced: bool, skill_index: int) -> void:
	_effect_serial += 1
	var tick: int = _controller.get_authoritative_server_tick()
	var impact := tick + ceili(float(stats.spell_windup) / FixedStepClock.STEP)
	var end := pos + (Vector2.UP if team == 0 else Vector2.DOWN) * float(stats.range)
	spark_casts.append({"team": team, "origin": pos, "end": end, "stats": stats, "impact_tick": impact,
		"blind": int(_active_heal_skill(stats, skill_index).get("blind_charges", 0)) if enhanced else 0})
	_controller.present_spell_flight(_effect_serial, "final_spark", pos, end, float(stats.radius), tick, impact, team)
	# 原版三处空间声音都从起手播放，事件内部自带0.9秒爆发层延迟。
	_controller.runtime.card_event("final_spark", "spell:middle", pos.lerp(end, 0.5), team)
	_controller.runtime.card_event("final_spark", "spell:end", end, team)

static func final_spark_intersects(origin: Vector2, end: Vector2, width: float, pos: Vector2, body_radius: float) -> bool:
	var direction := (end - origin).normalized()
	var relative := pos - origin
	var local := Vector2(relative.dot(Vector2(-direction.y, direction.x)), relative.dot(direction))
	var nearest := Vector2(clampf(local.x, -width * 0.5, width * 0.5), clampf(local.y, 0.0, origin.distance_to(end)))
	return local.distance_squared_to(nearest) <= body_radius * body_radius

func _tick_final_spark() -> void:
	var tick: int = _controller.get_authoritative_server_tick()
	var resolver: CombatResolver = _controller.combat_service()
	for cast in spark_casts:
		if tick < int(cast.impact_tick): continue
		var interaction := _spell_context(int(cast.team))
		var source: Node2D = interaction.get("source")
		var delivery := CombatInteraction.Delivery.new()
		interaction["delivery"] = delivery
		for target in _controller.get_tree().get_nodes_in_group("combatants"):
			if not is_instance_valid(target) or target.is_queued_for_deletion() or target.hp <= 0 or target.team == int(cast.team): continue
			if not (target is Unit or target is Tower) or not CombatInteraction.allows_effect(target, interaction): continue
			if not final_spark_intersects(cast.origin, cast.end, float(cast.stats.wave_width), target.global_position, float(target.body_radius)): continue
			var previous := CombatInteraction.current_delivery
			CombatInteraction.current_delivery = delivery
			var amount := float(cast.stats.damage) * (float(cast.stats.tower_damage_multiplier) if target is Tower else 1.0)
			var receipt := BattleNumbers.hit(target, amount, source, int(cast.team), interaction.get("position", Vector2.INF))
			CombatInteraction.current_delivery = previous
			var finish := func():
				if not bool(receipt.landed): return
				if int(cast.blind) > 0 and is_instance_valid(target) and target is Unit and not target.is_building and target.hp > 0:
					target.apply_blind(int(cast.blind), interaction)
			if resolver.collecting: resolver.defer_effect(finish)
			else: finish.call()
	spark_casts.assign(spark_casts.filter(func(cast): return tick < int(cast.impact_tick)))
