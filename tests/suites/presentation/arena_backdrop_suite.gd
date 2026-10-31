extends RefCounted
## Scenery bounds and production camera mapping, no match/deck/audio prewarming.
const LAYOUT := preload("res://scripts/ui/battle_layout.gd")

func run(harness: Object) -> void:
	for flipped in [false, true]:
		var view := BattlePresentation3D.new()
		harness.root.add_child(view)
		view.setup(Vector2(720,1280), 40, flipped)
		var arena := view._world_root.get_node("RiftArena")
		var ground := AABB()
		for node in arena.find_children("*RiftGround*", "MeshInstance3D", true, false):
			var bounds: AABB = node.global_transform * node.get_aabb()
			ground = bounds if ground.size == Vector3.ZERO else ground.merge(bounds)
		harness._expect(ground.size.x > 60 and ground.size.z > 70, "正式地面覆盖扩展外围，非仅复制装饰")
		harness._expect(arena.find_children("*", "CollisionObject3D", true, false).is_empty()
			and arena.find_children("*", "NavigationRegion3D", true, false).is_empty(), "地图不引入碰撞或导航权威")
		for size in [Vector2(720,1280), Vector2(720,1600), Vector2(1024,768), Vector2(1280,720), Vector2(1280,1280), Vector2(360,640), Vector2(3440,1440), Vector2(720,3000)]:
			var canvas: Transform2D = LAYOUT.canvas(size, flipped)
			var rect: Rect2 = LAYOUT.visible_world(size, canvas)
			view.set_view_rect(rect)
			if size.x/size.y >= 9.0/20.0 and size.x/size.y <= 16.0/9.0:
				var a := canvas * rect.position
				var b := canvas * rect.end
				harness._expect(a.min(b).x <= .01 and a.max(b).x >= size.x-.01
					and a.min(b).y <= .01 and a.max(b).y >= size.y-.01, "常用比例完整填充画面：%s/%s" % [size,flipped])
			harness._expect(LAYOUT.BACKDROP_BOUNDS.encloses(rect), "极端比例的绘制尺寸仍有界")
			for point in [rect.position, rect.end, Vector2(rect.position.x,rect.end.y), Vector2(rect.end.x,rect.position.y), Vector2(140,600), Vector2(580,680), Vector2(360,1160)]:
				var origin := BattleGroundProjection.ray_origin(view._camera, point)
				var ray := BattleGroundProjection.ray_normal(view._camera, point)
				var world := origin + ray * (-origin.y/ray.y)
				harness._expect(world.x >= ground.position.x-.02 and world.x <= ground.end.x+.02
					and world.z >= ground.position.z-.02 and world.z <= ground.end.z+.02, "取景地面有实际几何覆盖：%s/%s" % [size,point])
				var drawn := view._render_camera.unproject_position(world)*view._overlay.scale+rect.position
				harness._expect(drawn.distance_to(point)<.02, "外围扩展不改变桥头、水晶和输入投影")
		view.free()
