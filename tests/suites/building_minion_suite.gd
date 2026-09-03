class_name BuildingMinionSuite
extends RefCounted
## 建筑卡与兵线领域：墓碑占地/生成周期、小鬼与四类兵线单位机制。

var _harness: Object
var _main: Node2D

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_tombstone_art_integration()
	_check_minion_line_mechanism()
	_check_death_animation_durations()
	_check_tombstone_footprint()
	_check_tombstone_does_not_push_air_units()
	_check_tombstone_spawn_cycle()
	_check_generic_periodic_summon()

func _check_tombstone_art_integration() -> void:
	var cards := CardDB.all()
	var tombstone_stats: Dictionary = cards["tombstone"]
	var imp_stats: Dictionary = CardDB.get_unit_stats("imp")
	var tombstone_packed := load(tombstone_stats.visual_scene_path) as PackedScene
	var imp_packed := load(imp_stats.visual_scene_path) as PackedScene
	var tombstone_sample := tombstone_packed.instantiate() as Node3D if tombstone_packed != null else null
	var imp_sample := imp_packed.instantiate() as Node3D if imp_packed != null else null
	if tombstone_sample != null:
		_main.add_child(tombstone_sample)
	if imp_sample != null:
		_main.add_child(imp_sample)
	var tombstone_player := SuiteUtils.find_anim_player(tombstone_sample) if tombstone_sample != null else null
	var imp_player := SuiteUtils.find_anim_player(imp_sample) if imp_sample != null else null
	var fog_layers: Array[Node] = tombstone_sample.find_children("BlackFog*", "MeshInstance3D", true, false) if tombstone_sample != null else []
	var fog_ok := fog_layers.size() >= 5
	var fog_material_ids := {}
	for fog_node in fog_layers:
		var fog := fog_node as MeshInstance3D
		var fog_material := fog.material_override as ShaderMaterial
		fog_ok = fog_ok and fog.mesh is QuadMesh and fog_material != null
		fog_ok = fog_ok and fog.is_in_group("tombstone_fog") and fog.is_in_group("presentation_fx")
		if fog_material != null:
			fog_material_ids[fog_material.get_instance_id()] = true
	fog_ok = fog_ok and fog_material_ids.size() == fog_layers.size()
	var fog_death_ok := tombstone_sample != null and tombstone_sample.has_method("begin_visual_death")
	var health_anchor_ok := tombstone_sample != null and tombstone_sample.has_method("get_health_bar_anchor_local")
	if fog_death_ok:
		tombstone_sample.call("begin_visual_death", 0.8)
		tombstone_sample.call("_process", 0.4)
		for fog_node in fog_layers:
			var fog_material := (fog_node as MeshInstance3D).material_override as ShaderMaterial
			var visibility := float(fog_material.get_shader_parameter("fog_visibility")) if fog_material != null else 1.0
			fog_death_ok = fog_death_ok and visibility > 0.0 and visibility < 1.0
	if health_anchor_ok:
		var anchor = tombstone_sample.call("get_health_bar_anchor_local")
		health_anchor_ok = anchor is Vector3 and (anchor as Vector3).y > 1.0
	var imp_animation_mapping_ok: bool = String(imp_stats.visual_animations.move) == "Run1" and imp_stats.visual_animations.attack == ["Yorick_ghoul_leapWindup_anm"]
	_expect(tombstone_packed != null and tombstone_player != null and fog_ok, "墓碑包装场景使用五层独立流动黑雾覆盖地面与模型内部")
	_expect(fog_death_ok, "墓碑死亡时每座墓碑的黑雾独立随 Death 动画扩散并淡出")
	_expect(health_anchor_ok, "墓碑使用稳定的模型顶部锚点定位血条")
	_expect(imp_packed != null and imp_player != null and imp_animation_mapping_ok, "小鬼移动循环 Run1，攻击使用 leapWindup")
	if tombstone_sample != null:
		tombstone_sample.free()
	if imp_sample != null:
		imp_sample.free()

func _check_minion_line_mechanism() -> void:
	var cards := CardDB.all()
	var minion_ids := ["melee_minion", "ranged_minion", "siege_minion", "super_minion"]
	var data_ok := true
	var expected_costs := {"melee_minion": 1, "ranged_minion": 1, "siege_minion": 3, "super_minion": 4}
	for card_id in minion_ids:
		data_ok = data_ok and cards.has(card_id) and bool(cards[card_id].get("selectable", true))
		data_ok = data_ok and CardDB.selectable_ids().has(card_id)
		data_ok = data_ok and int(cards[card_id].cost) == int(expected_costs[card_id])
	_expect(data_ok, "四类兵线单位进入玩家/AI 卡池，费用为近战1、远程1、炮车3、超级兵4")
	_expect(
		cards.melee_minion.size_tier == CardDB.SIZE_SMALL
		and cards.ranged_minion.size_tier == CardDB.SIZE_SMALL
		and cards.siege_minion.size_tier == CardDB.SIZE_SLIGHTLY_SMALL
		and cards.super_minion.size_tier == CardDB.SIZE_MEDIUM
		and is_equal_approx(cards.melee_minion.speed, CardDB.SPEED_MEDIUM)
		and is_equal_approx(cards.ranged_minion.speed, CardDB.SPEED_MEDIUM)
		and is_equal_approx(cards.siege_minion.speed, CardDB.SPEED_MEDIUM)
		and is_equal_approx(cards.super_minion.speed, CardDB.SPEED_MEDIUM)
		and cards.ranged_minion.can_attack_air
		and cards.siege_minion.can_attack_air,
		"四类小兵的权威体型统一下调一档，速度与对空能力保持原定义"
	)

	var ranged_blue := Unit.new()
	var ranged_red := Unit.new()
	var siege_blue := Unit.new()
	ranged_blue.setup(0, cards.ranged_minion, cards.ranged_minion.name)
	ranged_red.setup(1, cards.ranged_minion, cards.ranged_minion.name)
	siege_blue.setup(0, cards.siege_minion, cards.siege_minion.name)
	_expect(
		ranged_blue.projectile_visual == &"orb"
		and ranged_blue.projectile_color.b > ranged_blue.projectile_color.r
		and ranged_red.projectile_color.r > ranged_red.projectile_color.b
		and siege_blue.projectile_color.r < 0.1
		and ranged_blue.projectile_visual_forward_offset > 0.0
		and siege_blue.projectile_visual_forward_offset > ranged_blue.projectile_visual_forward_offset,
		"远程兵按阵营发射蓝/红小光球，炮车发射黑球，权杖与炮口均配置纯表现起点"
	)
	ranged_blue.free()
	ranged_red.free()
	siege_blue.free()

	var old_waves_enabled: bool = _main._minion_waves_enabled
	_main._minion_waves_enabled = true
	_expect(
		is_equal_approx(_main.MATCH_TIME, 185.0)
		and is_equal_approx(_main.OVERTIME_TIME, 120.0)
		and is_equal_approx(_main.NORMAL_MINION_WAVE_INTERVAL, 45.0)
		and is_equal_approx(_main.DOUBLE_MINION_WAVE_INTERVAL, 30.0),
		"正赛 185 秒、加时 120 秒，普通兵线 45 秒、炮车兵线 30 秒"
	)
	var first_wave_ok := _run_scheduled_wave(4.95, 5.0, _main.MINION_WAVE_NORMAL)
	var first_interval_ok := is_equal_approx(_main._next_minion_wave_time, 50.0)
	_expect(first_wave_ok, "0:05 首波双方两路生成近战兵，0.5 秒后补远程兵")
	var second_wave_ok := _run_scheduled_wave(49.95, 50.0, _main.MINION_WAVE_NORMAL)
	var second_interval_ok := is_equal_approx(_main._next_minion_wave_time, 95.0)
	var third_wave_ok := _run_scheduled_wave(94.95, 95.0, _main.MINION_WAVE_NORMAL)
	var third_interval_ok := is_equal_approx(_main._next_minion_wave_time, 140.0)
	_expect(second_wave_ok and third_wave_ok and first_interval_ok and second_interval_ok and third_interval_ok, "普通阶段兵线时间为 0:05、0:50、1:35，间隔保持 45 秒")

	_clear_minion_test_units()
	_main._pending_lane_minions.clear()
	_main._battle_elapsed = 124.95
	_main._next_minion_wave_time = 140.0
	_main._match_timer = _main.MATCH_TIME
	_main._overtime = false
	_main._tick_minion_waves(0.05)
	var double_start_front := _minion_test_units()
	var double_start_front_ok := double_start_front.size() == 4
	for minion in double_start_front:
		double_start_front_ok = double_start_front_ok and minion.card_id == "melee_minion"
	_expect(double_start_front_ok and is_equal_approx(_main._next_minion_wave_time, 155.0), "2:05 立即生成炮车线，并取消普通阶段原定的 2:20 兵线")
	_main._tick_minion_waves(0.5)
	_expect(_wave_cards_ok("melee_minion", "siege_minion"), "2:05 炮车线的后排为炮车兵")
	var next_double_wave_ok := _run_scheduled_wave(154.95, 155.0, _main.MINION_WAVE_SIEGE)
	_expect(next_double_wave_ok, "双倍金币阶段从 2:05 起按 30 秒间隔继续生成炮车线")

	_main._battle_elapsed = 0.0
	_main._match_timer = _main.MATCH_TIME
	_main._overtime = false
	_main._update_elixir_rate()
	var one_x_at_start := is_equal_approx(_main._elixir.regen_multiplier, 1.0)
	_main._battle_elapsed = 124.95
	_main._match_timer = _main.DOUBLE_ELIXIR_TIME + 0.05
	_main._update_elixir_rate()
	var one_x_before_double := is_equal_approx(_main._elixir.regen_multiplier, 1.0)
	_main._battle_elapsed = 125.0
	_main._match_timer = _main.DOUBLE_ELIXIR_TIME
	_main._update_elixir_rate()
	var two_x_at_double_start := is_equal_approx(_main._elixir.regen_multiplier, 2.0)
	_main._battle_elapsed = 130.0
	_main._match_timer = 55.0
	_main._update_elixir_rate()
	var two_x_after_double_start := is_equal_approx(_main._elixir.regen_multiplier, 2.0)
	_main._overtime = true
	_main._match_timer = _main.OVERTIME_TIME
	_main._update_elixir_rate()
	var two_x_in_overtime: bool = is_equal_approx(_main._elixir.regen_multiplier, 2.0)
	_main._match_timer = _main.OVERTIME_TRIPLE_ELIXIR_TIME
	_main._update_elixir_rate()
	var three_x_at_overtime_last_minute: bool = is_equal_approx(_main._elixir.regen_multiplier, 3.0)
	_expect(one_x_at_start and one_x_before_double, "正赛 0:00~2:05 金币倍率为 1x")
	_expect(two_x_at_double_start and two_x_after_double_start and two_x_in_overtime, "2:05 后及加时前一分钟金币倍率为 2x")
	_expect(three_x_at_overtime_last_minute, "加时最后一分钟金币倍率为 3x")

	var tower_hps: Array[float] = []
	for tower in _main._towers:
		tower_hps.append(tower.hp)
	_main._overtime = false
	_main._match_timer = 0.0
	_main._battle_elapsed = 185.0
	_main._next_minion_wave_time = 185.0
	_main._towers[0].hp = 0.0
	_main.game_over = false
	_main._sim_acc = 0.0
	_clear_minion_test_units()
	_main._pending_lane_minions.clear()
	_main._process(0.0)
	_expect(_main.game_over and not _main._overtime and _minion_test_units().is_empty(), "3:05 若正赛已分出胜负则直接结束，不生成 3:05 兵线")
	for index in _main._towers.size():
		_main._towers[index].hp = tower_hps[index]

	_main._overtime = false
	_main._match_timer = 0.0
	_main._battle_elapsed = 185.0
	_main._next_minion_wave_time = 185.0
	_main.game_over = false
	_main._sim_acc = 0.0
	_main._process(0.0)
	var overtime_front_ok: bool = _main._overtime and not _main.game_over and _minion_test_units().size() == 4
	for minion in _minion_test_units():
		overtime_front_ok = overtime_front_ok and minion.card_id == "melee_minion"
	_main._tick_minion_waves(0.5)
	var overtime_wave_ok: bool = overtime_front_ok and _wave_cards_ok("melee_minion", "siege_minion")
	_expect(overtime_wave_ok, "3:05 只有实际进入加时才立即生成炮车线")
	_clear_minion_test_units()
	_main._pending_lane_minions.clear()
	var overtime_215_ok := _run_scheduled_wave(214.95, 215.0, _main.MINION_WAVE_SIEGE, true)
	var overtime_245_ok := _run_scheduled_wave(244.95, 245.0, _main.MINION_WAVE_SIEGE, true)
	var overtime_275_ok := _run_scheduled_wave(274.95, 275.0, _main.MINION_WAVE_SIEGE, true)
	_expect(overtime_215_ok and overtime_245_ok and overtime_275_ok, "加时继续在 3:35、4:05、4:35 生成炮车线，间隔为 30 秒")

	_clear_minion_test_units()
	_main._pending_lane_minions.clear()
	_main._overtime = true
	_main._match_timer = 0.0
	_main._battle_elapsed = 305.0
	_main._next_minion_wave_time = 305.0
	_main.game_over = false
	_main._sim_acc = 0.0
	_main._process(0.0)
	_expect(_main.game_over and _minion_test_units().is_empty(), "5:05 加时结束，不生成理论上的下一波兵线")

	for index in _main._towers.size():
		_main._towers[index].hp = tower_hps[index]

	_clear_minion_test_units()
	_main._pending_lane_minions.clear()
	var enemy_left_hp: float = _main._towers[2].hp
	_main._towers[2].hp = 0.0
	_main._battle_elapsed = 0.0
	_main._spawn_minion_wave(_main.MINION_WAVE_NORMAL)
	var upgraded_front_ok := false
	var untouched_front_ok := false
	for minion in _minion_test_units():
		if minion.team == 0 and minion.position.x < _main.FIELD_W * 0.5:
			upgraded_front_ok = minion.card_id == "super_minion"
		elif minion.team == 0 and minion.position.x > _main.FIELD_W * 0.5:
			untouched_front_ok = minion.card_id == "melee_minion"
	_expect(upgraded_front_ok and untouched_front_ok, "推掉敌方左塔后，仅己方左路后续近战兵替换为超级兵")
	_main._towers[2].hp = enemy_left_hp
	_clear_minion_test_units()
	_main._pending_lane_minions.clear()
	_main._battle_elapsed = 0.0
	_main._next_minion_wave_time = _main.FIRST_MINION_WAVE_TIME
	_main._match_timer = _main.MATCH_TIME
	_main._overtime = false
	_main.game_over = false
	_main._sim_acc = 0.0
	_main._minion_waves_enabled = old_waves_enabled

func _run_scheduled_wave(elapsed_before: float, wave_time: float, wave_type: String, overtime: bool = false) -> bool:
	_clear_minion_test_units()
	_main._pending_lane_minions.clear()
	_main._battle_elapsed = elapsed_before
	_main._next_minion_wave_time = wave_time
	_main._match_timer = _main.OVERTIME_TIME if overtime else _main.MATCH_TIME
	_main._overtime = overtime
	_main._tick_minion_waves(0.05)
	var front_only_ok := _minion_test_units().size() == 4
	for minion in _minion_test_units():
		front_only_ok = front_only_ok and minion.card_id in ["melee_minion", "super_minion"]
	_main._tick_minion_waves(0.5)
	return front_only_ok and _wave_cards_ok("melee_minion", "siege_minion" if wave_type == _main.MINION_WAVE_SIEGE else "ranged_minion")

func _wave_cards_ok(front_card: String, rear_card: String) -> bool:
	var units := _minion_test_units()
	if units.size() != 8:
		return false
	var front_count := 0
	var rear_count := 0
	var ready_ok := true
	for minion in units:
		if minion.card_id == front_card:
			front_count += 1
		elif minion.card_id == rear_card:
			rear_count += 1
		ready_ok = ready_ok and minion.is_deployed() and is_equal_approx(minion._deploy_timer, 0.0)
	return front_count == 4 and rear_count == 4 and ready_ok

func _check_death_animation_durations() -> void:
	var cards := CardDB.all()
	var hero_ids := ["garen", "xin", "ashe", "teemo", "masteryi", "gwen", "sett", "aurelionsol"]
	var minion_ids := ["melee_minion", "ranged_minion", "siege_minion", "super_minion"]
	var durations_ok := true
	for card_id in hero_ids:
		durations_ok = durations_ok and is_equal_approx(float(cards[card_id].visual_animations.get("death_duration", 0.0)), 0.8)
	for card_id in minion_ids:
		durations_ok = durations_ok and is_equal_approx(float(cards[card_id].visual_animations.get("death_duration", 0.0)), 0.5)
	_expect(durations_ok, "全部英雄死亡动画统一为 0.8 秒，四类小兵统一为 0.5 秒")
	_expect(
		_runtime_death_speed_matches("garen", 0.8)
		and _runtime_death_speed_matches("melee_minion", 0.5),
		"通用 3D 表现层按配置时长缩放英雄与小兵的死亡动画"
	)

func _runtime_death_speed_matches(card_id: String, expected_duration: float) -> bool:
	var stats: Dictionary = CardDB.get_card(card_id).duplicate(true)
	stats["deploy_time"] = 0.0
	var unit := Unit.new()
	unit.position = Vector2(360.0, 900.0)
	unit.card_id = card_id
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var attached: bool = _main._battle_presentation.attach_unit(unit, stats)
	unit.take_damage(unit.max_hp + 1.0)
	var playback_ok := false
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			var view := child as UnitModel3D
			var animation := view._animation_player.get_animation(view._death_animation) if view._animation_player != null else null
			if animation != null and animation.length > 0.0:
				var expected_speed: float = animation.length / expected_duration
				playback_ok = is_equal_approx(view._animation_player.get_playing_speed(), expected_speed)
			view.free()
			break
	if is_instance_valid(unit):
		unit.free()
	return attached and playback_ok

func _minion_test_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for combatant in _main.get_tree().get_nodes_in_group("combatants"):
		if combatant is Unit and ["melee_minion", "ranged_minion", "siege_minion", "super_minion"].has(combatant.card_id):
			result.append(combatant as Unit)
	return result

func _clear_minion_test_units() -> void:
	for minion in _minion_test_units():
		minion.free()

func _check_tombstone_footprint() -> void:
	var snapped: Vector2 = _main._snap_card_position("tombstone", Vector2(467.0, 1093.0))
	_expect(fmod(snapped.x, _main.TILE_SIZE) == 0.0 and fmod(snapped.y, _main.TILE_SIZE) == 0.0, "2x2 墓碑中心吸附在格线交点")
	var tombstone: Unit = _main._spawn_unit(0, "tombstone", snapped)
	var half_size_ok := is_equal_approx(tombstone.body_radius, _main.TILE_SIZE)
	var first := Vector2(snapped.x - 20.0, snapped.y - 20.0)
	var occupied := true
	for offset in [Vector2.ZERO, Vector2(40.0, 0.0), Vector2(0.0, 40.0), Vector2(40.0, 40.0)]:
		occupied = occupied and not _main.nav.is_walkable(first + offset)
	_expect(half_size_ok and occupied, "墓碑实际占据完整 2x2 格并写入导航障碍")
	tombstone._die()

func _check_tombstone_does_not_push_air_units() -> void:
	# 空军在墓碑落地时不受建筑部署推挤影响，位置应保持不变。
	var dragon_stats: Dictionary = CardDB.get_card("aurelionsol").duplicate(true)
	dragon_stats["deploy_time"] = 0.0
	var dragon := Unit.new()
	# 墓碑 2x2 吸附到格线交点；龙王也放在同一中心，确保 overlap 触发推挤分支。
	var shared_pos: Vector2 = Vector2(480.0, 1080.0)
	dragon.position = shared_pos
	dragon.setup(0, dragon_stats, dragon_stats.name)
	_main.add_child(dragon)
	var before_pos: Vector2 = dragon.global_position
	_expect(dragon.is_air, "龙王 is_air=true，属于空军")
	# 先直接调用 _push_units_around：墓碑 radius=40，龙王 radius≈21，中心距 0 < 61 → 若不加 is_air 保护必推。
	_main._push_units_around(shared_pos, 40.0)
	var after_direct: Vector2 = dragon.global_position
	_expect(before_pos.is_equal_approx(after_direct), "直接推挤时龙王位置不动：before=%s after=%s" % [str(before_pos), str(after_direct)])
	# 再走 _execute_card_deployment 真实链路：building 分支会先 _push_units_around 再生成墓碑。
	_main._execute_card_deployment(0, "tombstone", shared_pos)
	var after_execute: Vector2 = dragon.global_position
	_expect(before_pos.is_equal_approx(after_execute), "真实墓碑落地在龙王上方时，龙王位置仍保持不变")
	# 清理：查找生成的墓碑并销毁
	for c in _main.get_tree().get_nodes_in_group("combatants"):
		if c is Unit and (c as Unit).card_id == "tombstone" and c.global_position.is_equal_approx(shared_pos):
			(c as Unit)._die()
			break
	dragon.free()

func _check_tombstone_spawn_cycle() -> void:
	var stats: Dictionary = CardDB.get_card("tombstone").duplicate(true)
	stats["deploy_time"] = 0.0
	var left := Unit.new()
	left.position = Vector2(240.0, 900.0)
	left.setup(0, stats, stats.name)
	_main.add_child(left)
	var before_left := _imp_units()
	left.sim_tick(_main.SIM_DT)
	var after_initial := _imp_units()
	var initial_count := after_initial.size() - before_left.size()
	var initial_left_side := true
	for imp in after_initial:
		if not before_left.has(imp):
			initial_left_side = initial_left_side and imp.position.x < left.position.x
	var initial_ready := true
	for imp in after_initial:
		if not before_left.has(imp):
			initial_ready = initial_ready and imp.is_deployed() and is_equal_approx(imp._deploy_timer, 0.0)
	_expect(initial_count == 2 and initial_left_side and initial_ready, "墓碑完成部署后立即在地图左侧连续生成两个无需部署读条的小鬼")
	left.sim_tick(4.95)
	var after_periodic := _imp_units()
	_expect(after_periodic.size() - after_initial.size() == 2, "墓碑每 5 秒额外生成两个小鬼")

	var right := Unit.new()
	right.position = Vector2(480.0, 900.0)
	right.setup(1, stats, stats.name)
	_main.add_child(right)
	var before_right := _imp_units()
	right.sim_tick(_main.SIM_DT)
	var after_right := _imp_units()
	var right_count := after_right.size() - before_right.size()
	var initial_right_side := true
	for imp in after_right:
		if not before_right.has(imp):
			initial_right_side = initial_right_side and imp.position.x > right.position.x
	_expect(right_count == 2 and initial_right_side, "墓碑完成部署后立即在地图右侧生成两个小鬼")

	var diagonal_corner := left.position + Vector2(40.0, 40.0)
	var direct_overlap := left.position + Vector2(30.0, 0.0)
	_expect(
		_main.is_ground_position_walkable(diagonal_corner, CardDB.RADIUS_EXTREMELY_SMALL)
		and not _main.is_ground_position_walkable(direct_overlap, CardDB.RADIUS_EXTREMELY_SMALL),
		"墓碑 2x2 格占地的实际碰撞为内切圆，圆角外可通行而边缘内不可穿过"
	)
	for imp in _imp_units():
		imp.free()
	left.free()
	right.free()


func _check_generic_periodic_summon() -> void:
	var stats: Dictionary = CardDB.get_card("tombstone").duplicate(true)
	stats["spawn_id"] = "melee_minion"
	stats["spawn_count"] = 1
	stats["spawn_side"] = ""
	var generator := Unit.new()
	generator.position = Vector2(360.0, 900.0)
	generator.setup(0, stats, stats.name)
	_main.add_child(generator)
	var before: Unit = _main._latest_unit_for_card("melee_minion", 0)
	generator._spawn_batch()
	var summoned: Unit = _main._latest_unit_for_card("melee_minion", 0)
	_expect(summoned != null and summoned != before, "周期召唤建筑按 spawn_id 生成任意已登记单位，不再写死小鬼")
	if summoned != null and is_instance_valid(summoned):
		summoned.free()
	generator.free()

func _imp_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for combatant in _main.get_tree().get_nodes_in_group("combatants"):
		if combatant is Unit and (combatant as Unit).card_id == "imp":
			result.append(combatant as Unit)
	return result
