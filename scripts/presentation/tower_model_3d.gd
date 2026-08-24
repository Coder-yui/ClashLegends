class_name TowerModel3D
extends Node3D
## 防御塔/基地水晶的纯 3D 表现代理。只读取 Tower 的位置、血量阶段与摧毁事件，
## 不参与血量、攻击、碰撞、寻路或联网权威状态。
## 两种表现模式：
## 1. 阶段模式（公主塔新素材）：塔体表面按血量三等分切换（Base→Stage1→Stage2），
##    掉到哪个阶段就直接播放该阶段碎块（Destroyed 序列的轨道过滤片段，烘焙成
##    正放坠毁轨迹，原动画倒放压缩到演出时长）。跨阶段掉血直接跳播对应阶段的
##    碎块动画并打断旧的；被摧毁直接播第三块，演完定格 Rubble 废墟。
##    坠入地下由裁切材质隐藏，演出结束后彻底隐藏碎块表面。
## 2. 旧模式（基地水晶）：存活/摧毁表面组 + 出生/待机/摧毁动画。

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
# 阶段模式状态：_visual_stage 0/1/2 对应 stage_surfaces 索引；死亡演出由 destroyed 信号驱动。
var _stage_mode := false
var _visual_stage := 0
var _death_pending := false
var _debris_timer := 0.0
var _active_debris_surface := ""

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
	# 源模型以世界 Y=0 为地面。碎块与废墟几何会运动到地下，不能静态删面；
	# 裁切材质必须逐帧按蒙皮后的世界高度隐藏地下片元。
	_apply_ground_clip_materials(float(config.get("ground_cutoff", 0.0)))
	_stage_mode = _animations.has("stage_surfaces")
	if _stage_mode:
		_setup_stage_mode()
	else:
		_show_alive_surfaces()
		if tower.hp <= 0.0:
			_show_final_ruin()
		else:
			_play_spawn_or_idle()
	_source.destroyed.connect(_on_source_destroyed)
	_source.visual_hit.connect(_on_source_visual_hit)
	_sync_position()
	# 模型默认正面朝世界 +Z（画面下方）。蓝方在下，应转身朝上方红方；红方保持朝下。
	rotation.y = PI if tower.team == 0 else 0.0
	return true

func _process(delta: float) -> void:
	if _source == null or not is_instance_valid(_source):
		queue_free()
		return
	_update_hit_flash(delta)
	_update_stage_flow(delta)
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

## ---------------- 阶段模式（公主塔）：血量驱动的掉块演出 ----------------

## 按血量三等分计算塔体阶段：满血 Base、破 2/3 Stage1、破 1/3 Stage2。
func _stage_from_hp(hp: float, max_hp: float) -> int:
	if max_hp <= 0.0:
		return 0
	var ratio := hp / max_hp
	if ratio <= 1.0 / 3.0:
		return 2
	if ratio <= 2.0 / 3.0:
		return 1
	return 0

func _setup_stage_mode() -> void:
	_build_debris_clips()
	if _source.hp <= 0.0:
		# 接入已摧毁的塔（重连/快照恢复）：跳过演出直接定格废墟。
		_destroyed = true
		_set_surface_visible(String(_animations.get("ruin_surface", "Rubble")), true)
		return
	_visual_stage = _stage_from_hp(_source.hp, _source.max_hp)
	var surfaces: Array = _animations.get("stage_surfaces", [])
	for surface_name in _surface_materials_by_name.keys():
		_set_surface_visible(String(surface_name), false)
	if _visual_stage < surfaces.size():
		_set_surface_visible(String(surfaces[_visual_stage]), true)

## 阶段推进与掉块演出：血量掉到哪个阶段就直接跳到哪个阶段（跨阶段不补演
## 中间碎块），播放该阶段碎块并打断可能还在播的旧碎块；演出计时结束时隐藏
## 碎块表面。死亡演出结束后隐藏残核并定格废墟。
func _update_stage_flow(delta: float) -> void:
	if not _stage_mode:
		return
	if not _active_debris_surface.is_empty():
		_debris_timer = maxf(0.0, _debris_timer - delta)
		if _debris_timer <= 0.0:
			# 演出结束后彻底隐藏碎块表面：碎块虽已坠入地下，但蒙皮网格
			# 可能贴着地面残留边缘。
			_set_surface_visible(_active_debris_surface, false)
			_active_debris_surface = ""
			if _death_pending:
				_death_pending = false
				_set_surface_visible(String(_animations.get("final_stage_surface", "Stage3")), false)
				_set_surface_visible(String(_animations.get("ruin_surface", "Rubble")), true)
	if _destroyed or _source == null:
		return
	var target_stage := _stage_from_hp(_source.hp, _source.max_hp)
	if target_stage > _visual_stage:
		_begin_stage_transition(target_stage)

## 阶段切换演出：塔体表面直接换到目标阶段，隐藏还在掉的旧碎块并播放新阶段
## 碎块的坠毁片段（跨阶段掉血跳播对应阶段，不补演中间碎块）。
func _begin_stage_transition(next_stage: int) -> void:
	var surfaces: Array = _animations.get("stage_surfaces", [])
	if next_stage <= 0 or next_stage >= surfaces.size():
		return
	if _visual_stage < surfaces.size():
		_set_surface_visible(String(surfaces[_visual_stage]), false)
	_set_surface_visible(String(surfaces[next_stage]), true)
	_visual_stage = next_stage
	_play_debris(next_stage - 1)

## 死亡演出：塔体换残核并直接播放第三块碎块（不管之前掉到哪），演完隐藏
## 残核定格 Rubble。
func _begin_death_sequence() -> void:
	var surfaces: Array = _animations.get("stage_surfaces", [])
	if _visual_stage < surfaces.size():
		_set_surface_visible(String(surfaces[_visual_stage]), false)
	_visual_stage = surfaces.size()
	_set_surface_visible(String(_animations.get("final_stage_surface", "Stage3")), true)
	if not _play_debris(2):
		# 第三块片段缺失：退回直接定格废墟。
		_set_surface_visible(String(_animations.get("final_stage_surface", "Stage3")), false)
		_hide_active_debris()
		_set_surface_visible(String(_animations.get("ruin_surface", "Rubble")), true)
		return
	_death_pending = true

## 播放第 index 块碎块的坠毁片段（打断在播的旧碎块动画，隐藏其表面）。
## 返回是否成功启动。
func _play_debris(index: int) -> bool:
	var debris: Array = _animations.get("debris", [])
	if _animation_player == null or index < 0 or index >= debris.size():
		return false
	var clip_name := StringName("debris/debris%d" % (index + 1))
	if not _has_animation(clip_name):
		return false
	_hide_active_debris()
	var surface := String(debris[index].get("surface", ""))
	if not surface.is_empty():
		_set_surface_visible(surface, true)
		_active_debris_surface = surface
	_debris_timer = maxf(float(_animations.get("debris_duration", 2.0)), 0.1)
	_animation_player.play(clip_name)
	return true

## 隐藏在掉的碎块表面并清空登记（阶段切换/摧毁打断旧演出时调用）。
func _hide_active_debris() -> void:
	if not _active_debris_surface.is_empty():
		_set_surface_visible(_active_debris_surface, false)
		_active_debris_surface = ""

## 从 Destroyed 序列提取只驱动指定骨骼组的片段，烘焙成"正放坠毁"轨迹后注册到
## 专用动画库（t=0 附着姿态 → t=演出时长 落定地下）。
func _build_debris_clips() -> void:
	if _animation_player == null:
		return
	var destroy_name := StringName(_animations.get("destroy", ""))
	if not _has_animation(destroy_name):
		return
	var source_anim := _animation_player.get_animation(destroy_name)
	var debris: Array = _animations.get("debris", [])
	if debris.is_empty():
		return
	var duration := maxf(float(_animations.get("debris_duration", 2.0)), 0.1)
	var library := AnimationLibrary.new()
	for i in range(debris.size()):
		var entry: Dictionary = debris[i]
		var clip := _extract_bone_clip(source_anim, String(entry.get("bones", "")))
		if clip == null or clip.get_track_count() == 0:
			continue
		var window: Array = entry.get("window", [0.0, source_anim.length])
		_bake_fall_clip(clip, float(window[0]), float(window[1]), duration)
		library.add_animation("debris%d" % (i + 1), clip)
	if not library.get_animation_list().is_empty():
		_animation_player.add_animation_library(&"debris", library)

func _extract_bone_clip(source_anim: Animation, bone_prefix: String) -> Animation:
	if bone_prefix.is_empty():
		return null
	var clip := Animation.new()
	for i in range(source_anim.get_track_count()):
		var track_path := source_anim.track_get_path(i)
		var bone := String(track_path.get_concatenated_subnames())
		if not bone.begins_with(bone_prefix):
			continue
		clip.add_track(source_anim.track_get_type(i))
		var new_index := clip.get_track_count() - 1
		clip.track_set_path(new_index, track_path)
		clip.track_set_interpolation_type(new_index, source_anim.track_get_interpolation_type(i))
		for k in range(source_anim.track_get_key_count(i)):
			clip.track_insert_key(new_index, source_anim.track_get_key_time(i, k), source_anim.track_get_key_value(i, k))
	return clip

## 把组装向片段烘焙为正放坠毁：素材轨迹 t=窗口起点 落定地下、t=窗口终点 附着位，
## 反转时间轴并把窗口时长线性压缩到演出时长后，t=0 即附着姿态、t=演出时长
## 落定地下（原动画倒放）。窗口外的 key（休止/附着的静止段）直接丢弃。
func _bake_fall_clip(clip: Animation, window_start: float, window_end: float, duration: float) -> void:
	var span := maxf(window_end - window_start, 0.1)
	var rebuilt: Array = []
	for i in range(clip.get_track_count()):
		var keys: Array = []
		for k in range(clip.track_get_key_count(i)):
			var old_time := clip.track_get_key_time(i, k)
			if old_time < window_start - 0.001 or old_time > window_end + 0.001:
				continue
			keys.append([clampf((window_end - old_time) / span * duration, 0.0, duration), clip.track_get_key_value(i, k)])
		if keys.is_empty():
			continue
		rebuilt.append({
			"type": clip.track_get_type(i),
			"path": clip.track_get_path(i),
			"interp": clip.track_get_interpolation_type(i),
			"keys": keys,
		})
	while clip.get_track_count() > 0:
		clip.remove_track(0)
	clip.length = duration
	clip.loop_mode = Animation.LOOP_NONE
	for spec in rebuilt:
		clip.add_track(spec.type)
		var new_index := clip.get_track_count() - 1
		clip.track_set_path(new_index, spec.path)
		clip.track_set_interpolation_type(new_index, spec.interp)
		for pair in spec.keys:
			clip.track_insert_key(new_index, float(pair[0]), pair[1])

## ---------------- 旧模式（基地水晶）：表面组 + 动画 ----------------

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
	if _stage_mode:
		_begin_death_sequence()
		return
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
		_set_surface_visible(String(material_name_variant), is_visible)

func _set_surface_visible(surface_name: String, is_visible: bool) -> void:
	var materials: Array = _surface_materials_by_name.get(surface_name, [])
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
