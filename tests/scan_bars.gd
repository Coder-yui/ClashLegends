extends SceneTree
## 临时诊断：在每个塔的 x 位置做纵向扫描，找出血条（黑底+红/绿填充）实际 y 范围。

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

	# 每条扫描：x 固定，y 范围；统计 深黑底(0.05..0.2 灰度) 与 红/绿填充 的 y 位置
	var scans := [
		["敌公主左 x=140", 140, 150, 300],
		["敌公主右 x=580", 580, 150, 300],
		["己公主左 x=140", 140, 850, 1050],
		["己公主右 x=580", 580, 850, 1050],
		["敌水晶 x=360", 360, 10, 200],
		["己水晶 x=360", 360, 1100, 1200],
	]
	for s in scans:
		var x: int = s[1]
		var dark_rows: Array = []
		var red_rows: Array = []
		var green_rows: Array = []
		for y in range(s[2], s[3]):
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.7 and c.g < 0.45 and c.b < 0.45:
				red_rows.append(y)
			elif c.g > 0.6 and c.r < 0.5 and c.b < 0.5:
				green_rows.append(y)
			elif c.r < 0.2 and c.g < 0.2 and c.b < 0.2:
				dark_rows.append(y)
		var dump := func(rows, label):
			if rows.is_empty():
				print("[scan] %s %s: 无" % [s[0], label])
			else:
				print("[scan] %s %s: y[%d..%d] 数=%d" % [s[0], label, rows[0], rows[-1], rows.size()])
		dump.call(dark_rows, "黑底")
		dump.call(red_rows, "红填充")
		dump.call(green_rows, "绿填充")
	quit(0)
