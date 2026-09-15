extends SceneTree
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 current_scene = main
 await main._start_local_with_loading()
 if "--no-ai" in OS.get_cmdline_user_args():
  main._ai.enabled = false
 if "--no-waves" in OS.get_cmdline_user_args():
  main._minion_waves_enabled = false
 main.child_entered_tree.connect(func(node):
  if node is Unit: print("SPAWN card=",node.card_id," ticks=",Time.get_ticks_msec()))
 main.set_process(false)
 main._audio_manager.set_process(false)
 var views := []
 for view in main._battle_presentation._world_root.get_children():
  if view is TowerModel3D:
   view.set_process(false)
   views.append(view)
 var begun := Time.get_ticks_usec()
 print("START ticks=",begun/1000)
 var previous := begun
 while Time.get_ticks_usec()-begun < 10000000:
  var now := Time.get_ticks_usec()
  var dt := minf(float(now-previous)/1000000.0,0.1)
  previous = now
  var a := Time.get_ticks_usec()
  main._process(dt)
  var b := Time.get_ticks_usec()
  main._audio_manager._process(dt)
  var c := Time.get_ticks_usec()
  for view in views: view._process(dt)
  var d := Time.get_ticks_usec()
  RenderingServer.force_draw()
  var e := Time.get_ticks_usec()
  if e-a > 18000:
   print("STALL t=",(a-begun)/1000000.0," main_ms=",(b-a)/1000.0," audio_ms=",(c-b)/1000.0," anim_ms=",(d-c)/1000.0," render_ms=",(e-d)/1000.0)
  await process_frame
 quit()
