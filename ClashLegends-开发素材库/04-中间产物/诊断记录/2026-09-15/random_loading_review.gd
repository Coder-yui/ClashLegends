extends SceneTree
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 current_scene = main
 main._pick_deck_ui(func(): pass)
 await process_frame
 main._deck_builder._randomize_deck()
 await process_frame
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("/tmp/clash-random-deck.png")
 main._deck = main._deck_builder._deck_selected.duplicate()
 main._deck_builder._clear_deck_ui()
 var cues := []
 main._audio_manager.cue_played.connect(func(card, cue, _pos): cues.append([card, cue, paused]))
 var start := Time.get_ticks_msec()
 main._start_local_with_loading()
 await create_timer(0.2, true).timeout
 print("LOADING paused=", paused, " cues=", cues, " clock=", main._simulation_clock.remainder)
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("/tmp/clash-loading.png")
 while main._battle_loading:
  await process_frame
 print("READY seconds=", (Time.get_ticks_msec()-start)/1000.0, " paused=", paused, " cues=", cues)
 await create_timer(0.7).timeout
 print("STARTED cues=", cues)
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("/tmp/clash-loaded.png")
 quit()
