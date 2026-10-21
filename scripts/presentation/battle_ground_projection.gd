class_name BattleGroundProjection
extends RefCounted
## Shared 54-degree battle projection. Authority coordinates remain unchanged.
const Q := 0.8090169943749475

static func reference_point(camera: Camera3D, point: Vector2) -> Vector2:
	if not camera.has_meta("uniform_ground"): return point
	var center := camera.get_viewport().get_visible_rect().size * 0.5
	return center + (point - center) * Vector2(1.0, Q)

static func ray_origin(camera: Camera3D, point: Vector2) -> Vector3:
	return camera.project_ray_origin(reference_point(camera, point))

static func ray_normal(camera: Camera3D, point: Vector2) -> Vector3:
	return camera.project_ray_normal(reference_point(camera, point))

static func unproject(camera: Camera3D, point: Vector3) -> Vector2:
	var projected := camera.unproject_position(point)
	if not camera.has_meta("uniform_ground"): return projected
	var center := camera.get_viewport().get_visible_rect().size * 0.5
	return center + (projected - center) / Vector2(1.0, Q)

## Native mesh projected into the authority canvas. The canvas applies Q once.
static func native_canvas_point(vertex: Vector3, yaw: float = 0.0) -> Vector2:
	return Vector2(vertex.x, vertex.z).rotated(yaw) - Vector2(0, vertex.y * sqrt(1.0 - Q * Q) / Q)

static func native_canvas_face(vertices: PackedVector3Array, yaw: float, native_scale: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for vertex in vertices: points.append(native_canvas_point(vertex, yaw) * native_scale)
	return points
