extends SceneTree
## Isolated production-mechanism film fixtures. Never loaded by the game.
## Godot --path . --fixed-fps 60 --write-movie <new.avi> --script tools/capture/capture_control_scenes.gd -- --shot=attack_freeze --out=<directory>
## Normal speed, 20 Hz Main clock, engine render/audio only. No microphone.
const FPS := 60
const FRAMES := 720
var main: Node2D
var subject: Unit
var target: Unit
var shot := "attack_freeze"
var output := ""
var frame := -1
var control_frame := -1
var trace: FileAccess
var applied := false
var projectile_id := -1
var fishes: Array[Unit] = []
var tower: Tower
var outer_archer: Unit
var inner_archer: Unit
var herald_spell_center := Vector2(420, 500)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): shot = arg.trim_prefix("--shot=")
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	_run.call_deferred()

func _run() -> void:
	if output.is_empty():
		push_error("An explicit, new promo output directory is required.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	trace = FileAccess.open(output.path_join(shot + "_trace.jsonl"), FileAccess.WRITE)
	seed(60104)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._deck = ["garen", "gnar", "target_dummy", "ashe", "belveth", "freeze", "stasis", "zap"]
	main._start_local()
	seed(60104)
	main.set_process(false)
	main._ai.enabled = false
	main._minion_waves_enabled = false
	# Preview fixture: neutral arena structures do not interfere with the subject.
	for actor in main._towers + [main._king_player, main._king_enemy]: actor.can_attack = false
	for child in main.get_children():
		if child is CanvasLayer: child.hide()
	main._audio_manager.cue_played.connect(func(id, cue, pos): _event("audio", {"card": id, "cue": cue, "pos": [pos.x, pos.y]}))
	_setup()
	await process_frame
	_event("capture_start", {"engine_frame": Engine.get_frames_drawn(), "shot": shot, "fps": FPS, "seed": 60104})
	for index in FRAMES:
		frame = index
		_actions()
		main._process(1.0 / FPS)
		await process_frame
		if frame % 3 == 0: _sample()
		# Movie mode normally forces this; explicit drawing also handles background windows.
		RenderingServer.force_draw(false)
	_event("capture_end", {"ticks": main._sim_tick_id, "control_frame": control_frame})
	trace.close()
	main.queue_free()
	await process_frame
	quit()

func _play(id: String, team: int, pos: Vector2) -> Unit:
	var ok: bool = main.play_card(team, id, pos, {"immediate": true, "validate_position": false})
	_event("play_card", {"card": id, "team": team, "accepted": ok})
	return main._latest_unit_for_card(id, team)

func _setup() -> void:
	if shot.begins_with("attack_") or shot == "judgment":
		# Ordinary building target, original health, damage and timings.
		_play("target_dummy", 1, Vector2(360, 400))
		subject = _play("garen", 0, Vector2(360, 510))
	elif shot == "projectile":
		_play("target_dummy", 1, Vector2(360, 400))
		subject = _play("ashe", 0, Vector2(360, 550))
	elif shot.begins_with("scatter_"):
		subject = _play("belveth", 0, Vector2(360, 840))
	elif shot == "transform":
		_play("target_dummy", 1, Vector2(360, 400))
		subject = _play("gnar", 0, Vector2(360, 540))
	elif shot == "tower":
		tower = main._towers[0]
		subject = _play("garen", 1, tower.position + Vector2(0, -110))
		# Arrange a stage threshold; production damage crosses it during recording.
		tower.hp = tower.max_hp * 2.0 / 3.0 + 88.0
	elif shot in ["mist", "mist_baseline"]:
		var red_dummy := _play("target_dummy", 1, Vector2(360, 400))
		red_dummy.set_meta("film_role", "red_dummy")
		var decoy := _play("target_dummy", 0, Vector2(520, 720))
		decoy.set_meta("film_role", "blue_decoy")
		subject = _play("gwen", 0, Vector2(360, 510))
		subject.set_meta("film_role", "gwen")
		outer_archer = _play("ashe", 1, Vector2(550, 500))
		outer_archer.set_meta("film_role", "outer_archer")
	elif shot in ["knockback", "knockback_baseline"]:
		var left_dummy := _play("target_dummy", 1, Vector2(280, 400))
		left_dummy.set_meta("film_role", "left_target")
		var right_dummy := _play("target_dummy", 1, Vector2(440, 400))
		right_dummy.set_meta("film_role", "right_target")
		subject = _play("sett", 0, Vector2(300, 500))
		subject.set_meta("film_role", "sett")
	elif shot.begins_with("herald_"):
		var building := _play("target_dummy", 1, Vector2(360, 300))
		building.set_meta("film_role", "rush_target")
		subject = _play("rift_herald", 0, Vector2(360, 540))
		subject.set_meta("film_role", "herald")
		var witness := _play("ashe", 0, Vector2(480, 500))
		witness.set_meta("film_role", "control_witness")
	else:
		push_error("Unknown shot: " + shot)
		quit(2)

func _actions() -> void:
	if not is_instance_valid(target): target = main._latest_unit_for_card("target_dummy", 1)
	if shot.begins_with("attack_"):
		# Match the same ordinary Garen windup in all three films.
		if frame >= 210 and not applied and subject.get_attack_elapsed_visual() >= 0.15 and subject.get_attack_elapsed_visual() <= 0.30:
			_control(subject, shot.trim_prefix("attack_"))
	elif shot == "judgment":
		if frame == 180:
			_event("judgment_start", {"accepted": main.preview_active_skill(subject, CardDB.active_skills_for("garen")[1])})
		if frame == 255:
			# Actual stasis spell, with its normal travel, impact VFX and audio.
			_event("stasis_cast", {"accepted": main.play_card(0, "stasis", subject.position, {"immediate": true, "validate_position": false})})
	elif shot == "projectile":
		if frame >= 200 and not applied:
			for id in main._projectile_system.projectiles:
				var p: Dictionary = main._projectile_system.projectiles[id]
				if p.get("attacker") == subject and p.get("target") == target and (p.pos as Vector2).distance_to(subject.position) > 55:
					projectile_id = id
					_event("projectile_before", {"id": id, "hp": target.hp, "pos": [p.pos.x,p.pos.y]})
					_control(target, "stasis")
					_event("projectile_invalidated", {"id": id, "still_present": main._projectile_system.projectiles.has(id), "hp": target.hp})
					break
	elif shot.begins_with("scatter_"):
		if frame == 210:
			_event("belveth_death", {"pos": [subject.position.x, subject.position.y]})
			subject.take_damage(subject.hp + 1.0)
		if frame == 219:
			for actor in get_nodes_in_group("combatants"):
				if actor is Unit and actor.card_id == "voidfish": fishes.append(actor)
			_event("fish_before", {"count": fishes.size()})
			for fish in fishes: _control(fish, shot.trim_prefix("scatter_"))
	elif shot == "transform":
		if frame == 180:
			_event("transform_start", {"accepted": main.preview_active_skill(subject, CardDB.active_skills_for("gnar")[0]), "form": subject.form_index})
		if frame == 204: _control(subject, "stasis")
	elif shot == "tower":
		if not applied and tower.hp < tower.max_hp * 2.0 / 3.0:
			_control(tower, "stasis")
			_event("tower_stage", {"hp": tower.hp})
	elif shot in ["mist", "mist_baseline"]:
		if frame == 180:
			if shot == "mist":
				_event("mist_start", {"accepted": main.preview_active_skill(subject, CardDB.active_skills_for("gwen")[1])})
			else:
				_event("comparison_marker", {"protection": false})
		if frame == 270 and is_instance_valid(subject):
			inner_archer = _play("ashe", 1, subject.position + Vector2(70, 0))
			inner_archer.set_meta("film_role", "inner_archer")
			_event("inner_archer_spawn", {"pos": [inner_archer.position.x, inner_archer.position.y]})
	elif shot in ["knockback", "knockback_baseline"]:
		if frame == 180:
			_event("skill_start", {"accepted": main.preview_active_skill(subject, CardDB.active_skills_for("sett")[0]), "pos": [subject.position.x, subject.position.y], "serial": subject.active_skill_cast_serial, "forward": [subject.active_skill_cast_facing.x, subject.active_skill_cast_facing.y]})
		if frame == 192 and shot == "knockback":
			_event("knockback_before", {"pos": [subject.position.x, subject.position.y], "serial": subject.active_skill_cast_serial})
			subject.apply_knockback(subject.position - Vector2(60, 0), 240.0, 0.4)
			_event("knockback_after", {"action_left": subject.get_visual_action_time_left(), "serial": subject.active_skill_cast_serial, "remaining": subject.knockback.remaining})
	elif shot.begins_with("herald_") and not applied:
		# Time only the real spell launch. Deployment, preparation, dash and impact remain autonomous.
		var spell_team := 1 if shot == "herald_enemy_stasis" else 0
		var origin: Vector2 = main._king_enemy.position if spell_team == 1 else main._king_player.position
		var stats := CardDB.get_card("stasis")
		var flight_time := ceilf(maxf(float(stats.flight_min_duration), origin.distance_to(herald_spell_center) / float(stats.flight_speed)) / FixedStepClock.STEP - 0.00000001) * FixedStepClock.STEP
		if subject.structure_rush.phase == StructureRushState.Phase.PREPARING and subject.structure_rush.remaining <= flight_time - 0.15 + 0.000001:
			var accepted: bool = main.play_card(spell_team, "stasis", herald_spell_center, {"immediate": true, "validate_position": false})
			_event("herald_stasis_cast", {"accepted": accepted, "team": spell_team, "pos": [herald_spell_center.x, herald_spell_center.y], "flight_time": flight_time, "prepare_remaining": subject.structure_rush.remaining})
			applied = true

func _control(actor: Node2D, kind: String) -> void:
	_event("control_before", {"kind": kind, "id": actor.get_instance_id(), "pos": [actor.position.x, actor.position.y]})
	match kind:
		"stun": actor.stun(3.0)
		"freeze": actor.freeze(3.0)
		"stasis": actor.apply_stasis(3.0)
	applied = true
	control_frame = frame
	_event("control_after", {"kind": kind, "id": actor.get_instance_id(), "pos": [actor.position.x, actor.position.y]})

func _sample() -> void:
	var actors := []
	for actor in get_nodes_in_group("combatants"):
		if not actor is Unit and actor != tower: continue
		var data := {"id": actor.get_instance_id(), "pos": [actor.position.x, actor.position.y], "hp": actor.hp, "stasis": actor.control.stasis_timer, "freeze": actor.control.frozen_timer, "stun": actor.control.stun_timer}
		if actor is Unit:
			data.merge({"card": actor.card_id, "form": actor.form_index, "action": actor.get_visual_action_name(), "action_left": actor.get_visual_action_time_left(), "attack_serial": actor.get_attack_visual_serial(), "attack_elapsed": actor.get_attack_elapsed_visual(), "external_motion": actor.knockback.collisionless})
			if shot.begins_with("herald_"):
				data.merge({"role": actor.get_meta("film_role", ""), "team": actor.team, "body_radius": actor.body_radius, "rush_phase": actor.structure_rush.phase, "rush_remaining": actor.structure_rush.remaining, "rush_immune": actor.structure_rush.control_immune(), "spell_distance": actor.position.distance_to(herald_spell_center)})
			if shot in ["mist", "mist_baseline", "knockback", "knockback_baseline"]:
				data.merge({"role": actor.get_meta("film_role", ""), "target_id": actor._target.get_instance_id() if is_instance_valid(actor._target) else -1, "target_role": actor._target.get_meta("film_role", "structure") if is_instance_valid(actor._target) else "", "protection_left": actor.target_protection.remaining(), "knockback_left": actor.knockback.remaining, "cast_serial": actor.active_skill_cast_serial, "cancelled_cast": actor.cancelled_skill_cast_serial, "forward": [actor.active_skill_cast_facing.x, actor.active_skill_cast_facing.y]})
				if is_instance_valid(subject) and subject.card_id == "gwen":
					data["allows_hit_gwen"] = CombatInteraction.allows(subject, actor)
					data["inside_mist"] = subject.target_protection.contains(actor.position)
		for view in main._battle_presentation._world_root.get_children():
			if (view is UnitModel3D or view is TowerModel3D) and view._source == actor and is_instance_valid(view._animation_player):
				data["animation"] = view._animation_player.current_animation
				data["animation_position"] = view._animation_player.current_animation_position if not view._animation_player.current_animation.is_empty() else 0.0
				data["animation_speed"] = view._animation_player.get_playing_speed()
				if view is TowerModel3D:
					data["debris"] = []
					for debris in view._debris_layers:
						data.debris.append({"surface": debris.surface, "remaining": debris.remaining, "animation_position": debris.player.current_animation_position})
		actors.append(data)
	_event("sample", {"actors": actors, "projectile_ids": main._projectile_system.projectiles.keys(), "sustain_keys": main._audio_manager._sustain_players.keys()})

func _event(kind: String, data: Dictionary = {}) -> void:
	if trace == null: return
	data.merge({"event": kind, "frame": frame, "t": float(frame) / FPS})
	trace.store_line(JSON.stringify(data))
