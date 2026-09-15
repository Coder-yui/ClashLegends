class_name TowerModel3D
extends Node3D
## 防御塔/基地水晶的纯 3D 表现代理。只读取 Tower 的位置、血量阶段与摧毁事件，
## 不参与血量、攻击、碰撞、寻路或联网权威状态。
## 两种表现模式：
## 1. 阶段模式：Base→Stage1→Stage2；Broken1/2/3 使用原版 Break1/2/3 动画。
##    每块碎块独立播放，跨阶段伤害只触发目标阶段；死亡立即显示 Rubble。
##    坠入地下由裁切材质隐藏，原片结束后隐藏碎块表面。
## 2. 水晶模式：存活/摧毁表面组 + 出生/待机/摧毁动画。

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
	vec3 world_position = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float world_height = world_position.y;
	// 正交相机射线与地面相交：地下几何只能从水晶开口看到。
	if (ground_cutoff < 0.0 && world_height < 0.0) {
		vec3 to_camera = INV_VIEW_MATRIX[2].xyz;
		vec3 aperture = world_position - to_camera * world_height / to_camera.y;
		if (length(aperture.xz - MODEL_MATRIX[3].xz) > 1.35) { discard; }
	}
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
var _spawn_hold_remaining := 0.0
var _death_pending := false
var _debris_timer := 0.0
var _active_debris_surface := ""
var _debris_layers: Array[Dictionary] = []

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
		_apply_animation_masks()
		_animation_player.animation_finished.connect(_on_animation_finished)
	# 源模型以世界 Y=0 为地面。碎块与废墟几何会运动到地下，不能静态删面；
	# 裁切材质必须逐帧按蒙皮后的世界高度隐藏地下片元。
	_apply_ground_clip_materials(float(config.get("ground_cutoff", 0.0)))
	_stage_mode = _animations.has("stage_surfaces")
	if _stage_mode:
		_setup_stage_mode()
	else:
		if _animation_player != null:
			_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_show_alive_surfaces()
		if tower.hp <= 0.0:
			_show_final_ruin()
		else:
			_begin_spawn_sequence()
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
	var animation_delta := delta
	if _spawn_hold_remaining > 0.0 and not _destroyed:
		var held := minf(_spawn_hold_remaining, animation_delta)
		_spawn_hold_remaining -= held
		animation_delta -= held
		if _spawn_hold_remaining <= 0.000001:
			_spawn_hold_remaining = 0.0
			_play_spawn_or_idle()
	if not _stage_mode:
		_advance_nexus_animation(animation_delta)
	_update_hit_flash(delta)
	_update_stage_flow(delta)
	_sync_position()

## 原图零混合 Sequencer：跨片段帧的剩余时间继续推进下一片段，不能在首帧停一拍。
func _advance_nexus_animation(delta: float) -> void:
	if _animation_player == null or not _animation_player.is_playing() or delta <= 0.0:
		return
	if _active_one_shot != &"":
		var clip := _animation_player.get_animation(_active_one_shot)
		var speed := maxf(_animation_player.get_playing_speed(), 0.001)
		var remaining := maxf(clip.length - _animation_player.current_animation_position, 0.0) / speed
		if delta >= remaining:
			var finished := _active_one_shot
			_animation_player.seek(clip.length, true)
			_on_animation_finished(finished)
			if _animation_player.is_playing():
				_animation_player.advance(maxf(delta - remaining, 0.0))
			return
	_animation_player.advance(delta)

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
	return PresentationConfig.structure_damage_stage(hp, max_hp)

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
	for layer in _debris_layers.duplicate():
		layer.remaining = maxf(0.0, float(layer.remaining) - delta)
		if layer.remaining <= 0.0:
			_set_surface_visible(layer.surface, false)
			layer.player.queue_free()
			_debris_layers.erase(layer)
	if _debris_layers.is_empty():
		_active_debris_surface = ""
		_death_pending = false
	if _destroyed or _source == null:
		return
	var target_stage := _stage_from_hp(_source.hp, _source.max_hp)
	if target_stage > _visual_stage:
		_begin_stage_transition(target_stage)

## 塔体直接换到目标阶段；已有碎块继续独立播放，跨段不补演中间碎块。
func _begin_stage_transition(next_stage: int) -> void:
	var surfaces: Array = _animations.get("stage_surfaces", [])
	if next_stage <= 0 or next_stage >= surfaces.size():
		return
	if _visual_stage < surfaces.size():
		_set_surface_visible(String(surfaces[_visual_stage]), false)
	_set_surface_visible(String(surfaces[next_stage]), true)
	_visual_stage = next_stage
	_play_debris(next_stage - 1)

## 原表 Break3：立即切到 Rubble，独立播放第三组碎块。
func _begin_death_sequence() -> void:
	var surfaces: Array = _animations.get("stage_surfaces", [])
	for surface in surfaces: _set_surface_visible(String(surface), false)
	_set_surface_visible(String(_animations.get("final_stage_surface", "Stage3")), false)
	_set_surface_visible(String(_animations.get("ruin_surface", "Rubble")), true)
	_visual_stage = surfaces.size()
	_play_debris(2)
	_death_pending = true

## 为第 index 组碎块创建独立播放器，保留之前掉落中的碎块。
## 返回是否成功启动。
func _play_debris(index: int) -> bool:
	var debris: Array = _animations.get("debris", [])
	if _animation_player == null or index < 0 or index >= debris.size():
		return false
	var clip_name := StringName("debris/debris%d" % (index + 1))
	if not _has_animation(clip_name):
		return false
	var surface := String(debris[index].get("surface", ""))
	_set_surface_visible(surface, true)
	_active_debris_surface = surface
	var player := AnimationPlayer.new()
	_animation_player.get_parent().add_child(player)
	player.root_node = _animation_player.root_node
	var library := AnimationLibrary.new()
	var clip := _animation_player.get_animation(clip_name)
	library.add_animation(&"break", clip)
	player.add_animation_library(&"", library)
	player.play(&"break")
	_debris_timer = clip.length
	_debris_layers.append({"player": player, "surface": surface, "remaining": clip.length})
	return true

## 从原版 Break 动作提取相应骨骼组，保留原始轨迹和时长。
func _build_debris_clips() -> void:
	if _animation_player == null:
		return
	var debris: Array = _animations.get("debris", [])
	if debris.is_empty():
		return
	var library := AnimationLibrary.new()
	for i in range(debris.size()):
		var entry: Dictionary = debris[i]
		var native := StringName(entry.get("animation", ""))
		if not _has_animation(native):
			push_error("Missing native turret break animation: %s" % native)
			continue
		var original := _animation_player.get_animation(native)
		var clip := _extract_bone_clip(original, String(entry.get("bones", "")))
		if clip == null or clip.get_track_count() == 0:
			continue
		clip.length = original.length
		clip.loop_mode = Animation.LOOP_NONE
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

## 原图 Base 与 Destroyed 是互补骨骼遮罩；只修改实例动画库。
func _apply_animation_masks() -> void:
	var base_bones: Array = _animations.get("base_bones", [])
	if base_bones.is_empty():
		return
	for library_name in _animation_player.get_animation_library_list():
		var original := _animation_player.get_animation_library(library_name)
		var library := original.duplicate(true) as AnimationLibrary
		_animation_player.remove_animation_library(library_name)
		_animation_player.add_animation_library(library_name, library)
		for name in library.get_animation_list():
			var full_name := String(name) if String(library_name).is_empty() else String(library_name) + "/" + String(name)
			var is_base := full_name in [String(_animations.get("spawn_hold", "")), String(_animations.get("spawn", "")), String(_animations.get("idle", ""))]
			var is_destroy := full_name == String(_animations.get("destroy", ""))
			if not is_base and not is_destroy:
				continue
			var clip := library.get_animation(name)
			for track in range(clip.get_track_count() - 1, -1, -1):
				var path := clip.track_get_path(track)
				if path.get_subname_count() == 0:
					continue
				var bone := String(path.get_subname(0))
				if (is_base and bone not in base_bones) or (is_destroy and bone in base_bones):
					clip.remove_track(track)

func _begin_spawn_sequence() -> void:
	var hold := StringName(_animations.get("spawn_hold", ""))
	if _has_animation(hold):
		_spawn_hold_remaining = float(_animations.get("spawn_hold_duration", 0.0))
		_animation_player.play(hold, 0.0)
		_animation_player.seek(0.0, true)
		_animation_player.pause()
		if _spawn_hold_remaining > 0.0:
			return
	_play_spawn_or_idle()

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
		_animation_player.play(idle_name, float(_animations.get("blend_duration", 0.08)))

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
	_animation_player.play(animation_name, float(_animations.get("blend_duration", 0.08)), playback_speed)

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
