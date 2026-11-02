extends "res://tests/suites/battle_suite.gd"
func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	for tower in main.world.towers_snapshot(): tower.can_attack = false
	var passive: Dictionary = CardDetails.passives(CardDB.get_card("vine_lasher"))[0]
	_expect(passive.name == "攻击减速" and not "万箭齐发" in passive.description, "详情不误套寒冰专属被动说明")
	_expect(CardDetails.passives(CardDB.get_card("ashe")).any(func(row): return row.name == "冰霜射击" and "万箭齐发" in row.description), "寒冰详情保留真实技能触发说明")
	var plant := _spawn_ready_unit("vine_lasher", 0, Vector2(200,1000))
	var target := _spawn_ready_unit("target_dummy", 1, Vector2(200,920))
	var air := _spawn_ready_unit("anivia", 1, Vector2(200,910))
	target.can_attack = false
	air.can_attack = false
	_expect(plant._target_is_attackable(target) and not plant._target_is_attackable(air), "藤蔓只选择地面目标")
	var before := target.hp
	var projectiles: int = main._projectile_system.projectiles.size()
	plant._attack_visual_serial += 1
	plant._perform_attack_strike(target, plant.damage)
	_expect(target.hp == before - 100.0 and main._projectile_system.projectiles.size() == projectiles, "近战命中100伤害不创建弹体")
	_expect(target.control.slow_multiplier == 0.7 and target.control.slow_timer == 2.0, "命中减速30%持续2秒")
	target.control.tick_slows(1.0)
	plant._attack_visual_serial += 1
	plant._perform_attack_strike(target, plant.damage)
	_expect(target.control.slow_multiplier == 0.7 and target.control.slow_timer == 2.0, "重复命中只刷新不叠减速")
	target.control.tick_slows(1.95)
	_expect(target.movement_slow_visual(), "39Tick仍减速")
	target.control.tick_slows(0.05)
	_expect(not target.movement_slow_visual(), "40Tick减速到期")
	var skill: Dictionary = CardDB.active_skills_for("vine_lasher")[0]
	_expect(skill.cost == 2 and skill.health_bonus_ratio == 0.5 and CardDB.get_card("vine_lasher").range == 100.0, "缠绕之根2金币50%生命且射程2.5格")
	_expect(UIPalette.card_border(CardDB.get_card("vine_lasher").color) == UIPalette.CARD_EMBER, "藤蔓卡框采用红色系")
	plant.hp = 400.0
	main.preview_active_skill(plant, skill)
	_expect(plant.max_hp == 1080.0 and plant.hp == 760.0 and plant.body_radius == 26.25, "缠绕之根增加360生命及25%碰撞")
	_expect(is_equal_approx(plant.get_active_attack_speed_multiplier_visual(),1.6) and plant.active_damage_multiplier == 1.0, "强化攻速60%不加单次伤害")
	main.preview_active_skill(plant, skill)
	_expect(plant.hp == 760.0 and plant.max_hp == 1080.0, "刷新不重复补血")
	plant._tick_active_statuses(6.0)
	_expect(plant.hp == 720.0 and plant.max_hp == 720.0 and plant.body_radius == 21.0 and plant.get_active_attack_speed_multiplier_visual() == 1.0, "6秒到期恢复上限体型攻速仅裁剪溢出生命")
	plant._tick_building_lifetime(1.0)
	_expect(plant.hp == 690.0, "24秒基准每秒自然衰减30生命")
	var view = load("res://assets/units/vine_lasher/vine_lasher_view.tscn").instantiate()
	main.add_child(view)
	view.scale = Vector3.ONE * 1.25
	var buff = load("res://assets/effects/thorn_spitter/buff.tscn").instantiate()
	main.add_child(buff)
	buff.configure(30.0,0)
	buff.bind_model(view)
	buff.status_state = Vector2(0.5,6.0)
	buff.advance_status(true,true,0.0)
	_expect(view.is_ancestor_of(buff._player) and buff._player.get_parent() == buff._anchor, "特效挂在放大模型骨架内")
	_expect(is_equal_approx(buff._player.global_basis.get_scale().abs().x,0.016/1.2*1.25), "原版特效只随模型放大一次")
	buff.free()
	view.free()
	plant.free()
	target.free()
	air.free()
