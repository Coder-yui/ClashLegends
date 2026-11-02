extends "res://tests/suites/battle_suite.gd"
func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	for tower in main.world.towers_snapshot(): tower.can_attack = false
	for unit in main.get_tree().get_nodes_in_group("combatants"):
		if unit is Unit: unit.free()
	var plant := _spawn_ready_unit("thorn_spitter", 0, Vector2(200, 1000))
	var target := _spawn_ready_unit("target_dummy", 1, Vector2(200, 820))
	target.can_attack = false
	var nav_before: Array = plant.nav_cells.duplicate()
	var nav_revision: int = _main.world.nav.revision
	var skill: Dictionary = CardDB.active_skills_for("thorn_spitter")[0]
	_expect(skill.name == "致命棘刺" and skill.cost == 2 and skill.duration == 6.0, "致命棘刺名称费用持续时间")
	_expect(skill.health_bonus_ratio == 0.5 and UIPalette.card_border(CardDB.get_card("thorn_spitter").color) == UIPalette.CARD_EMBER, "致命棘刺50%生命与红色卡框")
	plant.hp = 500.0
	_main.preview_active_skill(plant, skill)
	_expect(plant.max_hp == 1200.0 and plant.hp == 900.0, "增加50%上限并获得新增400生命")
	_expect(is_equal_approx(plant.body_radius, 26.25) and is_equal_approx(plant.visual_radius, 37.5), "权威碰撞与模型尺寸均增大25%")
	_expect(is_equal_approx(plant.surface_gap_to_circle(plant.position + Vector2(40,0), 0), 13.75), "攻击和碰撞查询读取增大后的半径")
	_expect(_main.world.nav.revision > nav_revision and plant.nav_cells == _main.world.nav.cells_for_circle(plant.global_position, plant.body_radius + ArenaRules.NAV_CLEARANCE), "增大同步重建建筑导航障碍")
	_expect(plant.get_active_attack_speed_multiplier_visual() == 1.0, "强化伤害不增加攻速")
	_main.preview_active_skill(plant, skill)
	_expect(plant.max_hp == 1200.0 and plant.hp == 900.0 and plant.body_radius == 26.25, "重复刷新不叠加生命和体型")
	plant._attack_visual_serial = 1
	var before: int = _main._projectile_system.projectiles.size()
	_expect(plant.active_damage_multiplier == 1.5, "技能提高伤害至150%")
	plant._perform_attack_strike(target, plant.damage * plant.active_damage_multiplier)
	plant._queue_extra_attack_hits(0, 100.0, target)
	plant._tick_pending_extra_attacks(0.2)
	_expect(_main._projectile_system.projectiles.size() == before + 1 and plant._pending_extra_attacks.is_empty(), "强化仍只发射一枚，不排追加攻击")
	var hp_before := target.hp
	for tick in 12: _main._projectile_system.tick(0.05)
	_expect(target.hp == hp_before - 150.0, "强化单发真实造成150伤害")
	plant._tick_active_statuses(5.95)
	_expect(plant.max_hp == 1200.0 and plant.timed_growth_stats.y == 1.25, "119Tick仍保持强化")
	plant.hp = 1000.0
	plant._tick_active_statuses(0.05)
	_expect(plant.max_hp == 800.0 and plant.hp == 800.0 and plant.body_radius == 21.0 and plant.visual_radius == 30.0, "120Tick恢复体型上限并裁剪超额生命")
	_expect(plant.nav_cells == nav_before, "到期恢复原导航圆形障碍，释放扩张格")
	before = _main._projectile_system.projectiles.size()
	plant._tick_pending_extra_attacks(0.15)
	_expect(_main._projectile_system.projectiles.size() == before and plant.active_damage_multiplier == 1.0, "到期无追加攻击且恢复原伤害")
	_main.preview_active_skill(plant, skill)
	plant.hp = 600.0
	plant._tick_active_statuses(6.0)
	_expect(plant.max_hp == 800.0 and plant.hp == 600.0, "到期不扣未溢出的现有生命")
	_main.preview_active_skill(plant, skill)
	_check_snapshot(plant)
	_check_visual()
	plant.free()
	target.free()

func _check_snapshot(plant: Unit) -> void:
	var fixture = preload("res://tests/fixtures/network_fixture.gd")
	var payload: Array = fixture.snapshot_payload(_main._snapshot_system, 955, plant)
	var packet: Array = fixture.packet(_main._snapshot_system, [payload], [], fixture.tower_payloads(_main._snapshot_system), 0, 180, false)
	_expect(payload[NetworkSnapshotSystem.U_TIMED_GROWTH] == Vector2(400,1.25), "快照同步临时增量及体型")
	_expect(_main._snapshot_system.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE)) != null, "临时成长快照正式解码")
	for invalid in [Vector2(-1,1.25), Vector2(400,0.5), Vector2(INF,1.25), 1]:
		var bad := packet.duplicate(true)
		bad[NetworkSnapshotSystem.S_UNITS][0][NetworkSnapshotSystem.U_TIMED_GROWTH] = invalid
		_expect(_main._snapshot_system.decode_validated(var_to_bytes(bad).compress(FileAccess.COMPRESSION_DEFLATE)) == null, "非法临时成长整包拒绝")

func _check_visual() -> void:
	var view = load("res://assets/units/thorn_spitter/thorn_spitter_view.tscn").instantiate()
	_main.add_child(view)
	var muzzle: BoneAttachment3D = view.create_projectile_anchor()
	var center: BoneAttachment3D = view.create_buff_anchor()
	_expect(muzzle.get_parent().get_bone_name(muzzle.bone_idx) == "Buffbone_Glb_Weapon_1", "弹体挂接原模型武器骨")
	_expect(center.get_parent().get_bone_name(center.bone_idx) == "C_Buffbone_Glb_Center_Loc", "强化挂接原模型中心骨")
	_expect(is_equal_approx(view.native_effect_scale(), 0.016/1.2), "粒子缩放区分源skinScale")
	view.scale = Vector3.ONE * 1.25
	_expect(is_equal_approx(view.native_effect_scale(), 0.016/1.2*1.25), "强化特效随模型增大一次")
	var buff = load("res://assets/effects/thorn_spitter/buff.tscn").instantiate()
	_main.add_child(buff)
	buff.configure(30.0, 0)
	buff.bind_model(view)
	buff.status_state = Vector2(0.5, 6.0)
	buff.advance_status(true, true, 0.0)
	_expect(buff._player.get_parent() == buff._anchor and view.is_ancestor_of(buff._player), "强化粒子实际挂在放大模型的骨架层级下")
	var scale_before: float = buff._player.global_basis.get_scale().abs().x
	view.scale = Vector3.ONE
	_expect(is_equal_approx(buff._player.global_basis.get_scale().abs().x, scale_before / 1.25), "不调用特效advance也立即继承模型缩放")
	view.scale = Vector3.ONE * 1.25
	_expect(is_equal_approx(buff._player.global_basis.get_scale().abs().x, 0.016/1.2*1.25), "强化粒子只继承一次25%放大")
	_expect(buff._player.global_position.is_equal_approx(buff._anchor.global_position), "放大后的粒子原点与模型骨骼挂点一致")
	buff.status_state = Vector2(6.0, 6.0)
	buff.advance_status(true, true, 0.0)
	_expect(not buff._player.visible, "到期关闭骨架下的粒子，不遗留独立发光")
	buff.free()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/thorn_spitter/missile/sampled.json"))
	_expect(data.emitters.size() == 1 and data.emitters[0].name == "vine_thorn", "弹体仅保留原版尖刺网格")
	view.free()
