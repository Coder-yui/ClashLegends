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
var _death_animation := &""
var _dying := false

func setup(unit: Unit, packed: PackedScene, camera: Camera3D, animations: Dictionary, forward_yaw: float) -> bool:
	var instance := packed.instantiate()
	if not instance is Node3D:
		push_warning("单位 3D 表现场景的根节点必须是 Node3D")
		instance.queue_free()
		return false
	_source = unit
	_source.died.connect(_on_source_died)
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
	_configure_looping_animations()
	_sync_visual(true, 0.0)
	return true

func _process(delta: float) -> void:
	if _dying:
		return
	if _source == null or not is_instance_valid(_source):
		queue_free()
		return
	_sync_visual(false, delta)

func _sync_visual(force: bool, delta: float) -> void:
	var screen_position := _source.global_position + _source._vis_offset
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
	var animation_name := StringName(attacks[(serial - 1) % attacks.size()])
	if animation_name == &"" or not _animation_player.has_animation(animation_name):
		return
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		return
	animation.loop_mode = Animation.LOOP_NONE
	var playback_speed := maxf(float(animation.length) / _attack_duration, 0.01)
	_active_attack_animation = animation_name
	_playing_attack = true
	_holding_attack_pose = false
	_current_state = 3
	_animation_player.play(animation_name, 0.07, playback_speed)

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
	var configured = _animation_names.get("attack", [])
	var attacks: Array = configured if configured is Array else [configured]
	for value in attacks:
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
	_active_attack_animation = &""
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
