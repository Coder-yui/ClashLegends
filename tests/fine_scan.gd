extends SceneTree
## 临时诊断：对敌公主塔血条区域做 1px 精细扫描，判断红条是否被模型部分覆盖。

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
	for i in range(150):
		await process_frame
	var win: Window = root
	var img: Image = win.get_texture().get_image()

	# 敌公主左：塔 y=260，血条中心 y=184 (x 80..200)。扫描 x[70..210], y[170..200]
	for y in range(170, 201):
		var red_count := 0
		var total := 0
		for x in range(70, 211):
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.7 and c.g < 0.45 and c.b < 0.45:
				red_count += 1
			total += 1
		print("[fine] y=%d 红色像素=%d/%d" % [y, red_count, total])
	quit(0)
