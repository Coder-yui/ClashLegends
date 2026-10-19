extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	await _check_regeneration_warmup()
	_check_regeneration_visual()
	_check_visual_snapshot()
	_check_birth_lifecycle()
	_check_birth_coordinates_and_clock()
	_check_splash_randomization()
	_check_army()
	_check_projectile_origin_and_timing()
	var skill: Dictionary = CardDB.active_skills_for("voidfish_ranged")[0]
	for team in [0, 1]:
		_clean()
		var members: Array = _main.runtime._spawn_card_units(team, "voidfish_ranged", Vector2(350, 950), 0.0, 0)
		_expect(members.size() == 3, "双方正式卡各生成三只")
		_expect(absf((members[1].position - members[0].position).cross(members[2].position - members[0].position)) > 1.0, "三角阵型不退化为直线")
		var other: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, "voidfish_ranged", Vector2(150, 950), {"deploy_time_override": 0.0}))
		members[2].take_damage(9999.0)
		_main._active_skill_effect_system.apply(members[0], skill)
		_expect(members[0].buffs.remaining(&"death_spawn") == 3.0 and members[1].buffs.remaining(&"death_spawn") == 3.0, "技能覆盖本批存活成员")
		_expect(other.buffs.remaining(&"death_spawn") == 0.0 and _children(team).is_empty(), "不影响别批、不复活技能前死亡成员")
		var origin: Vector2 = members[0].global_position
		for tick in 59: members[0].buffs.advance(0.05)
		members[0].take_damage(9999.0)
		_expect(not members[0]._death_visual_emitted, "再生死亡不发出死亡动画信号")
		var children := _children(team)
		_expect(children.size() == 1, "第59Tick死亡生成且只生成一只")
		if children.size() == 1:
			_expect(children[0].global_position.distance_to(origin) < 0.01, "新鱼生成于死亡位置")
			_expect(children[0].hp == 80.0 and children[0].active_ability_id == -1 and children[0].buffs.remaining(&"death_spawn") == 0.0, "新鱼满血且不继承技能资格或再生")
			children[0].take_damage(9999.0)
			_expect(children[0]._death_visual_emitted, "新鱼无再生窗口，正常播放死亡动画")
			_expect(_children(team).is_empty(), "新鱼再次死亡不连锁再生")
		for tick in 60: members[1].buffs.advance(0.05)
		members[1].take_damage(9999.0)
		_expect(members[1]._death_visual_emitted, "三秒到期死亡正常播放死亡动画")
		_expect(_children(team).is_empty(), "第60Tick满三秒后死亡不再生")
		other.take_damage(9999.0)
		_expect(_children(team).is_empty(), "未加状态成员死亡不再生")
	_clean()
	var plan = load("res://scripts/presentation/match_resource_plan.gd").for_match([["voidfish_ranged"], []], [{}, {}])
	_expect(plan.cards.has("voidfish_ranged_single"), "主动技能资源计划递归包含复生单只")

func _children(team: int) -> Array:
	return _main.get_tree().get_nodes_in_group("combatants").filter(func(node): return node is Unit and node.card_id == "voidfish_ranged_single" and node.team == team)

func _clean() -> void:
	for node in _main.get_tree().get_nodes_in_group("combatants"):
		if node is Unit: node.free()

func _check_visual_snapshot() -> void:
	var system := NetworkSnapshotSystem.new(_main, _main._projectile_system)
	var payload := system._projectile_snapshot_payload(991, {"pos": Vector2(120, 340), "color": Color.PURPLE, "radius": 4.0, "visual": &"voidfish_missile", "direction": Vector2.UP, "speed": 320.0})
	var old_mode: String = _main.runtime.mode
	var old_team: int = _main.runtime.local_team
	_main.runtime.mode = "client"
	_main.runtime.local_team = 1
	system._apply_projectiles([payload])
	var projectile: Dictionary = _main._projectile_system.client_snapshot().get(991, {})
	_expect(String(projectile.get("visual", "")) == "voidfish_missile", "远程虚空鱼原版弹体标识通过客户端快照往返")
	_main._projectile_system.clear_client()
	_main.runtime.mode = old_mode
	_main.runtime.local_team = old_team
	var view = load("res://assets/units/voidfish_ranged/voidfish_ranged_view.tscn").instantiate()
	_main.add_child(view)
	view.prepare_visual_animations()
	var surfaces := 0
	for instance in view.find_children("*", "MeshInstance3D", true, false):
		for index in instance.mesh.get_surface_count():
			surfaces += 1
			_expect(instance.mesh.surface_get_material(index).resource_name == "Ranged", "远程包装只显示原版Ranged表面")
	_expect(surfaces > 0, "远程网格真实存在，不能仅保留动画而成为空模型")
	view.free()

func _check_birth_lifecycle() -> void:
	var source: Unit = _main._spawn_unit(UnitSpawnRequest.new(0, "voidfish_ranged_single", Vector2(350, 950), {"deploy_time_override": 1.0}))
	var view = load("res://assets/units/voidfish_ranged/voidfish_ranged_view.tscn").instantiate()
	_main.add_child(view)
	view.configure_unit_visual(source)
	view.advance_deployment_visual(0.0, 1.0, true)
	_expect(is_instance_valid(view._spawn) and not view.get_node("Model").visible, "出生原版剪影阶段隐藏正式模型，避免两只鱼叠加")
	var spawn = view._spawn
	view.advance_deployment_visual(0.2, 1.0, true)
	_expect(view._spawn == spawn, "连续部署状态不重新创建出生发射器")
	view.advance_deployment_visual(0.72, 1.0, true)
	_expect(view.get_node("Model").visible, "原版剪影结束后显示正式模型")
	view.begin_visual_death(0.6)
	view._process(0.1)
	_expect(view._spawn == null, "死亡停止出生，后续帧不重新亮起")
	view.configure_unit_visual(source)
	view.advance_deployment_visual(0.0, 1.0, true)
	_expect(is_instance_valid(view._spawn), "模型复用后新部署能正常播放出生")
	source.cancelled_deployment = true
	view._process(0.01)
	_expect(view._spawn == null and view.get_node("Model").visible, "取消部署清除出生网格并恢复模型可见状态")
	view.advance_deployment_visual(0.2, 1.0, true)
	_expect(view._spawn == null, "取消后的残留部署通知不重播出生")
	view.configure_unit_visual(source)
	view.advance_deployment_visual(1.0, 1.0, false)
	_expect(view._spawn == null and view.get_node("Model").visible, "已部署对象重连不补播出生")
	view.configure_unit_visual(source)
	view.advance_deployment_visual(0.0, 0.5, true)
	view.advance_deployment_visual(0.5, 0.5, true)
	_expect(view._spawn == null and view.get_node("Model").visible, "短部署结束也不能让模型留在隐藏状态")
	view.free()
	source.free()

func _check_birth_coordinates_and_clock() -> void:
	for team in [0, 1]:
		for card in ["voidfish", "voidfish_ranged_single"]:
			var source: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, card, Vector2(200, 900), {"deploy_time_override": 1.0}))
			var view = load(CardDB.get_unit_stats(card).visual_scene_path).instantiate()
			_main.add_child(view)
			view.position = Vector3(4, 2, 3)
			view.rotation.y = 0.0 if team == 0 else PI
			view.scale = Vector3.ONE * 1.4
			view.configure_unit_visual(source)
			view.advance_deployment_visual(0.3, 1.0, true)
			var spawn = view._spawn
			_expect(is_instance_valid(spawn), "近远程两队普通部署均有原版出生")
			var native_center := Vector3(0, 50, 0)
			_expect(spawn.to_global(native_center).distance_to(view.get_node("Model").to_global(native_center)) < 0.00001, "发射中心等于模型根局部50，不额外偏移胸骨且随缩放")
			var camera := Camera3D.new()
			_main.add_child(camera)
			camera.position = Vector3(5, 8, 12)
			camera.look_at(view.position)
			var face: Basis = spawn._camera_mesh_basis(spawn._data.emitters[0], [0, 0, 50, 0], camera)
			var back: Vector3 = (spawn.global_basis * face.z).normalized()
			var eye: Vector3 = spawn.to_global(native_center).direction_to(camera.global_position)
			_expect(back.dot(eye) < -0.999, "蓝红及缩放下SCB朝镜头方向保留原版背面向镜头规则")
			camera.free()
			var before: float = spawn._age
			view._process(0.6)
			view.advance_deployment_visual(0.3, 1.0, true)
			_expect(is_equal_approx(spawn._age, before) and not view.get_node("Model").visible, "部署时钟暂停时特效不自行推进或提前显现")
			view.position += Vector3(3, 0, 2)
			view.rotation.y += PI / 2.0
			_expect(spawn.to_global(native_center).distance_to(view.get_node("Model").to_global(native_center)) < 0.00001, "位置和方向改变时出生保持对象局部坐标")
			view.advance_deployment_visual(0.78, 1.0, true)
			_expect(view._spawn == null and view.get_node("Model").visible, "原版最后溶解层结束后清理，正式模型显现")
			view.free()
			source.free()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/voidfish_ranged/spawn/sampled.json"))
	var provider = load("res://assets/effects/voidfish_ranged/player.gd")
	var ground: Array = data.emitters.filter(func(e): return e.groundLayer)
	var body: Array = data.emitters.filter(func(e): return not e.groundLayer)
	_expect(ground.size() == 3 and body.size() == 11, "原版14层分为3个背景层与11个主体层")
	for under in ground:
		for over in body:
			_expect(provider.native_render_priority(under) < provider.native_render_priority(over), "原版groundLayer始终先于鱼剪影和蛋壳")
	for e in body:
		if e.name == "Egg_Voidling":
			_expect(provider.resource_shader_path(e).ends_with("opaque.gdshader"), "原版鱼剪影禁用透明混合且写深度")

func _check_projectile_origin_and_timing() -> void:
	for team in [0, 1]:
		for flip in [false, true]:
			_clean()
			_main._projectile_system.clear_all()
			var camera := Camera3D.new()
			_main.add_child(camera)
			camera.position = Vector3(0, 16, -20 if flip else 20)
			camera.look_at(Vector3.ZERO)
			var other: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, "voidfish_ranged_single", Vector2(600, 1000), {"deploy_time_override": 0.0}))
			other.net_id = 100
			var fish: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, "voidfish_ranged_single", Vector2(300, 800), {"deploy_time_override": 0.0}))
			var target: Unit = _main._spawn_unit(UnitSpawnRequest.new(1-team, "garen", fish.position + Vector2(0, -130 if team == 0 else 130), {"deploy_time_override": 0.0}))
			var view := UnitModel3D.new()
			_main.add_child(view)
			var stats := CardDB.get_card("voidfish_ranged_single")
			view.setup(fish, load(stats.visual_scene_path), camera, stats.visual_animations, 0.0)
			view.set_process(false)
			view._animation_player.play("ranged_attack")
			view._animation_player.seek(14.1 / 30.0, true)
			view._animation_player.advance(0.0)
			view._model_root._skeleton.force_update_all_bone_transforms()
			view._update_health_bar_anchor()
			_expect(view._projectile_anchor is BoneAttachment3D and view._projectile_anchor.bone_name == "BackSpine_end", "远程鱼弹体挂原版尾端骨骼而非模型中心")
			var clip := view._animation_player.get_animation("ranged_attack")
			_expect(absf(14.1 / 30.0 / clip.length * fish.attack_interval - fish.first_hit_time) < 0.005, "原版14.1帧按片长映射到0.46秒发射，误差小于5毫秒")
			var fx = load("res://scripts/presentation/voidfish_effect_3d.gd").new()
			_main.add_child(fx)
			fish._target = target
			fish.attack_timeline.begin_windup(fish.first_hit_time, 1.0)
			var hp := target.hp
			for tick in 9: fish._attack(0.05)
			fx.sync_effects(null, _main._projectile_system, camera)
			_expect(_main._projectile_system.projectiles.is_empty() and fx._missiles.is_empty(), "0.45秒尚未发射，不提前创建弹体或特效")
			fish._attack(0.05)
			_expect(_main._projectile_system.projectiles.size() == 1 and target.hp == hp, "0.50秒权威Tick创建一枚弹体，创建不直接扣血")
			var projectile: Dictionary = _main._projectile_system.projectiles.values()[0]
			var anchor := view._projectile_anchor.global_position
			fish.net_id = 201
			var remote_source: Dictionary = projectile.visual_path.source.duplicate()
			remote_source.id = 201
			remote_source.erase("local_id")
			_expect(_main._projectile_system.visual_model_anchor_position(remote_source).distance_to(anchor) < 0.0001, "客户端按网络ID继续查找后续同队单位，不能在第一只不匹配单位处退出")
			fx.sync_effects(null, _main._projectile_system, camera)
			var visual: Dictionary = fx._missiles.values()[0]
			_expect(visual.player.global_position.distance_to(anchor) < 0.0001, "蓝红/翻转视角首帧真实3D位置贴合尾端挂点")
			_expect(visual.age == 0.0 and is_equal_approx(visual.player._age, 1.0 / 120.0), "首帧只取最早原版采样，不预跳到0.1秒")
			_expect(projectile.pos.is_equal_approx(fish.global_position), "尾端挂点不改变权威弹体中心出生点")
			_main._projectile_system.tick(0.05)
			fx.sync_effects(null, _main._projectile_system, camera)
			_expect(is_equal_approx(visual.age, 0.05), "弹体特效时间随真实飞行距离推进")
			var frozen_age: float = visual.player._age
			fx.sync_effects(null, _main._projectile_system, camera)
			_expect(is_equal_approx(visual.player._age, frozen_age), "重复同一快照不额外推进弹体时钟")
			for tick in 20: _main._projectile_system.tick(0.05)
			fx.sync_effects(null, _main._projectile_system, camera)
			_expect(target.hp == hp - fish.damage and fx._missiles.is_empty(), "真实碰撞后扣一次伤害并清理弹体特效")
			view.free()
			fx.free()
			camera.free()
	_clean()

func _check_regeneration_visual() -> void:
	for team in [0, 1]:
		var source: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, "voidfish_ranged", Vector2(220, 900), {"deploy_time_override": 0.0}))
		var view := _view_for(source)
		var effect = view._active_buff_visual
		view._update_active_buff_visual(0.0)
		_expect(effect != null and not effect.visible and not view._last_buff_visible, "未开启技能无紫色模型覆层或上升光流")
		_main._active_skill_effect_system.apply(source, CardDB.active_skills_for("voidfish_ranged")[0])
		source.buffs.advance(0.15)
		view._update_active_buff_visual(0.0)
		_expect(effect.visible and effect._wisps.any(func(w): return w.visible) and view._last_buff_visible, "开启时上升光流与模型覆层同时显示")
		_expect(not effect.overlay_instances.is_empty() and effect.overlay_instances.all(func(m): return float(m.get_shader_parameter("strength")) == 1.0), "覆层绑定真实蒙皮模型，强度启用")
		var height: float = effect._wisps[0].position.y
		var age: float = effect._age
		view._update_active_buff_visual(0.5)
		_expect(is_equal_approx(effect._age, age), "暂停和重复表现帧不推进技能特效")
		source.buffs.advance(0.2)
		view._update_active_buff_visual(0.0)
		_expect(effect._wisps[0].position.y > height, "开启光流沿竖直方向上升")
		source.buffs.advance(0.65)
		view._update_active_buff_visual(0.0)
		_expect(effect.visible and not effect._wisps.any(func(w): return w.visible) and view._last_buff_visible, "持续阶段只保留模型紫色覆层，上升光流不循环")
		var payload := preload("res://tests/fixtures/network_fixture.gd").snapshot_payload(NetworkSnapshotSystem.new(_main, _main._projectile_system), 981, source)
		_expect(payload[NetworkSnapshotSystem.U_DEATH_SPAWN_STATE].is_equal_approx(Vector2(2.0, 3.0)), "权威快照保留剩余和总时长")
		var mode: String = _main.runtime.mode
		_main.runtime.mode = "client"
		source.net_death_spawn_state = payload[NetworkSnapshotSystem.U_DEATH_SPAWN_STATE]
		source.buffs.clear_family(&"death_spawn")
		view._update_active_buff_visual(0.0)
		_expect(effect.visible and effect._age >= 1.0 and not effect._wisps.any(func(w): return w.visible), "客户端中途恢复只显示覆层，不重播开启")
		source.net_death_spawn_state = Vector2.ZERO
		view._update_active_buff_visual(0.0)
		_expect(not effect.visible and not view._last_buff_visible and effect.overlay_instances.all(func(m): return float(m.get_shader_parameter("strength")) == 0.0), "窗口清零恢复原模型材质")
		_main.runtime.mode = mode
		source.free()

func _check_regeneration_warmup() -> void:
	var plan = load("res://scripts/presentation/match_resource_plan.gd").for_match([["voidfish_ranged"], []], [{}, {}])
	var warm = load("res://scripts/presentation/spell_effect_warmup.gd").new()
	var presentation: BattlePresentation3D = _main._battle_presentation
	var before := presentation._world_root.get_child_count()
	await warm.prepare(plan.cards, presentation._world_root, presentation._camera, Callable(), plan)
	_expect(warm.errors.is_empty() and warm.sampled_layers.get("voidfish_ranged/regeneration", 0) == 2, "上升光流与紫色覆层实际预热")
	_expect(presentation._world_root.get_child_count() == before, "再生预热不遗留节点")
	var inactive = load("res://scripts/presentation/match_resource_plan.gd").for_match([["garen", "garen", "voidfish_ranged"], []], [{}, {}])
	_expect(not warm.dependency_paths(inactive.cards, inactive).has("res://assets/effects/voidfish_regeneration/rise.gdshader"), "非主动槽不预热再生专属效果")


func _check_splash_randomization() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/voidfish_ranged/spawn/sampled.json"))
	var emitter: Dictionary = data.emitters.filter(func(e): return e.name == "vecalign")[0]
	var script = load("res://assets/effects/voidfish_ranged/spawn_splash.gd")
	var first = script.new()
	seed(12345)
	var expected_global := randi()
	seed(12345)
	first.setup(emitter, data.fps)
	_expect(randi() == expected_global, "出生随机只用私有RNG，不消耗权威随机流")
	var birth: Array = first.sample(20)
	first.sample(32)
	_expect(first.sample(20) == birth, "溅射暂停、重读与向后seek不重抽随机数")
	var second = script.new()
	second.setup(emitter, data.fps)
	_expect(second._particles != first._particles, "不同出生实例不再共享固定seed样本")
	var counts := {}
	var left := false
	var right := false
	var valid := true
	for visual_seed in 128:
		second.setup(emitter, data.fps, visual_seed)
		counts[second._particles.size()] = true
		valid = valid and second._particles.size() >= 3 and second._particles.size() <= 7
		for particle in second._particles:
			var v: Vector3 = particle.velocity
			left = left or v.x < 0.0
			right = right or v.x > 0.0
			valid = valid and absf(v.x) <= 700.001 and absf(v.y) <= 400.001 and v.z >= -650.001 and v.z <= 0.001
			valid = valid and particle.life >= 0.102 - 0.00001 and particle.life <= 0.34 + 0.00001
		_expect(second.sample(12).is_empty() and second.sample(60).is_empty(), "原始延迟之前及最长寿命后无溅射")
	_expect(valid and left and right and counts.size() > 1, "原始概率表保留随机数量、左右速度、负Z与寿命范围")
	first.setup(emitter, data.fps, 79)
	second.setup(emitter, data.fps, 79)
	_expect(first.sample(20) == second.sample(20), "指定视觉seed可复现源参数以便校验")

func _check_army() -> void:
	var old_deck: Array = _main.runtime._deck.duplicate()
	var old_team: int = _main.runtime.local_team
	_main.runtime._deck[0] = "voidfish_ranged_army"
	for team in [0, 1]:
		_clean()
		_main.runtime.local_team = team
		var center := Vector2(360, 940 if team == 0 else 340)
		var wallet = _main.runtime.account(team)
		wallet.elixir = 10.0
		_expect(_main.play_card(team, "voidfish_ranged_army", center, {"immediate": true, "elixir": wallet, "active_slot": 0}), "大军通过正式放牌入口部署")
		var members: Array = _main.get_tree().get_nodes_in_group("combatants").filter(func(n): return n is Unit and n.card_id == "voidfish_ranged_army" and n.team == team)
		_expect(members.size() == 6 and wallet.elixir == 5.0, "双方大军均5费六只")
		if members.size() != 6: continue
		var centroid := Vector2.ZERO
		for member in members: centroid += member.position / 6.0
		for i in 6:
			_expect(absf(members[i].position.distance_to(centroid) - 36.0) < 0.01 and absf(members[i].position.distance_to(members[(i + 1) % 6].position) - 36.0) < 0.01, "六成员均在正六边形顶点，中心留空")
			members[i]._deploy_timer = 0.0
		var other: Array = _main.runtime._spawn_card_units(team, "voidfish_ranged", Vector2(150, center.y), 0.0)
		var skill: Dictionary = CardDB.active_skills_for("voidfish_ranged_army")[0]
		_main._active_skill_effect_system.apply(members[0], skill)
		for member in members:
			_expect(member.buffs.remaining(&"death_spawn") == 3.0, "六只均进入再生窗口")
		for member in other:
			_expect(member.buffs.remaining(&"death_spawn") == 0.0, "三只原卡与六只大军不串批")
		for member in members: member.take_damage(9999.0)
		var children := _children(team)
		_expect(children.size() == 6, "六原成员同批死亡仅生成六只")
		for child in children:
			_expect(child.hp == 80 and child.active_ability_id == -1 and child.buffs.remaining(&"death_spawn") == 0.0, "六再生鱼均不继承技能资格")
			child.take_damage(9999.0)
		_expect(_children(team).is_empty(), "六只新鱼再次死亡无递归再生")
		_clean()
		# 正式技能付款，待执行时原持有者死亡，剩余五只继承整批资格。
		var paid: Array = _main.runtime._spawn_card_units(team, "voidfish_ranged_army", center, 0.0, 0)
		var ability: int = paid[0].active_ability_id
		wallet.elixir = 10.0
		_expect(_main.use_active_skill(ability, team) and wallet.elixir == 8.0, "大军主动按原技能只收2费")
		paid[0].take_damage(9999.0)
		_main.runtime._sim_tick_id += 10
		_main.runtime._tick_pending_active_skills(0.05)
		for i in range(1, 6):
			_expect(paid[i].buffs.remaining(&"death_spawn") == 3.0, "队长死亡后五个存活成员执行再生")
		_expect(wallet.elixir == 8.0 and not _main.use_active_skill(ability, team), "资格转交不重复收费且技能仍限一次")
	_clean()
	_main.runtime._deck = old_deck
	_main.runtime.local_team = old_team
	var plan = load("res://scripts/presentation/match_resource_plan.gd").for_match([["voidfish_ranged_army"], []], [{}, {}])
	_expect(plan.cards.has("voidfish_ranged_single"), "大军预热递归包含再生单只")
