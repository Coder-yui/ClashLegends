extends RefCounted
const WORLD = preload("res://scripts/battle/battle_world.gd")
## 开始时以真实身体净空规划，结果作为不可重算的部署载荷传给表现与客户端。
static func plan(world: WORLD, team: int, destination: Vector2, radius: float) -> PackedVector2Array:
	var nexus := world.king(team)
	if nexus == null: return PackedVector2Array()
	var target := world.nearest_valid_ground_spawn(destination, radius, team)
	if not target.is_finite(): return PackedVector2Array()
	# 从水晶外缘出发；不能从建筑中心开始后再穿出其碰撞体。
	var exits: Array[Vector2] = []
	var clearance := nexus.body_radius + radius + ArenaRules.STRUCTURE_SEPARATION + 4.0
	for index in 32:
		var point := nexus.global_position + Vector2.UP.rotated(TAU * float(index)/32.0) * clearance
		if world.is_ground_position_walkable(point, radius): exits.append(point)
	if exits.is_empty(): return PackedVector2Array()
	# 反向多终点搜索一次选择可达水晶出口，复用地面单位的桥岸/建筑净空规则。
	var points := world.find_ground_path_to_any(target, exits, radius)
	if points.is_empty(): return points
	points.reverse()
	return _round(world, points, radius)

static func curve(points: PackedVector2Array) -> Curve2D:
	var result := Curve2D.new()
	result.bake_interval = 2.0
	for point in points: result.add_point(point)
	return result

static func _legal(world: WORLD, points: PackedVector2Array, radius: float) -> bool:
	for index in range(1, points.size()):
		if not world._navigation_segment_walkable(points[index-1],points[index],radius,false): return false
	return true

static func _round(world: WORLD, points: PackedVector2Array, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array([points[0]])
	for index in range(1, points.size()-1):
		var corner := points[index]
		var trim := minf(32.0,minf(corner.distance_to(points[index-1]),corner.distance_to(points[index+1]))*0.25)
		var accepted := false
		for attempt in 5:
			var start := corner.move_toward(points[index-1],trim)
			var end := corner.move_toward(points[index+1],trim)
			var arc := PackedVector2Array([result[-1],start])
			for step in 17:
				var weight := float(step)/16.0
				arc.append(start.lerp(corner,weight).lerp(corner.lerp(end,weight),weight))
			arc.append(points[index+1])
			if _legal(world,arc,radius):
				for point in arc.slice(1,arc.size()-1):
					if result[-1].distance_to(point)>0.001: result.append(point)
				accepted = true
				break
			trim *= 0.5
		if not accepted: result.append(corner)
	if result[-1].distance_to(points[-1])>0.001: result.append(points[-1])
	return result if _legal(world,result,radius) else PackedVector2Array()
