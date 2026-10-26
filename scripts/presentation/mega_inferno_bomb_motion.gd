extends RefCounted
## 炸弹视觉与2D声源共用的表现轨迹；不参与权威飞行/伤害计时。
const ARC_HEIGHT := 230.0
const LAUNCH_HEIGHT := 100.0

static func height(progress: float) -> float:
	var t := clampf(progress, 0.0, 1.0)
	return 4.0 * t * (1.0-t) * ARC_HEIGHT + (1.0-t) * LAUNCH_HEIGHT

static func slope(progress: float) -> float:
	return 4.0 * (1.0-2.0*progress) * ARC_HEIGHT - LAUNCH_HEIGHT

static func canvas_position(origin: Vector2, target: Vector2, progress: float) -> Vector2:
	return origin.lerp(target, progress) + BattleGroundProjection.native_canvas_point(Vector3(0, height(progress), 0))
