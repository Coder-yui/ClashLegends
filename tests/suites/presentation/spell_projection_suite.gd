extends "res://tests/suites/battle_suite.gd"
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const PLAYER = preload("res://assets/effects/stasis/native/player.gd")

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	main.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	for eye in [Vector3(0, 12, 10), Vector3(0, 7, -12)]:
		camera.position = eye
		camera.look_at(Vector3.ZERO)
		for point in [Vector2(180, 300), Vector2(360, 650), Vector2(540, 1000)]:
			var center := PROJECTION.ground(camera, point)
			var basis := PROJECTION.footprint_basis(camera, point, 110.0)
			var unit_scale := PROJECTION.ground(camera, point + Vector2(110, 0)).distance_to(center)
			_expect(camera.unproject_position(center).distance_to(point) < 0.01, "地面锚点反投影准确")
			_expect(basis.y.is_equal_approx(Vector3.UP), "竖向不逆补偿相机压缩")
			for angle in [0.0, 0.7, 1.7, 3.1, 4.2]:
				var rim := center + basis * Vector3(cos(angle), 0, sin(angle)) * unit_scale
				_expect(absf(camera.unproject_position(rim).distance_to(point) - 110.0) < 0.01, "不同视角及圆周方向均保持110屏幕半径")
			var end := PROJECTION.flight_position(camera, Vector2(360, 1150), point, 1.0, 160.0, 60.0)
			_expect(end.distance_to(center) < 0.001, "空中弧线末端准确衔接范围中心")
	viewport.free()
	var player := PLAYER.new()
	main.add_child(player)
	player._source = "flight"
	player._data = {"birthTimes": {"0:1": 0.2}}
	player.scale = Vector3.ONE * 0.5
	player.position = Vector3(10, 0, 0)
	player.flight_position_at = func(time: float) -> Vector3: return Vector3(time * 10.0, 0, 0)
	var sample := [1, 0.0, 0.0, 0.0]
	for weight in [0.0, 0.5, 1.0]:
		var result: Array = player._sample({"index": 0, "bindWeight": {"constant": [weight]}}, sample)
		var world_x := player.position.x + float(result[1]) * player.scale.x
		_expect(is_equal_approx(world_x, lerpf(2.0, 10.0, weight)), "原版绑定权重决定出生位置与当前弹体之间的跟随")
	_expect(sample == [1, 0.0, 0.0, 0.0], "世界空间修正不修改共享采样")
	player.free()
