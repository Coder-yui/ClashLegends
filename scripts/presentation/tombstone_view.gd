extends Node3D
## 墓碑包装场景的纯表现控制器：雾气生长、流动与死亡消散均不参与权威逻辑。

const FOG_GROUP := &"tombstone_fog"

var _fog_layers: Array[MeshInstance3D] = []
var _base_scales: Array[Vector3] = []
var _age := 0.0
var _death_elapsed := 0.0
var _death_duration := 0.0
var _dying := false

func _ready() -> void:
	for child in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if not mesh_instance.is_in_group(FOG_GROUP):
			continue
		# 每座墓碑使用独立材质；否则其中一座死亡会把场上所有墓碑的黑雾一起淡出。
		var source_material := mesh_instance.get_active_material(0) as ShaderMaterial
		if source_material == null:
			continue
		var local_material := source_material.duplicate() as ShaderMaterial
		mesh_instance.material_override = local_material
		local_material.set_shader_parameter("layer_seed", float(_fog_layers.size()) * 2.173 + 0.41)
		local_material.set_shader_parameter("fog_visibility", 0.0)
		_fog_layers.append(mesh_instance)
		_base_scales.append(mesh_instance.scale)

func _process(delta: float) -> void:
	_age += delta
	var spawn_visibility := smoothstep(0.0, 0.42, _age)
	var death_visibility := 1.0
	var disperse := 0.0
	if _dying:
		_death_elapsed = minf(_death_elapsed + delta, _death_duration)
		disperse = clampf(_death_elapsed / maxf(_death_duration, 0.001), 0.0, 1.0)
		# 前半段仍包裹墓碑，后半段再快速变薄，避免死亡动画刚开始雾就瞬间消失。
		death_visibility = 1.0 - smoothstep(0.12, 1.0, disperse)
	for index in range(_fog_layers.size()):
		var fog := _fog_layers[index]
		if fog == null or not is_instance_valid(fog):
			continue
		var material := fog.material_override as ShaderMaterial
		if material != null:
			material.set_shader_parameter("fog_visibility", spawn_visibility * death_visibility)
			material.set_shader_parameter("disperse", disperse)
		# 死亡时雾气略微向外摊开、变薄，随后与 Death 动画同时消失。
		var expansion := Vector3(1.0 + disperse * 0.34, 1.0 + disperse * 0.12, 1.0 + disperse * 0.34)
		fog.scale = _base_scales[index] * expansion

## UnitModel3D 在可靠死亡事件到达时调用；仅驱动表现淡出。
func begin_visual_death(duration: float) -> void:
	_dying = true
	_death_elapsed = 0.0
	_death_duration = maxf(duration, 0.05)

## 墓碑形体横向展开且动画 AABB 变化较大，使用稳定的模型顶端锚点放置血条。
func get_health_bar_anchor_local() -> Vector3:
	return Vector3(0.0, 1.34, 0.0)
