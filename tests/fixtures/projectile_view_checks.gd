extends "res://tests/suites/battle_suite.gd"
## 表现投影的内容代次与所有权合同；真实7消费者调用数由独立GUI性能夹具记录。
class CountingProjectiles extends ProjectileSystem:
	var builds := 0
	func _build_visible_view(source: Dictionary) -> Dictionary:
		builds += 1
		return super._build_visible_view(source)

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_expect(_main.runtime.mode == "local" and not _main.runtime.game_over, "弹体表现子检查承接正常本地战场")
	_main._projectile_system.clear_all()
	_main.reset_network_clock()
	_check_authority_view()
	_check_client_interpolation()
	_check_delayed_wave()
	_check_lock_cancellation()
	_check_source_lifetime_and_form()
	_check_wire_speed_and_consumers()
	_check_end_and_new_owner()

func _owner() -> CountingProjectiles:
	var owner := CountingProjectiles.new()
	# 使用正式上下文与命中路径；本套件不重复创建图形子节点。
	owner._context = _main.battle_context
	_main.add_child(owner)
	return owner

func _pair(card: String = "ashe") -> Array[Unit]:
	return [_spawn_test_unit(card, 0, Vector2(10000, 10000)), _spawn_test_unit("xin", 1, Vector2(10500, 10000))]

func _launch(owner: ProjectileSystem, pair: Array[Unit]) -> void:
	_expect(owner.launch(pair[0], pair[1], 25.0, 400.0, 0.0, 0.0, Color.WHITE), "真实发射入口创建测试弹体")

func _free_pair(pair: Array[Unit]) -> void:
	for unit in pair:
		if is_instance_valid(unit): unit.free()

func _has_object(value: Variant) -> bool:
	if value is Object: return true
	if value is Dictionary:
		for key in value:
			if _has_object(key) or _has_object(value[key]): return true
	if value is Array:
		for child in value:
			if _has_object(child): return true
	return false

func _check_authority_view() -> void:
	var owner := _owner()
	var empty := owner.visible_view()
	_expect(empty.is_read_only() and empty.is_empty() and is_same(empty, owner.visible_view()) and owner.builds == 1, "空表现代次只构建一次且只读")
	var pair := _pair()
	_launch(owner, pair)
	var first := owner.visible_view()
	var id: int = first.keys()[0]
	var row: Dictionary = first[id]
	var path: Dictionary = row.visual_path
	_expect(owner.builds == 2 and empty.is_empty() and first.size() == 1, "发射失效旧代次，先前读者仍持有独立旧内容")
	_expect(first.is_read_only() and row.is_read_only() and path.is_read_only() and path.source.is_read_only() and path.target.is_read_only(), "顶层、行、路径与双方实体描述全部只读")
	_expect(not _has_object(first) and not row.has("attacker") and not row.has("target") and not row.has("effects") and not row.has("skill") and not row.has("cast") and not row.has("damage"), "表现投影没有对象、伤害、技能或权威状态别名")
	_expect(not is_same(path, owner.projectiles[id].visual_path) and not is_same(path.source, owner.projectiles[id].visual_path.source), "路径与描述符拥有独立容器")
	_expect(not owner.projectiles[id].is_read_only() and not owner.projectiles[id].visual_path.is_read_only() and not owner.projectiles[id].effects.is_read_only(), "构建只读视图不冻结权威弹体、路径或效果")
	for key in ProjectileSystem.VISIBLE_FIELDS:
		_expect(not owner.projectiles[id].has(key) or row.get(key) == owner.projectiles[id][key], "表现字段保持实际出手值：" + key)
	_expect(owner._visual_position(row) == owner._visual_position(owner.projectiles[id]) and owner._direction(row) == owner._direction(owner.projectiles[id]), "同一内容代次投影位置与朝向等于原权威读取")
	for _read in 7: _expect(is_same(first, owner.visible_view()), "同代次多读共享同一不可变投影")
	_expect(owner.builds == 2, "多读没有再次构建（此为合同检查，不作为真实生产调用次数证据）")
	var snapshot := owner.visible_snapshot()
	snapshot[id].pos = Vector2.ZERO
	snapshot[id].visual_path.progress = 99.0
	_expect(owner.projectiles[id].pos == row.pos and owner.projectiles[id].visual_path.progress == path.progress and not snapshot[id].is_read_only(), "原visible_snapshot仍返回可独立修改的隔离副本")
	var before: Vector2 = row.pos
	owner.tick(0.05)
	var after := owner.visible_view()
	_expect(owner.builds == 3 and not is_same(first, after) and first[id].pos == before and after[id].pos != before, "同引擎帧内模拟后必须使用新代次，旧读者不变")
	owner.hide()
	owner.tick(0.05)
	var hidden := owner.visible_view()
	owner.show()
	_expect(hidden[id].pos != after[id].pos and is_same(hidden, owner.visible_view()), "隐藏中内容仍正常推进，重新显示不复用过期位置")
	owner.clear_all()
	_expect(owner.visible_view().is_empty() and first.size() == 1, "clear释放缓存内容且不改写外部持有的不可变旧视图")
	owner.free()
	_free_pair(pair)

func _check_client_interpolation() -> void:
	var owner := _owner()
	var pair := _pair()
	_launch(owner, pair)
	var authority := owner.visible_view()
	var id: int = authority.keys()[0]
	var targets := owner.authoritative_snapshot()
	targets[id]["target_pos"] = targets[id].pos
	targets[id]["target_visual_offset"] = targets[id].visual_offset
	var old_mode: String = _main.runtime.mode
	_main.runtime.mode = "client"
	owner.apply_client_targets(targets)
	var first := owner.visible_view()
	_expect(not is_same(first, authority) and first[id].pos == authority[id].pos, "模式切换选择客户端内容，不误用权威缓存")
	var original: Vector2 = first[id].pos
	targets[id].pos += Vector2(120, 30)
	targets[id].target_pos = targets[id].pos
	targets[id].visual_offset += Vector2(4, 8)
	targets[id].target_visual_offset = targets[id].visual_offset
	targets[id].visual_path.end += Vector2(10, 5)
	owner.apply_client_targets(targets)
	var received := owner.visible_view()
	_expect(not is_same(first, received) and received[id].pos == original and received[id].visual_path.end != first[id].visual_path.end, "收包更新路径及插值目标，同时保留当前可见位置")
	targets[id].visual_path.end = Vector2.ZERO
	_expect(received[id].visual_path.end != Vector2.ZERO, "接收输入后修改外部嵌套字典不污染视图")
	var expected := original
	var target: Vector2 = owner.client_snapshot()[id].target_pos
	for frame in 6:
		expected = expected.lerp(target, 14.0 / 120.0)
		owner.tick_client_interpolation(1.0 / 120.0)
		var visible := owner.visible_view()
		_expect(visible[id].pos.is_equal_approx(expected) and visible[id].pos != original, "120Hz第%d帧继续真实插值，不退为20Hz" % frame)
		_expect(is_same(visible, owner.visible_view()), "插值完成后的同代次可重复读取")
	var stable := owner.visible_view()
	var builds := owner.builds
	owner.tick_client_interpolation(0.0)
	_expect(is_same(stable, owner.visible_view()) and owner.builds == builds, "没有内容变化的零时长插值不重建")
	_expect(first[id].pos == original and authority[id].pos == original, "客户端逐帧推进不污染旧视图或权威视图")
	owner.apply_client_targets({})
	_expect(owner.visible_view().is_empty(), "完整收包删除消失的可见弹体")
	owner.clear_client()
	_expect(owner.visible_view().is_empty(), "客户端clear后不残留可见缓存")
	_main.runtime.mode = old_mode
	_expect(owner.visible_view().has(id) and owner.visible_view()[id].pos == original, "切回权威端选择未被客户端插值改变的真实内容")
	owner.clear_all()
	owner.free()
	_free_pair(pair)

func _check_delayed_wave() -> void:
	var owner := _owner()
	var pair := _pair("kayle_ranged")
	_launch(owner, pair)
	var first := owner.visible_view()
	_expect(first.size() == 1 and owner._pending_attack_waves.size() == 1, "真实天使发射仅展示光剑，延迟焰浪不提前出现")
	owner.tick(0.05)
	_expect(owner.visible_view().size() == 1, "延迟首Tick保持单弹体")
	owner.tick(0.05)
	var released := owner.visible_view()
	_expect(released.size() == 2 and first.size() == 1 and released.values().any(func(p): return p.visual == &"kayle_wave"), "延迟焰浪发布失效并立即进入新视图，旧视图不变")
	owner.clear_all()
	owner.free()
	_free_pair(pair)

func _check_lock_cancellation() -> void:
	var owner := _owner()
	var pair := _pair()
	_launch(owner, pair)
	var flying := owner.visible_view()
	pair[1].target_protection.begin(pair[1].position, 100.0, 4.0)
	owner.invalidate_target_locks(pair[1])
	_expect(owner.visible_view().is_empty() and flying.size() == 1, "结界取消目标锁立即失效视图，旧内容不被写回")
	pair[0].position = pair[1].position + Vector2(-50, 0)
	_launch(owner, pair)
	var allowed := owner.visible_view()
	owner.invalidate_target_locks(pair[1])
	_expect(allowed.size() == 1 and is_same(allowed, owner.visible_view()), "合法圈内来源保持弹体，不因无变化取消检查而重建")
	owner.clear_all()
	owner.free()
	_free_pair(pair)

func _check_source_lifetime_and_form() -> void:
	var owner := _owner()
	var pair := _pair()
	_launch(owner, pair)
	var old := owner.visible_view()
	var target_hp := pair[1].hp
	pair[0].free()
	for _tick in 30: owner.tick(0.05)
	_expect(pair[1].hp == target_hp - 25.0 and owner.visible_view().is_empty() and not _has_object(old), "来源释放后在途弹体仍独立命中，旧表现投影不持有来源节点")
	pair[1].free()
	owner.clear_all()
	pair = _pair("gnar")
	# 换形会执行完整身体落点校验，不能沿用纯弹体用例的场外隔离坐标。
	pair[0].position = Vector2(100, 800)
	pair[1].position = Vector2(600, 800)
	_launch(owner, pair)
	var launched := owner.visible_view()
	var id: int = launched.keys()[0]
	var generation: int = owner.projectiles[id].effects.source_generation
	_expect(pair[0].transform_to_mega() and not _main.runtime.game_over and UnitLandingQuery.legal(pair[0], pair[0].position, false), "真实纳尔换形成功且保持合法落点和运行中的战场")
	owner.tick(0.05)
	_expect(owner.visible_view()[id].visual == launched[id].visual and owner.visible_view()[id].source_form_index == 0 and owner.projectiles[id].effects.source_generation == generation and pair[0].form_change_serial > generation, "来源换形不改出手弹体外观、形态或generation归因")
	target_hp = pair[1].hp
	for _tick in 30: owner.tick(0.05)
	_expect(pair[1].hp == target_hp - 25.0 and pair[0].transform_hit_count == 0, "跨形态弹体保留伤害且不把旧generation收益记给新形态")
	owner.clear_all()
	owner.free()
	_free_pair(pair)

func _sync_flight_effect(view: Node3D, card: String, system: ProjectileSystem, camera: Camera3D) -> void:
	if card == "tristana": view.sync_effects(system, camera)
	else: view.sync_effects(_main._skill_presentation, system, camera)

func _capture_next_flight(snapshot: NetworkSnapshotSystem, system: ProjectileSystem, tick: int) -> Array:
	var mode_before: String = _main.runtime.mode
	var tick_before: int = _main.runtime._sim_tick_id
	_main.runtime.mode = "local"
	_main.runtime._sim_tick_id = tick
	system.tick(0.05)
	var frame := snapshot.capture_public_frame()
	_main.runtime._sim_tick_id = tick_before
	_main.runtime.mode = mode_before
	return frame

func _check_wire_speed_and_consumers() -> void:
	var system: ProjectileSystem = _main._projectile_system
	system.clear_all()
	var snapshot := NetworkSnapshotSystem.new(_main, system)
	snapshot.reset_session("projectile-speed-wire")
	var specs := [
		{"card": "anivia", "effect": "res://scripts/presentation/anivia_effect_3d.gd"},
		{"card": "tristana", "effect": "res://scripts/presentation/gwen_tristana_effect_3d.gd"},
		{"card": "voidfish_ranged_single", "effect": "res://scripts/presentation/voidfish_effect_3d.gd"},
	]
	var targets: Array[Unit] = []
	var sources: Array[Unit] = []
	var ids: Array[int] = []
	var speeds: Array[float] = []
	for index in specs.size():
		var source := _spawn_test_unit(specs[index].card, 0, Vector2(10000, 10000 + index * 500))
		var target := _spawn_test_unit("xin", 1, source.position + Vector2(600, 0))
		source.buffs.apply(&"ranged_attack", source.status_source("speed_contract"), 2.0, {"projectile_speed_multiplier": 1.75})
		_expect(system.launch(source, target, 25.0, source.projectile_speed, 0.0, 0.0, Color.WHITE), "%s真实发射带强化速度弹体" % specs[index].card)
		var id: int = system.projectiles.keys().back()
		sources.append(source)
		targets.append(target)
		ids.append(id)
		speeds.append(source.projectile_speed * 1.75)
		source.buffs.advance(2.0)
		_expect(source.buffs.strongest(&"ranged_attack", &"projectile_speed_multiplier", 1.0) == 1.0 and system.projectiles[id].speed == speeds[index], "强化到期不改变已经发射弹体的实际速度")
	for _tick in 3: system.tick(0.05)
	for source in sources: source.free()
	var frame := snapshot.capture_public_frame()
	for index in ids.size():
		var payload: Array = frame[NetworkSnapshotSystem.S_PROJECTILES].filter(func(p): return int(p[NetworkSnapshotSystem.P_ID]) == ids[index])[0]
		_expect(payload.size() == 15 and payload[NetworkSnapshotSystem.P_SPEED] == speeds[index] and payload[NetworkSnapshotSystem.P_X] > payload[NetworkSnapshotSystem.P_VISUAL_PATH].start.x, "来源释放后真实capture仍发送已飞位置和原出膛速度")
	_check_received_flight_effects(snapshot, system, frame, specs, ids, speeds)
	system.clear_all()
	snapshot.reset_session("")
	for target in targets: target.free()

func _check_received_flight_effects(snapshot: NetworkSnapshotSystem, system: ProjectileSystem, frame: Array, specs: Array, ids: Array[int], speeds: Array[float]) -> void:
	var old_mode: String = _main.runtime.mode
	var old_team: int = _main.runtime.local_team
	_main.runtime.mode = "client"
	_main.runtime.local_team = 1
	var decoded := snapshot.decode_validated(snapshot.encode_frame(frame))
	var applied := decoded != null and snapshot.apply_decoded(decoded)
	_expect(applied, "真实capture/encode/decode/apply往返完整速度元数据")
	if not applied:
		_main.runtime.mode = old_mode
		_main.runtime.local_team = old_team
		return
	var first := system.visible_view()
	_expect(not _has_object(first), "真实客户端飞行视图不依赖已经释放的来源对象")
	var views: Array[Node3D] = []
	var initial_ages: Array[float] = []
	var camera: Camera3D = _main._battle_presentation._camera
	for index in specs.size():
		var view: Node3D = load(specs[index].effect).new()
		_main._battle_presentation._world_root.add_child(view)
		_sync_flight_effect(view, specs[index].card, system, camera)
		_expect(first[ids[index]].speed == speeds[index] and view._missiles.has(ids[index]), "真实%s消费者首次收到已飞弹体时读取实际网络速度" % specs[index].card)
		views.append(view)
		initial_ages.append(float(view._missiles[ids[index]].age))
		if specs[index].card == "voidfish_ranged_single":
			var distance: float = (first[ids[index]].pos as Vector2).distance_to(first[ids[index]].visual_path.start)
			_expect(is_equal_approx(initial_ages.back(), distance / speeds[index]) and initial_ages.back() > 0.0, "远程虚空鱼首次已飞年龄按出膛速度恢复")
	# 位置来自下一次真实权威弹体推进和capture，不在夹具中填speed或猜测基础值。
	var next_frame := _capture_next_flight(snapshot, system, int(frame[NetworkSnapshotSystem.S_SERVER_TICK]) + 1)
	var next := snapshot.decode_validated(snapshot.encode_frame(next_frame))
	_expect(next != null and snapshot.apply_decoded(next), "后续真实capture更新客户端插值目标")
	system.tick_client_interpolation(1.0 / 60.0)
	var interpolated := system.visible_view()
	for index in specs.size():
		_sync_flight_effect(views[index], specs[index].card, system, camera)
		var distance: float = (interpolated[ids[index]].pos as Vector2).distance_to(first[ids[index]].pos)
		_expect(distance > 0.0 and is_equal_approx(float(views[index]._missiles[ids[index]].age) - initial_ages[index], distance / speeds[index]), "%s逐帧年龄增量严格等于可见位移/实际速度" % specs[index].card)
	# 普通收包的真实消费者释放；终态未知恢复由TerminalSuite正式host/RPC路径覆盖。
	system.clear_client()
	for index in specs.size():
		_sync_flight_effect(views[index], specs[index].card, system, camera)
		_expect(views[index]._missiles.is_empty(), "清场释放普通快照创建的弹体表现")
		views[index].free()
	_main.runtime.mode = old_mode
	_main.runtime.local_team = old_team

func _check_end_and_new_owner() -> void:
	var system: ProjectileSystem = _main._projectile_system
	var pair := _pair()
	_launch(system, pair)
	var before := system.visible_view()
	_main._end_game(0, "projectile_view_test")
	_expect(system.visible_view().is_empty() and system.projectiles.is_empty() and system.client_snapshot().is_empty(), "真实终局清理权威、客户端弹体和表现缓存")
	var new_owner := _owner()
	_expect(new_owner.visible_view().is_empty() and not is_same(before, new_owner.visible_view()), "新场所有者起点为空，不复用上一局视图")
	_launch(new_owner, pair)
	_expect(new_owner.visible_view().size() == 1 and before.size() == 1, "新所有者独立生成，外部旧视图保持不可变")
	new_owner.clear_all()
	new_owner.free()
	_free_pair(pair)
