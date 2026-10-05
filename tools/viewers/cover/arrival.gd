extends "res://assets/units/pantheon/pantheon_arrival.gd"
## 用固定的游戏投影采样路径，拍摄相机移动不改变特效落点或轨迹。
var staging_transform := Transform3D.IDENTITY

func ground(point: Vector2) -> Vector3:
	return staging_transform * super.ground(point)
