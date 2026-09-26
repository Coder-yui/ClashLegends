class_name PresentationEvents
extends RefCounted
## 当前实际派发能力表；新增 cue 必须同时实现权威派发与消费者。
static func supports(stats: Dictionary, cue: String) -> bool:
	if cue in ["attack_wave:launch", "attack_wave:hit"]: return float(stats.get("attack_wave_damage", 0.0)) > 0.0
	if cue in ["terrain:enter", "terrain:sustain", "terrain:exit"]: return bool(stats.get("terrain_traversal", false))
	if cue == "active:spin": return (stats.get("active_skills", []) as Array).any(func(skill): return String(skill.get("kind", "")) == "dash_strike")
	if cue == "execute:kill": return (stats.get("active_skills", []) as Array).any(func(skill): return String(skill.get("kind", "")) == "bleeding_execute")
	if cue in ["blood_rage:start", "blood_rage:sustain"]: return stats.has("bleed_max_stacks")
	if cue in ["rebirth:begin", "rebirth:voice", "rebirth:ready", "berserk:sustain"]:
		return float(stats.get("death_form_delay", 0.0)) > 0.0
	if cue in ["shield:explode", "explosive_shield:sustain", "explosive_shield:break"]:
		return (stats.get("active_skills", []) as Array).any(func(skill): return String(skill.get("kind", "")) == "explosive_shield")
	if cue in ["rush_prepare:sustain", "rush:start", "rush:path_hit", "rush:hit"]:
		return float(stats.get("rush_distance", 0.0)) > 0.0
	var spell := String(stats.get("type", "")) == "spell"
	if spell:
		return cue == "spell:cast"
	if cue in ["sanctuary:sustain", "sanctuary:end"]:
		return (stats.get("active_skills", []) as Array).any(func(skill): return String(skill.get("kind", "")) == "sanctuary")
	if cue == "active:cast":
		# 没有独立 visual_action 的瞬时主动技能也需要一个稳定的 Cast Start 音频入口。
		var active_skills: Variant = stats.get("active_skills", [])
		return active_skills is Array and not (active_skills as Array).is_empty()
	if cue == "form:refresh":
		return bool(stats.get("form_refresh_on_kill", false)) and float(stats.get("form_lifetime", 0.0)) > 0.0
	var attacks := float(stats.get("damage", 0.0)) > 0.0
	if cue in ["continuous_attack:start", "continuous_attack:sustain", "continuous_attack:end", "continuous_attack:release"]:
		return attacks and bool(stats.get("is_continuous_attack", false))
	if cue == "replacement:start":
		return not String(stats.get("death_replacement_id", "")).is_empty()
	if cue in ["revival:sustain", "revival:end"]:
		return not String(stats.get("timed_revival_id", "")).is_empty()
	if cue == "spawn:start":
		return not spell
	if cue in ["shield:cast", "shield:applied"]:
		return (stats.get("active_skills", []) as Array).any(func(skill): return String(skill.get("kind", "")) == "area_shield")
	if cue == "idle:sustain":
		return not spell
	if cue in ["death", "death:voice"]:
		return true
	if cue == "pre_deploy:start":
		return float(stats.get("pre_deploy_time", 0.0)) > 0.0
	if cue == "deploy:hit":
		return float(stats.get("deploy_sweep_damage", 0.0)) > 0.0 and float(stats.get("deploy_sweep_radius", 0.0)) > 0.0
	if cue in ["deploy:start", "deploy:voice"]:
		return float(stats.get("deploy_time", 1.0)) > 0.0
	if cue in ["attack_launch", "attack_missile_cast"]:
		return attacks and float(stats.get("projectile_speed", 0.0)) > 0.0
	if cue == "empowered_launch":
		return attacks and float(stats.get("projectile_speed", 0.0)) > 0.0 and supports(stats, "empowered_swing")
	if cue in ["empowered_buff:start", "empowered_buff:end"]:
		return supports(stats, "empowered_ready")
	if cue == "resource_full":
		return float(stats.get("skill_resource_max", 0.0)) > 0.0
	if cue == "passive_heal":
		return int(stats.get("heal_every_hits", 0)) > 0 and float(stats.get("heal_amount", 0.0)) > 0.0
	if cue.begins_with("first_strike:"):
		return attacks and not bool(stats.get("is_continuous_attack", false)) and float(stats.get("first_strike_damage_multiplier", 1.0)) != 1.0 and (cue in ["first_strike:cast", "first_strike:hit_location"] or (cue in ["first_strike:missile_cast", "first_strike:missile_launch"] and float(stats.get("projectile_speed", 0.0)) > 0.0))
	var lifecycle := cue.split(":")
	if lifecycle.size() == 2 and lifecycle[1] in ["start", "end", "sustain"] and stats.get("visual_animations", {}).get("visual_actions", {}).has(lifecycle[0]):
		if lifecycle[0] == "transform" and int(stats.get("transform_after_hits", 0)) > 0 and float(stats.get("transform_duration", 0.0)) > 0.0:
			return true
		if lifecycle[0] == "revert" and (int(stats.get("revert_after_hits", 0)) > 0 or float(stats.get("form_lifetime", 0.0)) > 0.0) and float(stats.get("revert_duration", 0.0)) > 0.0:
			return true
	for skill in stats.get("active_skills", []):
		var kind := String(skill.get("kind", ""))
		if kind in ["dual_form", "timed_form"] and lifecycle.size() == 2 and lifecycle[0] == "transform_active" and lifecycle[1] in ["start", "end", "sustain", "hit"]:
			return float(stats.get("active_transform_duration", stats.get("transform_duration", 0.0))) > 0.0
		if cue in ["empowered_ready", "empowered_swing"] and kind in ["empowered_attack", "bleeding_execute"]:
			return true
		if cue in ["active_buff:start", "active_buff:end", "active_buff:sustain"] and kind == "buff":
			return float(skill.get("duration", 0.0)) > 0.0
		var actions: Array = [String(skill.get("visual_action", "")), String(skill.get("full_resource_visual_action", ""))]
		actions.append_array(skill.get("resource_visual_actions", []))
		var parts := cue.split(":")
		if parts.size() != 2 or parts[0].is_empty() or parts[0] not in actions:
			continue
		if parts[1] in ["start", "end", "sustain", "voice"]:
			return float(skill.get("cast_duration", 0.0)) > 0.0
		if parts[1] == "impact":
			return kind == "forward_area"
		if parts[1] == "wave_hit":
			return kind == "forward_area" and float(skill.get("shockwave_duration", 0.0)) > 0.0
		if parts[1] == "release":
			return kind == "frontal"
		if parts[1] in ["zone_sustain", "zone_end"]:
			return kind == "forward_area" and float(skill.get("zone_duration", 0.0)) > 0.0
		if parts[1] in ["hit_first", "hit_middle", "hit_last", "hit_first_center", "hit_middle_center", "hit_last_center"]:
			return kind == "frontal" and not skill.get("resource_hit_damage_sequences", []).is_empty()
		if parts[1] == "hit_center":
			return kind == "frontal" and (float(skill.get("center_ratio", 0.0)) > 0.0 or float(skill.get("center_width", 0.0)) > 0.0)
		if parts[1] == "hit":
			return kind in ["dash_strike", "frontal", "continuous_area", "nova", "dual_form"] or (kind == "forward_area" and float(skill.get("zone_duration", 0.0)) > 0.0)
	return false
