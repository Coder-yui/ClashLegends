extends SceneTree
## 实际渲染与混音审查。截图/录音只供人工复核，不自动声明听感通过。
var OUTPUT := preload("res://tools/lib/development_paths.gd").output("clash-combat-terminal")
func _initialize() -> void: _run.call_deferred()
func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png"))
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_local()
	main.set_process(false)
	main._ai.enabled = false
	main._minion_waves_enabled = false
	for tower in main._towers: tower.can_attack = false
	var a: Unit = main._spawn_unit(0, "masteryi", Vector2(180, 760), 0)
	var b: Unit = main._spawn_unit(1, "masteryi", Vector2(180, 725), 0)
	a.hp = a.damage
	b.hp = b.damage
	for tick in 12:
		main._sim_step(0.05)
		if a.hp <= 0 or b.hp <= 0:
			print("[render mirror] tick=", main._sim_tick_id, " hp=", a.hp, "/", b.hp)
			await _capture("mirror-death")
			break
		await create_timer(0.05).timeout
	await create_timer(1.0).timeout
	var yi: Unit = main._spawn_unit(0, "masteryi", Vector2(180, 760), 0)
	var target: Unit = main._spawn_unit(1, "garen", Vector2(180, 715), 0)
	target.max_hp = 100000
	target.hp = target.max_hp
	target.freeze(100)
	var last := 0
	for tick in 200:
		main._sim_step(0.05)
		if yi._attack_hit_index != last:
			last = yi._attack_hit_index
			if last % 3 == 0:
				print("[render combo] tick=", main._sim_tick_id, " main_attack=", last, " extras=", yi._pending_extra_attacks.size())
				await _capture("combo-" + str(last))
		if last == 9 and yi._pending_extra_attacks.is_empty(): break
		await create_timer(0.05).timeout
	yi.queue_free()
	target.queue_free()
	await process_frame
	var recorder := AudioEffectRecord.new()
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, recorder)
	recorder.set_recording_active(true)
	var started := Time.get_ticks_msec()
	main._audio_manager.cue_played.connect(func(card, cue, _position):
		if card == "match" or String(card).begins_with("world_nexus"):
			print("[terminal audio] ms=", Time.get_ticks_msec() - started, " ", card, " ", cue))
	main._king_enemy.take_damage(main._king_enemy.hp + 1)
	main._sim_step(0.05)
	await _capture("terminal-immediate")
	var deadline := Time.get_ticks_msec() + 30000
	while main._audio_manager._terminal_audio_pending and Time.get_ticks_msec() < deadline:
		await process_frame
	while main._audio_manager._announcer.playing and Time.get_ticks_msec() < deadline:
		await process_frame
	await _capture("terminal-finished")
	recorder.set_recording_active(false)
	var wav := recorder.get_recording()
	if wav != null: wav.save_to_wav(OUTPUT.path_join("explosion-victory.wav"))
	AudioServer.remove_bus_effect(0, slot)
	main.free()
	await create_timer(0.25).timeout
	quit()
