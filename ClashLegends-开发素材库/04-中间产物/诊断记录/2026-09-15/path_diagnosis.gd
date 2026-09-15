extends SceneTree
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 for card in ["ashe", "garen"]:
  for x in [140.0, 300.0]:
   var main = load("res://scenes/main.tscn").instantiate()
   root.add_child(main)
   current_scene = main
   main._start_local()
   main.set_process(false)
   main._ai.enabled = false
   main._minion_waves_enabled = false
   for tower in main._towers:
    tower.can_attack = false
   var unit = main._spawn_unit(0, card, Vector2(x, 900), 0.0)
   var crossing := false
   for tick in range(600):
    main._sim_step(0.05)
    if tick == 0:
     print("PATH_START ",card," x=",x," target=",unit._target.global_position," goal=",unit._path_goal," path=",unit._path)
    if not crossing and unit.position.y < 580:
     crossing = true
     print("PATH_EXIT ",card," x=",x," pos=",unit.position," goal=",unit._path_goal," next=",unit._path[unit._path_index] if unit._path_index < unit._path.size() else Vector2.INF)
    if unit._attacking:
     print("PATH_ATTACK ",card," x=",x," pos=",unit.position," target=",unit._target.global_position)
     break
   main.queue_free()
   await process_frame
 quit()
