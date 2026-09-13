extends Node3D
## 太阳圆盘的组合包装：动态圆盘 + 已烘焙为单一 Rubble 表面的静态公主塔废墟。
## 本脚本只处理纯表现：固定废墟朝向和死亡末帧显隐。

const GROUND_CLIP_SHADER_CODE := """
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float metallic = 0.0;
uniform float roughness = 1.0;
uniform float ground_cutoff = 0.0;

void fragment() {
	float world_height = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	if (world_height < ground_cutoff) {
		discard;
	}
	vec4 sampled = texture(albedo_texture, UV) * albedo_color;
	if (sampled.a < 0.1) {
		discard;
	}
	ALBEDO = sampled.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
"""
const SPAWN_RUIN_CUTOFF := 0.85

var _source: Unit
var _built_on_tower_ruin := false
var _ruin_world_yaw := INF
var _ground_clip_materials: Array[ShaderMaterial] = []
var _spawn_clip_active := false


func configure_unit_visual(source: Unit) -> void:
	_source = source
	_built_on_tower_ruin = source.built_on_tower_ruin
	var ruin_root := get_node_or_null("RuinBase") as Node3D
	if ruin_root != null:
		# 真实塔墟由 TowerModel3D 保留；此处隐藏自带基座，避免双层废墟叠模。
		ruin_root.visible = not _built_on_tower_ruin
	_apply_ground_clip_materials()


func _process(_delta: float) -> void:
	if _spawn_clip_active and (_source == null or not is_instance_valid(_source) or _source.is_deployed()):
		_set_ground_cutoff(0.0)
		_spawn_clip_active = false


## 战场背景是 2D，无法靠深度缓冲遮住地下模型；圆盘材质因此按世界地面高度裁切。
## 地面以上仍保留普通深度测试，进入废墟内部的碎片会继续被废墟自然遮挡。
func _apply_ground_clip_materials() -> void:
	var disc_root := get_node_or_null("DiscModel") as Node3D
	if disc_root == null:
		return
	var shader := Shader.new()
	shader.code = GROUND_CLIP_SHADER_CODE
	var initial_cutoff := SPAWN_RUIN_CUTOFF if _source != null and not _source.is_deployed() else 0.0
	for node in disc_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source_material := mesh_instance.get_active_material(surface_index) as BaseMaterial3D
			if source_material == null:
				continue
			var clip_material := ShaderMaterial.new()
			clip_material.resource_local_to_scene = true
			clip_material.shader = shader
			clip_material.set_shader_parameter("albedo_texture", source_material.albedo_texture)
			clip_material.set_shader_parameter("albedo_color", source_material.albedo_color)
			clip_material.set_shader_parameter("metallic", source_material.metallic)
			clip_material.set_shader_parameter("roughness", source_material.roughness)
			clip_material.set_shader_parameter("ground_cutoff", initial_cutoff)
			mesh_instance.set_surface_override_material(surface_index, clip_material)
			_ground_clip_materials.append(clip_material)
	_spawn_clip_active = initial_cutoff > 0.0 and not _ground_clip_materials.is_empty()


func _set_ground_cutoff(value: float) -> void:
	for material in _ground_clip_materials:
		if material != null:
			material.set_shader_parameter("ground_cutoff", value)


## UnitModel3D 随权威朝向旋转；自带废墟反向抵消，保持部署首帧的世界朝向。
func sync_visual_facing(parent_yaw: float) -> void:
	var ruin_root := get_node_or_null("RuinBase") as Node3D
	if ruin_root == null:
		return
	if is_inf(_ruin_world_yaw):
		_ruin_world_yaw = parent_yaw + ruin_root.rotation.y
	ruin_root.rotation.y = _ruin_world_yaw - parent_yaw


func begin_visual_death(_duration: float) -> void:
	# 废墟保持到死亡片段完整播完；Spawn / Death 始终沿用正常深度遮挡。
	_set_ground_cutoff(0.0)
	_spawn_clip_active = false


func finish_visual_death() -> void:
	var ruin_root := get_node_or_null("RuinBase") as Node3D
	if ruin_root != null and not _built_on_tower_ruin:
		# 废墟没有死亡片段，在圆盘 Death 的最后一帧直接移除。
		ruin_root.hide()


## 原 AzirSunDisc Disk 遮罩只启用第 11/12 号骨骼。
## 复制实例动画后裁掉静态基座轨道，两个攻击片段只驱动圆盘上部。
func prepare_visual_animations() -> void:
	var players := get_node("DiscModel").find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var player := players[0] as AnimationPlayer
	for library_name in player.get_animation_library_list():
		var library := player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		for clip_name in ["Attack1_BASE", "Attack2_BASE"]:
			if not library.has_animation(clip_name):
				continue
			var clip := library.get_animation(clip_name)
			for track in range(clip.get_track_count() - 1, -1, -1):
				var bone := String(clip.track_get_path(track).get_concatenated_subnames())
				if bone not in ["C_Buffbone_Glb_Chest_Loc", "Buffbone_Cstm_Obelisk_Tip"]:
					clip.remove_track(track)
		player.remove_animation_library(library_name)
		player.add_animation_library(library_name, library)
