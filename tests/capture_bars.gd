extends SceneTree
## 临时诊断：真实场景截图，检查塔血条是否被模型遮挡。
## 在四个塔的预期血条屏幕位置采样像素颜色并输出，另保存整帧截图。

const DECK := ["garen", "xin", "ashe", "teemo", "freeze", "masteryi", "gwen", "sett"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		print("[capture] 场景加载失败 ", err)
		quit(1)
		return
	await process_frame
	await process_frame
	var main: Node = current_scene
	if not main.has_method("_start_local"):
		print("[capture] 未找到 _start_local")
		quit(1)
		return
	main.set("_deck", DECK.duplicate())
	main.call("_start_local")
	# 等塔出生动画基本结束
	for i in range(90):
		await process_frame
	var win: Window = root
	var img: Image = win.get_texture().get_image()

	# 塔屏幕坐标与血条中心偏移（与 tower.gd 一致）
	var samples := [
		["敌公主塔左", Vector2(140, 260), -76.0],
		["敌公主塔右", Vector2(580, 260), -76.0],
		["己公主塔左", Vector2(140, 1020), -120.0],
		["己公主塔右", Vector2(580, 1020), -120.0],
		["敌水晶", Vector2(360, 120), -80.0],
		["己水晶", Vector2(360, 1160), 8.0],
	]
	for s in samples:
		var center: Vector2 = s[1]
		var bar_center := Vector2(center.x, center.y + s[2])
		var px: Color = img.get_pixel(int(bar_center.x), int(bar_center.y))
		print("[capture] %s 血条中心(%d,%d) 像素=%s" % [s[0], int(bar_center.x), int(bar_center.y), px])
	img.save_png("user://tower_bars_check.png")
	print("[capture] 已保存 user://tower_bars_check.png")
	quit(0)
