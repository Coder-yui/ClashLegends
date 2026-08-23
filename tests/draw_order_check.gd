extends SceneTree
## 临时诊断：验证「先加入的透明 3D 视口叠加层 Sprite，后加入的 Node2D 绘制」谁在上层。
## 输出 overlap 像素颜色；若为红色说明 Node2D 画在 3D 之上，否则是绿色。

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var win: Window = root

	# 1) 透明 3D 视口：中心一个绿色方块
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 320)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	win.add_child(viewport)

	var world := Node3D.new()
	viewport.add_child(world)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 8.0
	cam.position = Vector3(0.0, 4.0, 4.0)
	world.add_child(cam)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	cam.current = true

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)

	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	(box.mesh as BoxMesh).size = Vector3(2.0, 2.0, 2.0)
	world.add_child(box)

	# 2) 叠加层 Sprite，先加入（模拟 battle_presentation 的 overlay）
	var overlay := Sprite2D.new()
	overlay.centered = false
	overlay.texture = viewport.get_texture()
	win.add_child(overlay)

	# 3) 后加入的 Node2D，画一个红色方块，位置覆盖绿色方块投影区域
	var painter := Node2D.new()
	painter.z_index = 0
	win.add_child(painter)
	painter.draw.connect(func():
		painter.draw_rect(Rect2(Vector2(80, 80), Vector2(160, 160)), Color.RED))

	await process_frame
	await process_frame
	await process_frame

	var img: Image = win.get_texture().get_image()
	# 中心点 (160,160)：若被红色盖住 → 后加入的 2D 在上；绿色 → 3D 在上
	var center_pixel: Color = img.get_pixel(160, 160)
	var top_pixel: Color = img.get_pixel(160, 40)
	print("[draw_order] center=", center_pixel, " top=", top_pixel)
	quit(0)
