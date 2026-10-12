extends SceneTree
var viewport: SubViewport
var idle: Node3D
var spit: Node3D
func _initialize(): call_deferred("run")
func frame() -> Image:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	return viewport.get_texture().get_image()
func difference(a: Image, b: Image) -> float:
	var sum := 0.0
	for y in range(112,144):
		for x in range(112,144):
			var ca := a.get_pixel(x,y)
			var cb := b.get_pixel(x,y)
			sum += absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)
	return sum/(32*32*3)
func run():
	viewport=SubViewport.new()
	viewport.size=Vector2i(256,256)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world:=Node3D.new()
	viewport.add_child(world)
	var camera:=Camera3D.new()
	world.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.4
	camera.position=Vector3(0,1.0625,5)
	camera.current=true
	for kind in ["idle","spit"]:
		var fx=load("res://assets/effects/void_gate/player.gd").new()
		world.add_child(fx)
		fx.load_kind(kind)
		fx.setup_native(0.02125)
		fx.seek(5.0 if kind=="idle" else 0.192)
		for i in fx._pools.size():
			if fx._data.emitters[i].name!="void1":
				for item in fx._pools[i]: item.hide()
		if kind=="idle":idle=fx
		else:spit=fx
	var failures := 0
	for angle in [Vector3(0,0,5), Vector3(0,3,4), Vector3(3,3,-4)]:
		camera.position = Vector3(0,1.0625,0) + angle
		camera.look_at(Vector3(0,1.0625,0))
		for age in [0.05,0.12,0.192,0.28,0.70]:
			for fx in [idle,spit]:
				fx._frame = -1
				fx.seek(5.0 if fx==idle else age)
				for i in fx._pools.size():
					if fx._data.emitters[i].name!="void1":
						for item in fx._pools[i]: item.hide()
			idle.show()
			spit.show()
			var both:Image=await frame()
			idle.hide()
			var spit_only: Image = await frame()
			idle.show()
			spit.hide()
			var idle_only: Image = await frame()
			idle.hide()
			var empty: Image = await frame()
			var error := difference(both, spit_only if age >= 0.12 and age < 0.3 else idle_only)
			var contrast := difference(both, empty)
			print("OCCLUSION angle=",angle," age=",age," error=",error," signal=",contrast)
			# Early small Spit is already on top; at its opaque peak it hides Idle,
			# and after the source fade the unchanged Idle sphere is visible again.
			if contrast < 0.01: failures += 1
			if age < 0.12:
				if error < 0.002: failures += 1
			elif error >= 0.002: failures += 1
	viewport.free()
	print("OCCLUSION_RESULT cases=15 failures=",failures)
	quit(0 if failures==0 else 1)
