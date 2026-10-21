extends Node2D
## 复用实战眩晕漩涡，分别投影到拍摄相机和外部相机的画布。
var camera: Camera3D
var members: Array[Dictionary] = []
var _markers: Dictionary = {}

class Marker extends Node2D:
	var phase := 0.0
	func _draw() -> void:
		preload("res://scripts/presentation/stun_effect.gd").draw_effect(self, Vector2.ZERO, phase)

func _process(_delta: float) -> void:
	if not is_instance_valid(camera): return
	var active := {}
	for member in members:
		if member.status != "stun" or not is_instance_valid(member.model): continue
		var model: Node3D = member.model
		var id := model.get_instance_id()
		active[id] = true
		if not _markers.has(id):
			var marker := Marker.new()
			add_child(marker)
			_markers[id] = marker
		var marker: Marker = _markers[id]
		var top := model.global_position.y
		var bottom := top
		for mesh: MeshInstance3D in member.resources.meshes():
			if not is_instance_valid(mesh) or not mesh.is_visible_in_tree(): continue
			var bounds := mesh.get_aabb()
			for corner in 8:
				var point := mesh.to_global(bounds.position + bounds.size * Vector3(corner & 1, (corner >> 1) & 1, (corner >> 2) & 1))
				top = maxf(top, point.y)
				bottom = minf(bottom, point.y)
		var head := Vector3(model.global_position.x, top, model.global_position.z)
		marker.visible = not camera.is_position_behind(head)
		if not marker.visible: continue
		var origin := camera.unproject_position(head)
		var radius := maxf((top - bottom) * 0.13, 0.2)
		var screen_radius := origin.distance_to(camera.unproject_position(head + camera.global_basis.x * radius))
		var marker_scale := maxf(screen_radius / 13.0, 0.1)
		origin.y -= 8.0 * marker_scale
		marker.position = origin
		marker.scale = Vector2.ONE * marker_scale
		marker.phase = member.status_time
		marker.queue_redraw()
	for id in _markers.keys():
		if not active.has(id):
			_markers[id].queue_free()
			_markers.erase(id)
