extends SceneTree
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 current_scene = main
 main._start_local()
 main.set_process(false)
 for view in main._battle_presentation._world_root.get_children():
  if not view is TowerModel3D or not view._source.is_king: continue
  var player: AnimationPlayer = view._animation_player
  print("TEAM ",view._source.team)
  for name in player.get_animation_list():
   var clip := player.get_animation(name)
   print("CLIP ",name," length=",clip.length," tracks=",clip.get_track_count())
   if name not in ["Idle1_Base", "Nexus_spawn_anm"]: continue
   for t in range(clip.get_track_count()):
    var n := clip.track_get_key_count(t)
    if n == 0: continue
    print("TRACK ",clip.track_get_path(t)," type=",clip.track_get_type(t)," keys=",n," start=",clip.track_get_key_value(t,0)," end=",clip.track_get_key_value(t,n-1)," times=",clip.track_get_key_time(t,0),",",clip.track_get_key_time(t,n-1))
 main.queue_free()
 await process_frame
 quit()
