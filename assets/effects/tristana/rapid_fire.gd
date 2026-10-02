extends ActiveBuffVisual3D
## 炮筒表面热光：从原网格选择武器蒙皮面，共用原骨骼；不使用弹体挂点。
const HEAT_SHADER := preload("res://assets/effects/tristana/rapid_fire.gdshader")
var _heat: MeshInstance3D
var _material: ShaderMaterial
var _time := 0.0

func configure(_radius: float, _team: int = 0) -> void:
	visible = false

func _create_heat() -> void:
	for source: MeshInstance3D in get_parent().find_children("*", "MeshInstance3D", true, false):
		if source.skin == null or source.mesh == null: continue
		var skeleton := source.get_node_or_null(source.skeleton) as Skeleton3D
		if skeleton == null: continue
		var weapon_binds: Array[int] = []
		var muzzle_bind := Transform3D.IDENTITY
		for bind in source.skin.get_bind_count():
			var bone_name := String(source.skin.get_bind_name(bind))
			if bone_name.is_empty(): bone_name = skeleton.get_bone_name(source.skin.get_bind_bone(bind))
			if bone_name in ["Weapon_Base", "WeaponTip_Scale"]: weapon_binds.append(bind)
			if bone_name == "Buffbone_Glb_Weapon_1": muzzle_bind = source.skin.get_bind_pose(bind)
		if weapon_binds.is_empty(): continue
		var mesh := ArrayMesh.new()
		for surface in source.mesh.get_surface_count():
			var arrays := source.mesh.surface_get_arrays(surface)
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var selected := PackedInt32Array()
			var stride := bones.size() / vertices.size()
			var mask := PackedByteArray()
			mask.resize(vertices.size())
			for vertex in vertices.size():
				var weight := 0.0
				for slot in stride:
					if bones[vertex * stride + slot] in weapon_binds: weight += weights[vertex * stride + slot]
				mask[vertex] = 1 if weight > 0.95 else 0
			for triangle in range(0, indices.size(), 3):
				if mask[indices[triangle]] and mask[indices[triangle + 1]] and mask[indices[triangle + 2]]:
					selected.append_array(indices.slice(triangle, triangle + 3))
			if selected.is_empty(): continue
			# 源GLB没有法线，先按Godot顺时针绕序生成，避免叠层与原表面闪烁。
			var normals := PackedVector3Array()
			normals.resize(vertices.size())
			for triangle in range(0, indices.size(), 3):
				var a := indices[triangle]
				var b := indices[triangle + 1]
				var c := indices[triangle + 2]
				var normal := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
				for vertex in [a, b, c]: normals[vertex] += normal
			var colors := PackedColorArray()
			for vertex in vertices.size():
				normals[vertex] = normals[vertex].normalized()
				var local := muzzle_bind * vertices[vertex]
				var heat := 1.0 - smoothstep(0.65, 0.9, local.z)
				colors.append(Color(1, 1, 1, heat))
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_COLOR] = colors
			arrays[Mesh.ARRAY_INDEX] = selected
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if mesh.get_surface_count() == 0: continue
		_heat = MeshInstance3D.new()
		_heat.name = "RapidFireBarrelHeat"
		_heat.mesh = mesh
		_heat.skin = source.skin
		_heat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		source.add_child(_heat)
		_heat.skeleton = _heat.get_path_to(skeleton)
		_material = ShaderMaterial.new()
		_material.shader = HEAT_SHADER
		_heat.material_override = _material
		return

func advance(enabled: bool, delta: float) -> void:
	super.advance(enabled, delta)
	if enabled and not is_instance_valid(_heat): _create_heat()
	if not is_instance_valid(_heat): return
	_heat.visible = enabled
	if not enabled: return
	_time += delta
	_material.set_shader_parameter("phase", _time)

func _exit_tree() -> void:
	if is_instance_valid(_heat): _heat.queue_free()
