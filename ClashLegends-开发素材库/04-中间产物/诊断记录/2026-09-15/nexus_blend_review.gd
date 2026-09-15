extends SceneTree
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 current_scene = main
 main._start_local()
 main.set_process(false)
 main._ai.enabled = false
 var views := []
 for view in main._battle_presentation._world_root.get_children():
  if view is TowerModel3D and view._source.is_king:
   view.set_process(false)
   view._play_spawn_or_idle()
   view._animation_player.seek(0.0, true)
   view._advance_nexus_animation(4.6)
   views.append(view)
 await process_frame
 await process_frame
 var sheet := Image.create(1080, 920, false, Image.FORMAT_RGB8)
 for frame in range(8):
  for view in views: view._advance_nexus_animation(0.1)
  await process_frame
  RenderingServer.force_draw()
  var shot := root.get_texture().get_image()
  shot.convert(Image.FORMAT_RGB8)
  var x := (frame % 4) * 270
  var y := (frame / 4) * 460
  sheet.blit_rect(shot, Rect2i(225, 0, 270, 230), Vector2i(x,y))
  sheet.blit_rect(shot, Rect2i(225, 1080, 270, 230), Vector2i(x,y+230))
  print("BLEND frame=", frame, " animation=", views[0]._animation_player.current_animation, " time=", views[0]._animation_player.current_animation_position)
 sheet.save_png("/tmp/clash-nexus-blend.png")
 quit()
