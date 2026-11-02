extends Node3D
## 原始材质可见性：完整晶体与死亡碎片互斥；只读取当前表现动画。
var _meshes: Array[MeshInstance3D] = []
var _player: AnimationPlayer
var _surfaces: Array[Dictionary] = []
var _dead := false

func _ready() -> void:
	add_to_group("ground_aperture_views")
	for child in find_children("*", "MeshInstance3D", true, false):
		_meshes.append(child)
		for index in child.mesh.get_surface_count():
			var original := child.mesh.surface_get_material(index) as StandardMaterial3D
			if original == null: continue
			var material := ShaderMaterial.new()
			material.shader = preload("res://assets/units/inhibitor/well.gdshader")
			material.set_shader_parameter("albedo_texture", original.albedo_texture)
			material.set_shader_parameter("albedo_color", original.albedo_color)
			child.set_surface_override_material(index, material)
			_surfaces.append({"material": material, "destroyed": original.resource_name == "Destroyed"})
	for child in find_children("*", "AnimationPlayer", true, false):
		_player = child
	_apply_visibility(false)

func _process(_delta: float) -> void:
	var dead := is_instance_valid(_player) and String(_player.assigned_animation).ends_with("Death_Base")
	if dead != _dead: _apply_visibility(dead)

func _apply_visibility(dead: bool) -> void:
	_dead = dead
	for surface in _surfaces:
		surface.material.set_shader_parameter("surface_visible", 1.0 if surface.destroyed == dead else 0.0)

func set_visual_clip(animation_name: StringName) -> void:
	_apply_visibility(String(animation_name).ends_with("Death_Base"))

func get_preview_bounds() -> AABB:
	# 地下晶柱与隐藏碎片不参与摄影取景；地面仍是原点。
	return AABB(Vector3(-1.48, 0, -1.48), Vector3(2.96, 2.61, 2.96))

func get_health_bar_anchor_local() -> Vector3:
	return Vector3(0, 2.61, 0)

func ground_aperture_radius() -> float:
	return 0.82 * global_basis.get_scale().x
