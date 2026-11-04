extends SceneTree
## 正式工作台入口的双阵营连续攻击、移动换弹、技能、控制与死亡渲染/混音。
var main: Node2D
var output := ProjectSettings.globalize_path("res://ClashLegends-开发素材库/04-中间产物/法外狂徒/验收2")
func _initialize() -> void: _run.call_deferred()
func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("graves")
	panel.show_workspace(1)
	panel._set_battle_zoom(1.15)
	main.set_process(false)
	main.set_physics_process(false)
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id == "graves":
			print("[Graves cue] ", main.runtime._sim_tick_id, " ", cue)
			if cue == "attack_launch":
				for unit in get_nodes_in_group("combatants"):
					if unit is Unit and unit.card_id == "graves" and unit.has_meta("projectile_model_anchor"):
						var anchor = unit.get_meta("projectile_model_anchor").get_ref()
						if is_instance_valid(anchor): print("[Muzzle] team=",unit.team," authoritative=",unit.position," bone=",anchor.global_position," attack_elapsed=",unit.get_attack_elapsed_visual()))
	var units: Array[Unit] = []
	var targets: Array[Unit] = []
	for team in [0, 1]:
		var pos := Vector2(180 + 360 * team, 800)
		main.play_card(team, "graves", pos, {"immediate": true, "validate_position": false})
		for unit in get_nodes_in_group("combatants"):
			if unit is Unit and unit.card_id == "graves" and unit.team == team:
				units.append(unit)
				unit.configure_carried_active_skill(CardDB.active_skills_for("graves")[0])
				unit.max_hp = 10000
				unit.hp = 10000
		var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1-team, "target_dummy", pos + Vector2(0, -115 if team == 0 else 115), {"deploy_time_override": 0.0}))
		target.max_hp = 10000
		target.hp = 10000
		targets.append(target)
	for pair in [["sett", Vector2(290, 1050)], ["graves", Vector2(420, 1050)]]:
		main.play_card(0, pair[0], pair[1], {"immediate": true, "validate_position": false})
	for unit in get_nodes_in_group("combatants"):
		if unit is Unit and unit.position.y > 1000: unit.can_attack = false; unit.move_speed = 0.0
	for tick in 220:
		if tick == 105:
			for i in units.size():
				targets[i].position = units[i].position + Vector2(0, -350 if i == 0 else 350)
		if tick == 130:
			for unit in units: print("[Graves dash] ", main.preview_active_skill(unit, CardDB.active_skills_for("graves")[0]))
		if tick == 145:
			for i in units.size():
				targets[i].free()
				targets[i] = main._spawn_unit(UnitSpawnRequest.new(1-i, "anivia", units[i].position + Vector2(105 if i == 0 else -105, 0), {"deploy_time_override": 0.0}))
				targets[i].can_attack = false
				targets[i].move_speed = 0.0
				targets[i].hp = 10000
		if tick == 165: units[0].freeze(0.6)
		if tick == 195:
			for unit in units: unit.take_damage(99999.0)
		main._sim_step(0.05)
		await create_timer(0.05).timeout
		if tick in [22, 40, 115, 132, 152, 160, 201]: await _capture("battle_%03d" % tick)
		if tick in [30, 33, 36, 61, 115, 132]:
			for unit in units:
				print("[Graves state] ",tick," team=",unit.team," ammo=",unit.magazine.snapshot()," pos=",unit.position," attack=",unit.get_attack_elapsed_visual())
	record.set_recording_active(false)
	var recording := record.get_recording()
	if recording != null: recording.save_to_wav(output.path_join("runtime.wav"))
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0)-1)
	main._clear_art_dev_units()
	panel.show_workspace(2)
	await create_timer(0.3).timeout
	await _capture("card_info")
	main.queue_free()
	await process_frame
	quit()
