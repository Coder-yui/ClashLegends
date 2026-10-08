extends Node3D
## 两个独立表现窗口；冰脉护手覆盖内圈，巨魔W显示外圈并在解冻后完整露出。
const PLAYER = preload("res://assets/effects/freeze/native_player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const SHADER := "res://assets/effects/freeze/range_ring.gdshader"
const BLUE_RIM := Color(0.15, 0.55, 1.0)
const RED_RIM := Color(1.0, 0.25, 0.20)
# 原贴图亮边位于贴片内部：冰脉护手约0.86×357，巨魔W按外围冷雾约0.91×870。
# 用可见外沿校准，不把透明留白算作覆盖范围。
const VISIBLE_SOURCE_RADIUS := {"iceborn": 310.0, "trundle": 790.0}
var _views: Array[MeshInstance3D] = []
var _players: Array[Node3D] = []

func sync_effects(spells: RefCounted, camera: Camera3D) -> void:
	var index := 0
	for effect in spells.freeze_effects:
		_sync_view(index, effect, camera, "iceborn")
		index += 1
	for effect in spells.slow_effects:
		_sync_view(index, effect, camera, "trundle")
		index += 1
	for spare in range(index, _views.size()):
		_views[spare].hide()
		_players[spare].hide()

func _sync_view(index: int, effect: Dictionary, camera: Camera3D, kind: String) -> void:
	if index == _views.size():
		var ring := MeshInstance3D.new()
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = load(SHADER)
		ring.material_override = material
		add_child(ring)
		_views.append(ring)
		_players.append(null)
	var player := _players[index]
	if player == null or player.get_meta("kind") != kind:
		if player != null: player.free()
		player = PLAYER.new()
		player.set_meta("kind", kind)
		add_child(player)
		player.load_kind(kind)
		player.setup_native(1.0)
		_players[index] = player
	var center: Vector2 = effect.pos
	var radius := float(effect.radius)
	player.position = PROJECTION.ground(camera, center)
	player.projection_basis = PROJECTION.footprint_basis(camera, center, radius)
	var world_radius := PROJECTION.ground(camera, center + Vector2(radius, 0)).distance_to(player.position)
	player.scale = Vector3.ONE * world_radius / float(VISIBLE_SOURCE_RADIUS[kind])
	var age := maxf(float(effect.duration) - float(effect.timer), 0.0)
	# The authored item field lasts 2s; map its lifetime to the authoritative 3s freeze.
	var source_age := age * 2.0 / float(effect.duration) if kind == "iceborn" else age
	player.freeze_occluder = Vector4.ZERO
	if kind == "trundle" and age < float(effect.get("freeze_duration", 0.0)):
		player.freeze_occluder = Vector4(center.x, center.y, float(effect.get("freeze_radius", 0.0)), 0.0)
	player.show()
	player.seek(maxf(source_age, 1.0 / 120.0))
	var view := _views[index]
	view.show()
	view.material_override.set_shader_parameter("rim_color", BLUE_RIM if int(effect.get("team", 0)) == 0 else RED_RIM)
	var bounds := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	if view.get_meta("bounds", Rect2()) != bounds: _update_mesh(view, bounds, camera)

func _update_mesh(view: MeshInstance3D, bounds: Rect2, camera: Camera3D) -> void:
	view.set_meta("bounds", bounds)
	var center := bounds.get_center()
	var radius := bounds.size.x * 0.5
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var vertices := PackedVector3Array()
	for corner in corners:
		var screen: Vector2 = center + corner * radius
		var origin := camera.project_ray_origin(screen)
		var direction := camera.project_ray_normal(screen)
		# 正交相机逆投影四角：画面上始终匹配对应权威圆形范围。
		vertices.append(origin + direction * ((0.065 - origin.y) / direction.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	view.mesh = mesh


func prepare_visual(camera: Camera3D, radius: float, enhanced: bool = true) -> void:
	for kind in (["iceborn", "trundle"] if enhanced else ["iceborn"]):
		for age in [0.02, 0.15, 0.8, 1.5]:
			_sync_view(0, {"pos": Vector2(360,640), "radius":radius, "team":0, "duration":3.0, "timer":3.0 - age}, camera, kind)
			if DisplayServer.get_name() != "headless": RenderingServer.force_draw(false)
	_views[0].hide()
	_players[0].hide()

static func resource_manifest(variant: String) -> Dictionary:
	if variant not in ["iceborn", "trundle"]: return {}
	return {"emitter_provider": "res://assets/effects/freeze/native_player.gd", "json": ["res://assets/effects/freeze/" + variant + "/sampled.json"], "paths": [SHADER, "res://assets/effects/freeze/attached_frost.gdshader"] if variant == "iceborn" else [SHADER], "target_states": ["freeze"] if variant == "iceborn" else [], "ground": {"slot": "_freeze_ground", "variant": variant}}

func prepare_resource_variant(camera: Camera3D, radius: float, variant: String, stop: Callable) -> void:
	for age in [0.02, 0.15, 0.8, 1.5]:
		if stop.is_valid() and bool(stop.call()): break
		_sync_view(0, {"pos": Vector2(360, 640), "radius": radius, "team": 0, "duration": 3.0, "timer": 3.0 - age}, camera, variant)
		if DisplayServer.get_name() != "headless": RenderingServer.force_draw(false)
	if not _views.is_empty():
		_views[0].hide()
		_players[0].hide()
