extends Node3D
## Pure scenery. The authored mesh uses the existing 45-degree camera projection;
## no bodies, navigation, animation events, or authority state live in this scene.
const RIVER_SHADER := preload("res://assets/arena/rift_arena/river.gdshader")
const GROUND_SHADER := preload("res://assets/arena/rift_arena/ground.gdshader")
const SURFACE_SHADER := preload("res://assets/arena/rift_arena/surface.gdshader")
const SURFACE_ATLAS := preload("res://assets/arena/rift_arena/rift_surface_atlas.png")

func _ready() -> void:
	_apply_arena_materials(self)

func _apply_arena_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if node.name.begins_with("RiverSurface"):
			var material := ShaderMaterial.new()
			material.shader = RIVER_SHADER
			mesh_instance.material_override = material
		elif node.name.begins_with("Terrain__Living_moss"):
			var material := ShaderMaterial.new()
			material.shader = GROUND_SHADER
			material.set_shader_parameter("surface_atlas", SURFACE_ATLAS)
			mesh_instance.material_override = material
		else:
			for surface in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
				var material_name := material.resource_name
				if material_name.begins_with("Slate") or material_name.begins_with("Basalt") or material_name.begins_with("Weathered") or material_name.begins_with("Pine needles"):
					var painted := ShaderMaterial.new()
					painted.shader = SURFACE_SHADER
					painted.set_shader_parameter("surface_atlas", SURFACE_ATLAS)
					if material_name.begins_with("Pine needles"):
						painted.set_shader_parameter("quadrant", Vector2(0.5, 0.5))
						painted.set_shader_parameter("tint", Vector3(0.83, 0.95, 0.91))
						painted.set_shader_parameter("texture_scale", 0.48)
					else:
						var color := material.albedo_color.srgb_to_linear()
						painted.set_shader_parameter("tint", Vector3(color.r, color.g, color.b) * 3.5)
					mesh_instance.set_surface_override_material(surface, painted)
					continue
				# Deliberate palette darkening under the shared Compatibility
				# lighting, keeping the textured heroes above the scenery in value.
				material.albedo_color = material.albedo_color.srgb_to_linear()
				material.metallic_specular = 0.15
				mesh_instance.set_surface_override_material(surface, material)
	for child in node.get_children():
		_apply_arena_materials(child)
