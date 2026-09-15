extends SceneTree
var main: Node2D
var output := preload("res://tools/lib/development_paths.gd").output("pix_arena_review")
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 DirAccess.make_dir_recursive_absolute(output)
 root.size = Vector2i(720,1400)
 main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 current_scene = main
 await process_frame
 main._start_local()
 main.set_process(false)
 main._ai.enabled = false
 main._minion_waves_enabled = false
 main._spawn_card_units(0, "pix", Vector2(360, 850), 0.0)
 main._spawn_card_units(1, "pix", Vector2(360, 430), 0.0)
 await create_timer(3.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join("arena.png"))
 for tower in main.get_tree().get_nodes_in_group("combatants"):
  if tower is Tower and tower.is_king:
   tower.take_damage(tower.hp + 1.0)
 await create_timer(3.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join("arena_ruins.png"))
 print("PIX_ARENA_REVIEW: ", output)
 quit()
