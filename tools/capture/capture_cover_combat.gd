extends SceneTree
## 封面抓拍工具：复用项目 BattlePresentation3D + Tower 搭建 3D 竞技场与防御塔/水晶，
## 抓拍指定单位对战画面。支持竖版（9:16）与横版（16:9）两种构图。
##
## 用法：
##   Godot --path . --script tools/capture/capture_cover_combat.gd -- --ratio=9x16
##   Godot --path . --script tools/capture/capture_cover_combat.gd -- --ratio=16x9 --out=res://ClashLegends-promo-materials/ClashLegends宣传素材/Video5素材/cover_background_16x9.png
##
## 参数：
##   --ratio=9x16|16x9   输出比例，默认 9x16
##   --out=<路径>         输出 png 路径，默认按比例输出到 Video5素材

const AATROX_ULT := preload("res://assets/units/aatrox/ultimate_view.tscn")
const HERALD := preload("res://assets/units/rift_herald/rift_herald_view.tscn")
const AIR_ELEVATION := 2.3

const DEFAULT_OUT_9X16 := "res://ClashLegends-promo-materials/ClashLegends宣传素材/Video5素材/cover_background_9x16.png"
const DEFAULT_OUT_16X9 := "res://ClashLegends-promo-materials/ClashLegends宣传素材/Video5素材/cover_background_16x9.png"

# 复用 main.gd _create_towers() 坐标
const TOWER_SPECS := [
	[0, Vector2(ArenaRules.BRIDGE_X_LEFT,  25.5 * ArenaRules.TILE_SIZE), false],
	[0, Vector2(ArenaRules.BRIDGE_X_RIGHT, 25.5 * ArenaRules.TILE_SIZE), false],
	[1, Vector2(ArenaRules.BRIDGE_X_LEFT,  6.5 * ArenaRules.TILE_SIZE),  false],
	[1, Vector2(ArenaRules.BRIDGE_X_RIGHT, 6.5 * ArenaRules.TILE_SIZE),  false],
	[0, Vector2(9.0 * ArenaRules.TILE_SIZE, 29.0 * ArenaRules.TILE_SIZE), true],
	[1, Vector2(9.0 * ArenaRules.TILE_SIZE, 3.0 * ArenaRules.TILE_SIZE),  true],
]

var _ratio := "9x16"
var _out_path := ""
var _presentation: BattlePresentation3D
var _world_root: Node3D
var _aatrox: Node3D
var _herald: Node3D
var _aatrox_player: AnimationPlayer
var _herald_player: AnimationPlayer
var _combat_mid: Vector3
var _viewport: SubViewport
var _camera: Camera3D
var _frame := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ratio="):
			_ratio = arg.trim_prefix("--ratio=")
		elif arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
	if _out_path.is_empty():
		_out_path = DEFAULT_OUT_16X9 if _ratio == "16x9" else DEFAULT_OUT_9X16
	call_deferred("_build")

func _build() -> void:
	_presentation = BattlePresentation3D.new()
	root.add_child(_presentation)
	_presentation.setup(Vector2(ArenaRules.FIELD_W, ArenaRules.FIELD_H), ArenaRules.TILE_SIZE)
	_world_root = _presentation._world_root
	var ortho: Camera3D = _presentation._camera

	# 复用项目 Tower + attach_tower 挂 4 公主塔 + 2 水晶
	for spec in TOWER_SPECS:
		var t := Tower.new()
		var is_king: bool = spec[2]
		var stats := CardDB.NEXUS_STATS if is_king else CardDB.PRINCESS_TOWER_STATS
		var cfg := CardDB.NEXUS_VISUAL_CONFIG if is_king else CardDB.PRINCESS_TOWER_VISUAL_CONFIG
		t.setup(spec[0], stats, is_king)
		t.position = spec[1]
		root.add_child(t)
		_presentation.attach_tower(t, cfg)

	await process_frame

	# 水晶切待机态（水晶柱升起）
	for child in _world_root.get_children():
		if child is TowerModel3D and child._source != null and child._source.is_king:
			var ap: AnimationPlayer = child._animation_player
			if ap != null and ap.has_animation("Idle1_Base"):
				ap.play("Idle1_Base")
				ap.seek(0.0, true)
			child._show_alive_surfaces()

	# 冻结塔 process，换相机后不重新投影
	for child in _world_root.get_children():
		if child is TowerModel3D:
			child.process_mode = Node.PROCESS_MODE_DISABLED

	_spawn_units()
	_position_units(ortho)
	ortho.queue_free()
	_setup_camera()

func _spawn_units() -> void:
	_aatrox = AATROX_ULT.instantiate() as Node3D
	_world_root.add_child(_aatrox)
	_aatrox_player = _aatrox.find_child("AnimationPlayer", true, false) as AnimationPlayer

	_herald = HERALD.instantiate() as Node3D
	_world_root.add_child(_herald)
	_herald_player = _herald.find_child("AnimationPlayer", true, false) as AnimationPlayer

func _position_units(ortho: Camera3D) -> void:
	if _ratio == "16x9":
		# 横版：先锋在河左岸、剑魔在河右岸，拉开间距形成左右对峙中间留白
		var herald_ground := _screen_to_ground(ortho, Vector2(310.0, 530.0))
		var aatrox_ground := _screen_to_ground(ortho, Vector2(430.0, 760.0))
		_herald.position = herald_ground
		_aatrox.position = aatrox_ground + Vector3.UP * AIR_ELEVATION
	else:
		# 竖版：斜俯视，战斗居中偏下，上方留 logo 空间
		var herald_ground := _screen_to_ground(ortho, Vector2(340.0, 720.0))
		var aatrox_ground := _screen_to_ground(ortho, Vector2(410.0, 790.0))
		_herald.position = herald_ground
		_aatrox.position = aatrox_ground + Vector3.UP * AIR_ELEVATION
	_combat_mid = (_herald.position + _aatrox.position) * 0.5

	# 相向而立
	var to_herald := (_herald.position - _aatrox.position); to_herald.y = 0.0
	_aatrox.rotation.y = atan2(to_herald.x, to_herald.z)
	var to_aatrox := (_aatrox.position - _herald.position); to_aatrox.y = 0.0
	_herald.rotation.y = atan2(to_aatrox.x, to_aatrox.z)

	# 剑魔大灭攻击命中帧
	if _aatrox_player != null:
		_aatrox_player.play("Aatrox_ULT_Idle_anm")
		_aatrox_player.seek(0.0, true)
		await process_frame
		var chosen := "Attack1_Ult"
		for clip in ["Passive_Attack_Ult", "Attack1_Ult", "Attack2_Ult"]:
			if _aatrox_player.has_animation(clip):
				chosen = clip
				break
		_aatrox_player.play(chosen)
		var len := _aatrox_player.get_animation(chosen).length
		_aatrox_player.seek(clampf(len * 0.50, 0.0, len), true)
		_aatrox_player.pause()

	if _herald_player != null:
		if _herald_player.has_animation("Stun"):
			_herald_player.play("Stun")
		else:
			_herald_player.play("Idle_Base")
		_herald_player.seek(0.0, true)
		_herald_player.pause()

func _screen_to_ground(cam: Camera3D, screen_pos: Vector2) -> Vector3:
	var origin := cam.project_ray_origin(screen_pos)
	var direction := cam.project_ray_normal(screen_pos)
	if absf(direction.y) < 0.0001:
		return Vector3.ZERO
	return origin + direction * (-origin.y / direction.y)

func _setup_camera() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1080, 1920) if _ratio == "9x16" else Vector2i(1920, 1080)
	_viewport.own_world_3d = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.world_3d = _world_root.get_world_3d()
	root.add_child(_viewport)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.near = 0.1
	_camera.far = 200.0

	if _ratio == "16x9":
		# 横版：相机在河流一端上方，与地面法线成约 30° 俯视，近距放大
		_camera.fov = 30.0
		_camera.position = _combat_mid + Vector3(-10.0, 17.0, 0.0)
		_viewport.add_child(_camera)
		_camera.look_at(Vector3(_combat_mid.x, _combat_mid.y, _combat_mid.z), Vector3.UP)
	else:
		# 竖版：斜俯视，上方留 logo
		_camera.fov = 42.0
		_camera.position = _combat_mid + Vector3(-1.0, 12.0, 7.5)
		_viewport.add_child(_camera)
		_camera.look_at(Vector3(_combat_mid.x + 0.5, _combat_mid.y, _combat_mid.z - 3.0), Vector3.UP)
	_camera.current = true

func _process(delta: float) -> bool:
	_frame += 1
	if _frame == 10:
		var img := _viewport.get_texture().get_image()
		if img != null:
			img.save_png(_out_path)
			print("COVER_SAVED:%s" % _out_path)
		quit()
	return false
