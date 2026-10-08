extends RefCounted
## 2D权威范围与3D表现的坐标约定；只提供几何转换。
static func ground(camera: Camera3D, point: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	return origin + direction * ((0.06 - origin.y) / direction.y)

static func footprint_basis(camera: Camera3D, point: Vector2, pixel_radius: float) -> Basis:
	var center := ground(camera, point)
	var across := ground(camera, point + Vector2(pixel_radius, 0)) - center
	var along := ground(camera, point + Vector2(0, pixel_radius)) - center
	# XZ映射权威屏幕圆；Y保持真实世界竖直和原始相对尺度，不抵消相机俯角。
	return Basis(across / across.length(), Vector3.UP, along / across.length())

static func flight_position(camera: Camera3D, origin: Vector2, target: Vector2, progress: float, arc_height: float, launch_height: float) -> Vector3:
	var point := origin.lerp(target, progress)
	var base := ground(camera, point)
	# 飞行弧线是项目约定的屏幕轨迹，与粒子本体形状分离。
	var pixels_per_y := maxf(absf(camera.unproject_position(base + Vector3.UP).y - camera.unproject_position(base).y), 0.001)
	return base + Vector3.UP * (sin(progress * PI) * arc_height + (1.0 - progress) * launch_height) / pixels_per_y
