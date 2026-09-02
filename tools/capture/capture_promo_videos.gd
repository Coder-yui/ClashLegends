extends SceneTree
## 宣传片素材摄影脚本：只创建表现层，不修改正式战斗场景。
## 用法：
##   Godot --path . --script tools/capture/capture_promo_videos.gd --write-movie /tmp/shot.avi --fixed-fps 30 --resolution 1280x720 --quit-after 360 -- --shot=tower
##   Godot --path . --script tools/capture/capture_promo_videos.gd --write-movie /tmp/shot.avi --fixed-fps 30 --resolution 1280x720 --quit-after 360 -- --shot=crystal

const OUTPUT_SIZE := Vector2i(1280, 720)
const FPS := 30.0
const SHOT_DURATION := 11.0
const TOWER_DURATION := 10.5
const CRYSTAL_DURATION := 10.5

const TOWER_STATS := {
	"hp": 2100.0,
	"damage": 0.0,
	"range": 0.0,
	"interval": 1.0,
	"radius": 54.0,
	"visual_radius": 60.0,
	"deployment_radius": 54.0,
	"first_hit": 0.2,
	"projectile_speed": 0.0,
	"can_attack": false,
}

const CRYSTAL_STATS := {
	"hp": 3600.0,
	"damage": 0.0,
	"range": 0.0,
	"interval": 1.0,
	"radius": 72.0,
	"visual_radius": 80.0,
	"deployment_radius": 72.0,
	"first_hit": 0.2,
	"projectile_speed": 0.0,
	"can_attack": false,
}

const TOWER_CONFIG := {
	"scene_paths": [
		"res://assets/towers/princess/princess_tower_blue_view.tscn",
		"res://assets/towers/princess/princess_tower_red_view.tscn",
	],
	"ground_cutoff": 0.0,
	"animations": {
		"destroy": "Destroyed",
		"stage_surfaces": ["Base", "Stage1", "Stage2"],
		"final_stage_surface": "Stage3",
		"ruin_surface": "Rubble",
		"debris": [
			{"bones": "Break1", "surface": "Broken1", "window": [10.0, 15.0]},
			{"bones": "Break2", "surface": "Broken2", "window": [8.0, 15.0]},
			{"bones": "Break3", "surface": "Broken3", "window": [8.0, 15.0]},
		],
		"debris_duration": 2.0,
	},
}

const CRYSTAL_CONFIG := {
	"scene_paths": [
		"res://assets/towers/nexus/nexus_blue_view.tscn",
		"res://assets/towers/nexus/nexus_red_view.tscn",
	],
	"ground_cutoff": 0.0,
	"animations": {
		"spawn": "Nexus_spawn_anm",
		"idle": "Idle1_Base",
		"destroy": "Death",
		"spawn_duration": 2.5,
		"destroy_duration": 4.0,
		"alive_materials": ["SRUAP_OrderNexus_Mat"],
		"destroyed_materials": ["Destroyed"],
	},
}

var _shot := "tower"
var _frame_size := Vector2(720.0, 1400.0)
var _elapsed := 0.0
var _stage: Node3D
var _camera: Camera3D
var _subject: Tower
var _subject_view: TowerModel3D
var _subject_is_crystal := false
var _impact_times: Array[float] = []
var _impact_index := 0
var _effects: Array[Dictionary] = []
var _finished := false

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			_shot = argument.trim_prefix("--shot=").to_lower()
	call_deferred("_build_shot")

func _build_shot() -> void:
	_frame_size = get_root().get_viewport().get_visible_rect().size
	if _frame_size.x < 2.0 or _frame_size.y < 2.0:
		_frame_size = Vector2(720.0, 1400.0)
	_build_stage()
	_subject_is_crystal = _shot == "crystal"
	if _subject_is_crystal:
		_setup_crystal()
	else:
		_setup_tower()
	# 先让表现代理完成一次定位和模型导入，再开始计时。
	await process_frame
	await process_frame
	if _subject_view != null:
		_subject_view.set_process(true)
	print("[宣传素材] 开始录制 shot=", _shot)

func _process(delta: float) -> bool:
	if _finished:
		return false
	_elapsed += delta
	_update_camera()
	_update_effects(delta)
	if _subject == null or not is_instance_valid(_subject):
		return false
	if _subject_is_crystal:
		_process_crystal_shot()
	else:
		_process_tower_shot()
	if _elapsed >= SHOT_DURATION:
		_finished = true
		print("[宣传素材] 录制完成 shot=", _shot)
		call_deferred("quit")
	return false

func _build_stage() -> void:
	_stage = Node3D.new()
	_stage.name = "PromoStage"
	root.add_child(_stage)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.006, 0.018, 0.045, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.24, 0.34, 0.52)
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.15
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_stage.add_child(world_environment)

	var ground := MeshInstance3D.new()
	ground.name = "CinematicGround"
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(34.0, 34.0)
	ground.mesh = ground_mesh
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.018, 0.06, 0.09)
	ground_material.metallic = 0.42
	ground_material.roughness = 0.58
	ground_material.emission_enabled = true
	ground_material.emission = Color(0.0, 0.025, 0.04)
	ground_material.emission_energy_multiplier = 0.8
	ground.material_override = ground_material
	_stage.add_child(ground)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-47.0, -28.0, 0.0)
	key_light.light_color = Color(1.0, 0.86, 0.70)
	key_light.light_energy = 2.0
	key_light.shadow_enabled = true
	_stage.add_child(key_light)

	var blue_rim := OmniLight3D.new()
	blue_rim.name = "BlueRim"
	blue_rim.position = Vector3(-3.6, 3.4, 1.8)
	blue_rim.light_color = Color(0.10, 0.45, 1.0)
	blue_rim.light_energy = 10.0
	blue_rim.omni_range = 8.0
	_stage.add_child(blue_rim)

	var warm_rim := OmniLight3D.new()
	warm_rim.name = "WarmRim"
	warm_rim.position = Vector3(3.0, 2.2, 3.5)
	warm_rim.light_color = Color(1.0, 0.30, 0.09)
	warm_rim.light_energy = 7.0
	warm_rim.omni_range = 7.0
	_stage.add_child(warm_rim)

	_camera = Camera3D.new()
	_camera.name = "PromoCamera"
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 30.0 if _shot != "crystal" else 28.0
	_camera.near = 0.05
	_camera.far = 60.0
	_stage.add_child(_camera)
	_camera.current = true

func _setup_tower() -> void:
	_subject = Tower.new()
	_subject.name = "PromoPrincessTower"
	_subject.setup(1, TOWER_STATS, false)
	_subject.position = Vector2(_frame_size.x * 0.5, _frame_size.y * 0.78)
	root.add_child(_subject)
	_subject.visible = false
	_subject_view = TowerModel3D.new()
	_subject_view.name = "PrincessTowerPresentation"
	_stage.add_child(_subject_view)
	_subject_view.setup(_subject, load(String(TOWER_CONFIG.scene_paths[1])) as PackedScene, _camera, TOWER_CONFIG)
	_subject.has_model_art = true
	_subject.queue_redraw()
	_impact_times = [2.4, 4.25, 6.15]

func _setup_crystal() -> void:
	_subject = Tower.new()
	_subject.name = "PromoCrystal"
	_subject.setup(1, CRYSTAL_STATS, true)
	_subject.position = Vector2(_frame_size.x * 0.5, _frame_size.y * 0.54)
	root.add_child(_subject)
	_subject.visible = false
	_subject_view = TowerModel3D.new()
	_subject_view.name = "CrystalPresentation"
	_stage.add_child(_subject_view)
	_subject_view.setup(_subject, load(String(CRYSTAL_CONFIG.scene_paths[1])) as PackedScene, _camera, CRYSTAL_CONFIG)
	_subject.has_model_art = true
	_subject.queue_redraw()
	_impact_times = [5.15]

func _update_camera() -> void:
	if _camera == null:
		return
	var progress := clampf(_elapsed / SHOT_DURATION, 0.0, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	var position_start := Vector3(0.0, 6.25, 19.5)
	var position_end := Vector3(0.0, 5.75, 17.0)
	var target := Vector3(0.0, 1.65, 0.0)
	if _subject_is_crystal:
		position_start = Vector3(0.0, 5.45, 15.5)
		position_end = Vector3(0.0, 5.0, 13.2)
		target = Vector3(0.0, 1.85, 0.0)
	_camera.position = position_start.lerp(position_end, eased)
	_camera.look_at(target, Vector3.UP)

func _process_tower_shot() -> void:
	if _impact_index >= _impact_times.size():
		return
	if _elapsed < _impact_times[_impact_index]:
		return
	var impact_number := _impact_index
	_impact_index += 1
	if impact_number == 0:
		_subject.take_damage(_subject.max_hp * 0.38)
	elif impact_number == 1:
		_subject.take_damage(_subject.max_hp * 0.30)
	else:
		_subject.take_damage(_subject.max_hp + 1.0)
	_spawn_impact(impact_number == 2, Color(1.0, 0.42, 0.12))

func _process_crystal_shot() -> void:
	if _impact_index >= _impact_times.size():
		return
	if _elapsed < _impact_times[_impact_index]:
		return
	_impact_index += 1
	_subject.take_damage(_subject.max_hp + 1.0)
	_spawn_impact(true, Color(0.20, 0.76, 1.0))

func _spawn_impact(final_burst: bool, color: Color) -> void:
	var center := _subject_view.position + Vector3(0.0, 1.1 if not _subject_is_crystal else 1.75, 0.0)
	var flash := OmniLight3D.new()
	flash.position = center
	flash.light_color = color
	flash.light_energy = 14.0 if final_burst else 8.0
	flash.omni_range = 7.5 if final_burst else 5.0
	_stage.add_child(flash)

	var particles := CPUParticles3D.new()
	particles.position = center
	particles.amount = 110 if final_burst else 48
	particles.lifetime = 1.25 if final_burst else 0.75
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 180.0
	particles.initial_velocity_min = 2.0 if final_burst else 1.0
	particles.initial_velocity_max = 6.0 if final_burst else 3.5
	particles.gravity = Vector3(0.0, -4.0, 0.0)
	particles.scale_amount_min = 0.035
	particles.scale_amount_max = 0.16 if final_burst else 0.06
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.045
	spark_mesh.height = 0.09
	particles.mesh = spark_mesh
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = color
	spark_material.emission_enabled = true
	spark_material.emission = Color(color.r, color.g, color.b)
	spark_material.emission_energy_multiplier = 4.0
	particles.material_override = spark_material
	_stage.add_child(particles)
	particles.emitting = true

	var glow: MeshInstance3D = null
	if final_burst:
		glow = MeshInstance3D.new()
		var glow_mesh := SphereMesh.new()
		glow_mesh.radius = 0.85
		glow_mesh.height = 1.7
		glow.mesh = glow_mesh
		glow.position = center
		glow.scale = Vector3.ONE * 0.1
		var glow_material := StandardMaterial3D.new()
		glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow_material.albedo_color = Color(color.r, color.g, color.b, 0.55)
		glow_material.emission_enabled = true
		glow_material.emission = Color(color.r, color.g, color.b)
		glow_material.emission_energy_multiplier = 5.0
		glow.material_override = glow_material
		_stage.add_child(glow)

	_effects.append({"light": flash, "particles": particles, "glow": glow, "age": 0.0, "life": 1.0 if final_burst else 0.72})

func _update_effects(delta: float) -> void:
	for i in range(_effects.size() - 1, -1, -1):
		var effect: Dictionary = _effects[i]
		effect.age = float(effect.age) + delta
		var t := clampf(float(effect.age) / float(effect.life), 0.0, 1.0)
		var flash := effect.light as OmniLight3D
		var glow := effect.glow as MeshInstance3D
		if glow != null and is_instance_valid(glow):
			glow.scale = Vector3.ONE * lerpf(0.1, 2.6, t)
			var glow_material := glow.material_override as StandardMaterial3D
			if glow_material != null:
				glow_material.albedo_color.a = 0.55 * (1.0 - t)
				glow_material.emission_energy_multiplier = 5.0 * (1.0 - t)
		if flash != null and is_instance_valid(flash):
			flash.light_energy = lerpf(14.0, 0.0, t)
		if float(effect.age) >= float(effect.life) + 0.55:
			for key in ["light", "particles", "glow"]:
				var node := effect[key] as Node
				if node != null and is_instance_valid(node):
					node.queue_free()
			_effects.remove_at(i)
