extends RefCounted
## 真正三进程：主机施放，双客户端只由快照恢复R窗口与表现音轨。
var started := false
var cast := false
var hooked := false
var sources: Array[Unit] = []
var active_teams := {}
var expired_teams := {}
var attack_teams := {}
var cues := {}
var authority_ok := true

func poll(main: Node2D) -> void:
	if not hooked and main._audio_manager != null:
		hooked = true
		main._audio_manager.cue_played.connect(func(card: String, cue: StringName, _pos: Vector2):
			if card == "olaf_single" and String(cue).begins_with("control_immunity:"): cues[cue] = true)
	if main.runtime.mode == "server" and main.runtime._match_started:
		if main.runtime._sim_tick_id >= 12 and not started:
			started = true
			for team in [0, 1]:
				var point := Vector2(70 if team == 0 else 650, 1050 if team == 0 else 230)
				var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(team, "olaf_single", point, {"deploy_time_override": 0.0}))
				unit.freeze(10.0)
				sources.append(unit)
				var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1-team, "target_dummy", point + Vector2(0, -55 if team == 0 else 55), {"deploy_time_override": 0.0}))
				target.hp = 10000
				target.max_hp = 10000
		if main.runtime._sim_tick_id >= 20 and not cast:
			cast = true
			for unit in sources:
				authority_ok = main.preview_active_skill(unit, CardDB.active_skills_for("olaf_single")[1]) and authority_ok
				unit.stun(2.0)
				for source_team in [unit.team, 1 - unit.team]:
					unit.apply_stasis(2.0, &"network_stasis", CombatInteraction.effect_context(null, source_team))
				authority_ok = authority_ok and not unit.is_frozen() and not unit.is_stunned() and not CombatInteraction.in_stasis(unit)
	var units: Array = main.world.replica_units_snapshot().values() if main.runtime.mode == "client" else main.world.authoritative_units_snapshot().values()
	for unit in units:
		if not is_instance_valid(unit) or unit.card_id != "olaf_single": continue
		var clock: Vector2 = unit.control_immunity_clock_visual()
		if clock.y > clock.x:
			active_teams[unit.team] = true
			if unit.get_attack_visual_serial() > 0: attack_teams[unit.team] = true
		elif active_teams.has(unit.team): expired_teams[unit.team] = true
		if main.runtime.mode == "client": authority_ok = authority_ok and unit.buffs.remaining(&"control_immunity") == 0.0

func result(is_server: bool) -> Dictionary:
	var audio_ok := is_server or (cues.has(&"control_immunity:start") and cues.has(&"control_immunity:sustain") and cues.has(&"control_immunity:attack_swing") and cues.has(&"control_immunity:attack_hit"))
	return {"passed": authority_ok and active_teams.size() == 2 and expired_teams.size() == 2 and attack_teams.size() == 2 and audio_ok,
		"active_teams": active_teams.size(), "expired_teams": expired_teams.size(), "attack_teams": attack_teams.size(), "authority_ok": authority_ok, "audio_ok": audio_ok, "cues": cues.keys()}
