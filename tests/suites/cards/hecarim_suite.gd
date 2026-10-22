extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var source := _unit(0, Vector2(300, 1000))
	source._charged = true
	var snapshots := NetworkSnapshotSystem.new(main, main._projectile_system)
	var fixture = preload("res://tests/fixtures/network_fixture.gd")
	var payload: Array = fixture.snapshot_payload(snapshots, 77, source)
	var packet: Array = fixture.packet(snapshots, [payload], [], fixture.tower_payloads(snapshots), 0.0, main.runtime._match_rules.time_left, false)
	var decoded = snapshots.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE))
	_expect(decoded != null and decoded.packet[NetworkSnapshotSystem.S_UNITS][0][NetworkSnapshotSystem.U_CHARGED] == 1, "冲刺状态通过压缩快照显式同步，不依赖减速后的移速猜测")
	payload[NetworkSnapshotSystem.U_CHARGED] = 2
	_expect(snapshots.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE)) == null, "快照拒绝非法冲刺标志")
	source.cancel_charge()
	var edge_target := _unit(1, Vector2(439, 1000))
	var beyond_target := _unit(1, Vector2(443, 1000))
	var area_skill: Dictionary = CardDB.active_skills_for("hecarim")[0].duplicate(true)
	main._active_skill_effect_system.activate_continuous_area(source, area_skill)
	main._active_skill_effect_system.tick_effects(0.5)
	_expect(edge_target.hp == 830.0 and beyond_target.hp == 850.0, "120像素领域按身体边缘命中139像素中心目标，排除143像素中心目标")
	main._active_skill_effect_system.continuous_area_effects.clear()
	source.buffs.clear_family(&"timed_lifesteal")
	edge_target.free()
	beyond_target.free()
	var front := _unit(1, Vector2(370, 1000))
	var rear := _unit(1, Vector2(230, 1000))
	var outside := _unit(1, Vector2(420, 1000))
	var resolver: CombatResolver = main.combat_service()
	var result := resolver.resolve_attack_hit(0, source.position, front, 80.0, 0.0, 0.0, source, source.position, -1, {"self_radius": 85.0, "ground_only": true})
	_expect(result.landed and front.hp == 770.0 and rear.hp == 770.0 and outside.hp == 850.0, "旋斩以自身为中心同时命中前后，排除圈外")
	source.hp = 400.0
	var skill: Dictionary = CardDB.active_skills_for("hecarim")[0].duplicate(true)
	main._active_skill_effect_system.activate_continuous_area(source, skill)
	for tick in 9: main._active_skill_effect_system.tick_effects(0.05)
	_expect(source.hp == 400.0 and front.hp == 770.0, "领域半秒前不提前伤害或回血")
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(front.hp == 750.0 and rear.hp == 750.0 and outside.hp == 830.0, "领域第10Tick命中全部范围目标")
	_expect(source.hp == 418.0, "领域按三目标真实掉血30%治疗")
	resolver.resolve_attack_hit(0, source.position, front, 80.0, 0.0, 0.0, source, source.position, -1, {"self_radius": 85.0, "ground_only": true})
	_expect(source.hp == 466.0, "领域中旋斩对两个目标的真实掉血均吸血")
	main._active_skill_effect_system.continuous_area_effects.clear()
	source.buffs.clear_family(&"timed_lifesteal")
	source._move_intent = Vector2.UP * 76.0
	for tick in 39: source.on_movement_applied(3.0, 0.05)
	_expect(not source._charged, "117像素尚未蓄满")
	source.on_movement_applied(3.0, 0.05)
	_expect(source._charged, "累计120像素即3格进入冲刺")
	source.cancel_charge()
	for tick in 120: source.on_movement_applied(1.0, 0.05)
	_expect(source._charged, "慢速移动用更长时间走满3格同样蓄满")
	source.cancel_charge()
	source.on_movement_applied(119.0, 10.0)
	_expect(not source._charged, "时间再长但不足3格仍不蓄满")
	source.on_movement_applied(0.0, 0.05)
	_expect(source._charge_distance_travelled == 0.0, "受阻停止清空连续移动距离")
	for unit in [front, rear, outside]: unit.free()
	var target := _unit(1, Vector2(410, 1000))
	source._charged = true
	_expect(source.movement_strike.tick(source, 0.05), "2格范围内启动突进")
	for tick in 20:
		if source.movement_strike.target_ref == null: break
		source.global_position += source._move_intent * 0.05
		source._move_intent = Vector2.ZERO
		source.movement_strike.tick(source, 0.05)
	_expect(target.hp == 770.0 and target.control.stun_timer == 1.5, "接触后单次伤害与1.5秒眩晕")
	_expect(not source._charged and source.movement_strike.target_ref == null, "命中消费蓄势")
	var q_view = load("res://assets/units/hecarim/hecarim_view.tscn").instantiate()
	main.add_child(q_view)
	q_view.configure_unit_visual(source)
	source._attacking = true
	source._attack_visual_serial = 1
	source.attack_timeline.visual_elapsed = 0.2
	q_view.advance_ambient_visual(0.0)
	_expect(not q_view._cas.visible, "冲刺动作仍在播放时不叠加Q刀光")
	source._visual_action_time_left = 0.0
	q_view.advance_ambient_visual(0.0)
	_expect(source.get_visual_action_name() == &"charge_strike" and q_view._cas.visible and q_view._buf.visible, "冲刺名称保留但窗口结束后恢复Q施放与附着层")
	source._attack_visual_serial += 1
	source.attack_timeline.visual_elapsed = 0.25
	q_view.advance_ambient_visual(0.0)
	_expect(q_view._cas.visible, "冲刺后的后续连续普攻继续播放Q")
	_expect(q_view._buf._pools[7].is_empty() and q_view._buf._ribbon.mesh.get_surface_count() == 1, "Q武器拖尾使用连续带状网格而非固定火焰面片")
	var geometry = preload("res://assets/effects/hecarim/geometry.gd")
	_expect(is_equal_approx(517.7974672797 * geometry.W_SCALE * geometry.PIXELS_PER_WORLD, 120.0), "W原版绿色指示线的中心半径为120像素")
	var early_anchor: Array = q_view._buf._weapon_points[0]
	var swing_anchor: Array = q_view._buf._weapon_points[48]
	_expect(Vector3(early_anchor[0],early_anchor[1],early_anchor[2]).distance_to(Vector3(swing_anchor[0],swing_anchor[1],swing_anchor[2])) > 1.0, "Q拖尾挂点来自旋斩动画中的实际武器轨迹")
	q_view.reset_pool_visual()
	_expect(not q_view._cas.visible and not q_view._buf.visible, "模型回收清理Q特效")
	q_view.free()
	source._attacking = false
	source.attack_timeline.cancel(true)
	source.position = Vector2(300,1000)
	source._charged = true
	source.movement_strike.tick(source, 0.05)
	source.stun(1.0)
	source.sim_tick(0.05)
	_expect(source.movement_strike.target_ref == null and not source._charged, "硬控取消突进，不在控制结束后补打")
	source.control.hard.clear_family(&"stun")
	source.cancel_charge()
	source.attack_timeline.cancel(true)
	source.position = Vector2(300,1000)
	target.position = Vector2(423,1000)
	source._charged = true
	_expect(not source.movement_strike.tick(source,0.05), "两格之外不触发冲刺")
	target.position = Vector2(420,1000)
	_expect(source.movement_strike.tick(source,0.05), "两格内触发冲刺")
	for tick in 20:
		if source.movement_strike.target_ref == null: break
		main._movement.tick(0.05)
		source._move_intent = Vector2.ZERO
		source.movement_strike.tick(source,0.05)
	_expect(source._target_gap(target) >= -0.05 and target.hp == 690.0, "真实移动系统保持身体分离并结算一次冲击")
	source.cancel_charge()
	source.attack_timeline.cancel(true)
	source.position = Vector2(350,700)
	target.position = Vector2(350,580)
	source._charged = true
	_expect(not source.movement_strike.tick(source,0.05), "两格极限跨河没有合法前侧站位时不启动")
	source.cancel_charge()
	source.position = Vector2(300,1000)
	target.position = Vector2(370,1000)
	source.hp = 400.0
	target.hp = 5.0
	main._active_skill_effect_system.activate_continuous_area(source, skill)
	main._active_skill_effect_system.tick_effects(0.5)
	_expect(source.hp == 402.0, "领域过量伤害只按5点实际掉血治疗并遵守统一整数规则")
	source.freeze(1.0)
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(main._active_skill_effect_system.continuous_area_effects.is_empty() and source.buffs.remaining(&"timed_lifesteal") == 0.0, "冰冻同时取消领域和限时吸血")
	source.free()
	if is_instance_valid(target): target.free()

func _unit(team: int, point: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, "hecarim", point, {"deploy_time_override": 0.0}))
