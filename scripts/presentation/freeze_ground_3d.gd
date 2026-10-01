extends Node3D
## 冰霜护手的原版冰面遮罩，贴地且参与人物深度检测；只读取法术表现窗口。
const SHADER = preload("res://assets/effects/freeze/ice_ground.gdshader")
const ICE = preload("res://assets/effects/freeze/ice_mask.png")
const BLUE_RIM := Color(0.15, 0.55, 1.0)
const RED_RIM := Color(1.0, 0.25, 0.20)
var _views: Array[MeshInstance3D] = []

func sync_effects(spells: RefCounted, camera: Camera3D) -> void:
	var index := 0
	for effect in spells.freeze_effects:
		_sync_view(index, effect, camera)
		index += 1
	for effect in spells.slow_effects:
		if float(effect.delay) > 0.0: continue
		_sync_view(index, effect, camera)
		index += 1
	# 槽位复用，只随当前可见区域数增长；清场立即隐藏。
	for spare in range(index, _views.size()): _views[spare].hide()

func _sync_view(index: int, effect: Dictionary, camera: Camera3D) -> void:
	if index == _views.size():
		var view := MeshInstance3D.new()
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("ice_mask", ICE)
		view.material_override = material
		add_child(view)
		_views.append(view)
	var view := _views[index]
	view.show()
	var material: ShaderMaterial = view.material_override
	material.set_shader_parameter("rim_color", BLUE_RIM if int(effect.get("team", 0)) == 0 else RED_RIM)
	var center: Vector2 = effect.pos
	var radius := float(effect.radius)
	var bounds := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	if view.get_meta("bounds", Rect2()) != bounds:
		_update_mesh(view, bounds, camera)

func _update_mesh(view: MeshInstance3D, bounds: Rect2, camera: Camera3D) -> void:
	view.set_meta("bounds", bounds)
	var center := bounds.get_center()
	var radius := bounds.size.x * 0.5
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var vertices := PackedVector3Array()
	for corner in corners:
		var screen: Vector2 = center + corner * radius
		var origin := camera.project_ray_origin(screen)
		var direction := camera.project_ray_normal(screen)
		# 正交相机逆投影四角：画面上始终匹配110px权威圆形范围。
		vertices.append(origin + direction * ((0.04 - origin.y) / direction.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	view.mesh = mesh
