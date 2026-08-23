class_name UnitModel3D
extends Node3D
## 单个 3D 模型的表现代理。只读取 Unit 的插值位置与表现状态，不参与模拟。

const STATE_KEYS := [&"deploy", &"idle", &"move", &"attack"]

var _source: Unit
var _camera: Camera3D
var _model_root: Node3D
var _animation_player: AnimationPlayer
var _animation_names: Dictionary
var _team_ring: MeshInstance3D
var _forward_yaw := 0.0
var _attack_duration := 1.0
var _current_state := -1
var _last_attack_serial := 0
var _playing_attack := false
var _holding_attack_pose := false
var _active_attack_animation := &""
var _active_attack_index := 0
var _attack_hit_timer := 0.0
var _attack_recover_timer := 0.0
var _attack_hit_pending := false
var _attack_recover_pending := false
var _death_animation := &""
var _dying := false
var _hit_flash_timer := 0.0
var _hit_flash_material: StandardMaterial3D
var _flash_meshes: Array[MeshInstance3D] = []
var _original_overlays: Array[Material] = []

func setup(unit: Unit, packed: PackedScene, camera: Camera3D, animations: Dictionary, forward_yaw: float) -> bool:
	# 客户端 Unit 会在默认优先级更新快照插值；3D 代理随后读取最终位置。
	process_priority = 10
	var instance := packed.instantiate()
	if not instance is Node3D:
		push_warning("单位 3D 表现场景的根节点必须是 Node3D")
		instance.queue_free()
		return false
	_source = unit
	_source.died.connect(_on_source_died)
	_source.visual_hit.connect(_on_source_visual_hit)
	_camera = camera
	_model_root = instance as Node3D
	_animation_names = animations.duplicate()
	_forward_yaw = forward_yaw
	# 一套完整挥剑（前摇、命中、后摇）占满一个攻击周期；动画长度不改变战斗计时。
	_attack_duration = maxf(unit.attack_interval, 0.05)
	add_child(_model_root)
	_animation_player = _find_animation_player(_model_root)
	if _animation_player == null:
		push_warning("单位 3D 模型中未找到 AnimationPlayer")
	else:
		_animation_player.animation_finished.connect(_on_animation_finished)
	_create_team_ring()
	_prepare_hit_flash()
	_configure_looping_animations()
	_sync_visual(true, 0.0)
	_update_health_bar_anchor()
	return true

func _process(delta: float) -> void:
	_update_hit_flash(delta)
	if _dying:
		return
	if _source == null or not is_instance_valid(_source):
		queue_free()
		return
	_update_attack_stages(delta)
	_sync_visual(false, delta)
	_update_health_bar_anchor()

func _sync_visual(force: bool, delta: float) -> void:
	var screen_position := _source.get_visual_screen_position()
	var ground_position := _screen_to_ground(screen_position)
	position = ground_position

	var facing_2d := _source.get_visual_facing_direction()
	var facing_ground := _screen_to_ground(screen_position + facing_2d * 20.0)
	var facing_3d := facing_ground - ground_position
	facing_3d.y = 0.0
	if facing_3d.length_squared() > 0.0001:
		var target_yaw := atan2(facing_3d.x, facing_3d.z) + _forward_yaw
		rotation.y = target_yaw if force else lerp_angle(rotation.y, target_yaw, minf(delta * 12.0, 1.0))

	var attack_serial := _source.net_attack_visual_serial if _source._in_client_mode() else _source.get_attack_visual_serial()
	if attack_serial != _last_attack_serial:
		_last_attack_serial = attack_serial
		_play_attack(attack_serial)
	var state := _source.net_visual_state if _source._in_client_mode() else _source.get_visual_state_code()
	# attack_serial 只触发一次挥剑；逻辑仍处于攻击状态时，动作结束后保持末帧。
	# 只有失去目标或开始移动，才从当前攻击姿态混合回对应的基础状态。
	if state != 3 and (_playing_attack or _holding_attack_pose):
		_playing_attack = false
		_holding_attack_pose = false
		_attack_hit_pending = false
		_attack_recover_pending = false
		_active_attack_animation = &""
		_current_state = state
		_play_state(state, 0.12)
	elif state != 3 and not _playing_attack and (force or state != _current_state):
		_current_state = state
		_play_state(state)
	elif state == 3 and not _playing_attack and not _holding_attack_pose and force:
		_current_state = 1
		_play_state(1)
	if _animation_player != null:
		_animation_player.speed_scale = 0.0 if _source.frozen_timer > 0.0 else 1.0

func _screen_to_ground(screen_position: Vector2) -> Vector3:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return Vector3.ZERO
	return origin + direction * (-origin.y / direction.y)

## 用包装场景中全部网格的实际投影顶部定位血条；模型缩放或脚底校正后无需再手填像素偏移。
func _update_health_bar_anchor() -> void:
	if _source == null or _camera == null or _flash_meshes.is_empty():
		return
	var ground_screen := _camera.unproject_position(global_position)
	var top_screen_y := ground_screen.y
	var found_visible_point := false
	for mesh_instance in _flash_meshes:
		if mesh_instance == null or not is_instance_valid(mesh_instance):
			continue
		var bounds := mesh_instance.get_aabb()
		for corner_index in range(8):
			var corner := Vector3(
				bounds.position.x + bounds.size.x * float(corner_index & 1),
				bounds.position.y + bounds.size.y * float((corner_index >> 1) & 1),
				bounds.position.z + bounds.size.z * float((corner_index >> 2) & 1)
			)
			var world_corner := mesh_instance.to_global(corner)
			if _camera.is_position_behind(world_corner):
				continue
			top_screen_y = minf(top_screen_y, _camera.unproject_position(world_corner).y)
			found_visible_point = true
	if found_visible_point:
		# 武器/披风等网格也在 AABB 内，直接取最顶点会把血条拉离头部；
		# 以体型半径给人物头顶设合理上限，避免红蓝朝向或动作造成大幅漂移。
		var max_head_height := _source.visual_radius * 3.25
		top_screen_y = maxf(top_screen_y, ground_screen.y - max_head_height)
		_source.set_visual_head_world_position(Vector2(ground_screen.x, top_screen_y))

func _play_state(state: int, blend_time: float = 0.08) -> void:
	if _animation_player == null:
		return
	var key: StringName = STATE_KEYS[clampi(state, 0, STATE_KEYS.size() - 1)]
	var animation_name := StringName(_animation_names.get(String(key), ""))
	if animation_name == &"" or not _animation_player.has_animation(animation_name):
		animation_name = StringName(_animation_names.get("idle", ""))
	if animation_name != &"" and _animation_player.has_animation(animation_name):
		var playback_speed := _state_playback_speed(state, animation_name)
		_animation_player.play(animation_name, blend_time, playback_speed)

func _play_attack(serial: int) -> void:
	if _animation_player == null or serial <= 0:
		return
	var configured = _animation_names.get("attack", [])
	var attacks: Array = configured if configured is Array else [configured]
	if attacks.is_empty():
		return
	_active_attack_index = (serial - 1) % attacks.size()
	var animation_name := StringName(attacks[_active_attack_index])
	if animation_name == &"" or not _animation_player.has_animation(animation_name):
		return
	_attack_hit_pending = false
	_attack_recover_pending = false
	_attack_hit_timer = 0.0
	_attack_recover_timer = 0.0
	_active_attack_animation = animation_name
	_playing_attack = true
	_holding_attack_pose = false
	_current_state = 3
	var hit_animations := _animation_list("attack_hit")
	if _active_attack_index < hit_animations.size() and StringName(hit_animations[_active_attack_index]) != &"":
		# 分段普攻只影响表现：Start 在权威 first_hit 窗口内播放，计时到点切到 Hit。
		_attack_hit_pending = true
		_attack_hit_timer = maxf(_source.first_hit_time, 0.01)
		_play_attack_clip(animation_name, _attack_hit_timer)
	else:
		_play_attack_clip(animation_name, _attack_duration)

func _update_attack_stages(delta: float) -> void:
	if not _playing_attack or _animation_player == null:
		return
	# 冰冻期间模拟攻击计时不推进，分段表现计时也必须同步暂停。
	if _source.frozen_timer > 0.0:
		return
	if _attack_hit_pending:
		_attack_hit_timer = maxf(0.0, _attack_hit_timer - delta)
		if _attack_hit_timer <= 0.0:
			_attack_hit_pending = false
			var hit_animations := _animation_list("attack_hit")
			if _active_attack_index < hit_animations.size():
				var hit_name := StringName(hit_animations[_active_attack_index])
				var recover_animations := _animation_list("attack_recover")
				var recover_name := &""
				if _active_attack_index < recover_animations.size():
					recover_name = StringName(recover_animations[_active_attack_index])
				var recover_delay := _attack_recover_delay(_active_attack_index)
				_play_attack_clip(hit_name, recover_delay if recover_name != &"" else _attack_hit_duration(_active_attack_index))
				if recover_name != &"":
					_attack_recover_pending = true
					_attack_recover_timer = recover_delay
		return
	if _attack_recover_pending:
		_attack_recover_timer = maxf(0.0, _attack_recover_timer - delta)
		if _attack_recover_timer <= 0.0:
			_attack_recover_pending = false
			var recover_animations := _animation_list("attack_recover")
			if _active_attack_index < recover_animations.size():
				_play_attack_clip(StringName(recover_animations[_active_attack_index]), 0.0)

func _play_attack_clip(animation_name: StringName, target_duration: float) -> void:
	if animation_name == &"" or not _animation_player.has_animation(animation_name):
		return
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		return
	animation.loop_mode = Animation.LOOP_NONE
	var playback_speed := 1.0
	if target_duration > 0.001:
		playback_speed = maxf(float(animation.length) / target_duration, 0.01)
	_active_attack_animation = animation_name
	_animation_player.play(animation_name, 0.05, playback_speed)

func _animation_list(key: String) -> Array:
	var configured = _animation_names.get(key, [])
	return configured if configured is Array else [configured]

func _attack_recover_delay(index: int) -> float:
	var configured = _animation_names.get("attack_recover_delay", 0.3)
	if configured is Array:
		var values := configured as Array
		if not values.is_empty():
			return maxf(float(values[index % values.size()]), 0.01)
	return maxf(float(configured), 0.01)

func _attack_hit_duration(index: int) -> float:
	var configured = _animation_names.get("attack_hit_duration", _attack_duration)
	if configured is Array:
		var values := configured as Array
		if not values.is_empty():
			return maxf(float(values[index % values.size()]), 0.01)
	return maxf(float(configured), 0.01)

## 部署动画按部署窗口缩放；逐次攻击动作有独立时长，不在这里绑定攻击间隔。
func _state_playback_speed(state: int, animation_name: StringName) -> float:
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		return 1.0
	var target_duration := 0.0
	match state:
		0:
			target_duration = _source.deploy_time
	if target_duration <= 0.001:
		return 1.0
	return maxf(float(animation.length) / target_duration, 0.01)

func _configure_looping_animations() -> void:
	if _animation_player == null:
		return
	for key in ["idle", "move"]:
		var animation_name := StringName(_animation_names.get(key, ""))
		if animation_name == &"" or not _animation_player.has_animation(animation_name):
			continue
		var animation := _animation_player.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR
	for key in ["attack", "attack_hit", "attack_recover"]:
		for value in _animation_list(key):
			var animation_name := StringName(value)
			if animation_name != &"" and _animation_player.has_animation(animation_name):
				var animation := _animation_player.get_animation(animation_name)
				if animation != null:
					animation.loop_mode = Animation.LOOP_NONE

func _on_animation_finished(animation_name: StringName) -> void:
	if _dying:
		if animation_name == _death_animation:
			queue_free()
		return
	if not _playing_attack or animation_name != _active_attack_animation:
		return
	# 分段动作的 Start/Hit 由表现计时器继续推进，不能被普通“动作播完”逻辑提前截断。
	if _attack_hit_pending or _attack_recover_pending:
		return
	_playing_attack = false
	# AnimationPlayer 停在非循环动画的最后一帧。只要模拟仍锁定攻击目标，
	# 就保留这套骨骼姿态，下一次攻击从此处短混合到另一套动作。
	var state := _source.net_visual_state if _source._in_client_mode() else _source.get_visual_state_code()
	if state == 3:
		_holding_attack_pose = true
		_current_state = 3
	else:
		_holding_attack_pose = false
		_active_attack_animation = &""
		_current_state = state
		_play_state(state, 0.12)

func _on_source_died() -> void:
	if _dying:
		return
	_dying = true
	_playing_attack = false
	_holding_attack_pose = false
	_attack_hit_pending = false
	_attack_recover_pending = false
	_active_attack_animation = &""
	_hit_flash_timer = 0.0
	_set_hit_flash(false)
	if _team_ring != null:
		_team_ring.hide()
	if _animation_player == null:
		queue_free()
		return
	_death_animation = StringName(_animation_names.get("death", ""))
	if _death_animation == &"" or not _animation_player.has_animation(_death_animation):
		queue_free()
		return
	var animation := _animation_player.get_animation(_death_animation)
	if animation != null:
		animation.loop_mode = Animation.LOOP_NONE
	# 死亡不再受生前冰冻状态影响；播完素材的完整动作后再清理纯视觉代理。
	_animation_player.speed_scale = 1.0
	_animation_player.play(_death_animation, 0.08)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _create_team_ring() -> void:
	var ring_mesh := CylinderMesh.new()
	var ring_radius := maxf(_source.visual_radius / 40.0, 0.42)
	ring_mesh.top_radius = ring_radius
	ring_mesh.bottom_radius = ring_radius
	ring_mesh.height = 0.025
	ring_mesh.radial_segments = 40

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.20, 0.55, 1.0, 0.72) if _source.team == 0 else Color(1.0, 0.24, 0.18, 0.72)
	ring_mesh.material = material

	_team_ring = MeshInstance3D.new()
	_team_ring.name = "TeamRing"
	_team_ring.mesh = ring_mesh
	_team_ring.position.y = 0.01
	_team_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_team_ring)

func _prepare_hit_flash() -> void:
	_hit_flash_material = StandardMaterial3D.new()
	_hit_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# LoL 风格的轻微泛白：保留原材质和角色辨识度，不做整模型纯白剪影。
	_hit_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hit_flash_material.albedo_color = Color(1.0, 1.0, 1.0, 0.22)
	_collect_flash_meshes(_model_root)

func _collect_flash_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		_flash_meshes.append(mesh_instance)
		_original_overlays.append(mesh_instance.material_overlay)
	for child in node.get_children():
		_collect_flash_meshes(child)

func _on_source_visual_hit() -> void:
	if _dying:
		return
	_hit_flash_timer = 0.05
	_set_hit_flash(true)

func _update_hit_flash(delta: float) -> void:
	if _hit_flash_timer <= 0.0:
		return
	_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
	if _hit_flash_timer <= 0.0:
		_set_hit_flash(false)

func _set_hit_flash(enabled: bool) -> void:
	for i in range(_flash_meshes.size()):
		var mesh_instance := _flash_meshes[i]
		if mesh_instance == null or not is_instance_valid(mesh_instance):
			continue
		mesh_instance.material_overlay = _hit_flash_material if enabled else _original_overlays[i]
