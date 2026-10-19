extends SceneTree
## Video7 封面抓拍：潘森(部署冲击波) + 虚空女皇(飞行) vs 蛮王(技能火光) + 天使远程(飞行)
## 复用 BattlePresentation3D + Tower 搭建 3D 竞技场与防御塔/水晶。
##
## 用法：
##   Godot --path . --script tools/capture/capture_cover_video7.gd -- --ratio=16x9

const PANTHEON_VIEW := preload("res://assets/units/pantheon/pantheon_view.tscn")
const PANTHEON_ARRIVAL := preload("res://assets/units/pantheon/pantheon_arrival.tscn")
const BELVETH := preload("res://assets/units/belveth/belveth_view.tscn")
const TRYNDAMERE := preload("res://assets/units/tryndamere/tryndamere_view.tscn")
const UNDYING_RAGE := preload("res://assets/effects/tryndamere/undying_rage.tscn")
const KAYLE_RANGED := preload("res://assets/units/kayle/ranged_view.tscn")
const AIR_ELEVATION := 2.3

const DEFAULT_OUT_16X9 := "res://ClashLegends-promo-materials/ClashLegends宣传素材/Video7素材/cover_background_16x9.png"
const DEFAULT_OUT_9X16 := "res://ClashLegends-promo-materials/ClashLegends宣传素材/Video7素材/cover_background_9x16.png"

const TOWER_SPECS := [
	[0, Vector2(ArenaRules.BRIDGE_X_LEFT,  25.5 * ArenaRules.TILE_SIZE), false],
	[0, Vector2(ArenaRules.BRIDGE_X_RIGHT, 25.5 * ArenaRules.TILE_SIZE), false],
	[1, Vector2(ArenaRules.BRIDGE_X_LEFT,  6.5 * ArenaRules.TILE_SIZE),  false],
	[1, Vector2(ArenaRules.BRIDGE_X_RIGHT, 6.5 * ArenaRules.TILE_SIZE),  false],
	[0, Vector2(9.0 * ArenaRules.TILE_SIZE, 29.0 * ArenaRules.TILE_SIZE), true],
	[1, Vector2(9.0 * ArenaRules.TILE_SIZE, 3.0 * ArenaRules.TILE_SIZE),  true],
]

var _ratio := "16x9"
var _out_path := ""
var _presentation: BattlePresentation3D
var _world_root: Node3D
var _pantheon_arrival: Node3D
var _belveth: Node3D
var _tryndamere: Node3D
var _undying: Node3D
var _kayle: Node3D
var _combat_mid: Vector3
var _pantheon_screen := Vector2.ZERO
var _belveth_y := AIR_ELEVATION
var _kayle_y := AIR_ELEVATION
var _shock_progress := 0.72
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

	for child in _world_root.get_children():
		if child is TowerModel3D and child._source != null and child._source.is_king:
			var ap: AnimationPlayer = child._animation_player
			if ap != null and ap.has_animation("Idle1_Base"):
				ap.play("Idle1_Base")
				ap.seek(0.0, true)
			child._show_alive_surfaces()

	for child in _world_root.get_children():
		if child is TowerModel3D:
			child.process_mode = Node.PROCESS_MODE_DISABLED

	_spawn_units()
	_position_units(ortho)
	ortho.queue_free()
	_setup_camera()

func _spawn_units() -> void:
	# 部署特效期间潘森单位尚未创建，只用 arrival 冲击波特效
	_pantheon_arrival = PANTHEON_ARRIVAL.instantiate() as Node3D
	_world_root.add_child(_pantheon_arrival)

	_belveth = BELVETH.instantiate() as Node3D
	_world_root.add_child(_belveth)

	_tryndamere = TRYNDAMERE.instantiate() as Node3D
	_world_root.add_child(_tryndamere)

	_undying = UNDYING_RAGE.instantiate() as Node3D
	_world_root.add_child(_undying)

	_kayle = KAYLE_RANGED.instantiate() as Node3D
	_world_root.add_child(_kayle)

func _find_ap(node: Node3D) -> AnimationPlayer:
	return node.find_child("AnimationPlayer", true, false) as AnimationPlayer

func _play_first(node: Node3D, candidates: Array) -> void:
	var ap := _find_ap(node)
	if ap == null: return
	for name in candidates:
		if ap.has_animation(name):
			ap.play(name)
			var len := ap.get_animation(name).length
			ap.seek(clampf(len * 0.5, 0.0, len), true)
			ap.pause()
			print("ANIM %s -> %s" % [node.name, name])
			return
	# fallback: print available
	var anims: Array = []
	for a in ap.get_animation_list():
		anims.append(a)
	print("ANIMS %s: %s" % [node.name, anims])

func _position_units(ortho: Camera3D) -> void:
	var pantheon_ground: Vector3
	var belveth_ground: Vector3
	var trynd_ground: Vector3
	var kayle_ground: Vector3
	if _ratio == "16x9":
		# 横版：潘森与蛮王隔河正对，虚空女皇/天使在后上方且高度对齐
		_pantheon_screen = Vector2(340.0, 600.0)
		pantheon_ground = _screen_to_ground(ortho, _pantheon_screen)
		belveth_ground = _screen_to_ground(ortho, Vector2(275.0, 600.0))
		trynd_ground = _screen_to_ground(ortho, Vector2(340.0, 705.0))
		kayle_ground = _screen_to_ground(ortho, Vector2(410.0, 705.0))
		_belveth_y = AIR_ELEVATION + 0.5
		_kayle_y = AIR_ELEVATION + 0.5
		_shock_progress = 0.72
	else:
		# 竖版：潘森与蛮王隔河正对，虚空女皇在潘森后上方，天使在蛮王后上方，顶部留 logo
		_pantheon_screen = Vector2(300.0, 700.0)
		pantheon_ground = _screen_to_ground(ortho, _pantheon_screen)
		belveth_ground = _screen_to_ground(ortho, Vector2(230.0, 700.0))
		trynd_ground = _screen_to_ground(ortho, Vector2(300.0, 580.0))
		kayle_ground = _screen_to_ground(ortho, Vector2(370.0, 580.0))
		_belveth_y = AIR_ELEVATION + 0.6
		_kayle_y = AIR_ELEVATION
		_shock_progress = 0.72

	_pantheon_arrival.position = pantheon_ground
	_belveth.position = belveth_ground + Vector3.UP * _belveth_y
	_tryndamere.position = trynd_ground
	_undying.position = trynd_ground
	_kayle.position = kayle_ground + Vector3.UP * _kayle_y

	_combat_mid = (pantheon_ground + trynd_ground) * 0.5

	# 蛮王面向潘森方向
	var to_pan := (pantheon_ground - trynd_ground); to_pan.y = 0.0
	_tryndamere.rotation.y = atan2(to_pan.x, to_pan.z)
	# 虚空女皇面向蛮王
	var to_trynd := (trynd_ground - pantheon_ground); to_trynd.y = 0.0
	_belveth.rotation.y = atan2(to_trynd.x, to_trynd.z)
	# 天使面向潘森
	_kayle.rotation.y = atan2(to_pan.x, to_pan.z)

	# 潘森部署冲击波特效：setup 后 advance 到冲击波时刻
	if _pantheon_arrival.has_method("setup"):
		_pantheon_arrival.setup(ortho, _pantheon_screen, 1)
		# pre_deploy_sweep_start=0.65 / pre_deploy_time=1.3 => progress 0.5 开始扫冲击波
		_pantheon_arrival.advance_visual(_shock_progress)

	# 虚空女皇飞行动画
	_play_first(_belveth, ["Idle1", "Idle_Base", "Fly", "Respawn_Ult_anm", "Idle"])

	# 蛮王暴击挥刀 + 火光特效(技能开启2秒)
	_play_first(_tryndamere, ["Crit"])
	if _undying.has_method("configure"):
		_undying.configure(1.0, 1)
		_undying.position = _tryndamere.position
		_undying.advance(true, 2.0)

	# 天使远程攻击/待机动画
	_play_first(_kayle, ["Kayle_Attack3_anm", "Kayle_Attack4_anm", "Kayle_RunPassive_anm", "Idle1", "Idle_Base", "Idle"])

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
		# 横版：相机放低拉近，侧面近距拍摄
		_camera.fov = 40.0
		_camera.position = _combat_mid + Vector3(-11.0, 4.8, 0.0)
		_viewport.add_child(_camera)
		_camera.look_at(Vector3(_combat_mid.x, _combat_mid.y + 1.8, _combat_mid.z), Vector3.UP)
	else:
		# 竖版：斜俯视，战斗居中偏下，上方留 logo
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
