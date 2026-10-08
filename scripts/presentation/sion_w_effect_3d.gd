extends Node3D
## W 护盾读取独立盾层，爆炸读取权威表现事件；不参与伤害结算。
const PLAYER = preload("res://assets/effects/sion_w/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
var _units: Array[WeakRef] = []
var _shields: Dictionary = {}
var _bursts: Dictionary = {}
var _serial := 0

func track(unit: Unit) -> void:
	if unit.card_id == "sion": _units.append(weakref(unit))

func _player(kind: String) -> Node3D:
	var view := PLAYER.new()
	add_child(view)
	view.load_kind(kind)
	view.setup_native(1.0)
	return view

func sync_effects(skills: RefCounted, camera: Camera3D, delta: float) -> void:
	var active := {}
	for ref in _units.duplicate():
		var unit := ref.get_ref() as Unit
		if not is_instance_valid(unit):
			_units.erase(ref)
			continue
		if not unit.has_explosive_shield(): continue
		var id := unit.get_instance_id()
		active[id] = true
		if not _shields.has(id):
			_shields[id] = {"shield": _player("Shield"), "cast": _player("Cas"), "age": 0.0}
		var state: Dictionary = _shields[id]
		state.age += delta
		var point := unit.get_visual_screen_position()
		var base := PROJECTION.ground(camera, point)
		var radius := PROJECTION.ground(camera, point + Vector2(unit.body_radius * 2.6, 0)).distance_to(base)
		for key in ["shield", "cast"]:
			var view: Node3D = state[key]
			view.visible = unit.visible_to_local_player() and PresentationConfig.status_indicators_visible(unit)
			view.position = base + Vector3.UP * radius * 0.95
			view.scale = Vector3.ONE * radius / 285.0
			view.seek(minf(float(state.age), 3.0) if key == "shield" else float(state.age))
	for id in _shields.keys():
		if not active.has(id):
			_shields[id].shield.free()
			_shields[id].cast.free()
			_shields.erase(id)
	active.clear()
	for effect in skills.frontal_effects:
		if String(effect.get("shape", "")) != "shield_explosion": continue
		if not effect.has("sion_w_view_id"):
			_serial += 1
			effect.sion_w_view_id = _serial
		var id := int(effect.sion_w_view_id)
		active[id] = true
		if not _bursts.has(id): _bursts[id] = _player("Nova")
		var view: Node3D = _bursts[id]
		var point: Vector2 = effect.pos
		view.position = PROJECTION.ground(camera, point)
		var radius := float(effect.length)
		var world_radius := PROJECTION.ground(camera, point + Vector2(radius, 0)).distance_to(view.position)
		view.projection_basis = PROJECTION.footprint_basis(camera, point, radius)
		view.scale = Vector3.ONE * world_radius / 650.0
		view.seek(maxf(float(effect.duration) - float(effect.timer), 1.0 / 120.0))
	for id in _bursts.keys():
		if not active.has(id):
			_bursts[id].free()
			_bursts.erase(id)
