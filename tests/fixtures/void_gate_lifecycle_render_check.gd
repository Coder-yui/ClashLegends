extends SceneTree
## Full effect integration: never masks emitter pools in the captured result.
var viewport: SubViewport
func _initialize(): call_deferred("run")
func frame() -> Image:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	return viewport.get_texture().get_image()
func difference(a: Image, b: Image) -> float:
	var sum := 0.0
	for y in range(112, 144):
		for x in range(112, 144):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			sum += absf(ca.r-cb.r) + absf(ca.g-cb.g) + absf(ca.b-cb.b)
	return sum / (32 * 32 * 3)
func run():
	viewport = SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.4
	camera.current = true
	var view = load("res://assets/units/void_gate/void_gate_view.tscn").instantiate()
	world.add_child(view)
	view.set_process(false)
	var failures := 0
	var cases := 0
	for angle in [Vector3(0,0,5), Vector3(0,3,4), Vector3(3,3,-4)]:
		view.reset_pool_visual()
		view.seek_phase("Spawn", 1.7, 1.7)
		for cycle in 3:
			view.seek_phase("Idle1", 0.0, 0.0)
			if cycle > 0: view.seek_phase("Idle1", 5.0667, 5.0667)
			var previous := 0.0
			for age in [0.12, 0.192, 0.28]:
				view.seek_phase("Spit", age, age - previous)
				previous = age
				var fx: Node3D = view._effects.spit
				var center := fx.to_global(Vector3(0,50,0))
				camera.position = center + angle
				camera.look_at(center)
				# Recompute sorting after the camera changes; all authored layers stay on.
				fx._frame = -1
				fx.seek(age)
				for tail in view._tails:
					tail.effect._frame = -1
					tail.effect.seek(tail.age)
				var full: Image = await frame()
				view._effects.idle.hide()
				var no_idle: Image = await frame()
				fx.hide()
				var no_spit: Image = await frame()
				fx.show()
				view._effects.idle.show()
				for tail in view._tails: tail.effect.show()
				var error := difference(full, no_idle)
				var contrast := difference(no_idle, no_spit)
				cases += 1
				print("FULL_GATE cycle=",cycle+1," age=",age," angle=",angle," idle_center=",error," spit_signal=",contrast)
				if error >= 0.002 or (age >= 0.192 and contrast < 0.01) or not view._effects.has("idle"): failures += 1
			view.seek_phase("Idle1", 0.0, 0.9333 - previous)
	viewport.free()
	print("FULL_GATE_RESULT cases=", cases, " failures=", failures)
	quit(0 if failures == 0 else 1)
