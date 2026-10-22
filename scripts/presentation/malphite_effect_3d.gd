extends Node3D
## 原版大地震颤冲击；只读取可靠表现事件的位置和年龄。
const PLAYER = preload("res://assets/effects/malphite/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
var _views: Dictionary = {}
var _serial := 0
var _detached: Array[Node3D] = []
func _ready() -> void:
	get_parent().set_meta("malphite_effect_owner", weakref(self))

func spawn_detached(kind: String, placement: Transform3D, source: Node3D = null, age: float = 0.0) -> Node3D:
	var player := PLAYER.new()
	add_child(player)
	player.load_kind(kind)
	player.global_transform = placement
	if kind == "cas":
		# Source local-orientation flags are per emitter, not a rotation of every layer.
		player.cast_orientation = placement.basis.orthonormalized()
		player.global_basis = Basis.IDENTITY
	player.setup_native(preload("res://assets/units/malphite/visual_scale.gd").E_EFFECT_SCALE if kind == "cas" else PLAYER.NATIVE_SCALE)
	if source != null: player.bind_motion(source)
	player.seek(age)
	_detached.append(player)
	return player

func _process(delta: float) -> void:
	for player in _detached.duplicate():
		player.advance(delta)
		if player._age > 4.0:
			_detached.erase(player)
			player.queue_free()

func clear_detached() -> void:
	for player in _detached: player.queue_free()
	_detached.clear()

func sync_effects(skills: RefCounted, camera: Camera3D) -> void:
	var present := {}
	for effect in skills.frontal_effects:
		if String(effect.get("shape", "")) not in ["malphite_slam"]: continue
		if not effect.has("malphite_view_id"):
			_serial += 1
			effect.malphite_view_id = _serial
		var id := int(effect.malphite_view_id)
		present[id] = true
		if not _views.has(id):
			var player := PLAYER.new()
			add_child(player)
			player.load_kind("aoe")
			player.setup_native(preload("res://assets/units/malphite/visual_scale.gd").E_EFFECT_SCALE)
			_views[id] = player
		var view: Node3D = _views[id]
		var point: Vector2 = effect.pos
		view.position = PROJECTION.ground(camera, point)
		view.projection_basis = Basis.IDENTITY

		view.seek(maxf(float(effect.duration) - float(effect.timer), 1.0 / 120.0))
	for id in _views.keys():
		if not present.has(id):
			_views[id].free()
			_views.erase(id)
