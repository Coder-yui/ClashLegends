extends RefCounted
## 2D权威范围与3D表现的坐标约定；只提供几何转换。
static func ground(camera: Camera3D, point: Vector2) -> Vector3:
	var origin := BattleGroundProjection.ray_origin(camera, point)
	var direction := BattleGroundProjection.ray_normal(camera, point)
	return origin + direction * ((0.06 - origin.y) / direction.y)

static func footprint_basis(camera: Camera3D, point: Vector2, pixel_radius: float) -> Basis:
	var center := ground(camera, point)
	var across := ground(camera, point + Vector2(pixel_radius, 0)) - center
	var along := ground(camera, point + Vector2(0, pixel_radius)) - center
	# 统一地面只取朝向，不再将相机的纵向缩短写回粒子形状。
	if camera.has_meta("uniform_ground"):
		return Basis(across.normalized(), Vector3.UP, along.normalized())
	# 未迁移的独立预览仍使用旧坐标合同。
	return Basis(across / across.length(), Vector3.UP, along / across.length())

static func flight_position(camera: Camera3D, origin: Vector2, target: Vector2, progress: float, arc_height: float, launch_height: float) -> Vector3:
	var point := origin.lerp(target, progress)
	var base := ground(camera, point)
	# 飞行弧线是项目约定的屏幕轨迹，与粒子本体形状分离。
	var pixels_per_y := maxf(absf(BattleGroundProjection.unproject(camera, base + Vector3.UP).y - BattleGroundProjection.unproject(camera, base).y), 0.001)
	return base + Vector3.UP * (sin(progress * PI) * arc_height + (1.0 - progress) * launch_height) / pixels_per_y
