extends SceneTree
var output := preload("res://tools/lib/development_paths.gd").output("nexus-final-timing")
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 DirAccess.make_dir_recursive_absolute(output)
 for team in [0, 1]:
  var main = load("res://scenes/main.tscn").instantiate()
  root.add_child(main)
  current_scene = main
  main._start_local()
  main.set_process(false)
  main._ai.enabled = false
  main._minion_waves_enabled = false
  var recorder := AudioEffectRecord.new()
  var effect := AudioServer.get_bus_effect_count(0)
  AudioServer.add_bus_effect(0, recorder)
  recorder.set_recording_active(true)
  var started := Time.get_ticks_msec()
  main._audio_manager.cue_played.connect(func(card, cue, _pos):
   if cue == &"death" or card == "match": print("TIMING team=",team," event=",cue," seconds=",(Time.get_ticks_msec()-started)/1000.0))
  var nexus: Tower = main._king_player if team == 0 else main._king_enemy
  nexus.take_damage(nexus.hp + 1.0)
  main._end_game(1-team, "nexus")
  var deadline := Time.get_ticks_msec() + 16000
  while main._audio_manager._terminal_audio_pending and Time.get_ticks_msec() < deadline:
   await create_timer(0.05).timeout
  print("TIMING team=",team," complete=",not main._audio_manager._terminal_audio_pending," seconds=",(Time.get_ticks_msec()-started)/1000.0)
  RenderingServer.force_draw()
  root.get_texture().get_image().save_png(output.path_join("team%d.png" % team))
  recorder.set_recording_active(false)
  var recording := recorder.get_recording()
  if recording != null: recording.save_to_wav(output.path_join("team%d.wav" % team))
  AudioServer.remove_bus_effect(0,effect)
  main.queue_free()
  await process_frame
 print("TIMING_OUTPUT ",output)
 quit()
