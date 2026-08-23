extends SceneTree
## 临时诊断：给塔设置 z_index=10 后，检查敌公主塔血条是否完全可见。

const DECK := ["garen", "xin", "ashe", "teemo", "freeze", "masteryi", "gwen", "sett"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		quit(1)
		return
	await process_frame
	await process_frame
	var main: Node = current_scene
	main.set("_deck", DECK.duplicate())
	main.call("_start_local")
	# 给所有塔设置高 z_index
	for t in main.get("_towers") as Array:
		t.set("z_index", 10)
	for i in range(150):
		await process_frame
	var win: Window = root
	var img: Image = win.get_texture().get_image()

	# 敌公主左：血条中心 y=184 (x 80..200)
	for y in range(176, 192):
		var red_count := 0
		for x in range(70, 211):
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.7 and c.g < 0.45 and c.b < 0.45:
				red_count += 1
		print("[z] y=%d 红色像素=%d" % [y, red_count])
	quit(0)
