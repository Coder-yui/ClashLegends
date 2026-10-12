extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_native_lifecycle()
	_check_native_materials()
	_check_birth_alignment()
	var trail: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/void_spawn/trail/sampled.json")).emitters[0]
	var particles = load("res://assets/effects/void_spawn/player.gd")
	_expect(is_equal_approx(particles.native_bind_weight(trail, 0.0), 0.15), "原拖尾出生仅15%绑定身体，不整团跟随骨骼")
	_expect(is_zero_approx(particles.native_bind_weight(trail, 0.1)), "原拖尾四分之一寿命后完全释放在世界空间")
	for team in [0, 1]:
		_clean()
		var gate: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, "void_gate", Vector2(240, 900), {"deploy_time_override": 0.0}))
		_expect(gate.body_radius == 30.0 and gate.footprint_tiles == Vector2i(3, 3), "双方传送门使用30像素身体与3×3部署占地")
		var snapped: Vector2 = _main._snap_card_position("void_gate", Vector2(245, 905), team)
		_expect(snapped == Vector2(260, 900), "3×3传送门吸附格心")
		gate.position = snapped
		_expect(_main._structure_deployment_tiles(gate).size() == 9 and _main._structure_deployment_rect(gate).size == Vector2(120, 120), "传送门完整封锁九格120×120部署区域")
		var neighbor := Vector2(320, 920)
		_expect(_main._is_structure_deployment_tile_blocked(_main._world_to_arena_tile(snapped + Vector2(40, 0))) and not _main._is_structure_deployment_tile_blocked(_main._world_to_arena_tile(neighbor)), "传送门外圈格禁部署，紧邻占地边界的外格保持可用")
		gate.sim_tick(0.05)
		_expect(_children(team).size() == 1, "传送门双方部署完成首批只生成一只")
		_expect(_children(team)[0].summon_visual_origin == gate.global_position, "周期召唤保留真实门心作为只读出生来源")
		_expect(gate.get_visual_action_name() == &"summon", "出兽发布已有快照支持的表现动作")
		for tick in 119: gate.sim_tick(0.05)
		_expect(_children(team).size() == 1, "未满6秒不提前召唤")
		gate.sim_tick(0.05)
		_expect(_children(team).size() == 2, "120Tick后只追加一只")
		gate.freeze(6.5)
		for tick in 120: gate.sim_tick(0.05)
		_expect(_children(team).size() == 2, "冻结期间到期批次等待")
		for tick in 11: gate.sim_tick(0.05)
		_expect(_children(team).size() == 3, "解除冻结只补一批")
		var count := _children(team).size()
		var skill: Dictionary = CardDB.active_skills_for("void_gate")[0]
		_main._active_skill_effect_system.apply(gate, skill)
		_expect(gate.hp == 0.0 and not gate.is_in_group("combatants"), "主动立即死亡并释放占地")
		_expect(_children(team).size() == count + 2, "主动只生成两只，不叠加普通死亡召唤")
		for child in _children(team):
			_expect(child.active_ability_id == -1 and child._base_form_stats.sacrifice_damage == 240.0, "召唤物复用虚空兽但不继承主动资格")
		gate.free()
		_clean()
		gate = _main._spawn_unit(UnitSpawnRequest.new(team, "void_gate", Vector2(240, 900), {"deploy_time_override": 0.0}))
		gate._die()
		_expect(_children(team).is_empty(), "被摧毁不触发主动的两只召唤")
		gate.free()
		_clean()
		gate = _main._spawn_unit(UnitSpawnRequest.new(team, "void_gate", Vector2(240, 900), {"deploy_time_override": 0.0}))
		gate._tick_building_lifetime(1.0)
		_expect(gate.hp == 885.0, "传送门每秒自然衰减15生命")
		gate._tick_building_lifetime(59.0)
		_expect(gate.hp == 0.0 and _children(team).is_empty(), "60秒自然到期，不触发主动召唤")
		gate.free()
	_clean()

func _children(team: int) -> Array:
	return _main.get_tree().get_nodes_in_group("combatants").filter(func(node): return node is Unit and node.card_id == "void_spawn_single" and node.team == team)

func _clean() -> void:
	_main._active_skill_effect_system.clear()
	for node in _main.get_tree().get_nodes_in_group("combatants"):
		if node is Unit: node.free()

func _check_native_lifecycle() -> void:
	var view = load("res://assets/units/void_gate/void_gate_view.tscn").instantiate()
	_main.add_child(view)
	view.set_process(false)
	view.seek_phase("Spawn", 1.7, 1.7)
	view.seek_phase("Idle1", 0.0, 0.3)
	_expect(view._effects.spawn.visible and is_equal_approx(view._ages.spawn, 2.0), "部署长尾跨Idle切换持续，未在1.7秒截断")
	var idle_age: float = view._idle_age
	view.seek_phase("Spit", 0.5, 0.5)
	_expect(view._ages.has("idle") and is_equal_approx(view._idle_age, idle_age + 0.5), "出兵期间待机粒子与骨骼基底时钟连续")
	view._apply_additive_spit(0.0)
	var skeleton: Skeleton3D = view._skeleton
	var a := skeleton.get_bone_global_pose(skeleton.find_bone("bone_voidgate_crystal1")).origin
	var b := skeleton.get_bone_global_pose(skeleton.find_bone("bone_voidgate_crystal2")).origin
	_expect(a.distance_to(b) > 0.5, "Spit零帧叠加保留晶体间距，禁止增量轨道作为绝对位置塌到原点")
	_expect(skeleton.get_bone_global_pose(skeleton.find_bone("Buffbone_Ground")).origin.y > 0.2, "Spit叠加保留门户球挂点高度")
	view._animation.play("Spit")
	view._animation.seek(0.90, true)
	skeleton.force_update_all_bone_transforms()
	_expect(skeleton.get_bone_global_pose(skeleton.find_bone("bone_voidgate_crystal1")).origin.distance_to(skeleton.get_bone_global_pose(skeleton.find_bone("bone_voidgate_crystal2")).origin) > 0.5, "播放器末帧混合源也保持绝对晶体姿态")
	view.seek_phase("Idle1", 0.0, 0.5)
	_expect(not view._ages.has("spit") and view._effects.idle.visible, "出兵退出停止发射，待机持续显示")
	view.seek_phase("Idle1", 0.0, 0.0)
	_expect(is_equal_approx(view._ages.idle, 1.0), "暂停零步进不推进门户粒子")
	view.seek_phase("Idle1", 0.0, 6.0)
	_expect(not view._effects.spawn.visible and not view._effects.has("spit") and view._effects.idle.visible, "瞬态粒子自然结束而待机继续")
	var death: Animation = view._animation.get_animation("Death")
	_expect(is_equal_approx(death.length, 2.2), "死亡末姿态持有到2.2秒，原1秒关键帧不拉伸")
	var last_key := 0.0
	for track in death.get_track_count():
		for key in death.track_get_key_count(track): last_key = maxf(last_key, death.track_get_key_time(track, key))
	_expect(last_key <= 1.001, "Death关键帧仍在原生1秒以内")
	view.begin_visual_death(2.2)
	_expect(not view._effects.idle.visible and view._effects.death.visible, "死亡关闭常驻门户并启动原版崩解")
	view.seek_phase("Death", 0.0, 0.13)
	_expect(is_zero_approx(view._ages.death), "死亡首帧骨骼尚未推进时，球体不能抢跑一整帧")
	view.seek_phase("Death", 0.14, 0.14)
	_expect(is_equal_approx(view._ages.death, 0.14), "死亡球拉伸与原动画共用年龄")
	view.reset_pool_visual()
	_expect(view._ages.is_empty() and not view._idle_started and not view._dying, "池复用不残留上次门户或死亡状态")
	view.seek_phase("Spawn", 0.2, 0.2)
	_expect(is_equal_approx(view._ages.spawn, 0.2), "晚到部署首帧不重复累计动画已包含的时间")
	view.seek_phase("Idle1", 0.0, 0.1)
	view.seek_phase("Spit", 0.19, 0.19)
	_expect(is_equal_approx(view._ages.spit, 0.19), "晚到出兵首帧仍显示膨胀峰值，不能跳到回缩阶段")
	view.seek_phase("Spit", 0.19, 0.0)
	_expect(is_equal_approx(view._ages.spit, 0.19), "冻结不推进出兵球体")
	view.seek_phase("Spit", 0.10, 0.0)
	_expect(is_equal_approx(view._ages.spit, 0.10), "动画校时回退时球体同步，而非继续累计错误时钟")
	view.reset_pool_visual()
	for cycle in 3:
		view.seek_phase("Idle1", 0.0, 0.0)
		view.seek_phase("Idle1", 5.0, 5.0)
		var old_idle: Node3D = view._effects.idle
		view.seek_phase("Spit", 0.192, 0.192)
		_expect(view._effects.idle == old_idle and not old_idle._stopped, "出兵%d保留同一个持续发射的待机事件" % cycle)
		_expect(view._tails.all(func(tail): return tail.kind != "idle"), "待机不转成退出残留")
		var age_during_spit: float = view._ages.idle
		view.seek_phase("Idle1", 0.0, 0.741)
		_expect(view._effects.idle == old_idle and is_equal_approx(view._ages.idle, age_during_spit + 0.741), "出兵%d结束不重建或重置待机" % cycle)
	view.free()


func _check_native_materials() -> void:
	var player = load("res://assets/effects/void_gate/player.gd")
	var count := 0
	var negative: Array[int] = []
	var positive: Array[int] = []
	var warp_priority := 0
	var sphere_priorities := {}
	for kind in ["spawn", "idle", "spit", "death"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(player.ROOT + kind + "/sampled.json"))
		for e in data.emitters:
			count += 1
			if kind in ["idle", "spit"] and e.name == "void1":
				sphere_priorities[kind] = player.native_render_priority(e)
			var material: ShaderMaterial = player._material(e)
			_expect(material.render_priority >= -128 and material.render_priority <= 127, "原版跨系统绘制优先级处于Godot合法范围")
			if e.distortion != null:
				warp_priority = material.render_priority
				_expect(material.shader.resource_path.ends_with("warp.gdshader") and is_equal_approx(material.get_shader_parameter("warp_strength"), 0.05) and material.get_shader_parameter("normal_texture") != null, "死亡Distort启用原版法线纹理和0.05屏幕扭曲")
			elif int(e.pass) < 0: negative.append(material.render_priority)
			else: positive.append(material.render_priority)
			if e.reflection != null:
				var rim: Vector4 = material.get_shader_parameter("fresnel")
				_expect(material.get_shader_parameter("has_fresnel") and is_equal_approx(rim.w, 0.15) and rim.z == 1.0, "原版球体Fresnel读取RGB和指数，不因源颜色alpha=0关闭")
				var arrays: Array = player._mesh(e.mesh_path).surface_get_arrays(0)
				_expect(arrays[Mesh.ARRAY_NORMAL].size() == arrays[Mesh.ARRAY_VERTEX].size(), "球体源索引拓扑生成逐角法线，供原版视角边缘色使用")
	_expect(sphere_priorities.size() == 2 and sphere_priorities.idle == sphere_priorities.spit, "原始排序键相同的待机球与出兵球同优先级，不以各自文件编号强压覆盖")
	_expect(count == 25 and not negative.is_empty() and not positive.is_empty(), "四套原版特效全部25个发射器进入材质核验")
	_expect(negative.all(func(p): return p < warp_priority) and positive.all(func(p): return p > warp_priority), "负pass颜色先绘制，随后mode1扭曲，最后非负pass颜色")
	var idle_fx = player.new()
	var spit_fx = player.new()
	idle_fx.load_kind("idle")
	spit_fx.load_kind("spit")
	var highest_idle := -128
	for material in idle_fx._materials: highest_idle = maxi(highest_idle, material.render_priority)
	for material in spit_fx._materials:
		_expect(material.render_priority > highest_idle, "吐兽两层均覆盖在整套待机球和光晕之后")
	idle_fx.free()
	spit_fx.free()
	var paths: Array[String] = preload("res://scripts/presentation/spell_effect_warmup.gd").dependency_paths({"void_gate": true})
	_expect("res://assets/effects/void_gate/warp.gdshader" in paths, "卡牌资源闭包包含死亡扭曲shader")

func _check_birth_alignment() -> void:
	var view = load("res://assets/units/void_spawn/void_spawn_view.tscn").instantiate()
	_main.add_child(view)
	view.set_process(false)
	var unit := Unit.new()
	unit.summon_visual_origin = Vector2(240, 900)
	view.configure_unit_visual(unit)
	for side in [-1.0, 1.0]:
		var origin := Vector3(side * 1.1, 0.0, 0.0)
		var start: Vector3 = view.summon_birth_offset(origin, 0.0, 1.0) + view._birth_start
		_expect(Vector2(start.x, start.z).distance_to(Vector2(origin.x, origin.z)) < 0.001, "出生身体平面起点对齐门心，左右出口一致")
		_expect(view.summon_birth_offset(origin, 1.0, 1.0).is_zero_approx(), "出生结束回归合法单位位置，无残余表现偏移")
	unit.free()
	view.free()
