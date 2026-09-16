extends SceneTree
## 正式出牌入口的双阵营冲撞/控制恢复/技能/死亡实机录音与截图配方。
var output := preload("res://tools/lib/development_paths.gd").output("structure-rush")
var main: Node2D
var reviewed_source: Unit
func _initialize() -> void:
	_run.call_deferred()
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/" + label + ".png")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_local()
	main._audio_manager.cue_played.connect(func(id: String, cue: StringName, _position: Vector2):
		if id in ["rift_herald", "voidmite"] and is_instance_valid(reviewed_source):
			print("AUDIO team=", reviewed_source.team, " card=", id, " cue=", cue, " action_elapsed=", reviewed_source.get_visual_action_duration() - reviewed_source.get_visual_action_time_left()))
	main._minion_waves_enabled = false
	main._ai.enabled = false
	for tower in main._towers: tower.can_attack = false
	for attempt in 100:
		if main._match_started: break
		await create_timer(0.1).timeout
	var record := AudioEffectRecord.new()
	var record_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	for team in [0, 1]:
		var origin := Vector2(360, 520 if team == 0 else 760)
		var forward := Vector2.UP if team == 0 else Vector2.DOWN
		main.play_card(1-team, "tombstone", origin + forward * 220, {"immediate": true, "validate_position": false})
		var building: Unit = main._latest_unit_for_card("tombstone", 1-team)
		building.hp = 10000; building.max_hp = 10000; building.lifespan = 0; building.spawn_interval = 0; building.spawn_count = 0
		for side in [-1, 1]:
			main.play_card(1-team, "melee_minion", origin + forward * 140 + Vector2(side * 20, 0), {"immediate": true, "validate_position": false})
			var enemy: Unit = main._latest_unit_for_card("melee_minion", 1-team)
			enemy.damage = 0; enemy.move_speed = 0
		main.play_card(team, "rift_herald", origin, {"immediate": true, "validate_position": false})
		var source: Unit = main._latest_unit_for_card("rift_herald", team)
		reviewed_source = source
		await create_timer(0.65).timeout
		await shot("team%d_deploy" % team)
		var previous := -1
		var frozen := false
		var knocked := false
		var stunned := false
		var elapsed := 0.0
		while elapsed < 18.0:
			await process_frame
			elapsed += root.get_process_delta_time()
			var phase := source.structure_rush.phase
			if phase != previous:
				print("RUSH team=", team, " phase=", phase, " pos=", source.position, " hp=", source.hp)
				previous = phase
				await shot("team%d_phase%d" % [team, phase])
				if phase == StructureRushState.Phase.RECOVERY:
					await create_timer(0.12).timeout
					await shot("team%d_burst012" % team)
					await create_timer(0.18).timeout
					await shot("team%d_burst030" % team)
					await create_timer(0.15).timeout
					await shot("team%d_burst045" % team)
			if phase == StructureRushState.Phase.PREPARING and not frozen and source.structure_rush.remaining < 0.9:
				source.freeze(0.5)
				frozen = true
				await shot("team%d_frozen" % team)
			elif phase == StructureRushState.Phase.PREPARING and frozen and not knocked and source.structure_rush.remaining < 1.9:
				source.apply_knockback(source.position + forward, 40, 0.2)
				knocked = true
				await shot("team%d_knocked" % team)
			elif phase == StructureRushState.Phase.PREPARING and knocked and not stunned and source.structure_rush.remaining < 1.9:
				source.stun(0.4)
				stunned = true
				await shot("team%d_stunned" % team)
			if phase == StructureRushState.Phase.SPENT: break
		await create_timer(0.3).timeout
		await shot("team%d_mites" % team)
		main.preview_active_skill(source, CardDB.active_skills_for("rift_herald")[0])
		await create_timer(1.60).timeout
		await shot("team%d_skill" % team)
		await create_timer(1.6).timeout
		for c in get_nodes_in_group("combatants"):
			if c is Unit and c.card_id == "voidmite": c.take_damage(100000)
		await create_timer(0.45).timeout
		await shot("team%d_mite_death" % team)
		source.take_damage(100000)
		await create_timer(0.3).timeout
		await shot("team%d_death" % team)
		await create_timer(1.5).timeout
		main._clear_art_dev_units()
		await process_frame
	record.set_recording_active(false)
	var wav := record.get_recording()
	if wav != null: wav.save_to_wav(output + "/battle_mix.wav")
	AudioServer.remove_bus_effect(0, record_index)
	print("REVIEW_OUTPUT=", output)
	main.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	quit()
