class_name TowerModel3D
extends Node3D
## 防御塔/基地水晶的纯 3D 表现代理。只读取 Tower 的位置与摧毁事件，
## 不参与血量、攻击、碰撞、寻路或联网权威状态。

const GROUND_CLIP_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float ground_cutoff = 0.0;
uniform float surface_visible = 1.0;
uniform float flash_amount = 0.0;

void fragment() {
	// fragment() 的 VERTEX 已是蒙皮与模型变换后的视图空间位置；转回世界空间后
	// 才能正确裁掉当前帧仍在地下的完整塔体或待升起废墟。
	float world_height = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	if (world_height < ground_cutoff || surface_visible < 0.5) {
		discard;
	}
	vec4 sampled = texture(albedo_texture, UV) * albedo_color;
	if (sampled.a < 0.1) {
		discard;
	}
	// 受击闪白：向白色轻微混合，隐藏表面已在前面的 discard 中剔除。
	ALBEDO = mix(sampled.rgb, vec3(1.0), flash_amount);
}
"""

var _source: Tower
var _camera: Camera3D
var _model_root: Node3D
var _animation_player: AnimationPlayer
var _animations: Dictionary
var _destroyed := false
var _active_one_shot := &""
var _ground_clip_material_count := 0
var _surface_materials_by_name: Dictionary = {}
# 受击闪白：与单位同样轻微短暂，只混合进裁切材质，不触碰权威状态。
const HIT_FLASH_DURATION := 0.05
const HIT_FLASH_PEAK := 0.22
var _hit_flash_timer := 0.0

func setup(tower: Tower, packed: PackedScene, camera: Camera3D, config: Dictionary) -> bool:
	var instance := packed.instantiate()
	if not instance is Node3D:
		push_warning("塔的 3D 包装场景根节点必须是 Node3D")
		instance.queue_free()
		return false
	_source = tower
	_camera = camera
	_model_root = instance as Node3D
	_animations = config.get("animations", {}).duplicate()
	add_child(_model_root)
	_animation_player = _find_animation_player(_model_root)
	if _animation_player == null:
		push_warning("塔的 3D 模型中未找到 AnimationPlayer")
	else:
		_animation_player.animation_finished.connect(_on_animation_finished)
	# 源模型以世界 Y=0 为地面。废墟几何在存活状态下停在地下，之后会由动画升起，
	# 因此不能静态删面；裁切材质必须逐帧按蒙皮后的世界高度隐藏地下片元。
	_apply_ground_clip_materials(float(config.get("ground_cutoff", 0.0)))
	_show_alive_surfaces()
	_source.destroyed.connect(_on_source_destroyed)
	_source.visual_hit.connect(_on_source_visual_hit)
	_sync_position()
	# 模型默认正面朝世界 +Z（画面下方）。蓝方在下，应转身朝上方红方；红方保持朝下。
	rotation.y = PI if tower.team == 0 else 0.0
	if tower.hp <= 0.0:
		_show_final_ruin()
	else:
		_play_spawn_or_idle()
	return true

func _process(delta: float) -> void:
	if _source == null or not is_instance_valid(_source):
		queue_free()
		return
	_update_hit_flash(delta)
	_sync_position()

func _sync_position() -> void:
	if _source == null or _camera == null:
		return
	position = _screen_to_ground(_source.global_position)

func _screen_to_ground(screen_position: Vector2) -> Vector3:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return Vector3.ZERO
	return origin + direction * (-origin.y / direction.y)

func _play_spawn_or_idle() -> void:
	var spawn_name := StringName(_animations.get("spawn", ""))
	if _has_animation(spawn_name):
		_active_one_shot = spawn_name
		_play_one_shot(spawn_name, float(_animations.get("spawn_duration", 0.0)))
	else:
		_play_idle()

func _play_idle() -> void:
	if _animation_player == null or _destroyed:
		return
	var idle_name := StringName(_animations.get("idle", ""))
	if not _has_animation(idle_name):
		return
	var animation := _animation_player.get_animation(idle_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR
	_active_one_shot = &""
	_animation_player.play(idle_name, 0.08)

func _on_source_destroyed() -> void:
	if _destroyed:
		return
	_destroyed = true
	_hit_flash_timer = 0.0
	_set_flash_amount(0.0)
	_show_destroyed_surfaces()
	var destroy_name := StringName(_animations.get("destroy", ""))
	if _has_animation(destroy_name):
		_active_one_shot = destroy_name
		_play_one_shot(destroy_name, float(_animations.get("destroy_duration", 0.0)))
	else:
		_show_final_ruin()

func _show_final_ruin() -> void:
	_destroyed = true
	_show_destroyed_surfaces()
	if _animation_player == null:
		return
	var ruin_name := StringName(_animations.get("ruin", ""))
	if _has_animation(ruin_name):
		_active_one_shot = &""
		_animation_player.play(ruin_name, 0.0)
		var ruin_length := float(_animation_player.get_animation(ruin_name).length)
		_animation_player.seek(maxf(ruin_length - 0.001, 0.0), true)
		_animation_player.pause()
		return
	# 素材以独立表面保存废墟外观；摧毁动作最后一帧提供废墟的最终骨骼姿态。
	var destroy_name := StringName(_animations.get("destroy", ""))
	if _has_animation(destroy_name):
		_active_one_shot = &""
		_animation_player.play(destroy_name, 0.0)
		var destroy_length := float(_animation_player.get_animation(destroy_name).length)
		_animation_player.seek(maxf(destroy_length - 0.05, 0.0), true)
		_animation_player.pause()

func _play_one_shot(animation_name: StringName, target_duration: float) -> void:
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		return
	animation.loop_mode = Animation.LOOP_NONE
	var playback_speed := 1.0
	if target_duration > 0.001:
		playback_speed = maxf(float(animation.length) / target_duration, 0.01)
	_animation_player.play(animation_name, 0.08, playback_speed)

func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != _active_one_shot:
		return
	if _destroyed:
		_show_final_ruin()
	else:
		_play_idle()

func _has_animation(animation_name: StringName) -> bool:
	return _animation_player != null and animation_name != &"" and _animation_player.has_animation(animation_name)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _apply_ground_clip_materials(cutoff_y: float) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_model_root, meshes)
	var clip_shader := Shader.new()
	clip_shader.code = GROUND_CLIP_SHADER_CODE
	for mesh_instance in meshes:
		var source_mesh := mesh_instance.mesh
		if source_mesh == null:
			continue
		for surface_index in range(source_mesh.get_surface_count()):
			var source_material := source_mesh.surface_get_material(surface_index) as StandardMaterial3D
			if source_material == null or source_material.albedo_texture == null:
				continue
			var clipped_material := ShaderMaterial.new()
			clipped_material.shader = clip_shader
			clipped_material.set_shader_parameter("albedo_texture", source_material.albedo_texture)
			clipped_material.set_shader_parameter("albedo_color", source_material.albedo_color)
			clipped_material.set_shader_parameter("ground_cutoff", cutoff_y)
			mesh_instance.set_surface_override_material(surface_index, clipped_material)
			var material_name := String(source_material.resource_name)
			if not _surface_materials_by_name.has(material_name):
				_surface_materials_by_name[material_name] = []
			var surface_materials: Array = _surface_materials_by_name[material_name]
			surface_materials.append(clipped_material)
			_ground_clip_material_count += 1

func _show_alive_surfaces() -> void:
	_set_configured_surface_state("alive_materials", true)
	_set_configured_surface_state("destroyed_materials", false)

func _show_destroyed_surfaces() -> void:
	_set_configured_surface_state("alive_materials", false)
	_set_configured_surface_state("destroyed_materials", true)

func _set_configured_surface_state(config_key: String, is_visible: bool) -> void:
	var material_names: Array = _animations.get(config_key, [])
	for material_name_variant in material_names:
		var material_name := String(material_name_variant)
		var materials: Array = _surface_materials_by_name.get(material_name, [])
		for material_variant in materials:
			var material := material_variant as ShaderMaterial
			if material != null:
				material.set_shader_parameter("surface_visible", 1.0 if is_visible else 0.0)

func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, result)

## 受击闪白：只写裁切材质的 flash_amount 混合系数；隐藏表面（地下废墟）在
## Shader 里已被 discard，不会因闪白而显形。摧毁时立即归零。
func _on_source_visual_hit() -> void:
	_hit_flash_timer = HIT_FLASH_DURATION
	_set_flash_amount(HIT_FLASH_PEAK)

func _update_hit_flash(delta: float) -> void:
	if _hit_flash_timer <= 0.0:
		return
	_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
	if _hit_flash_timer <= 0.0:
		_set_flash_amount(0.0)
	else:
		_set_flash_amount(HIT_FLASH_PEAK * _hit_flash_timer / HIT_FLASH_DURATION)

func _set_flash_amount(amount: float) -> void:
	for material_list in _surface_materials_by_name.values():
		for material_variant in material_list:
			var material := material_variant as ShaderMaterial
			if material != null:
				material.set_shader_parameter("flash_amount", amount)
