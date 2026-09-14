extends Node3D
## Presentation-only diorama. Every shader reads visual coordinates and render time.
## Original atlases stay intact; regions below avoid unrelated UV islands.
const RIVER_SHADER := preload("res://assets/arena/rift_arena/river.gdshader")
const GROUND_SHADER := preload("res://assets/arena/rift_arena/ground.gdshader")
const SURFACE_SHADER := preload("res://assets/arena/rift_arena/surface.gdshader")
const FOLIAGE_SHADER := preload("res://assets/arena/rift_arena/foliage.gdshader")
const SOURCE_SHADER := preload("res://assets/arena/rift_arena/source_painted.gdshader")
const MEADOW := preload("res://assets/arena/rift_arena/textures/grass_primary.png")
const GRASS := preload("res://assets/arena/rift_arena/textures/sunlit_grass.png")
const ROCK := preload("res://assets/arena/rift_arena/textures/rock_cliff.png")
const CANOPY := preload("res://assets/arena/rift_arena/textures/canopy_foliage.png")
var _materials: Dictionary = {}

func _ready() -> void:
	_apply_arena_materials(self)

func _apply_arena_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		for index in instance.mesh.get_surface_count():
			var original := instance.mesh.surface_get_material(index) as StandardMaterial3D
			if original == null:
				continue
			var key := original.resource_name
			if not _materials.has(key):
				_materials[key] = _make_material(key, original)
			instance.set_surface_override_material(index, _materials[key])
	for child in node.get_children():
		_apply_arena_materials(child)

func _make_material(key: String, original: StandardMaterial3D) -> Material:
	var shader := ShaderMaterial.new()
	if key.begins_with("LoLSource_"):
		shader.shader = SOURCE_SHADER
		shader.set_shader_parameter("source_albedo", original.albedo_texture)
		return shader
	if key == "RiftWater":
		shader.shader = RIVER_SHADER
		return shader
	if key == "RiftGround":
		shader.shader = GROUND_SHADER
		shader.set_shader_parameter("meadow_atlas", MEADOW)
		shader.set_shader_parameter("grass_texture", GRASS)
		return shader
	if key.begins_with("RiftPine"):
		shader.shader = FOLIAGE_SHADER
		shader.set_shader_parameter("canopy_atlas", CANOPY)
		var tier := float(key.trim_prefix("RiftPine_"))
		shader.set_shader_parameter("tint", Vector3(1.22, 1.48, 1.36) * (0.92 + tier * 0.07))
		return shader
	if key.begins_with("RiftRock") or key.begins_with("RiftStone") or key.begins_with("RiftCrown") or key.begins_with("RiftBark") or key.begins_with("RiftSoil"):
		shader.shader = SURFACE_SHADER
		shader.set_shader_parameter("painted_atlas", ROCK)
		# Atlas pixels supply the surface color; a restrained tint keeps source hues.
		shader.set_shader_parameter("tint", Vector3(1.12, 1.18, 1.08))
		if key.begins_with("RiftRock"):
			shader.set_shader_parameter("atlas_region", Vector4(0.15, 0.07, 0.35, 0.18))
			shader.set_shader_parameter("painted_weight", 0.85)
		elif key.begins_with("RiftStone"):
			shader.set_shader_parameter("atlas_region", Vector4(0.15, 0.033, 0.25, 0.065))
			shader.set_shader_parameter("texture_scale", 0.75)
			shader.set_shader_parameter("painted_weight", 0.85)
		elif key.begins_with("RiftCrown"):
			shader.set_shader_parameter("painted_atlas", CANOPY)
			shader.set_shader_parameter("atlas_region", Vector4(0.19, 0.08, 0.19, 0.15))
			shader.set_shader_parameter("texture_scale", 0.8)
			shader.set_shader_parameter("painted_weight", 0.75)
		else:
			shader.set_shader_parameter("atlas_region", Vector4(0.57, 0.125, 0.1, 0.12))
			shader.set_shader_parameter("painted_weight", 0.5)
		return shader
	var material := original.duplicate() as StandardMaterial3D
	material.albedo_color = material.albedo_color.srgb_to_linear()
	material.metallic_specular = 0.12
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
