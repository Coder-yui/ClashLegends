extends Node3D
## 只读权威状态；原版触手的常驻、拍击和R生成提示各自管理生命周期。
const SOURCE_SLAM_WIDTH := 200.0
const SOURCE_SKIN_SCALE := 0.9
const PLAYER := "res://assets/effects/soul_tentacle/player.gd"
var _players: Dictionary = {}
var _stats: Dictionary
var _hit_time := 0.75
var _age := 0.0
var _dead := false
var _combat_driven := false
var _death_duration := 0.8
var _death_elapsed := 0.0
var _death_start_age := 0.0

func _ready() -> void:
	_stats = CardDB.get_unit_stats("soul_tentacle")
	_hit_time = float(_stats.first_hit)
	var native_scale := float(_stats.fixed_attack_width) / 40.0 / SOURCE_SLAM_WIDTH
	# 原皮肤skinScale属于网格自身，粒子仍按拍击宽度统一映射。
	$Model.scale = Vector3.ONE * native_scale * SOURCE_SKIN_SCALE
	for kind in ["slam", "base_active", "activation", "avatar", "indicator_blue", "indicator_red"]:
		var player: Node3D = load(PLAYER).new()
		player.add_to_group("presentation_fx")
		add_child(player)
		player.load_kind(kind)
		player.setup_native(native_scale)
		if kind.begins_with("indicator_"):
			player.fit_indicator(Vector2(float(_stats.fixed_attack_width), float(_stats.fixed_attack_length)) / 40.0)
		player.visible = false
		_players[kind] = player
	for mesh_instance in $Model.find_children("*", "MeshInstance3D", true, false):
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in mesh_instance.mesh.get_surface_count():
			# 源P_TentacleBase的MatOverride贴图全透明；主体来自Avatar附着层。
			var invisible := StandardMaterial3D.new()
			invisible.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			invisible.albedo_color = Color(0, 0, 0, 0)
			mesh_instance.set_surface_override_material(surface, _players.avatar.make_overlay(invisible))

	_ambient(1.0) # 独立模型预览没有权威Unit，也必须初始化附着材质。

func _ambient(age: float) -> void:
	_players.avatar.seek_attached_loop(age)
	_players.avatar.update_attached(true)
	_players.base_active.visible = true
	_players.base_active.seek(age)

func _process(delta: float) -> void:
	if _dead:
		_death_elapsed += delta
		# 原粒子最长尾迹3秒，适配压缩到项目死亡窗口。
		_players.base_active.seek(_death_start_age + _death_elapsed * 3.0 / _death_duration)
	elif not _combat_driven:
		_age += delta
		_ambient(1.0 + _age)

func begin_visual_death(duration: float) -> void:
	if _dead: return
	_dead = true
	_death_duration = maxf(duration, 0.05)
	_death_start_age = _players.base_active._age
	_players.base_active.stop_emitting()
	for kind in ["slam", "activation", "indicator_blue", "indicator_red"]: _players[kind].visible = false

func finish_visual_death() -> void:
	$Model.visible = false
	for player in _players.values(): player.visible = false
	_players.avatar.update_attached(false)
	set_process(false)

func sync_combat_visual(state: UnitPresentationState, delta: float, dying: bool) -> void:
	_combat_driven = true
	if not state.frozen and not _dead: _age += delta
	_players.avatar.seek_attached_loop(_age)
	_players.avatar.update_attached(true)
	_players.avatar.visible = false # 附着材质独立；瞬时fireLine只由技能开启播放器播放。
	if dying or state.dead:
		begin_visual_death(0.8)
		for kind in ["slam", "activation", "indicator_blue", "indicator_red"]: _players[kind].visible = false
		return
	# IdleAngry、Spawn和Attack都是激活态，不能把无目标待机误当Dormant。
	_players.base_active.visible = true
	_players.base_active.seek(_age)
	var elapsed := state.attack_elapsed
	var attacking := state.behavior == 3 and state.attack_serial > 0
	var camera := get_viewport().get_camera_3d()
	var viewer_team := 1 if camera != null and bool(camera.get_meta("canvas_flipped", false)) else 0
	var indicator_kind := "indicator_blue" if state.team == viewer_team else "indicator_red"
	for kind in ["indicator_blue", "indicator_red"]:
		_players[kind].visible = attacking and elapsed < _hit_time and kind == indicator_kind
		if _players[kind].visible: _players[kind].seek(maxf(elapsed, 1.0 / 120.0))
	_players.slam.visible = attacking and elapsed >= _hit_time and elapsed < float(_stats.interval)
	if _players.slam.visible: _players.slam.seek(elapsed - _hit_time)
	# 原AvatarActive.fireLine：白色调制保留纹理橙红色，延迟0.15秒、粒子0.4秒。
	var buff_clock := state.active_buff_clock
	_players.activation.visible = state.active_buff and buff_clock.y > 0.0 and buff_clock.x <= float(_players.activation._data.duration)
	if _players.activation.visible: _players.activation.seek(buff_clock.x)
