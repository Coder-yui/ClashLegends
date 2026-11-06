extends RefCounted
var placed := false
var started := false
var cast := false
var stopped := false
var source: Unit
var healing_seen := false
var activations := 0
var previous_active := false
var activation_ticks: Array[int] = []
var wave_views_seen := 0
var early_healing := false
var wave_level := true
var expired_seen := false
var heal_seen := false
var stun_seen := false
var bolt_seen := false
var wave_seen := false
var hooked := false
var is_server := false
var cues := {}
var client_readonly := true
var sustain_stopped := false
func poll(main: Node2D) -> void:
	is_server = main.runtime.mode == "server"
	if not placed and not is_server and main.runtime.local_team >= 0 and DisplayServer.get_name() != "headless":
		# 两端并排可见，避免完全遮挡影响资源预绘等待。
		placed = true
		main.get_window().always_on_top = true
		main.get_window().size = Vector2i(450, 800)
		main.get_window().position = Vector2i(20 + 460 * main.runtime.local_team, 40)
	if not hooked and main._audio_manager != null:
		hooked = true
		main._audio_manager.cue_played.connect(func(card, cue, _pos):
			if card == "sona": cues[String(cue)] = int(cues.get(String(cue), 0)) + 1)
	if main.runtime.mode == "server" and main.runtime._match_started:
		if main.runtime._sim_tick_id >= 12 and not started:
			started = true
			source = main._spawn_unit(UnitSpawnRequest.new(0, "sona", Vector2(90, 1000), {"deploy_time_override": 0.0}))
			source.move_speed = 0.0
			source.hp = 200
			var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1, "target_dummy", Vector2(90, 870), {"deploy_time_override": 0.0}))
			target.hp = 10000
			target.max_hp = 10000
		if is_instance_valid(source) and main.runtime._sim_tick_id >= 130 and not cast:
			cast = true
			main.preview_active_skill(source, CardDB.active_skills_for("sona")[0])
		if is_instance_valid(source) and main.runtime._sim_tick_id >= 90 and not stopped:
			stopped = true
			source.can_attack = false
			source.cancel_basic_attack(ActionCancellation.STUN)
	var units: Array = main.world.replica_units_snapshot().values() if main.runtime.mode == "client" else main.world.authoritative_units_snapshot().values()
	for unit in units:
		if not is_instance_valid(unit): continue
		if unit.card_id == "sona":
			var state: Vector2 = unit.heal_aura_state_visual()
			var active_now := state.y > 0.0
			if active_now and not previous_active:
				activations += 1
				activation_ticks.append(main.get_authoritative_server_tick())
			previous_active = active_now
			if main.get_authoritative_server_tick() < 52 and active_now: early_healing = true
			if not is_server:
				client_readonly = client_readonly and unit.heal_aura.remaining == 0.0
				if expired_seen and main._audio_manager != null:
					var active := false
					for key in main._audio_manager._sustain_players:
						if String(key).ends_with(":heal_aura"): active = true
					sustain_stopped = sustain_stopped or not active
			healing_seen = healing_seen or state.y > 0.0
			expired_seen = expired_seen or (healing_seen and state.y == 0.0)
			heal_seen = heal_seen or unit.hp > 200.0
		if unit.card_id == "target_dummy" and unit.team == 1: stun_seen = stun_seen or unit.is_stunned()
	for shot in main._projectile_system.visible_view().values():
		bolt_seen = bolt_seen or String(shot.get("visual", "")) == "sona_bolt"
		wave_seen = wave_seen or String(shot.get("visual", "")) == "sona_wave"
	if main._battle_presentation != null and main._battle_presentation._sona_projectiles != null:
		for view in main._battle_presentation._sona_projectiles._missiles.values():
			if view.get("wave", false):
				wave_views_seen += 1
				wave_level = wave_level and (view.basis as Basis).z.is_equal_approx(Vector3.UP) and is_equal_approx(view.launch.y, view.target.y)
func result() -> Dictionary:
	var render_ok := is_server or DisplayServer.get_name() == "headless" or wave_views_seen > 0
	var audio_ok := is_server or (["attack_swing", "attack_launch", "attack_hit", "heal_aura:start", "heal_aura:sustain", "crescendo:sustain", "crescendo:release", "crescendo:hit"].all(func(cue): return cues.has(cue)) and sustain_stopped and int(cues.get("heal_aura:start", 0)) >= 2)
	return {"passed": activations >= 2 and render_ok and not early_healing and wave_level and healing_seen and expired_seen and heal_seen and stun_seen and bolt_seen and wave_seen and client_readonly and audio_ok,
		"activations": activations, "activation_ticks": activation_ticks, "wave_views_seen": wave_views_seen, "render_ok": render_ok, "early_healing": early_healing, "wave_level": wave_level, "audio_ok": audio_ok, "cues": cues.keys(), "cue_counts": cues, "client_readonly": client_readonly, "sustain_stopped": sustain_stopped,
		"healing_seen": healing_seen, "expired_seen": expired_seen, "heal_seen": heal_seen, "stun_seen": stun_seen, "bolt_seen": bolt_seen, "wave_seen": wave_seen}
