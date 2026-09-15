extends SceneTree
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 current_scene = main
 await main._start_local_with_loading()
 var begun := Time.get_ticks_usec()
 var previous := begun
 main.child_entered_tree.connect(func(node):
  if node is Unit: print("UNIT t=",(Time.get_ticks_usec()-begun)/1000000.0," card=",node.card_id))
 while Time.get_ticks_usec()-begun < 10000000:
  await process_frame
  var now := Time.get_ticks_usec()
  if now-previous>30000:
   print("FRAME t=",(now-begun)/1000000.0," ms=",(now-previous)/1000.0)
  previous=now
 quit()
