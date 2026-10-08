extends "res://assets/units/pantheon/arrival/particle_player.gd"
## Cask-only flight clock: sample birth poses and ribbon points along the presentation path.
var position_at: Callable
const BARREL_SIZE_MULTIPLIER := 2.0
const STEP := 1.0 / 120.0
const TAIL_LIFETIME := 0.4

func seek_flight(age: float) -> void:
	while _time + 0.000001 < age:
		var delta := minf(STEP, age - _time)
		global_position = position_at.call(_time + delta)
		advance(delta)

func _spawn(c: Dictionary, birth: float, material: ShaderMaterial) -> void:
	var current := global_position
	global_position = position_at.call(birth)
	super._spawn(c, birth, material)
	global_position = current

func finish_flight() -> void:
	stop_emitting()
	# The bound barrel vanishes on impact; the world-space wake finishes its authored life.
	for i in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[i]
		if float(sample(particle.c.bind, 0.0)) >= 1.0:
			particle.node.free()
			_particles.remove_at(i)

func _update(p: Dictionary, age: float) -> void:
	super._update(p, age)
	if String(p.c.name) in ["barrel", "BarrelGlow"]:
		p.node.scale *= BARREL_SIZE_MULTIPLIER
