extends Node3D
## Stage composition only: phase, anchor and frame come from the integration profile.
const PARTICLES := preload("res://assets/units/pantheon/arrival/particle_player.gd")
const PROFILE := preload("res://assets/units/pantheon/arrival/profile.gd")
const METRICS := preload("res://assets/units/pantheon/visual_metrics.gd")
var _effects: Dictionary = {}
var _ages: Dictionary = {}
var _forward := Vector3.FORWARD
var _rise := 0.5

func setup(forward: Vector3, rise: float) -> void:
	_forward = forward
	_rise = rise

func reset() -> void:
	for effect: Node3D in _effects.values(): effect.free()
	_effects.clear()
	_ages.clear()

func _transform(phase: Dictionary, point: Vector3, destination: Vector3, landing: Vector3, time: float = 0.0) -> Transform3D:
	var origin := point
	if phase.anchor == "destination": origin = destination
	elif phase.anchor == "landing": origin = landing
	elif phase.anchor == "spear": origin = destination + (Vector3.UP * _rise - _forward) * 6.0 * (1.0 - clampf(time / 0.2, 0.0, 1.0))
	if phase.frame == "flight": origin += Vector3.UP * 1.1 * METRICS.RATIO
	return Transform3D(PROFILE.frame(phase.frame, _forward, _rise), origin)

func advance(time: float, point: Vector3, destination: Vector3, landing: Vector3) -> void:
	for name: String in PROFILE.data().systems:
		var phase: Dictionary = PROFILE.data().systems[name]
		if not phase.get("enabled", true): continue
		if phase.owner != "pre_deploy" or time + 0.000001 < float(phase.start): continue
		if time >= float(phase.stop) and name in ["update_missile", "Spear_Landing"]:
			if _effects.has(name):
				_effects[name].stop_emitting()
				_effects[name].hide()
			continue
		if not _effects.has(name):
			var effect := PARTICLES.new()
			add_child(effect)
			effect.global_transform = _transform(phase, point, destination, landing, time)
			effect.setup(name, METRICS.PARTICLE_SCALE, phase.frame in ["flight", "slide", "spear"])
			_effects[name] = effect
			_ages[name] = 0.0
		var node: Node3D = _effects[name]
		node.global_transform = _transform(phase, point, destination, landing, time)
		var age := maxf(time - float(phase.start), 0.0)
		node.advance(maxf(age - float(_ages[name]), 0.0))
		_ages[name] = age

## Render the exact requested pose without adding births or ribbon samples.
func present(time: float, point: Vector3, destination: Vector3, landing: Vector3) -> void:
	for name: String in _effects:
		var phase: Dictionary = PROFILE.data().systems[name]
		var effect: Node3D = _effects[name]
		effect.global_transform = _transform(phase, point, destination, landing, time)
		effect.present(maxf(time - float(phase.start), 0.0))
