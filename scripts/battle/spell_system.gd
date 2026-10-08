class_name SpellSystem
extends RefCounted
## 数据驱动法术的权威执行与持续区域。
## Main 只负责出牌编排；新增 spell_kind 时在这里实现一次，并由 CardDB 拒绝未实现的配置。

var corrosion_zones: Array[Dictionary] = []
var corrosion_effects: Array[Dictionary] = []

var freeze_effects: Array[Dictionary] = []
var slow_zones: Array[Dictionary] = []
var slow_effects: Array[Dictionary] = []
## 治疗术表现区域：阵营色边界与淡黄内光；全图强化治疗额外带全图扩散波纹。
var heal_effects: Array[Dictionary] = []

var cask_hits: Array[Dictionary] = []
var cask_effects: Array[Dictionary] = []
var spell_flights: Array[Dictionary] = []
var stasis_effects: Array[Dictionary] = []

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
	_tick_corrosion()
	_tick_flights()
	_tick_lightning()
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
		if not combatant is Unit or not is_instance_valid(combatant) or combatant.team == int(zone.team) or combatant.hp <= 0.0:
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
	for hit in cask_hits: hit.timer = maxf(0.0, float(hit.timer) - delta)
	cask_hits.assign(cask_hits.filter(func(hit): return float(hit.timer) > 0.0))
	for effect in corrosion_effects:
		effect.timer = maxf(0.0, float(effect.timer) - delta)
	corrosion_effects.assign(corrosion_effects.filter(func(effect): return float(effect.timer) > 0.0))
	for effect in stasis_effects + cask_effects:
		if bool(effect.impacted):
			effect.timer = maxf(0.0, float(effect.timer) - delta)
		else:
			var tick: int = int(_controller.get_presentation_tick())
			var fraction: float = 0.0 if _controller.is_net_client() else _controller.get_sim_interpolation_alpha()
			effect.progress = clampf((float(tick - int(effect.start_tick)) + fraction) / maxi(1, int(effect.impact_tick) - int(effect.start_tick)), 0.0, 1.0)
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
	corrosion_zones.clear()
	corrosion_effects.clear()
	spell_flights.clear()
	stasis_effects.clear()
	cask_effects.clear()
	cask_hits.clear()
	lightning_casts.clear()
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


func show_lightning(kind: String, position: Vector2, radius: float) -> void:
	if not _controller.has_presentation(): return
	# 风暴狂涌地面焦痕约2秒，电刑烟影约1秒；仅影响表现数组寿命。
	var duration := 2.1 if kind == "zap" else 1.1
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

func show_flight(id: int, kind: String, origin: Vector2, position: Vector2, radius: float, start_tick: int, impact_tick: int) -> void:
	if not _controller.has_presentation(): return
	# 首个皮肤为凝滞；其他法术复用调度并沿用自身抵达表现。
	if kind not in ["stasis", "explosive_cask"]: return
	var effects := cask_effects if kind == "explosive_cask" else stasis_effects
	effects.append({"id": id, "origin": origin, "pos": position, "radius": radius,
		"start_tick": start_tick, "impact_tick": impact_tick, "progress": 0.0, "impacted": false, "duration": 2.15 if kind == "explosive_cask" else 2.0, "timer": 2.15 if kind == "explosive_cask" else 2.0})

func show_arrival(id: int) -> void:
	if not _controller.has_presentation(): return
	for effect in stasis_effects + cask_effects:
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
		if target is Unit:
			if resolver.collecting:
				resolver.submit_knockback(target, position, float(stats.knockback), 0.2, 1.4, order, result, interaction)
			elif bool(result.landed) and is_instance_valid(target) and target.hp > 0:
				target.apply_knockback(position, float(stats.knockback), 0.2, 1.4, order, interaction)
