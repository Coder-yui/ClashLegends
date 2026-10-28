extends Node3D
## 只读已同步的攻击序号、进度与增益；几何不参与伤害。
## 原版 PassiveTentacleWidth=200；1格=1个3D单位，按权威宽度统一缩放。
const SOURCE_SLAM_WIDTH := 200.0
const PLAYER := "res://assets/effects/soul_tentacle/player.gd"
var _players: Dictionary = {}
var _stats: Dictionary
var _hit_time := 0.75
var _age := 0.0
var _buff_age := 0.0

func _ready() -> void:
	_stats = CardDB.get_unit_stats("soul_tentacle")
	_hit_time = float(_stats.first_hit)
	var native_scale := float(_stats.fixed_attack_width) / 40.0 / SOURCE_SLAM_WIDTH
	$Model.scale = Vector3.ONE * native_scale
	for kind in ["warning", "active", "spawn", "burst", "avatar", "dormant", "indicator_blue", "indicator_red"]:
		var player: Node3D = load(PLAYER).new()
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
			var invisible := StandardMaterial3D.new()
			invisible.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			invisible.albedo_color = Color(0, 0, 0, 0)
			var overlay: Material = _players.dormant.make_overlay(invisible)
			overlay = _players.avatar.make_overlay(overlay)
			mesh_instance.set_surface_override_material(surface, overlay)
	_players.dormant.seek(1.0)
	_players.dormant.update_attached(true)

func sync_combat_visual(state: UnitPresentationState, delta: float, dying: bool) -> void:
	_age += delta
	if dying or state.dead:
		for player in _players.values(): player.visible = false
		_players.avatar.update_attached(false)
		_players.dormant.seek(1.0)
		_players.dormant.update_attached(true)
		return
	_players.avatar.seek_attached_loop(_age)
	_players.dormant.seek_attached_loop(_age)
	_players.avatar.update_attached(state.behavior == 3 or state.active_buff)
	_players.dormant.update_attached(state.behavior != 3 and not state.active_buff)
	var elapsed := state.attack_elapsed
	var attacking := state.behavior == 3 and state.attack_serial > 0
	var camera := get_viewport().get_camera_3d()
	var viewer_team := 1 if camera != null and bool(camera.get_meta("canvas_flipped", false)) else 0
	var indicator_kind := "indicator_blue" if state.team == viewer_team else "indicator_red"
	for kind in ["indicator_blue", "indicator_red"]:
		_players[kind].visible = attacking and elapsed < _hit_time and kind == indicator_kind
		if _players[kind].visible: _players[kind].seek(maxf(elapsed, 1.0 / 120.0))
	_players.warning.visible = attacking and elapsed >= _hit_time and elapsed < float(_stats.interval)
	if _players.warning.visible: _players.warning.seek(elapsed - _hit_time)
	_players.spawn.visible = _age < 2.0
	if _players.spawn.visible: _players.spawn.seek(_age)
	_players.active.visible = state.active_buff
	if state.active_buff:
		_buff_age += delta
		_players.active.seek(fmod(_buff_age, 4.0))
	else: _buff_age = 0.0
	_players.burst.visible = state.active_buff and _buff_age < 1.0
	if _players.burst.visible: _players.burst.seek(_buff_age)
