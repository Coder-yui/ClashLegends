extends RefCounted
## Belveth Transform/vecalign: source probability tables, sampled once per birth.
## Only presentation uses this private RNG. Seeking never redraws random values.
var _emitter: Dictionary
var _particles: Array[Dictionary] = []
var _fps := 120.0
var _first_frame := 13

func setup(emitter: Dictionary, fps: float, visual_seed: int = -1) -> void:
	_emitter = emitter
	_fps = fps
	_first_frame = int(floor(float(emitter.timeBeforeFirstEmission) * fps)) + 1
	_particles.clear()
	var rng := RandomNumberGenerator.new()
	if visual_seed < 0: rng.randomize()
	else: rng.seed = visual_seed
	var phase := float(_first_frame) / fps / float(emitter.lifetime)
	var count := maxi(int(_draw(emitter.rate, phase, rng)[0]), 1)
	for i in count:
		var shared := rng.randf()
		var life := float(_draw(emitter.particleLifetime, phase, rng)[0])
		var velocity := _vec3(_draw(emitter.birthVelocity, phase, rng))
		var size := _draw(emitter.birthScale0, phase, rng)
		var drag := _vec3(_draw(emitter.birthDrag, phase, rng))
		var color := _draw(emitter.birthColor, phase, rng)
		_particles.append({"serial": i, "birth": float(_first_frame) / fps - (1.0 - float(i + 1) / count) / fps,
			"life": life, "velocity": velocity, "size": size, "drag": drag, "color": color, "shared": shared})

func sample(frame: int) -> Array:
	var result: Array = []
	if frame < _first_frame: return result
	var now := float(frame) / _fps
	var steps := frame - _first_frame
	for particle in _particles:
		var age := now - float(particle.birth)
		if age >= float(particle.life): continue
		var through := clampf(age / float(particle.life), 0.0, 1.0)
		var place := _vec3(_curve(_emitter.emitterPosition, 0.0))
		var travel := Vector3.ZERO
		# Closed sum of the original stepped drag: v *= (1-drag/fps), p += v/fps.
		# Fresh particles have zero travel on their emission frame.
		for axis in 3:
			var v: float = particle.velocity[axis]
			var drag: float = particle.drag[axis]
			var decay := maxf(1.0 - drag / _fps, 0.0)
			var factor := pow(decay, steps)
			place[axis] += v * decay * (1.0 - factor) / drag if drag > 0.0 else v * steps / _fps
			travel[axis] = v * factor if steps > 0 else 0.0
		place.x = -place.x
		travel.x = -travel.x
		var up := travel.normalized() if not travel.is_zero_approx() else Vector3.UP
		var stretch := maxf(float(_emitter.directionVelocityMinScale), travel.length() * float(_emitter.directionVelocityScale))
		var size := _curve(_emitter.scale0, through)
		for axis in 3: size[axis] *= particle.size[axis]
		size[1] *= stretch
		var color := _curve(_emitter.color, through)
		for channel in 4: color[channel] *= particle.color[channel] * _emitter.modulation[channel]
		var book: Dictionary = _emitter.uv.book
		var cell := int(float(book.start) + (particle.shared * float(book.frames) if book.randomStart else 0.0))
		var columns := maxi(int(book.divisions[0]), 1)
		var rows := maxi(int(book.divisions[1]), 1)
		cell = posmod(cell, columns * rows)
		# Same 38-float renderer contract as source-exported samples; no new shader scale.
		result.append([particle.serial, place.x, place.y, place.z, size[0], size[1], size[2],
			color[0], color[1], color[2], color[3], 0.0,
			1.0, up.x, 0.0, 0.0, up.y, 0.0, 0.0, up.z, 1.0,
			0.0, 1.0, 1.0, 0.0, 0.0, float(cell % columns) / columns, float(cell / columns) / rows,
			0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0,
			through, 1.0, _curve(_emitter.erosion.drive, through)[0]])
	return result

static func _vec3(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

static func _curve(value: Dictionary, at: float) -> Array:
	var keys: Array = value.keys
	return value.constant.duplicate() if keys.is_empty() else _keys(keys, at)

static func _keys(keys: Array, at: float) -> Array:
	if at <= float(keys[0].time): return keys[0].values.duplicate()
	for i in range(1, keys.size()):
		if at < float(keys[i].time):
			var weight := (at - float(keys[i - 1].time)) / (float(keys[i].time) - float(keys[i - 1].time))
			var values: Array = keys[i - 1].values.duplicate()
			for channel in values.size(): values[channel] = lerpf(values[channel], keys[i].values[channel], weight)
			return values
	return keys.back().values.duplicate()

static func _draw(value: Dictionary, at: float, rng: RandomNumberGenerator) -> Array:
	var values := _curve(value, at)
	for table in value.tables:
		var chance := rng.randf()
		var multiplier: float = table.single if table.keys.is_empty() else _keys(table.keys, chance)[0]
		values[int(table.channel)] *= multiplier
	return values
