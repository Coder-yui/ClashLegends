extends SceneTree
## 临时诊断：把真实场景截图转成 ASCII 字符画（每块 6x6 像素），直观查看塔与血条位置。

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

	const BLOCK := 6
	var out := ""
	for by in range(img.get_height() / BLOCK):
		var line := ""
		for bx in range(img.get_width() / BLOCK):
			var c: Color = img.get_pixel(bx * BLOCK + BLOCK / 2, by * BLOCK + BLOCK / 2)
			var ch := "."
			if c.r > 0.7 and c.g < 0.45 and c.b < 0.45:
				ch = "R"
			elif c.g > 0.6 and c.r < 0.5 and c.b < 0.5:
				ch = "G"
			elif c.r < 0.2 and c.g < 0.2 and c.b < 0.2:
				ch = "#"
			elif c.r < 0.35 and c.g < 0.32 and c.b < 0.28:
				ch = "o"
			elif c.b > c.r and c.b > 0.4:
				ch = "B"
			line += ch
		out += "%3d|%s\n" % [by * BLOCK, line]
	print(out)
	quit(0)
