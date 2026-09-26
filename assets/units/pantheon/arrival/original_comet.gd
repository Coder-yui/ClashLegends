extends Node3D
## Original LoL resource adapter. Native moving systems use +Y travel / +Z normal.
const PARTICLES := preload("res://assets/units/pantheon/r_original/particles.gd")
const METRICS := preload("res://assets/units/pantheon/visual_metrics.gd")
var _effects: Dictionary = {}
var _ages: Dictionary = {}
var _forward := Vector3.FORWARD
var _side := Vector3.RIGHT
var _flight_basis := Basis.IDENTITY
var _slide_basis := Basis.IDENTITY

func setup(forward: Vector3, rise: float) -> void:
	_forward = forward
	_side = forward.cross(Vector3.UP).normalized()
	var flight := (forward - Vector3.UP * rise).normalized()
	_flight_basis = Basis(_side, flight, _side.cross(flight).normalized())
	_slide_basis = Basis(_side, forward, Vector3.UP)

func _sample(name: String, time: float, start: float, point: Vector3, basis: Basis, moving: bool) -> void:
	if time < start: return
	if not _effects.has(name):
		var effect := PARTICLES.new()
		add_child(effect)
		effect.global_transform = Transform3D(basis, point)
		effect.setup(name, METRICS.PARTICLE_SCALE, moving)
		_effects[name] = effect
		_ages[name] = 0.0
	var node: Node3D = _effects[name]
	node.global_transform = Transform3D(basis, point)
	var age := maxf(time - start, 0.0)
	node.advance(maxf(age - float(_ages[name]), 0.0))
	_ages[name] = age

func advance(time: float, point: Vector3, destination: Vector3, landing: Vector3) -> void:
	var upright := Basis(Vector3.UP, atan2(_forward.x, _forward.z))
	_sample("Spear_Impact", time, 0.2, destination, upright, false)
	if time < 0.65:
		_sample("update_missile", time, 0.2, point + Vector3.UP * 1.1 * METRICS.RATIO, _flight_basis, true)
	elif _effects.has("update_missile"):
		_effects.update_missile.stop_emitting()
		_effects.update_missile.hide()
	_sample("Sliding_Comet", time, 0.65, point, _slide_basis, true)
	_sample("Damage_Mis", time, 0.65, point, _slide_basis, true)
	_sample("Update_Impact", time, 0.65, landing, upright, false)
	# Ending_Shockwave is the on-death child of Damage_Mis, played by the
	# deployed model at arrival, with its own +X-forward frame.
