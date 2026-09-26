class_name PreDeploymentVisual3D
extends Node3D
## 纯预部署表现：只接收队列快照，不能创建战斗对象或结算伤害。
var camera: Camera3D
var destination := Vector2.ZERO
var team := 0

func setup(view_camera: Camera3D, point: Vector2, source_team: int) -> void:
	camera = view_camera
	destination = point
	team = source_team

func ground(point: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	return origin + direction * (-origin.y / direction.y)

func advance_visual(_progress: float) -> void:
	pass
