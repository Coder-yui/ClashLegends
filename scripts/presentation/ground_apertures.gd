extends Node
## Each rendered world owns its terrain material copies and aperture texture.
var _surfaces_root: Node
var _bound := false
var _scope: Node
var _materials: Array[ShaderMaterial] = []
var _previous := PackedVector3Array()
var _texture: ImageTexture

func setup(scope: Node, surfaces: Node) -> void:
	_scope = scope
	_surfaces_root = surfaces

func _bind(node: Node, copies: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for index in node.mesh.get_surface_count():
			var original := node.get_active_material(index) as ShaderMaterial
			if original == null or original.shader == null or not ("nexus_aperture" in original.shader.code or "model_aperture" in original.shader.code): continue
			if not copies.has(original):
				var local := original.duplicate() as ShaderMaterial
				local.set_shader_parameter("model_well_count", 0)
				copies[original] = local
				_materials.append(local)
			if node.material_override != null: node.material_override = copies[original]
			else: node.set_surface_override_material(index, copies[original])
	for child in node.get_children(): _bind(child, copies)

func _process(_delta: float) -> void:
	if not is_instance_valid(_scope): return
	var wells := PackedVector3Array()
	for view in get_tree().get_nodes_in_group("ground_aperture_views"):
		if not _scope.is_ancestor_of(view) or not view.is_visible_in_tree(): continue
		var radius: float = view.ground_aperture_radius()
		if radius > 0.0: wells.append(Vector3(view.global_position.x, view.global_position.z, radius))
	if wells == _previous: return
	if not _bound:
		_bind(_surfaces_root, {})
		_bound = true
	_previous = wells
	var pixels := Image.create(maxi(wells.size(), 1), 1, false, Image.FORMAT_RGBAF)
	for index in wells.size(): pixels.set_pixel(index, 0, Color(wells[index].x, wells[index].y, wells[index].z, 1))
	_texture = ImageTexture.create_from_image(pixels)
	for material in _materials:
		material.set_shader_parameter("model_wells", _texture)
		material.set_shader_parameter("model_well_count", wells.size())
