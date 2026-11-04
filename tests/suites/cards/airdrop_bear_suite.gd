extends RefCounted
var h
var m: Node2D
var spells: SpellSystem
var sound_cues: Array[String] = []
func _capture_event(kind: String, data: Dictionary) -> void:
	if kind == "card_event" and data.card_id == "airdrop_bear": sound_cues.append(String(data.cue))
func run(harness, main: Node2D) -> void:
	h = harness
	m = main
	spells = m._spell_system
	m.runtime.event.connect(_capture_event)
	var stats := CardDB.get_card("airdrop_bear")
	var loop_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/airdrop_bear/aura/sampled.json"))
	check(loop_data.has("loop_start_frame") and loop_data.loop_duration == 10.0, "常驻启动段与完整生命周期循环分离")
	var final_frame: Array = loop_data.frames.back()
	var first_frame: Array = loop_data.frames[int(loop_data.loop_start_frame)]
	for i in loop_data.emitters.size():
		if loop_data.emitters[i].lifetime != null:
			check(first_frame[i].is_empty() and final_frame[i].is_empty(), "启动烟雾不重复发射")
			continue
		var previous := {}
		for particle in final_frame[i]: previous[int(particle[0])] = particle
		var continuous := 0
		for particle in first_frame[i]:
			if not previous.has(int(particle[0])): continue
			var before: Array = previous[int(particle[0])]
			if Vector3(particle[1], particle[2], particle[3]).distance_to(Vector3(before[1], before[2], before[3])) < 10.0: continuous += 1
		check(continuous > 0, "跨周期火焰粒子延续且位置连续")
	for kind in ["impact", "aura", "body"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/airdrop_bear/" + kind + "/sampled.json"))
		for emitter in data.emitters:
			if int(emitter.uvMode) != 2: continue
			var material := preload("res://assets/effects/airdrop_bear/player.gd")._material(emitter)
			check(material.get_shader_parameter("fixed_alpha_uv") and not material.get_shader_parameter("has_erosion") and not material.get_shader_parameter("has_soft"), "原LOCK_ALPHA火焰固定轮廓且不走溶解/软粒子：" + kind)
	for field in ["spell_windup", "duration", "spawn_deploy_time"]:
		for invalid in [-1.0, INF, NAN]:
			var bad := stats.duplicate(true)
			bad[field] = invalid
			var errors: Array = CardDB.VALIDATOR.validate_all({"airdrop_bear": bad, "tibbers": CardDB.get_card("tibbers")}, false)
			check(errors.any(func(error): return field in error), "拒绝非法阶段时长：" + field)
	var center := Vector2(360, 800)
	check(stats.cost == 4 and stats.active_cost_bonus == 2, "4费、强化6费")
	check(not CardDB.get_card("tibbers").selectable, "衍生单位不进选卡库")
	for team in [0, 1]:
		check(m.runtime.is_card_deploy_position_valid(team, "airdrop_bear", Vector2(360, 1000 if team == 0 else 280)), "双方己方半场")
		check(not m.runtime.is_card_deploy_position_valid(team, "airdrop_bear", Vector2(360, 280 if team == 0 else 1000)), "双方敌半场拒绝")
	check(stats.radius == 100.0 and stats.active_skills[0].radius == stats.radius, "落地与常驻火圈均为2.5格")
	var ground := spawn(1, "garen", center)
	var air := spawn(1, "anivia", center + Vector2(60, 0))
	var ally := spawn(0, "garen", center)
	var outside := spawn(1, "garen", center + Vector2(150, 0))
	var edge_in := spawn(1, "target_dummy", center + Vector2(99, 0))
	var edge_out := spawn(1, "target_dummy", center + Vector2(101, 0))
	edge_in.body_radius = 0.0
	edge_out.body_radius = 0.0
	spells.cast(0, stats, center)
	var landing: int = spells.bear_casts[0].impact_tick
	check(landing - m.get_authoritative_server_tick() == 30, "预警20Tick加下落10Tick")
	tick(landing - 11)
	check(not sound_cues.has("spell:cast"), "预警期间不播放召唤声")
	tick(landing - 10)
	check(sound_cues.count("spell:cast") == 1, "下降开始且落地前0.5秒播放召唤声")
	tick(landing - 9)
	check(sound_cues.count("spell:cast") == 1, "下降期间不重复召唤声")
	tick(landing - 1)
	check(bears().is_empty() and ground.hp == ground.max_hp, "落地前无单位无伤害")
	tick(landing)
	check(bears().size() == 1, "中心召出一只")
	check(sound_cues.count("spell:impact") == 1 and not sound_cues.has("spell:enraged"), "普通落地不误播狂暴获得音")
	check(bears()[0]._deploy_timer == 0.0 and bears()[0].deploy_time == 0.0, "落地无部署锁")
	check(not CardDB.get_card("tibbers").visual_animations.has("deploy"), "不播放出生动画")
	check(ground.hp == ground.max_hp - 160 and air.hp == air.max_hp - 160, "落地对地对空")
	check(ally.hp == ally.max_hp and outside.hp == outside.max_hp, "友军和范围外免伤")
	check(ground.control.stun_timer == 0 and not bears()[0].burning_aura, "普通无眩晕与火圈")
	check(bears()[0].global_position.distance_to(center) < 0.01, "合法中心不偏移")
	for unit in bears(): unit.free()
	ground.hp = ground.max_hp
	edge_in.hp = edge_in.max_hp
	air.hp = air.max_hp
	spells.cast(0, stats, center, true)
	landing = spells.bear_casts[0].impact_tick
	tick(landing)
	var bear: Unit = bears()[0]
	check(sound_cues.count("spell:enraged") == 1 and sound_cues.count("spell:impact") == 2, "强化落地同时派发一次爆发与狂暴获得音")
	check(ground.control.stun_timer == 1.5 and air.control.stun_timer == 1.5, "强化眩晕1.5秒")
	check(bear.burning_aura and is_equal_approx(bear.active_attack_speed_multiplier, 1.5), "永久火圈及50%攻速")
	tick(landing + 9)
	check(ground.hp == ground.max_hp - 160, "首个脉冲前不伤害")
	tick(landing + 10)
	check(ground.hp == ground.max_hp - 180 and air.hp == air.max_hp - 180, "0.5秒火圈对地对空20伤害")
	check(edge_in.hp == edge_in.max_hp - 180 and edge_out.hp == edge_out.max_hp, "落地与灼烧共同遵守100像素边界")
	bear.position += Vector2(200, 0)
	tick(landing + 20)
	check(ground.hp == ground.max_hp - 180 and outside.hp == outside.max_hp - 20, "火圈随熊移动")
	bear.apply_stasis(3.0)
	tick(landing + 30)
	check(outside.hp == outside.max_hp - 20, "凝滞抑制无补发")
	bear.control.clear_on_death()
	bear.freeze(2.0)
	tick(landing + 40)
	check(outside.hp == outside.max_hp - 40, "冰冻不取消火圈")
	bear.control.clear_on_death()
	bear.stun(2.0)
	tick(landing + 50)
	check(outside.hp == outside.max_hp - 60, "眩晕不取消火圈")
	check(sound_cues.count("spell:enraged") == 1, "凝滞冰冻眩晕恢复不重播狂暴获得音")
	bear.buffs.advance(5.0)
	check(is_equal_approx(bear.active_attack_speed_multiplier, 1.0) and bear.burning_aura, "攻速到期、灼烧常驻")
	var net = m._snapshot_system
	var payload: Array = preload("res://tests/fixtures/network_fixture.gd").snapshot_payload(net, 771, bear)
	check(payload[net.U_BURNING_AURA] == true, "快照包含永久灼烧")
	var frame: Array = preload("res://tests/fixtures/network_fixture.gd").packet(net, [payload], [], preload("res://tests/fixtures/network_fixture.gd").tower_payloads(net), 0, 100, false)
	check(net.decode_validated(var_to_bytes(frame).compress(FileAccess.COMPRESSION_DEFLATE)) != null, "完整新增快照可解析")
	frame[net.S_UNITS][0][net.U_BURNING_AURA] = 1
	check(net.decode_validated(var_to_bytes(frame).compress(FileAccess.COMPRESSION_DEFLATE)) == null, "非布尔灼烧拒绝")
	bear.hp = 0
	tick(landing + 60)
	check(spells.bear_auras.is_empty() and outside.hp == outside.max_hp - 60, "死亡终止火圈")
	bear.free()
	for unit in [ground, air, ally, outside, edge_in, edge_out]: unit.free()
	var shielded := spawn(1, "garen", center)
	shielded.buffs.apply(&"effect_shield", &"test", 5.0, {})
	spells.cast(0, stats, center, true)
	tick(spells.bear_casts[0].impact_tick)
	check(shielded.hp == shielded.max_hp and shielded.control.stun_timer == 0, "法术盾同时挡落地伤害与控制")
	check(bears().size() == 1, "法术盾不阻止召熊")
	shielded.free()
	for unit in bears(): unit.free()
	spells.clear()
	for tower in m.world.towers_snapshot():
		var hp: float = tower.hp
		spells.cast(1-tower.team, stats, tower.position, true)
		tick(spells.bear_casts[0].impact_tick)
		check(tower.hp == hp - 48, "防御塔水晶30%落地伤害")
		check(tower.control.stun_timer == (0.0 if tower.is_king else 1.5), "水晶免疫控制、防御塔可眩晕")
		tower.hp = hp
		tower.control.clear_on_death()
		for unit in bears(): unit.free()
		spells.clear()
	spells.cast(0, stats, center, true)
	spells.clear()
	tick(m.get_authoritative_server_tick() + 100)
	check(bears().is_empty(), "清场取消未落地法术")
	spells.show_flight(900, "airdrop_bear", center, center, 100, 0, 10)
	check(spells.bear_casts.is_empty() and spells.bear_auras.is_empty(), "表现事件不创建权威结果")
	spells.clear()
	_check_command_timing(center)
	m.runtime.event.disconnect(_capture_event)
func _check_command_timing(center: Vector2) -> void:
	var deck: Array = m.runtime._deck
	var cycle: Variant = m.runtime._authoritative_card_cycles.get(0)
	var account: Variant = m.runtime.account(0)
	var wallet := ElixirManager.new()
	m.add_child(wallet)
	wallet.elixir = 10.0
	m.runtime.bind_account(0, wallet)
	m.runtime._deck = ["airdrop_bear", "garen", "ashe", "teemo", "xin", "freeze", "heal", "pix"]
	m.runtime._authoritative_card_cycles[0] = CardCycle.new(m.runtime._deck, false)
	var cast_count := sound_cues.count("spell:cast")
	var start: int = m.get_authoritative_server_tick()
	check(m.play_card(0, "airdrop_bear", center), "正式出牌入口接受")
	m.runtime._sim_tick_id = start + 9
	m.runtime._tick_pending_card_deployments(0.05)
	check(spells.bear_casts.is_empty() and bears().is_empty(), "命令缓冲内没有预警与熊")
	m.runtime._sim_tick_id = start + 10
	m.runtime._tick_pending_card_deployments(0.05)
	check(spells.bear_casts.size() == 1 and int(spells.bear_casts[0].impact_tick) == start + 40, "公共10Tick加预警20Tick加下落10Tick")
	check(sound_cues.count("spell:cast") == cast_count, "正式出牌预警开始不提前播放召唤声")
	tick(start + 30)
	check(sound_cues.count("spell:cast") == cast_count + 1, "正式出牌第30Tick下降时播放召唤声")
	tick(start + 39)
	check(bears().is_empty(), "正式出牌第39Tick仍无实体")
	tick(start + 40)
	check(bears().size() == 1 and bears()[0]._deploy_timer == 0.0, "正式出牌第40Tick落地且立即解锁")
	for bear in bears(): bear.free()
	spells.clear()
	m.runtime._deck = deck
	if cycle != null: m.runtime._authoritative_card_cycles[0] = cycle
	else: m.runtime._authoritative_card_cycles.erase(0)
	m.runtime.bind_account(0, account)
	wallet.free()
func bears() -> Array:
	return m.get_tree().get_nodes_in_group("combatants").filter(func(u): return u is Unit and u.card_id == "tibbers")
func spawn(team: int, id: String, pos: Vector2) -> Unit:
	return m._spawn_unit(UnitSpawnRequest.new(team, id, pos, {"deploy_time_override": 0.0}))
func tick(value: int) -> void:
	m.runtime._sim_tick_id = value
	m.combat_service().begin_batch(value, "bear_test")
	spells.tick(0.05)
	m.combat_service().commit_batch()
func check(ok: bool, message: String) -> void:
	h._expect(ok, "空投熊：" + message)
