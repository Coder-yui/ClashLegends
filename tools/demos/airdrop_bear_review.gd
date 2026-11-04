extends SceneTree
## 正式工作台、真实play_card入口、双方落地/常驻/控制/死亡与卡面检查。
var main: Node2D
var bears: Array[Unit] = []
var animation_review := "--animation-audio-review" in OS.get_cmdline_user_args()
var last_animation := {}
var animation_frames: Array[Dictionary] = []
var range_review := "--range-review" in OS.get_cmdline_user_args()
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("airdrop_bear")
	panel.show_workspace(1)
	main._clear_art_dev_units()
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	panel._set_battle_zoom(1.0)
	for tower in main.world.towers_snapshot(): tower.can_attack = false
	if range_review: add_range_rings()
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id in ["airdrop_bear", "tibbers"]: print("[空投熊音频] tick=", main.get_authoritative_server_tick(), " ", id, " ", cue))
	for team in [0, 1]:
		var pos := Vector2(180 + 360 * team, 820 if team == 0 else 460)
		var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1-team, "target_dummy", pos + Vector2(110 if animation_review else 70, 0), {"deploy_time_override": 0.0}))
		target.can_attack = false
		if animation_review:
			target.max_hp = 100000.0
			target.hp = target.max_hp
		var reference: Unit = main._spawn_unit(UnitSpawnRequest.new(team, "garen", pos + Vector2(-95, 0), {"deploy_time_override": 0.0}))
		reference.can_attack = false
		reference.root(30.0)
	var loop_review := "--vfx-loop" in OS.get_cmdline_user_args()
	for tick in (480 if loop_review else (230 if animation_review else 190)):
		if tick == 5:
			for team in [0, 1]: main.play_card(team, "airdrop_bear", Vector2(180 + 360 * team, 820 if team == 0 else 460), {"immediate": true, "preview_active_spell": not animation_review or team == 1})
		if range_review:
			for unit in get_nodes_in_group("combatants"):
				if unit is Unit and unit.card_id == "tibbers":
					unit.can_attack = false
					unit.root(30.0)
		if animation_review and tick in [110, 130, 180]:
			for unit in get_nodes_in_group("combatants"):
				if not unit is Unit or unit.card_id != "tibbers": continue
				if tick == 110: unit.freeze(0.5)
				if tick == 130: unit.stun(0.5)
				if tick == 180:
					unit.can_attack = false
					unit.root(2.0)
		if tick == 85:
			for unit in get_nodes_in_group("combatants"):
				if unit is Unit and unit.card_id == "tibbers": unit.apply_stasis(1.0)
		if loop_review and tick == 200: await capture_seam()
		if tick == (450 if loop_review else (205 if animation_review else 165)):
			for unit in get_nodes_in_group("combatants"):
				if unit is Unit and unit.card_id == "tibbers": unit.take_damage(10000)
		main._sim_step(0.05)
		main._spell_system.tick_visuals(0.05)
		await create_timer(0.05).timeout
		if animation_review: trace_animations(tick)
		if tick in [6, 10, 24, 25, 29, 33, 34, 35, 36, 38, 40, 45, 55, 84, 90, 110, 145, 155, 165, 166, 175, 180, 190, 200, 206, 220, 240, 300, 400, 451, 470]: await capture("battle-%03d" % tick)
	record.set_recording_active(false)
	record.get_recording().save_to_wav(preload("res://tools/lib/development_paths.gd").output("airdrop-bear-runtime.wav"))
	panel.show_workspace(2)
	await create_timer(0.2).timeout
	await capture("card-info")
	panel._select_item("tibbers")
	await create_timer(0.2).timeout
	await capture("tibbers-info")
	record.set_recording_active(false)
	record.get_recording().save_to_wav(preload("res://tools/lib/development_paths.gd").output("airdrop-bear-runtime.wav"))
	if loop_review:
		print("[火圈清理] ", main._battle_presentation._bear_effect._auras.size())
	if animation_review:
		var trace := FileAccess.open(preload("res://tools/lib/development_paths.gd").output("animation-trace.json"), FileAccess.WRITE)
		trace.store_string(JSON.stringify(animation_frames, "  "))
	main.queue_free()
	await process_frame
	quit()
func capture(label: String) -> void:
	for frame in 3: await process_frame
	RenderingServer.force_draw()
	var path := preload("res://tools/lib/development_paths.gd").output("airdrop-bear-" + label + ".png")
	root.get_texture().get_image().save_png(path)
	print("[空投熊截图] ", path)

func capture_seam() -> void:
	var presentation: Node = main._battle_presentation
	presentation.process_mode = Node.PROCESS_MODE_DISABLED
	var players: Array = []
	for state in presentation._bear_effect._auras.values(): players.append(state.player)
	var attachments := 0
	for model in presentation._world_root.find_children("TibbersView", "Node3D", true, false):
		attachments += model._fire.size()
		for entry in model._fire: players.append(entry.player)
	print("[燃烧挂点] ", attachments, "；含地面播放器 ", players.size())
	var saved: Array = []
	for player in players: saved.append(player._age)
	for frame in 37:
		for player in players: player.seek(9.7 + float(frame) / 60.0)
		await capture("seam-%03d" % frame)
	for index in players.size(): players[index].seek(saved[index])
	presentation.process_mode = Node.PROCESS_MODE_INHERIT

func add_range_rings() -> void:
	var presentation: Node = main._battle_presentation
	var projection = preload("res://scripts/presentation/spell_effect_projection.gd")
	var radius := float(CardDB.get_card("airdrop_bear").radius)
	for team in [0, 1]:
		var center := Vector2(180 + 360 * team, 820 if team == 0 else 460)
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for i in 128:
			for j in [i, i+1]:
				var point := center + Vector2.from_angle(TAU * j / 128.0) * radius
				mesh.surface_add_vertex(projection.ground(presentation._camera, point))
		mesh.surface_end()
		var view := MeshInstance3D.new()
		view.mesh = mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		material.albedo_color = Color.CYAN
		view.material_override = material
		presentation._world_root.add_child(view)

func trace_animations(tick: int) -> void:
	for view in main._battle_presentation._world_root.get_children():
		if not view is UnitModel3D or view._animation_player == null: continue
		if not String(view._animation_player.assigned_animation).begins_with("annietibbers_"): continue
		var source_alive := is_instance_valid(view._source)
		var player: AnimationPlayer = view._animation_player
		var row := {"tick": tick, "team": view._source.team if source_alive else view.get_meta("review_team", -1), "clip": player.assigned_animation, "position": player.current_animation_position, "speed": player.get_playing_speed(), "hp": view._source.hp if source_alive else 0.0, "state": view._source.get_visual_state_code() if source_alive else 4}
		view.set_meta("review_team", row.team)
		animation_frames.append(row)
		var key := "%s/%.3f/%s" % [row.clip, row.speed, row.state]
		if last_animation.get(row.team, "") != key:
			last_animation[row.team] = key
			print("[提伯斯动画] ", row)
