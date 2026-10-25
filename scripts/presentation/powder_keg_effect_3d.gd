extends Node3D
## 可靠固定区域事件只负责落点与年龄；保留原生XYZ比例。
# 用户指定固定原生XYZ缩放；不随权威伤害半径变化。
const NATIVE_SCALE := 0.0125
var _views: Dictionary = {}
var _serial := 0
func sync_effects(skills: RefCounted, camera: Camera3D) -> void:
	var present := {}
	for effect in skills.frontal_effects:
		if String(effect.get("shape", "")) != "powder_keg_burst": continue
		if not effect.has("keg_view_id"):
			_serial += 1
			effect.keg_view_id = _serial
		var id := int(effect.keg_view_id)
		present[id] = true
		if not _views.has(id):
			var view: Node3D = load("res://assets/effects/powder_keg/player.gd").new()
			add_child(view)
			view.load_kind("explosion")
			view.setup_native(NATIVE_SCALE)
			_views[id] = view
		var point: Vector2 = effect.pos
		_views[id].position = _ground_point(camera, point)
		_views[id].seek(maxf(float(effect.duration) - float(effect.timer), 1.0 / 120.0))
	for id in _views.keys():
		if not present.has(id):
			_views[id].free()
			_views.erase(id)

func _ground_point(camera: Camera3D, point: Vector2) -> Vector3:
	var origin := BattleGroundProjection.ray_origin(camera, point)
	var direction := BattleGroundProjection.ray_normal(camera, point)
	return origin + direction * (-origin.y / direction.y)
