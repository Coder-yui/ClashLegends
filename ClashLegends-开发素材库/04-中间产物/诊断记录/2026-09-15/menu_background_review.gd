extends SceneTree
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 root.size = Vector2i(720,1400)
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 current_scene = main
 await create_timer(1.0).timeout
 await RenderingServer.frame_post_draw
 assert(main._arena_background_sprite.visible)
 root.get_texture().get_image().save_png("/Users/czh/Documents/Codex/2026-09-15/y/work/menu-restored.png")
 main._start_local()
 await process_frame
 assert(not main._arena_background_sprite.visible)
 assert(main._battle_presentation._world_root.get_node("RiftArena").visible)
 print("MENU_BACKGROUND_REVIEW_PASS")
 quit()
