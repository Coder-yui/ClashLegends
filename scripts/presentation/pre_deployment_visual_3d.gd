class_name PreDeploymentVisual3D
extends Node3D
## 纯预部署表现：只接收队列快照，不能创建战斗对象或结算伤害。
var camera: Camera3D
var destination := Vector2.ZERO
var team := 0
var audio_position := Vector2.ZERO
var duration := 0.0
var route := PackedVector2Array()

func setup(view_camera: Camera3D, point: Vector2, source_team: int) -> void:
	camera = view_camera
	destination = point
	audio_position = point
	team = source_team

func ground(point: Vector2) -> Vector3:
	var origin := BattleGroundProjection.ray_origin(camera, point)
	var direction := BattleGroundProjection.ray_normal(camera, point)
	return origin + direction * (-origin.y / direction.y)

func advance_visual(_progress: float) -> void:
	pass

## 默认立即收回；带世界空间拖尾的表现可停止发射后自行收尾。
func finish_visual() -> void:
	hide()
	queue_free()
