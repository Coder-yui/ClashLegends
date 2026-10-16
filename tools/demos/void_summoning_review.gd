extends SceneTree
var out := ProjectSettings.globalize_path("res://ClashLegends-开发素材库/04-中间产物/虚空召唤/revision-2/render")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("void_summoning")
	panel.show_workspace(0)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/card_workbench.png")
	panel.show_workspace(1)
	await create_timer(1.0).timeout
	var bus := AudioServer.get_bus_index("Master")
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus, record)
	record.set_recording_active(true)
	main.play_card(0, "void_summoning", Vector2(60, 850), {"immediate": true, "validate_position": false, "preview_active_spell": true})
	main.play_card(1, "void_summoning", Vector2(610, 850), {"immediate": true, "validate_position": false, "preview_active_spell": true})
	var age := 0.0
	for t in [0.1, 0.8, 1.6, 4.2, 7.5, 8.2, 8.9, 9.2]:
		await create_timer(t - age).timeout
		age = t
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out + "/battle_" + str(t) + ".png")
		print("RENDER ", t, " zones=", main._spell_system.summon_zones.size(), " views=", main._battle_presentation._summoning_ground._views.size())
	record.set_recording_active(false)
	record.get_recording().save_to_wav(out + "/battle.wav")
	main.queue_free()
	await process_frame
	quit()
