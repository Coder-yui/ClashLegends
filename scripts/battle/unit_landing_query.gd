class_name UnitLandingQuery
extends RefCounted
## 连续几何最近落点：合法矩形区域扣除扩张圆柱。只移动请求者，不推其他单位。
## 最近可行点必在区域投影、圆周径向投影或边界交点上；无解返回INF。
static func find_position(unit: Unit, desired: Vector2, allow_terrain: bool) -> Vector2:
	var circles := _circles(unit, allow_terrain)
	var regions := _regions(unit.body_radius, allow_terrain)
	var candidates: Array[Vector2] = []
	for region in regions:
		candidates.append(Vector2(clampf(desired.x,region.position.x,region.end.x),clampf(desired.y,region.position.y,region.end.y)))
		for point in [region.position,region.end,Vector2(region.position.x,region.end.y),Vector2(region.end.x,region.position.y)]: candidates.append(point)
	for index in circles.size():
		var circle: Vector3 = circles[index]
		var center := Vector2(circle.x,circle.y)
		var direction := center.direction_to(desired)
		if direction.is_zero_approx(): direction = Vector2.UP if unit.team == 0 else Vector2.DOWN
		candidates.append(center+direction*circle.z)
		for region in regions:
			for x in [region.position.x,region.end.x]:
				var delta := circle.z*circle.z-pow(x-center.x,2.0)
				if delta >= 0.0:
					candidates.append(Vector2(x,center.y+sqrt(delta)))
					candidates.append(Vector2(x,center.y-sqrt(delta)))
			for y in [region.position.y,region.end.y]:
				var delta := circle.z*circle.z-pow(y-center.y,2.0)
				if delta >= 0.0:
					candidates.append(Vector2(center.x+sqrt(delta),y))
					candidates.append(Vector2(center.x-sqrt(delta),y))
		for other_index in range(index+1,circles.size()):
			var other: Vector3 = circles[other_index]
			var offset := Vector2(other.x,other.y)-center
			var distance := offset.length()
			if distance < 0.00001 or distance > circle.z+other.z or distance < absf(circle.z-other.z): continue
			var along := (circle.z*circle.z-other.z*other.z+distance*distance)/(2.0*distance)
			var height := sqrt(maxf(0.0,circle.z*circle.z-along*along))
			var axis := offset/distance
			var foot := center+axis*along
			var side := Vector2(-axis.y,axis.x)*height
			candidates.append(foot+side)
			candidates.append(foot-side)
	var best := Vector2(INF,INF)
	var best_distance := INF
	for point in candidates:
		var distance := desired.distance_squared_to(point)
		if distance > best_distance+0.0001 or not _legal(point,regions,circles): continue
		if absf(distance-best_distance) <= 0.0001 and best.is_finite():
			# 镜像阵营同距优先前方，再按横向固定顺序。
			var sign_value := 1.0 if unit.team == 0 else -1.0
			if point.y*sign_value > best.y*sign_value+0.0001: continue
			if absf(point.y-best.y) <= 0.0001 and point.x*sign_value >= best.x*sign_value: continue
		best = point
		best_distance = distance
	return best

## 在目标攻击范围内检查3圈各16点，优先最小挤出距离，不产生自主移动。
## 最远两格；无近处合法站位时不挤出，避免跳到远处或退回射程外。
static func find_attack_exit(unit: Unit, target: Node2D) -> Vector2:
	if not is_instance_valid(target) or target.hp <= 0.0: return Vector2(INF, INF)
	var regions := _regions(unit.body_radius, false)
	var circles := _circles(unit, false)
	var inner: float = unit.body_radius + target.body_radius + ArenaRules.STRUCTURE_SEPARATION + 0.01
	var outer: float = unit.body_radius + target.body_radius + unit.attack_range - 2.0
	if outer < inner: return Vector2(INF, INF)
	var direction := target.global_position.direction_to(unit.global_position)
	if direction.is_zero_approx(): direction = Vector2.DOWN if unit.team == 0 else Vector2.UP
	var best := Vector2(INF, INF)
	var best_distance := pow(ArenaRules.TILE_SIZE * 2.0, 2.0) + 0.0001
	for radius in [inner, (inner + outer) * 0.5, outer]:
		for index in 16:
			var point: Vector2 = target.global_position + direction.rotated(TAU * index / 16.0) * radius
			var distance := unit.global_position.distance_squared_to(point)
			if distance >= best_distance or not _legal(point, regions, circles): continue
			best = point
			best_distance = distance
	return best

static func legal(unit: Unit, point: Vector2, allow_terrain: bool) -> bool:
	return _legal(point,_regions(unit.body_radius,allow_terrain),_circles(unit,allow_terrain))

static func _circles(unit: Unit, allow_terrain: bool) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for other in unit.get_tree().get_nodes_in_group("combatants"):
		if other == unit or not is_instance_valid(other) or other.hp <= 0.0: continue
		var structure: bool = other is Tower or (other is Unit and other.is_building)
		if structure and allow_terrain: continue
		if not structure and (not other is Unit or other.is_air != unit.is_air): continue
		# 极小安全余量抵消Vector2浮点交点误差，不借用普通接触的穿透容差。
		var radius: float = unit.body_radius+other.body_radius+0.002
		if structure: radius += ArenaRules.STRUCTURE_SEPARATION
		result.append(Vector3(other.global_position.x,other.global_position.y,radius))
	return result

static func _regions(radius: float, allow_terrain: bool) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var field := Rect2(Vector2(radius,radius),Vector2(ArenaRules.FIELD_W-2.0*radius,ArenaRules.FIELD_H-2.0*radius))
	if allow_terrain:
		result.append(field)
		return result
	var upper := ArenaRules.RIVER_Y-ArenaRules.RIVER_HALF-radius-0.002
	var lower := ArenaRules.RIVER_Y+ArenaRules.RIVER_HALF+radius+0.002
	result.append(Rect2(Vector2(radius,radius),Vector2(field.size.x,upper-radius)))
	result.append(Rect2(Vector2(radius,lower),Vector2(field.size.x,field.end.y-lower)))
	var half := ArenaRules.BRIDGE_HALF-radius-0.002
	if half > 0.0:
		for x in [ArenaRules.BRIDGE_X_LEFT,ArenaRules.BRIDGE_X_RIGHT]: result.append(Rect2(Vector2(x-half,radius),Vector2(2.0*half,field.size.y)))
	return result

static func _legal(point: Vector2, regions: Array[Rect2], circles: Array[Vector3]) -> bool:
	var in_region := false
	for region in regions:
		if point.x >= region.position.x-0.0001 and point.x <= region.end.x+0.0001 and point.y >= region.position.y-0.0001 and point.y <= region.end.y+0.0001:
			in_region = true
			break
	if not in_region: return false
	for circle in circles:
		if point.distance_squared_to(Vector2(circle.x,circle.y)) < circle.z*circle.z-0.01: return false
	return true
