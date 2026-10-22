extends RefCounted
## 原数据的camera trail：出生顺序、7点平滑、半宽、长度UV和cutoff。
static func build(particles: Array, positions: Array[Vector3], view: Vector3, cutoff: float, tiling: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if positions.size() < 2: return mesh
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var last := Vector3.ZERO
	var last_side := Vector3.ZERO
	var walked := 0.0
	for i in positions.size():
		var point := positions[i]
		if i > 0:
			point = Vector3.ZERO
			var count := 0
			for j in range(maxi(0,i-3),mini(positions.size(),i+4)):
				point += positions[j]
				count += 1
			point /= count
			walked += point.distance_to(last)
			if cutoff > 0.0 and walked >= cutoff: break
		var tangent := (positions[1]-point) if i == 0 else (point-last)
		var side := view.cross(tangent).normalized()
		if side.is_zero_approx(): side = last_side if i > 0 else Vector3.RIGHT
		var raw_side := side
		if i > 0 and not (side+last_side).is_zero_approx(): side = (side+last_side).normalized()
		var p: Array = particles[i]
		var half := float(p[4])
		vertices.append(point+side*half)
		vertices.append(point-side*half)
		var tint := Color(float(p[7]),float(p[8]),float(p[9]),float(p[10]))
		colors.append(tint)
		colors.append(tint)
		uvs.append(Vector2(walked/maxf(tiling,0.01),0))
		uvs.append(Vector2(walked/maxf(tiling,0.01),1))
		if i > 0: indices.append_array(PackedInt32Array([i*2,i*2-2,i*2-1,i*2,i*2-1,i*2+1]))
		last = point
		last_side = raw_side
	if indices.is_empty(): return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
