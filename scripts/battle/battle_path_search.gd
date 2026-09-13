class_name BattlePathSearch
extends RefCounted
## 对应 APK 0x115c7ac/0x115c118/0x115c284 的新版 A* 搜索核心。
## 地图/状态负责提供代价；本模块不推断水域、建筑或人物半径。
const NEIGHBORS := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(1, -1)]
var _g := PackedInt32Array()
var _f := PackedInt32Array()
var _state := PackedByteArray()
var _parent := PackedInt32Array()
var _heap := PackedInt32Array()
var _heap_index := PackedInt32Array()

## -1 表示调用者禁止进入。可通行代价须 >= heuristic_cost，保证启发式一致。
## 搜索层与原生一样允许斜向夹角；实际身体/地形限制由移动层处理。
func find_cells(size: Vector2i, costs: PackedInt32Array, start: Vector2i, goal: Vector2i,
		heuristic_cost: int = 5) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var region := Rect2i(Vector2i.ZERO, size)
	if size.x <= 0 or size.y <= 0 or costs.size() != size.x * size.y:
		return result
	if not region.has_point(start) or not region.has_point(goal):
		return result
	var source := start.x + start.y * size.x
	var target := goal.x + goal.y * size.x
	if costs[source] < 0 or costs[target] < 0:
		return result
	var count := costs.size()
	_g.resize(count)
	_f.resize(count)
	_state.resize(count)
	_parent.resize(count)
	_heap_index.resize(count)
	_g.fill(0)
	_f.fill(0)
	_state.fill(0)
	_parent.fill(-1)
	_heap_index.fill(-1)
	_heap.clear()
	_heap.append(source)
	_heap_index[source] = 0
	_state[source] = 1
	while not _heap.is_empty():
		var current := _pop()
		_state[current] = 2
		if current == target:
			var cursor := target
			while cursor != -1:
				result.append(Vector2i(cursor % size.x, cursor / size.x))
				cursor = _parent[cursor]
			result.reverse()
			return result
		var cell := Vector2i(current % size.x, current / size.x)
		for direction in NEIGHBORS:
			var next: Vector2i = cell + direction
			if not region.has_point(next):
				continue
			var index := next.x + next.y * size.x
			if costs[index] < 0 or _state[index] == 2:
				continue # 原生本模式 refresh_open=true, reopen_closed=false。
			var step := 14 if direction.x != 0 and direction.y != 0 else 10
			var score := _g[current] + costs[index] * step
			if _state[index] == 1 and score >= _g[index]:
				continue
			_parent[index] = current
			_g[index] = score
			var delta := (goal - next).abs()
			_f[index] = score + heuristic_cost * (10 * (delta.x + delta.y) - 6 * mini(delta.x, delta.y))
			if _state[index] == 0:
				_state[index] = 1
				_heap_index[index] = _heap.size()
				_heap.append(index)
			_rise(_heap_index[index])
	return result

func _rise(index: int) -> void:
	while index > 0:
		var parent := (index - 1) / 2
		if _f[_heap[parent]] <= _f[_heap[index]]:
			break
		_swap(index, parent)
		index = parent

func _pop() -> int:
	var first := _heap[0]
	var last := _heap[_heap.size() - 1]
	_heap.resize(_heap.size() - 1)
	_heap_index[first] = -1
	if not _heap.is_empty():
		_heap[0] = last
		_heap_index[last] = 0
		var index := 0
		while true:
			var best := index
			var right := index * 2 + 2
			var left := index * 2 + 1
			# 原生先比较右孩子，严格小于才交换；等代价路线依赖这个顺序。
			if right < _heap.size() and _f[_heap[right]] < _f[_heap[best]]:
				best = right
			if left < _heap.size() and _f[_heap[left]] < _f[_heap[best]]:
				best = left
			if best == index:
				break
			_swap(index, best)
			index = best
	return first

func _swap(a: int, b: int) -> void:
	var value := _heap[a]
	_heap[a] = _heap[b]
	_heap[b] = value
	_heap_index[_heap[a]] = a
	_heap_index[_heap[b]] = b
